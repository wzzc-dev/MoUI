import Foundation
import MoUIMobileRuntimeBridge

public final class MOUIMobileLaunchOptions {
  private let values: [String: String]

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    var values = environment
    if let enabled = environment["MOUI_MOBILE_TEST_PROBE"] {
      values["moui.mobile.testProbe"] = enabled
    }
    self.values = values
  }

  public func value(for key: String) -> String? {
    values[key]
  }

  public func isEnabled(_ key: String) -> Bool {
    guard let value = value(for: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    else { return false }
    return ["1", "true", "yes", "on"].contains(value)
  }
}

public struct MOUIMobileSemanticsNodeSnapshot {
  public let elementIdentifier: Int32
  public let role: String
  public let label: String
}

public struct MOUIMobileSemanticsSnapshot {
  public let sessionGeneration: Int
  public let revision: Int
  public let nodes: [MOUIMobileSemanticsNodeSnapshot]
}

public typealias MOUIMobileSemanticsObserver = (
  MOUIMobileSemanticsSnapshot,
  MOUIMobileRuntimeInputDispatcher
) -> Void

public final class MOUIMobilePluginSubscription {
  private let lock = NSLock()
  private var disposeHandler: (() -> Void)?

  init(dispose: @escaping () -> Void) {
    disposeHandler = dispose
  }

  public func dispose() {
    lock.lock()
    let handler = disposeHandler
    disposeHandler = nil
    lock.unlock()
    handler?()
  }

  deinit {
    dispose()
  }
}

public final class MOUIMobileSemanticsCapability {
  private weak var owner: MOUIMobilePluginCapabilities?

  init(owner: MOUIMobilePluginCapabilities) {
    self.owner = owner
  }

  public func observe(
    _ observer: @escaping MOUIMobileSemanticsObserver
  ) -> MOUIMobilePluginSubscription {
    guard let owner else { return MOUIMobilePluginSubscription(dispose: {}) }
    return owner.observe(observer)
  }
}

public final class MOUIMobileRuntimeInputDispatcher {
  private weak var owner: MOUIMobilePluginCapabilities?
  public let sessionGeneration: Int
  private let epoch: UInt64

  init(owner: MOUIMobilePluginCapabilities, generation: Int, epoch: UInt64) {
    self.owner = owner
    sessionGeneration = generation
    self.epoch = epoch
  }

  public var isActive: Bool {
    owner?.isCurrent(generation: sessionGeneration, epoch: epoch) == true
  }

  @discardableResult
  public func dispatchAccessibility(
    elementIdentifier: Int32,
    action: Int32,
    value: String = ""
  ) -> Bool {
    owner?.dispatch(generation: sessionGeneration, epoch: epoch) {
      MOUIMobileRuntimeBridge.shared.dispatchAccessibilityElement(
        elementIdentifier,
        action: action,
        value: value
      ) > 0
    } == true
  }

  @discardableResult
  public func dispatchTextInput(
    kind: Int32,
    text: String,
    start: Int32,
    end: Int32
  ) -> Bool {
    owner?.dispatch(generation: sessionGeneration, epoch: epoch) {
      MOUIMobileRuntimeBridge.shared.dispatchTextInputKind(
        kind,
        text: text,
        start: start,
        end: end
      ) > 0
    } == true
  }

  @discardableResult
  public func dispatchCommand(kind: Int32) -> Bool {
    owner?.dispatch(generation: sessionGeneration, epoch: epoch) {
      MOUIMobileRuntimeBridge.shared.dispatchCommandKind(kind) > 0
    } == true
  }
}

public final class MOUIMobilePluginCapabilities {
  public static let shared = MOUIMobilePluginCapabilities()

  public let launchOptions = MOUIMobileLaunchOptions()
  public lazy var semantics = MOUIMobileSemanticsCapability(owner: self)

  private let lock = NSLock()
  private var observers: [UUID: MOUIMobileSemanticsObserver] = [:]
  private var generation: Int?
  private var epoch: UInt64 = 0
  private var semanticsRevision = -1

  private init() {}

  func activateSession(generation nextGeneration: Int) {
    guard nextGeneration > 0 else {
      resetSession()
      return
    }
    lock.lock()
    if generation != nextGeneration {
      generation = nextGeneration
      epoch &+= 1
      semanticsRevision = -1
    }
    lock.unlock()
  }

  func publishSemantics(payload: [String: Any], generation: Int) {
    dispatchPrecondition(condition: .onQueue(.main))
    let revision = (payload["revision"] as? NSNumber)?.intValue ?? -1
    let encodedNodes = payload["nodes"] as? [[String: Any]] ?? []
    let nodes = encodedNodes.map { node in
      MOUIMobileSemanticsNodeSnapshot(
        elementIdentifier: (node["element_id"] as? NSNumber)?.int32Value ?? 0,
        role: node["role"] as? String ?? "",
        label: node["label"] as? String ?? ""
      )
    }
    lock.lock()
    guard self.generation == generation, revision > semanticsRevision else {
      lock.unlock()
      return
    }
    semanticsRevision = revision
    let dispatcher = MOUIMobileRuntimeInputDispatcher(
      owner: self,
      generation: generation,
      epoch: epoch
    )
    let callbacks = Array(observers.values)
    lock.unlock()
    let snapshot = MOUIMobileSemanticsSnapshot(
      sessionGeneration: generation,
      revision: revision,
      nodes: nodes
    )
    for callback in callbacks {
      callback(snapshot, dispatcher)
    }
  }

  func resetSession() {
    lock.lock()
    generation = nil
    epoch &+= 1
    semanticsRevision = -1
    lock.unlock()
  }

  fileprivate func observe(
    _ observer: @escaping MOUIMobileSemanticsObserver
  ) -> MOUIMobilePluginSubscription {
    let identifier = UUID()
    lock.lock()
    observers[identifier] = observer
    lock.unlock()
    return MOUIMobilePluginSubscription { [weak self] in
      guard let self else { return }
      self.lock.lock()
      self.observers.removeValue(forKey: identifier)
      self.lock.unlock()
    }
  }

  fileprivate func isCurrent(generation: Int, epoch: UInt64) -> Bool {
    guard Thread.isMainThread else { return false }
    lock.lock()
    defer { lock.unlock() }
    return self.generation == generation && self.epoch == epoch
  }

  fileprivate func dispatch(
    generation: Int,
    epoch: UInt64,
    operation: () -> Bool
  ) -> Bool {
    guard isCurrent(generation: generation, epoch: epoch) else { return false }
    return operation()
  }
}
