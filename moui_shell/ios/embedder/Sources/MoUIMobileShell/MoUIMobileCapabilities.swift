import Foundation
import MoUIShellRuntimeBridge

public final class MOUIShellLaunchOptions {
  private let values: [String: String]

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    var values = environment
    if let enabled = environment["MOUI_EMBEDDING_TEST_PROBE"] {
      values["moui.shell.testProbe"] = enabled
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

public struct MOUIShellSemanticsNodeSnapshot {
  public let elementIdentifier: Int32
  public let role: String
  public let label: String
}

public struct MOUIShellSemanticsSnapshot {
  public let sessionGeneration: Int
  public let revision: Int
  public let nodes: [MOUIShellSemanticsNodeSnapshot]
}

public typealias MOUIShellSemanticsObserver = (
  MOUIShellSemanticsSnapshot,
  MOUIShellRuntimeInputDispatcher
) -> Void

public final class MOUIShellPluginSubscription {
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

public final class MOUIShellSemanticsCapability {
  private weak var owner: MOUIShellPluginCapabilities?

  init(owner: MOUIShellPluginCapabilities) {
    self.owner = owner
  }

  public func observe(
    _ observer: @escaping MOUIShellSemanticsObserver
  ) -> MOUIShellPluginSubscription {
    guard let owner else { return MOUIShellPluginSubscription(dispose: {}) }
    return owner.observe(observer)
  }
}

public final class MOUIShellRuntimeInputDispatcher {
  private weak var owner: MOUIShellPluginCapabilities?
  public let sessionGeneration: Int
  private let epoch: UInt64

  init(owner: MOUIShellPluginCapabilities, generation: Int, epoch: UInt64) {
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
      MOUIShellRuntimeBridge.shared.dispatchAccessibilityElement(
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
      MOUIShellRuntimeBridge.shared.dispatchTextInputKind(
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
      MOUIShellRuntimeBridge.shared.dispatchCommandKind(kind) > 0
    } == true
  }
}

public final class MOUIShellPluginCapabilities {
  public static let shared = MOUIShellPluginCapabilities()

  public let launchOptions = MOUIShellLaunchOptions()
  public lazy var semantics = MOUIShellSemanticsCapability(owner: self)

  private let lock = NSLock()
  private var observers: [UUID: MOUIShellSemanticsObserver] = [:]
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
      MOUIShellSemanticsNodeSnapshot(
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
    let dispatcher = MOUIShellRuntimeInputDispatcher(
      owner: self,
      generation: generation,
      epoch: epoch
    )
    let callbacks = Array(observers.values)
    lock.unlock()
    let snapshot = MOUIShellSemanticsSnapshot(
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
    _ observer: @escaping MOUIShellSemanticsObserver
  ) -> MOUIShellPluginSubscription {
    let identifier = UUID()
    lock.lock()
    observers[identifier] = observer
    lock.unlock()
    return MOUIShellPluginSubscription { [weak self] in
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
