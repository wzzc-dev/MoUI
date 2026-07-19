import Foundation
import MoUIShellRuntimeBridge
import UIKit

public struct MOUIShellPlatformViewPlacement {
  public let identifier: String
  public let kind: String
  public let frame: CGRect
  public let clip: CGRect?
  public let properties: [String: String]

  init?(payload: [String: Any]) {
    guard
      let identifier = payload["id"] as? String,
      !identifier.isEmpty,
      let kind = payload["kind"] as? String,
      !kind.isEmpty,
      let frame = Self.rect(from: payload["frame"])
    else { return nil }
    self.identifier = identifier
    self.kind = kind
    self.frame = frame
    self.clip = Self.rect(from: payload["clip"])
    let encodedProperties = payload["properties"] as? [[String: Any]] ?? []
    var properties: [String: String] = [:]
    for property in encodedProperties {
      guard let key = property["key"] as? String else { continue }
      properties[key] = property["value"] as? String ?? ""
    }
    self.properties = properties
  }

  private static func rect(from value: Any?) -> CGRect? {
    guard
      let rect = value as? [String: Any],
      let origin = rect["origin"] as? [String: Any],
      let size = rect["size"] as? [String: Any]
    else { return nil }
    return CGRect(
      x: (origin["x"] as? NSNumber)?.doubleValue ?? 0,
      y: (origin["y"] as? NSNumber)?.doubleValue ?? 0,
      width: (size["width"] as? NSNumber)?.doubleValue ?? 0,
      height: (size["height"] as? NSNumber)?.doubleValue ?? 0
    )
  }
}

public final class MOUIShellPlatformViewEventSink {
  private let sessionGeneration: Int
  private let revision: Int
  private let viewKind: String
  private let identifier: String

  init(
    sessionGeneration: Int,
    revision: Int,
    viewKind: String,
    identifier: String
  ) {
    self.sessionGeneration = sessionGeneration
    self.revision = revision
    self.viewKind = viewKind
    self.identifier = identifier
  }

  @discardableResult
  public func send(
    name: String,
    value: String = "",
    detail: String = "",
    flag: Bool = false
  ) -> Bool {
    guard Thread.isMainThread, !name.isEmpty else { return false }
    let envelope: [String: Any] = [
      "schemaVersion": 1,
      "sessionGeneration": sessionGeneration,
      "response": [
        "kind": "platform-view",
        "revision": revision,
        "viewKind": viewKind,
        "id": identifier,
        "event": [
          "name": name,
          "value": value,
          "detail": detail,
          "flag": flag,
        ],
      ],
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return false }
    return MOUIShellRuntimeBridge.shared.dispatchHostResponseEnvelopeJSON(data) > 0
  }
}

public protocol MOUIShellPlatformViewFactory: AnyObject {
  func makePlatformView(identifier: String) -> UIView
  func updatePlatformView(
    _ view: UIView,
    placement: MOUIShellPlatformViewPlacement,
    events: MOUIShellPlatformViewEventSink
  )
  func disposePlatformView(_ view: UIView)
}

extension MOUIShellPlatformViewFactory {
  public func disposePlatformView(_ view: UIView) {}
}

public enum MOUIEmbedderHostChannelStatus: String {
  case ok
  case error
  case unavailable
}

public struct MOUIEmbedderHostChannelRequest {
  public let channel: String
  public let operation: String
  public let payload: String

  init?(payload: [String: Any]) {
    guard
      let channel = payload["channel"] as? String,
      !channel.isEmpty,
      let operation = payload["operation"] as? String,
      !operation.isEmpty,
      let body = payload["payload"] as? String
    else { return nil }
    self.channel = channel
    self.operation = operation
    self.payload = body
  }
}

public struct MOUIEmbedderHostChannelResponse {
  public let status: MOUIEmbedderHostChannelStatus
  public let payload: String

  public init(status: MOUIEmbedderHostChannelStatus, payload: String = "") {
    self.status = status
    self.payload = payload
  }
}

public protocol MOUIEmbedderHostChannelTask: AnyObject {
  func cancel()
}

public final class MOUIEmbedderHostChannelCompletion {
  private let lock = NSLock()
  private var finished = false
  private var deliver: ((MOUIEmbedderHostChannelResponse) -> Void)?

  init(deliver: @escaping (MOUIEmbedderHostChannelResponse) -> Void) {
    self.deliver = deliver
  }

  @discardableResult
  public func complete(_ response: MOUIEmbedderHostChannelResponse) -> Bool {
    lock.lock()
    guard !finished, let deliver else {
      lock.unlock()
      return false
    }
    finished = true
    self.deliver = nil
    lock.unlock()
    if Thread.isMainThread {
      deliver(response)
    } else {
      DispatchQueue.main.async { deliver(response) }
    }
    return true
  }

  @discardableResult
  public func succeed(payload: String = "") -> Bool {
    complete(MOUIEmbedderHostChannelResponse(status: .ok, payload: payload))
  }

  @discardableResult
  public func fail(payload: String) -> Bool {
    complete(MOUIEmbedderHostChannelResponse(status: .error, payload: payload))
  }

  @discardableResult
  public func unavailable(payload: String) -> Bool {
    complete(MOUIEmbedderHostChannelResponse(status: .unavailable, payload: payload))
  }

  func invalidate() {
    lock.lock()
    finished = true
    deliver = nil
    lock.unlock()
  }

  var isFinished: Bool {
    lock.lock()
    defer { lock.unlock() }
    return finished
  }
}

public protocol MOUIEmbedderHostChannelHandler: AnyObject {
  @discardableResult
  func handle(
    request: MOUIEmbedderHostChannelRequest,
    completion: MOUIEmbedderHostChannelCompletion
  ) -> MOUIEmbedderHostChannelTask?
}

public protocol MOUIShellPlugin {
  static var identifier: String { get }
  static func install(in registry: MOUIShellPluginRegistry)
  static func install(
    in registry: MOUIShellPluginRegistry,
    capabilities: MOUIShellPluginCapabilities
  )
}

extension MOUIShellPlugin {
  public static func install(
    in registry: MOUIShellPluginRegistry,
    capabilities: MOUIShellPluginCapabilities
  ) {
    install(in: registry)
  }
}

public final class MOUIShellPluginRegistry {
  public static let shared = MOUIShellPluginRegistry()

  private var platformViewFactories: [String: MOUIShellPlatformViewFactory] = [:]
  private var hostChannelHandlers: [String: MOUIEmbedderHostChannelHandler] = [:]
  private var installedPluginIdentifiers: Set<String> = []

  private init() {}

  public func install(
    _ plugins: [MOUIShellPlugin.Type],
    capabilities: MOUIShellPluginCapabilities = .shared
  ) {
    for plugin in plugins where installedPluginIdentifiers.insert(plugin.identifier).inserted {
      plugin.install(in: self, capabilities: capabilities)
    }
  }

  public func registerPlatformView(
    kind: String,
    factory: MOUIShellPlatformViewFactory
  ) {
    precondition(!kind.hasPrefix("moui."), "moui.* platform views are reserved")
    precondition(platformViewFactories[kind] == nil, "duplicate PlatformView kind: \(kind)")
    platformViewFactories[kind] = factory
  }

  public func registerHostChannel(
    name: String,
    handler: MOUIEmbedderHostChannelHandler
  ) {
    precondition(!name.hasPrefix("moui."), "moui.* host channels are reserved")
    precondition(hostChannelHandlers[name] == nil, "duplicate host channel: \(name)")
    hostChannelHandlers[name] = handler
  }

  func platformViewFactory(kind: String) -> MOUIShellPlatformViewFactory? {
    platformViewFactories[kind]
  }

  func hostChannelHandler(name: String) -> MOUIEmbedderHostChannelHandler? {
    hostChannelHandlers[name]
  }
}

final class MOUIShellPlatformViewOverlay {
  private struct ViewKey: Hashable {
    let kind: String
    let identifier: String
  }

  private struct HostedView {
    let factory: MOUIShellPlatformViewFactory
    let view: UIView
    let clipContainer: UIView
  }

  private weak var container: UIView?
  private var views: [ViewKey: HostedView] = [:]
  private var revision = -1

  init(container: UIView) {
    self.container = container
    container.isUserInteractionEnabled = true
    container.backgroundColor = .clear
  }

  func apply(snapshot: [String: Any], sessionGeneration: Int) {
    guard let container else { return }
    guard
      let nextRevision = (snapshot["revision"] as? NSNumber)?.intValue,
      nextRevision > revision
    else { return }
    revision = nextRevision
    let payloads = snapshot["placements"] as? [[String: Any]] ?? []
    var retained: Set<ViewKey> = []
    for payload in payloads {
      guard
        let placement = MOUIShellPlatformViewPlacement(payload: payload),
        let factory = MOUIShellPluginRegistry.shared.platformViewFactory(kind: placement.kind)
      else { continue }
      let key = ViewKey(kind: placement.kind, identifier: placement.identifier)
      retained.insert(key)
      let hosted: HostedView
      if let existing = views[key] {
        hosted = existing
      } else {
        let view = factory.makePlatformView(identifier: placement.identifier)
        let clipContainer = UIView(frame: .zero)
        clipContainer.clipsToBounds = true
        clipContainer.addSubview(view)
        hosted = HostedView(factory: factory, view: view, clipContainer: clipContainer)
        views[key] = hosted
        container.addSubview(clipContainer)
      }
      applyLayout(hosted, placement: placement)
      let events = MOUIShellPlatformViewEventSink(
        sessionGeneration: sessionGeneration,
        revision: nextRevision,
        viewKind: placement.kind,
        identifier: placement.identifier
      )
      hosted.factory.updatePlatformView(hosted.view, placement: placement, events: events)
      container.bringSubviewToFront(hosted.clipContainer)
    }
    for key in views.keys.filter({ !retained.contains($0) }) {
      remove(key)
    }
  }

  func reset() {
    for key in Array(views.keys) {
      remove(key)
    }
    revision = -1
  }

  private func applyLayout(
    _ hosted: HostedView,
    placement: MOUIShellPlatformViewPlacement
  ) {
    let visible = placement.clip?.intersection(placement.frame) ?? placement.frame
    if visible.isNull || visible.isEmpty {
      hosted.clipContainer.isHidden = true
      return
    }
    hosted.clipContainer.isHidden = false
    hosted.clipContainer.frame = visible
    hosted.view.frame = CGRect(
      x: placement.frame.minX - visible.minX,
      y: placement.frame.minY - visible.minY,
      width: placement.frame.width,
      height: placement.frame.height
    )
  }

  private func remove(_ key: ViewKey) {
    guard let hosted = views.removeValue(forKey: key) else { return }
    hosted.factory.disposePlatformView(hosted.view)
    hosted.clipContainer.removeFromSuperview()
  }
}
