import Foundation
import MoUIShellShell
import UIKit

private let pluginIdentifier = "dev.wzzc.moui.shell.test-probe"
private let platformViewKind = "\(pluginIdentifier).view"
private let hostChannel = "\(pluginIdentifier).channel"
private let testProbeGate = "moui.shell.testProbe"
private let serviceTextLabel = "Service probe text"
private let serviceActionLabel = "Activate service probe"
private let serviceProbeText = "ime-shell-probe"

private enum ProbeCounter: String, CaseIterable {
  case platformViewCreate
  case platformViewResize
  case platformViewClip
  case platformViewEvent
  case platformViewDispose
  case hostChannelSuccess
  case hostChannelError
  case hostChannelCancel
  case hostChannelExactlyOnce
  case hostChannelLateAfterDispose
  case serviceSmokeFired
  case serviceSmokeCompleted
}

private final class ProbeState {
  static let shared = ProbeState()

  private let lock = NSLock()
  private var counters = Dictionary(
    uniqueKeysWithValues: ProbeCounter.allCases.map { ($0.rawValue, 0) }
  )

  func increment(_ counter: ProbeCounter) {
    lock.lock()
    counters[counter.rawValue, default: 0] += 1
    let value = counters
    lock.unlock()
    NSLog("moui-shell test-probe snapshot=%@", Self.encode(value))
  }

  func snapshot() -> String {
    lock.lock()
    let value = counters
    lock.unlock()
    return Self.encode(value)
  }

  private static func encode(_ value: [String: Int]) -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
      let text = String(data: data, encoding: .utf8)
    else { return "{}" }
    return text
  }
}

private final class ProbePlatformView: UILabel {
  var eventSink: MOUIShellPlatformViewEventSink?
  var lastSize: CGSize?
  var sentReady = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor(red: 0.09, green: 0.40, blue: 0.20, alpha: 1)
    textColor = .white
    textAlignment = .center
    text = "MoUI test probe"
    isUserInteractionEnabled = true
    accessibilityIdentifier = "moui-shell-test-probe-platform-view"
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(activate)))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  @objc private func activate() {
    if eventSink?.send(
      name: "activate",
      value: "ios",
      detail: ProbeState.shared.snapshot(),
      flag: true
    ) == true {
      ProbeState.shared.increment(.platformViewEvent)
    }
  }
}

private final class ProbePlatformViewFactory: MOUIShellPlatformViewFactory {
  func makePlatformView(identifier: String) -> UIView {
    ProbeState.shared.increment(.platformViewCreate)
    let view = ProbePlatformView(frame: .zero)
    view.accessibilityValue = identifier
    return view
  }

  func updatePlatformView(
    _ view: UIView,
    placement: MOUIShellPlatformViewPlacement,
    events: MOUIShellPlatformViewEventSink
  ) {
    guard let probe = view as? ProbePlatformView else { return }
    if probe.lastSize != placement.frame.size {
      ProbeState.shared.increment(.platformViewResize)
      probe.lastSize = placement.frame.size
    }
    if placement.clip != nil { ProbeState.shared.increment(.platformViewClip) }
    probe.eventSink = events
    probe.text = placement.properties["label"] ?? "MoUI test probe"
    if !probe.sentReady {
      probe.sentReady = true
      if events.send(
        name: "ready",
        value: placement.identifier,
        detail: ProbeState.shared.snapshot(),
        flag: true
      ) {
        ProbeState.shared.increment(.platformViewEvent)
      }
    }
  }

  func disposePlatformView(_ view: UIView) {
    guard let probe = view as? ProbePlatformView else { return }
    ProbeState.shared.increment(.platformViewDispose)
    probe.eventSink?.send(
      name: "disposed",
      value: probe.accessibilityValue ?? "",
      detail: ProbeState.shared.snapshot()
    )
    probe.eventSink = nil
    probe.gestureRecognizers?.forEach { probe.removeGestureRecognizer($0) }
  }
}

private final class ProbePendingTask: MOUIEmbedderHostChannelTask {
  enum Kind {
    case cancel
    case lateAfterDispose
  }

  private let lock = NSLock()
  private var cancelled = false
  private let completion: MOUIEmbedderHostChannelCompletion
  private let kind: Kind

  init(completion: MOUIEmbedderHostChannelCompletion, kind: Kind) {
    self.completion = completion
    self.kind = kind
  }

  func cancel() {
    lock.lock()
    guard !cancelled else {
      lock.unlock()
      return
    }
    cancelled = true
    lock.unlock()
    switch kind {
    case .cancel:
      ProbeState.shared.increment(.hostChannelCancel)
    case .lateAfterDispose:
      if !completion.succeed(payload: "late-after-dispose") {
        ProbeState.shared.increment(.hostChannelLateAfterDispose)
      }
    }
  }
}

private final class ProbeHostChannelHandler: MOUIEmbedderHostChannelHandler {
  func handle(
    request: MOUIEmbedderHostChannelRequest,
    completion: MOUIEmbedderHostChannelCompletion
  ) -> MOUIEmbedderHostChannelTask? {
    switch request.operation {
    case "success", "echo":
      if completion.succeed(payload: request.payload) {
        ProbeState.shared.increment(.hostChannelSuccess)
      }
      return nil
    case "snapshot":
      completion.succeed(payload: ProbeState.shared.snapshot())
      return nil
    case "error":
      if completion.fail(payload: request.payload.isEmpty ? "test-probe error" : request.payload) {
        ProbeState.shared.increment(.hostChannelError)
      }
      return nil
    case "exactly-once":
      let firstAccepted = completion.succeed(payload: "first")
      let duplicateAccepted = completion.fail(payload: "duplicate")
      if firstAccepted && !duplicateAccepted {
        ProbeState.shared.increment(.hostChannelExactlyOnce)
      }
      return nil
    case "cancel":
      return ProbePendingTask(completion: completion, kind: .cancel)
    case "late-after-dispose":
      return ProbePendingTask(completion: completion, kind: .lateAfterDispose)
    default:
      completion.unavailable(payload: "unknown test-probe operation: \(request.operation)")
      return nil
    }
  }
}

private final class ProbeServiceSmoke {
  static let shared = ProbeServiceSmoke()

  private var fired = false
  private var subscription: MOUIShellPluginSubscription?

  func install(capabilities: MOUIShellPluginCapabilities) {
    guard subscription == nil else { return }
    subscription = capabilities.semantics.observe { [weak self, weak capabilities] snapshot, runtimeInput in
      guard
        let self,
        let capabilities,
        capabilities.launchOptions.isEnabled(testProbeGate),
        !self.fired,
        let textField = snapshot.nodes.first(where: {
          $0.label == serviceTextLabel && $0.role == "TextField"
        }),
        let action = snapshot.nodes.first(where: {
          $0.label == serviceActionLabel && $0.role == "Button"
        })
      else { return }
      self.fired = true
      ProbeState.shared.increment(.serviceSmokeFired)
      NSLog("moui-shell service smoke begin")
      let textFocusAccepted = runtimeInput.dispatchAccessibility(
        elementIdentifier: textField.elementIdentifier,
        action: 1
      )
      var accepted = textFocusAccepted
      let setTextAccepted = runtimeInput.dispatchAccessibility(
        elementIdentifier: textField.elementIdentifier,
        action: 2,
        value: serviceProbeText
      )
      accepted = setTextAccepted && accepted
      let imeCommitAccepted = runtimeInput.dispatchTextInput(
        kind: 1,
        text: serviceProbeText,
        start: 0,
        end: 0
      )
      accepted = imeCommitAccepted && accepted
      if imeCommitAccepted { NSLog("moui-shell service ime edit kind=commit") }
      let selectionAccepted = runtimeInput.dispatchTextInput(
        kind: 2,
        text: "",
        start: 0,
        end: Int32(serviceProbeText.utf16.count)
      )
      accepted = selectionAccepted && accepted
      let copyAccepted = runtimeInput.dispatchCommand(kind: 0)
      accepted = copyAccepted && accepted
      if copyAccepted { NSLog("moui-shell service smoke copy") }
      UIPasteboard.general.string = "clipboard-service-probe"
      let pasteAccepted = runtimeInput.dispatchCommand(kind: 2)
      accepted = pasteAccepted && accepted
      if pasteAccepted { NSLog("moui-shell service smoke paste") }
      let cutAccepted = runtimeInput.dispatchCommand(kind: 1)
      accepted = cutAccepted && accepted
      if cutAccepted { NSLog("moui-shell service smoke cut") }
      let actionFocusAccepted = runtimeInput.dispatchAccessibility(
        elementIdentifier: action.elementIdentifier,
        action: 1
      )
      accepted = actionFocusAccepted && accepted
      if actionFocusAccepted {
        NSLog("moui-shell service accessibility focus id=%d", action.elementIdentifier)
      }
      let actionActivateAccepted = runtimeInput.dispatchAccessibility(
        elementIdentifier: action.elementIdentifier,
        action: 0
      )
      accepted = actionActivateAccepted && accepted
      if actionActivateAccepted {
        NSLog("moui-shell service accessibility action=activate id=%d", action.elementIdentifier)
      }
      if accepted && runtimeInput.isActive {
        ProbeState.shared.increment(.serviceSmokeCompleted)
      }
      NSLog("moui-shell service smoke end accepted=%d", accepted ? 1 : 0)
    }
  }
}

public enum MoUIShellTestProbePlugin: MOUIShellPlugin {
  public static let identifier = pluginIdentifier

  public static func install(in registry: MOUIShellPluginRegistry) {
    registry.registerPlatformView(kind: platformViewKind, factory: ProbePlatformViewFactory())
    registry.registerHostChannel(name: hostChannel, handler: ProbeHostChannelHandler())
  }

  public static func install(
    in registry: MOUIShellPluginRegistry,
    capabilities: MOUIShellPluginCapabilities
  ) {
    install(in: registry)
    ProbeServiceSmoke.shared.install(capabilities: capabilities)
  }
}
