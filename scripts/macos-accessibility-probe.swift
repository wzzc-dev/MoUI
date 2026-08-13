#!/usr/bin/env swift

import ApplicationServices
import AppKit
import Foundation

private struct Options {
  let pid: pid_t
  let timeout: TimeInterval

  static func parse() throws -> Options {
    var pid: pid_t?
    var timeout: TimeInterval = 15.0
    var index = 1
    while index < CommandLine.arguments.count {
      switch CommandLine.arguments[index] {
      case "--pid":
        index += 1
        guard index < CommandLine.arguments.count,
              let value = Int32(CommandLine.arguments[index]), value > 0 else {
          throw ProbeError.usage("--pid requires a positive process id")
        }
        pid = value
      case "--timeout":
        index += 1
        guard index < CommandLine.arguments.count,
              let value = Double(CommandLine.arguments[index]), value > 0 else {
          throw ProbeError.usage("--timeout requires positive seconds")
        }
        timeout = value
      case "--help", "-h":
        throw ProbeError.usage("Usage: macos-accessibility-probe --pid PID [--timeout SECONDS]")
      default:
        throw ProbeError.usage("unknown argument: \(CommandLine.arguments[index])")
      }
      index += 1
    }
    guard let pid else { throw ProbeError.usage("--pid is required") }
    return Options(pid: pid, timeout: timeout)
  }
}

private enum ProbeError: Error, CustomStringConvertible {
  case usage(String)
  case accessibility(String)
  case assertion(String)

  var description: String {
    switch self {
    case .usage(let message), .accessibility(let message), .assertion(let message):
      return message
    }
  }
}

private let requiredIdentifiers = [
  "a11y.button", "a11y.checkbox", "a11y.slider", "a11y.textfield",
  "a11y.tree", "a11y.grid", "a11y.scroll", "a11y.status", "a11y.alert",
  "a11y.image", "a11y.separator",
]

private let expectedRoles = [
  "a11y.button": kAXButtonRole,
  "a11y.checkbox": kAXCheckBoxRole,
  "a11y.slider": kAXSliderRole,
  "a11y.textfield": kAXTextFieldRole,
  "a11y.tree": kAXOutlineRole,
  "a11y.grid": kAXGridRole,
  "a11y.scroll": kAXScrollAreaRole,
  "a11y.status": kAXStaticTextRole,
  "a11y.alert": kAXStaticTextRole,
  "a11y.image": kAXImageRole,
  "a11y.separator": kAXSplitterRole,
]

private final class NotificationRecorder {
  private(set) var announcements: [[String: Any]] = []
  private var observer: AXObserver?
  private let app: AXUIElement

  init(pid: pid_t, app: AXUIElement) throws {
    self.app = app
    var created: AXObserver?
    let createError = AXObserverCreateWithInfoCallback(
      pid,
      { _, _, notification, info, refcon in
        guard let refcon else { return }
        let recorder = Unmanaged<NotificationRecorder>.fromOpaque(refcon).takeUnretainedValue()
        let dictionary = info as NSDictionary
        recorder.announcements.append([
          "notification": notification as String,
          "text": dictionary[kAXAnnouncementKey as String] as? String ?? "",
          "priority": dictionary[kAXPriorityKey as String] ?? NSNull(),
        ])
      },
      &created
    )
    guard createError == .success, let created else {
      throw ProbeError.accessibility("AXObserver creation failed with AXError \(createError.rawValue)")
    }
    observer = created
    let addError = AXObserverAddNotification(
      created,
      app,
      kAXAnnouncementRequestedNotification as CFString,
      Unmanaged.passUnretained(self).toOpaque()
    )
    guard addError == .success else {
      throw ProbeError.accessibility("AX announcement subscription failed with AXError \(addError.rawValue)")
    }
    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(created),
      .defaultMode
    )
  }

  deinit {
    if let observer {
      AXObserverRemoveNotification(
        observer,
        app,
        kAXAnnouncementRequestedNotification as CFString
      )
      CFRunLoopRemoveSource(
        CFRunLoopGetCurrent(),
        AXObserverGetRunLoopSource(observer),
        .defaultMode
      )
    }
  }
}

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
  attribute(element, name) as? String
}

private func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
  (attribute(element, name) as? NSNumber)?.boolValue
}

private func doubleAttribute(_ element: AXUIElement, _ name: String) -> Double? {
  (attribute(element, name) as? NSNumber)?.doubleValue
}

private func elementsAttribute(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
  attribute(element, name) as? [AXUIElement] ?? []
}

private func actionNames(_ element: AXUIElement) -> [String] {
  var names: CFArray?
  guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
  return names as? [String] ?? []
}

private func jsonValue(_ value: CFTypeRef?) -> Any {
  guard let value else { return NSNull() }
  if let string = value as? String { return string }
  if let number = value as? NSNumber { return number }
  if CFGetTypeID(value) == AXValueGetTypeID() {
    let axValue = unsafeBitCast(value, to: AXValue.self)
    switch AXValueGetType(axValue) {
    case .cfRange:
      var range = CFRange()
      if AXValueGetValue(axValue, .cfRange, &range) {
        return ["location": range.location, "length": range.length]
      }
    case .cgPoint:
      var point = CGPoint.zero
      if AXValueGetValue(axValue, .cgPoint, &point) {
        return ["x": point.x, "y": point.y]
      }
    case .cgSize:
      var size = CGSize.zero
      if AXValueGetValue(axValue, .cgSize, &size) {
        return ["width": size.width, "height": size.height]
      }
    default:
      break
    }
  }
  return String(describing: value)
}

private func describeElement(_ element: AXUIElement) -> [String: Any] {
  let attributes: [(String, String)] = [
    ("identifier", kAXIdentifierAttribute),
    ("role", kAXRoleAttribute),
    ("subrole", kAXSubroleAttribute),
    ("title", kAXTitleAttribute),
    ("description", kAXDescriptionAttribute),
    ("value", kAXValueAttribute),
    ("valueDescription", kAXValueDescriptionAttribute),
    ("enabled", kAXEnabledAttribute),
    ("focused", kAXFocusedAttribute),
    ("selected", kAXSelectedAttribute),
    ("expanded", kAXExpandedAttribute),
    ("modal", kAXModalAttribute),
    ("minValue", kAXMinValueAttribute),
    ("maxValue", kAXMaxValueAttribute),
    ("selectedTextRange", kAXSelectedTextRangeAttribute),
    ("rowCount", kAXRowCountAttribute),
    ("columnCount", kAXColumnCountAttribute),
  ]
  var result: [String: Any] = [:]
  for (key, name) in attributes {
    let value = attribute(element, name)
    if value != nil { result[key] = jsonValue(value) }
  }
  result["actions"] = actionNames(element)
  return result
}

private struct TreeSnapshot {
  var nodesByIdentifier: [String: AXUIElement] = [:]
  var serializedNodes: [[String: Any]] = []

  mutating func walk(_ element: AXUIElement, parentIdentifier: String?, depth: Int) {
    if depth > 128 { return }
    var node = describeElement(element)
    let identifier = node["identifier"] as? String
    if let identifier, !identifier.isEmpty {
      nodesByIdentifier[identifier] = element
    }
    node["parentIdentifier"] = parentIdentifier ?? NSNull()
    node["depth"] = depth
    serializedNodes.append(node)
    let nextParent = identifier ?? parentIdentifier
    for child in elementsAttribute(element, kAXChildrenAttribute) {
      walk(child, parentIdentifier: nextParent, depth: depth + 1)
    }
  }
}

private func waitUntil<T>(
  timeout: TimeInterval,
  interval: TimeInterval = 0.08,
  _ body: () -> T?
) -> T? {
  let deadline = Date().addingTimeInterval(timeout)
  repeat {
    if let value = body() { return value }
    RunLoop.current.run(until: Date().addingTimeInterval(interval))
  } while Date() < deadline
  return nil
}

private func snapshot(_ app: AXUIElement) -> TreeSnapshot {
  var result = TreeSnapshot()
  result.walk(app, parentIdentifier: nil, depth: 0)
  return result
}

private func waitForElement(
  _ identifier: String,
  app: AXUIElement,
  timeout: TimeInterval
) -> (AXUIElement, TreeSnapshot)? {
  waitUntil(timeout: timeout) {
    let tree = snapshot(app)
    guard let element = tree.nodesByIdentifier[identifier] else { return nil }
    return (element, tree)
  }
}

private func waitForMissingElement(
  _ identifier: String,
  app: AXUIElement,
  timeout: TimeInterval
) -> TreeSnapshot? {
  waitUntil(timeout: timeout) {
    let tree = snapshot(app)
    return tree.nodesByIdentifier[identifier] == nil ? tree : nil
  }
}

private func perform(
  _ element: AXUIElement,
  action: String,
  id: String,
  records: inout [[String: Any]]
) throws {
  let error = AXUIElementPerformAction(element, action as CFString)
  let passed = error == .success
  records.append([
    "id": id,
    "action": action as String,
    "result": passed ? "passed" : "failed",
    "axError": error.rawValue,
  ])
  if !passed {
    throw ProbeError.assertion("\(id) \(action) failed with AXError \(error.rawValue)")
  }
}

private func setAttribute(
  _ element: AXUIElement,
  attribute name: String,
  value: CFTypeRef,
  id: String,
  action: String,
  records: inout [[String: Any]]
) throws {
  let settableError: AXError
  var settable = DarwinBoolean(false)
  settableError = AXUIElementIsAttributeSettable(element, name as CFString, &settable)
  let error = settableError == .success && settable.boolValue
    ? AXUIElementSetAttributeValue(element, name as CFString, value)
    : settableError == .success ? .attributeUnsupported : settableError
  let passed = error == .success
  records.append([
    "id": id,
    "action": action,
    "result": passed ? "passed" : "failed",
    "axError": error.rawValue,
  ])
  if !passed {
    throw ProbeError.assertion("\(id) \(action) failed with AXError \(error.rawValue)")
  }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if !condition() { throw ProbeError.assertion(message) }
}

private func focusedIdentifier(_ app: AXUIElement) -> String? {
  guard let focused = attribute(app, kAXFocusedUIElementAttribute) else { return nil }
  guard CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
  return stringAttribute(
    unsafeBitCast(focused, to: AXUIElement.self),
    kAXIdentifierAttribute
  )
}

private func runProbe(options: Options) throws -> [String: Any] {
  let trusted = AXIsProcessTrusted()
  guard trusted else {
    throw ProbeError.accessibility(
      "Accessibility permission is not enabled for this probe process; grant it in Privacy & Security > Accessibility"
    )
  }
  let app = AXUIElementCreateApplication(options.pid)
  guard waitUntil(timeout: options.timeout, { elementsAttribute(app, kAXWindowsAttribute).first }) != nil else {
    throw ProbeError.accessibility("AX did not expose a window for pid \(options.pid)")
  }
  guard var tree = waitUntil(timeout: options.timeout, { () -> TreeSnapshot? in
    let candidate = snapshot(app)
    return candidate.nodesByIdentifier["a11y.button"] != nil ? candidate : nil
  }) else {
    throw ProbeError.accessibility("AX tree did not expose the Accessibility Probe")
  }

  let initialMissing = requiredIdentifiers.filter { tree.nodesByIdentifier[$0] == nil }
  try require(initialMissing.isEmpty, "missing required AX identifiers: \(initialMissing.joined(separator: ", "))")
  for (identifier, expectedRole) in expectedRoles {
    guard let element = tree.nodesByIdentifier[identifier] else { continue }
    try require(
      stringAttribute(element, kAXRoleAttribute) == expectedRole,
      "\(identifier) has unexpected AXRole \(stringAttribute(element, kAXRoleAttribute) ?? "missing")"
    )
  }
  let notificationRecorder = try NotificationRecorder(pid: options.pid, app: app)
  var actions: [[String: Any]] = []
  var keyboardFocus: [[String: Any]] = []
  var accessibilityFocus: [[String: Any]] = []
  let beforeDialogFocus = focusedIdentifier(app)
  keyboardFocus.append(["phase": "before-dialog", "identifier": beforeDialogFocus ?? NSNull()])

  guard let button = tree.nodesByIdentifier["a11y.button"] else {
    throw ProbeError.assertion("button disappeared before AXPress")
  }
  try perform(button, action: kAXPressAction, id: "a11y.button", records: &actions)
  guard let (dialog, dialogTree) = waitForElement("a11y.dialog", app: app, timeout: options.timeout) else {
    throw ProbeError.assertion("AXPress did not expose a11y.dialog")
  }
  tree = dialogTree
  try require(boolAttribute(dialog, kAXModalAttribute) == true, "a11y.dialog did not expose AXModal=true")
  let modalVisibleIDs = requiredIdentifiers.filter { tree.nodesByIdentifier[$0] != nil }
  try require(modalVisibleIDs.isEmpty, "modal AX tree leaked outside Probe nodes: \(modalVisibleIDs)")
  accessibilityFocus.append([
    "phase": "dialog-open",
    "identifier": focusedIdentifier(app) ?? NSNull(),
  ])
  let dialogObservation = describeElement(dialog)
  try perform(dialog, action: kAXCancelAction, id: "a11y.dialog", records: &actions)
  guard let restoredTree = waitForMissingElement("a11y.dialog", app: app, timeout: options.timeout) else {
    throw ProbeError.assertion("AXCancel did not remove a11y.dialog")
  }
  tree = restoredTree
  keyboardFocus.append([
    "phase": "after-dialog",
    "identifier": focusedIdentifier(app) ?? NSNull(),
  ])

  guard let checkbox = tree.nodesByIdentifier["a11y.checkbox"],
        let checkboxBefore = doubleAttribute(checkbox, kAXValueAttribute) else {
    throw ProbeError.assertion("a11y.checkbox is missing AXValue")
  }
  let focusBeforeCheckbox = focusedIdentifier(app)
  try perform(checkbox, action: kAXPressAction, id: "a11y.checkbox", records: &actions)
  guard let (_, toggledTree) = waitForElement("a11y.checkbox", app: app, timeout: options.timeout),
        let toggledCheckbox = toggledTree.nodesByIdentifier["a11y.checkbox"],
        let checkboxAfter = doubleAttribute(toggledCheckbox, kAXValueAttribute),
        checkboxAfter != checkboxBefore else {
    throw ProbeError.assertion("AXPress did not change a11y.checkbox AXValue")
  }
  tree = toggledTree
  guard waitUntil(timeout: options.timeout, {
    notificationRecorder.announcements.isEmpty ? nil : true
  }) != nil else {
    throw ProbeError.assertion("checkbox live-region delta did not emit AXAnnouncementRequested")
  }
  accessibilityFocus.append([
    "phase": "checkbox-action",
    "before": focusBeforeCheckbox ?? NSNull(),
    "after": focusedIdentifier(app) ?? NSNull(),
    "moved": focusBeforeCheckbox != focusedIdentifier(app),
  ])

  guard let slider = tree.nodesByIdentifier["a11y.slider"],
        let sliderBefore = doubleAttribute(slider, kAXValueAttribute) else {
    throw ProbeError.assertion("a11y.slider is missing AXValue")
  }
  try perform(slider, action: kAXIncrementAction, id: "a11y.slider", records: &actions)
  guard let (_, incrementedTree) = waitForElement("a11y.slider", app: app, timeout: options.timeout),
        let incrementedSlider = incrementedTree.nodesByIdentifier["a11y.slider"],
        let sliderAfterIncrement = doubleAttribute(incrementedSlider, kAXValueAttribute),
        sliderAfterIncrement > sliderBefore else {
    throw ProbeError.assertion("AXIncrement did not increase a11y.slider AXValue")
  }
  try setAttribute(
    incrementedSlider,
    attribute: kAXValueAttribute,
    value: NSNumber(value: 0.7),
    id: "a11y.slider",
    action: "AXSetValue(0.7)",
    records: &actions
  )
  guard let (_, valuedTree) = waitForElement("a11y.slider", app: app, timeout: options.timeout),
        let valuedSlider = valuedTree.nodesByIdentifier["a11y.slider"],
        let sliderAfterSet = doubleAttribute(valuedSlider, kAXValueAttribute),
        abs(sliderAfterSet - 0.7) < 0.0001 else {
    throw ProbeError.assertion("AXValue did not set a11y.slider to 0.7")
  }
  tree = valuedTree

  guard let textfield = tree.nodesByIdentifier["a11y.textfield"] else {
    throw ProbeError.assertion("a11y.textfield disappeared")
  }
  try setAttribute(
    textfield,
    attribute: kAXFocusedAttribute,
    value: kCFBooleanTrue,
    id: "a11y.textfield",
    action: "AXFocus",
    records: &actions
  )
  guard waitUntil(timeout: options.timeout, { focusedIdentifier(app) == "a11y.textfield" ? true : nil }) != nil else {
    throw ProbeError.assertion("AXFocus did not focus a11y.textfield")
  }
  keyboardFocus.append(["phase": "textfield-focus", "identifier": "a11y.textfield"])
  guard let focusedTree = waitForElement("a11y.textfield", app: app, timeout: options.timeout)?.1,
        let focusedTextfield = focusedTree.nodesByIdentifier["a11y.textfield"] else {
    throw ProbeError.assertion("a11y.textfield unavailable after focus")
  }
  try setAttribute(
    focusedTextfield,
    attribute: kAXValueAttribute,
    value: "native AX probe" as CFString,
    id: "a11y.textfield",
    action: "AXSetValue(native AX probe)",
    records: &actions
  )
  guard let (_, textTree) = waitForElement("a11y.textfield", app: app, timeout: options.timeout),
        let updatedTextfield = textTree.nodesByIdentifier["a11y.textfield"],
        stringAttribute(updatedTextfield, kAXValueAttribute) == "native AX probe" else {
    throw ProbeError.assertion("AXValue did not update a11y.textfield")
  }
  var range = CFRange(location: 0, length: 6)
  guard let rangeValue = AXValueCreate(.cfRange, &range) else {
    throw ProbeError.assertion("failed to create AX text range")
  }
  try setAttribute(
    updatedTextfield,
    attribute: kAXSelectedTextRangeAttribute,
    value: rangeValue,
    id: "a11y.textfield",
    action: "AXSetSelection(0,6)",
    records: &actions
  )
  guard let (_, finalTree) = waitForElement("a11y.textfield", app: app, timeout: options.timeout),
        let finalTextfield = finalTree.nodesByIdentifier["a11y.textfield"] else {
    throw ProbeError.assertion("a11y.textfield unavailable after selection")
  }
  tree = finalTree
  let selection = jsonValue(attribute(finalTextfield, kAXSelectedTextRangeAttribute))
  try perform(finalTextfield, action: kAXConfirmAction, id: "a11y.textfield", records: &actions)

  let finalMissing = requiredIdentifiers.filter { tree.nodesByIdentifier[$0] == nil }
  try require(finalMissing.isEmpty, "final AX tree is missing identifiers: \(finalMissing)")
  let requiredNodes = requiredIdentifiers.compactMap { id -> [String: Any]? in
    guard let element = tree.nodesByIdentifier[id] else { return nil }
    return describeElement(element)
  }
  return [
    "pid": Int(options.pid),
    "trusted": trusted,
    "result": "passed",
    "nativeTree": [
      "source": "ax-api",
      "requiredIdentifiers": requiredIdentifiers,
      "missingIdentifiers": finalMissing,
      "nodes": requiredNodes,
      "nodeCount": tree.serializedNodes.count,
      "dialog": dialogObservation,
    ],
    "actions": actions,
    "keyboardFocus": keyboardFocus,
    "accessibilityFocus": accessibilityFocus,
    "selection": selection,
    "failures": [],
    "announcements": notificationRecorder.announcements,
    "environment": [
      "source": "NSWorkspace",
      "textScale": 1.0,
      "accessibilityContrast": NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
      "reducedMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    ],
  ]
}

private func writeJSON(_ value: [String: Any]) {
  let data = try! JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data("\n".utf8))
}

do {
  let options = try Options.parse()
  writeJSON(try runProbe(options: options))
} catch {
  let message = String(describing: error)
  writeJSON([
    "trusted": AXIsProcessTrusted(),
    "result": "failed",
    "nativeTree": [
      "source": "ax-api",
      "requiredIdentifiers": requiredIdentifiers,
      "missingIdentifiers": requiredIdentifiers,
      "nodes": [],
      "nodeCount": 0,
    ],
    "actions": [],
    "keyboardFocus": [],
    "accessibilityFocus": [],
    "failures": [message],
  ])
  fputs("macOS AX probe failed: \(message)\n", stderr)
  exit(1)
}
