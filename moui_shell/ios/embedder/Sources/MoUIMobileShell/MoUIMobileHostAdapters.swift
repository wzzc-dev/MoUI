import Foundation
import MoUIShellRuntimeBridge
import UIKit

final class MOUIShellTextProxy: UITextView {
  let runtimeBridge = MOUIShellRuntimeBridge.shared
  var candidateRectInContainer: CGRect = .zero

  override func firstRect(for range: UITextRange) -> CGRect {
    guard !candidateRectInContainer.isEmpty, let superview else {
      return super.firstRect(for: range)
    }
    return convert(candidateRectInContainer, from: superview)
  }

  override func copy(_ sender: Any?) {
    _ = runtimeBridge.dispatchCommandKind(0)
  }

  override func cut(_ sender: Any?) {
    _ = runtimeBridge.dispatchCommandKind(1)
  }

  override func paste(_ sender: Any?) {
    _ = runtimeBridge.dispatchCommandKind(2)
  }
}

final class MOUIShellIMEAdapter: NSObject, UITextViewDelegate {
  private let bridge = MOUIShellRuntimeBridge.shared
  private let proxy = MOUIShellTextProxy(frame: .zero)
  private var applyingUpdate = false
  private var committedText = ""
  private var composing = false

  init(container: UIView) {
    super.init()
    proxy.delegate = self
    proxy.autocorrectionType = .default
    proxy.autocapitalizationType = .sentences
    proxy.backgroundColor = .clear
    proxy.alpha = 0.01
    proxy.isAccessibilityElement = false
    container.addSubview(proxy)
  }

  func apply(_ payload: [String: Any]) {
    applyingUpdate = true
    defer { applyingUpdate = false }
    let enabled = payload["enabled"] as? Bool ?? false
    let text = payload["text"] as? String ?? ""
    committedText = text
    if proxy.text != text { proxy.text = text }
    if let selection = payload["selection"] as? [String: Any],
      let start = (selection["start"] as? NSNumber)?.intValue,
      let end = (selection["end"] as? NSNumber)?.intValue
    {
      let lower = max(0, min(start, proxy.text.utf16.count))
      let upper = max(lower, min(end, proxy.text.utf16.count))
      proxy.selectedRange = NSRange(location: lower, length: upper - lower)
    } else {
      let caret = (payload["caret"] as? NSNumber)?.intValue ?? 0
      let location = max(0, min(caret, proxy.text.utf16.count))
      proxy.selectedRange = NSRange(location: location, length: 0)
    }
    proxy.candidateRectInContainer = Self.frame(from: payload["candidate_anchor"]) ?? .zero
    if let frame = Self.frame(from: payload["frame"]) {
      proxy.frame = frame
    } else {
      proxy.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    proxy.isUserInteractionEnabled = enabled
    if enabled {
      proxy.becomeFirstResponder()
    } else {
      composing = false
      proxy.resignFirstResponder()
    }
  }

  func reset() {
    applyingUpdate = true
    proxy.resignFirstResponder()
    proxy.text = ""
    proxy.selectedRange = NSRange(location: 0, length: 0)
    proxy.candidateRectInContainer = .zero
    proxy.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    proxy.isUserInteractionEnabled = false
    committedText = ""
    composing = false
    applyingUpdate = false
  }

  func textViewDidChange(_ textView: UITextView) {
    guard !applyingUpdate else { return }
    if let marked = textView.markedTextRange {
      if !composing {
        _ = bridge.dispatchTextInputKind(3, text: "", start: 0, end: 0)
        composing = true
      }
      let text = textView.text(in: marked) ?? ""
      let length = Int32(text.utf16.count)
      _ = bridge.dispatchTextInputKind(4, text: text, start: length, end: length)
    } else {
      _ = bridge.dispatchTextInputKind(
        1,
        text: textView.text ?? "",
        start: 0,
        end: Int32(committedText.utf16.count)
      )
      committedText = textView.text ?? ""
      if composing {
        _ = bridge.dispatchTextInputKind(5, text: "", start: 0, end: 0)
        composing = false
      }
    }
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    guard !applyingUpdate, textView.markedTextRange == nil else { return }
    _ = bridge.dispatchTextInputKind(
      2,
      text: "",
      start: Int32(textView.selectedRange.location),
      end: Int32(NSMaxRange(textView.selectedRange))
    )
  }

  private static func frame(from value: Any?) -> CGRect? {
    guard
      let frame = value as? [String: Any],
      let origin = frame["origin"] as? [String: Any],
      let size = frame["size"] as? [String: Any]
    else { return nil }
    return CGRect(
      x: (origin["x"] as? NSNumber)?.doubleValue ?? 0,
      y: (origin["y"] as? NSNumber)?.doubleValue ?? 0,
      width: max(1, (size["width"] as? NSNumber)?.doubleValue ?? 1),
      height: max(1, (size["height"] as? NSNumber)?.doubleValue ?? 1)
    )
  }
}

final class MOUIShellAccessibilityElement: UIAccessibilityElement {
  var elementIdentifier: Int32 = 0
  var actions: Set<String> = []
  let bridge = MOUIShellRuntimeBridge.shared

  override func accessibilityActivate() -> Bool {
    bridge.dispatchAccessibilityElement(elementIdentifier, action: 0, value: "") > 0
  }

  override func accessibilityElementDidBecomeFocused() {
    _ = bridge.dispatchAccessibilityElement(elementIdentifier, action: 1, value: "")
  }

  override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
    guard actions.contains("Scroll") else { return false }
    let value: String
    switch direction {
    case .up: value = "up"
    case .down: value = "down"
    case .left: value = "left"
    case .right: value = "right"
    case .next: value = "forward"
    case .previous: value = "backward"
    @unknown default: value = "forward"
    }
    return bridge.dispatchAccessibilityElement(
      elementIdentifier,
      action: 4,
      value: value
    ) > 0
  }
}

final class MOUIShellAccessibilityAdapter {
  private weak var container: UIView?
  private var revision = -1

  init(container: UIView) {
    self.container = container
  }

  func apply(_ payload: [String: Any]) {
    guard let container else { return }
    let nextRevision = (payload["revision"] as? NSNumber)?.intValue ?? revision + 1
    guard nextRevision > revision else { return }
    revision = nextRevision
    let nodes = payload["nodes"] as? [[String: Any]] ?? []
    container.accessibilityElements = nodes.map { node in
      let element = MOUIShellAccessibilityElement(accessibilityContainer: container)
      element.elementIdentifier = (node["element_id"] as? NSNumber)?.int32Value ?? 0
      element.accessibilityLabel = node["label"] as? String ?? ""
      element.accessibilityValue = node["value"] as? String ?? ""
      element.accessibilityHint = node["description"] as? String ?? ""
      element.actions = Set(node["actions"] as? [String] ?? [])
      element.accessibilityTraits = Self.traits(node)
      element.accessibilityFrameInContainerSpace = Self.frame(node["frame"])
      return element
    }
    UIAccessibility.post(notification: .layoutChanged, argument: nil)
  }

  func reset() {
    revision = -1
    container?.accessibilityElements = nil
    UIAccessibility.post(notification: .layoutChanged, argument: nil)
  }

  private static func traits(_ node: [String: Any]) -> UIAccessibilityTraits {
    var result: UIAccessibilityTraits = []
    switch node["role"] as? String {
    case "Button": result.insert(.button)
    case "Text": result.insert(.staticText)
    case "TextField": result.insert(.updatesFrequently)
    default: break
    }
    let state = node["state"] as? [String: Any] ?? [:]
    if state["disabled"] as? Bool == true { result.insert(.notEnabled) }
    if state["selected"] as? Bool == true { result.insert(.selected) }
    return result
  }

  private static func frame(_ value: Any?) -> CGRect {
    guard
      let frame = value as? [String: Any],
      let origin = frame["origin"] as? [String: Any],
      let size = frame["size"] as? [String: Any]
    else { return .zero }
    return CGRect(
      x: (origin["x"] as? NSNumber)?.doubleValue ?? 0,
      y: (origin["y"] as? NSNumber)?.doubleValue ?? 0,
      width: (size["width"] as? NSNumber)?.doubleValue ?? 0,
      height: (size["height"] as? NSNumber)?.doubleValue ?? 0
    )
  }
}

final class MOUIEmbedderHostAdapter {
  private struct HostChannelKey: Hashable {
    let generation: Int
    let requestID: Int
  }

  private final class PendingHostChannel {
    let completion: MOUIEmbedderHostChannelCompletion
    var task: MOUIEmbedderHostChannelTask?

    init(completion: MOUIEmbedderHostChannelCompletion) {
      self.completion = completion
    }
  }

  private let bridge = MOUIShellRuntimeBridge.shared
  private let ime: MOUIShellIMEAdapter
  private let accessibility: MOUIShellAccessibilityAdapter
  private let platformViews: MOUIShellPlatformViewOverlay
  private let pluginCapabilities: MOUIShellPluginCapabilities
  private var sessionGeneration: Int?
  private var pendingHostChannels: [HostChannelKey: PendingHostChannel] = [:]

  init(
    surface: UIView,
    overlay: UIView,
    pluginCapabilities: MOUIShellPluginCapabilities
  ) {
    ime = MOUIShellIMEAdapter(container: overlay)
    accessibility = MOUIShellAccessibilityAdapter(container: surface)
    platformViews = MOUIShellPlatformViewOverlay(container: overlay)
    self.pluginCapabilities = pluginCapabilities
  }

  func drain() {
    let result = bridge.takeHostUpdateEnvelopeJSON()
    guard result.status == 0, let data = result.data, !data.isEmpty else { return }
    guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
    guard
      let envelope = json as? [String: Any],
      (envelope["schemaVersion"] as? NSNumber)?.intValue == 1,
      let generation = (envelope["sessionGeneration"] as? NSNumber)?.intValue,
      generation > 0,
      let updates = envelope["updates"] as? [[String: Any]]
    else { return }
    if sessionGeneration != generation {
      resetHostState()
      sessionGeneration = generation
      pluginCapabilities.activateSession(generation: generation)
    }
    for update in updates {
      apply(update, sessionGeneration: generation)
    }
  }

  func reset() {
    resetHostState()
    sessionGeneration = nil
  }

  private func resetHostState() {
    for pending in pendingHostChannels.values {
      pending.task?.cancel()
      pending.completion.invalidate()
    }
    pendingHostChannels.removeAll()
    ime.reset()
    accessibility.reset()
    platformViews.reset()
    pluginCapabilities.resetSession()
  }

  private func apply(_ update: [String: Any], sessionGeneration: Int) {
    let kind = update["kind"] as? String ?? ""
    let payload = update["payload"] as? [String: Any] ?? [:]
    switch kind {
    case "ime": ime.apply(payload)
    case "clipboard":
      applyClipboard(update, payload: payload, generation: sessionGeneration)
    case "semantics":
      accessibility.apply(payload)
      pluginCapabilities.publishSemantics(payload: payload, generation: sessionGeneration)
    case "diagnostic":
      NSLog("moui-shell diagnostic %@", String(describing: update["payload"] ?? ""))
    case "platform-views":
      platformViews.apply(snapshot: payload, sessionGeneration: sessionGeneration)
    case "platform-channel":
      applyPlatformChannel(update, payload: payload, generation: sessionGeneration)
    default: break
    }
  }

  private func applyClipboard(
    _ update: [String: Any],
    payload: [String: Any],
    generation: Int
  ) {
    let requestId = (update["id"] as? NSNumber)?.int32Value ?? 0
    let pasteboard = UIPasteboard.general
    let operation = payload["operation"] as? String ?? ""
    var accepted = false
    switch operation {
    case "read-text":
      accepted = bridge.completeClipboardSessionGeneration(
        Int32(generation),
        request: requestId,
        kind: 1,
        text: pasteboard.string ?? "",
        bytes: Data()
      ) > 0
    case "write-text":
      pasteboard.string = payload["text"] as? String ?? ""
      accepted = bridge.completeClipboardSessionGeneration(
        Int32(generation), request: requestId, kind: 3, text: "", bytes: Data()) > 0
    case "read-image":
      let data =
        pasteboard.data(forPasteboardType: "public.png")
        ?? pasteboard.data(forPasteboardType: "public.jpeg")
      accepted = bridge.completeClipboardSessionGeneration(
        Int32(generation),
        request: requestId,
        kind: data == nil ? 0 : 2,
        text: data == nil ? "clipboard image is unavailable" : "",
        bytes: data ?? Data()
      ) > 0
    case "write-image":
      let values = payload["bytes"] as? [NSNumber] ?? []
      let data = Data(values.map(\.uint8Value))
      let mime = payload["mime"] as? String ?? "image/png"
      pasteboard.setData(
        data, forPasteboardType: mime.contains("jpeg") ? "public.jpeg" : "public.png")
      accepted = bridge.completeClipboardSessionGeneration(
        Int32(generation), request: requestId, kind: 3, text: "", bytes: Data()) > 0
    default:
      accepted = bridge.completeClipboardSessionGeneration(
        Int32(generation),
        request: requestId,
        kind: 0,
        text: "unsupported clipboard operation",
        bytes: Data()
      ) > 0
    }
    NSLog(
      "moui-shell service clipboard complete operation=%@ accepted=%d",
      operation,
      accepted ? 1 : 0
    )
  }

  private func applyPlatformChannel(
    _ update: [String: Any],
    payload: [String: Any],
    generation: Int
  ) {
    guard
      let requestId = (update["id"] as? NSNumber)?.intValue,
      requestId > 0
    else { return }
    let key = HostChannelKey(generation: generation, requestID: requestId)
    guard pendingHostChannels[key] == nil else { return }
    let completion = MOUIEmbedderHostChannelCompletion { [weak self] response in
      self?.finishPlatformChannel(key, response: response)
    }
    let pending = PendingHostChannel(completion: completion)
    pendingHostChannels[key] = pending
    guard let request = MOUIEmbedderHostChannelRequest(payload: payload) else {
      completion.fail(payload: "invalid platform channel request")
      return
    }
    guard
      let handler = MOUIShellPluginRegistry.shared.hostChannelHandler(
        name: request.channel
      )
    else {
      completion.unavailable(
        payload: "platform channel is unavailable: \(request.channel)"
      )
      return
    }
    let task = handler.handle(request: request, completion: completion)
    if pendingHostChannels[key] === pending, !completion.isFinished {
      pending.task = task
    } else {
      task?.cancel()
    }
  }

  private func finishPlatformChannel(
    _ key: HostChannelKey,
    response: MOUIEmbedderHostChannelResponse
  ) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard pendingHostChannels.removeValue(forKey: key) != nil else { return }
    let envelope: [String: Any] = [
      "schemaVersion": 1,
      "sessionGeneration": key.generation,
      "response": [
        "kind": "platform-channel",
        "requestId": key.requestID,
        "status": response.status.rawValue,
        "payload": response.payload,
      ],
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }
    _ = bridge.dispatchHostResponseEnvelopeJSON(data)
  }
}
