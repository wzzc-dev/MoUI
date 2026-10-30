// HarmonyOS accessibility bridge: exposes the runtime semantics snapshot to
// ArkUI's native accessibility provider.
//
// ArkUI asks for element information through
// `ArkUI_AccessibilityProviderCallbacks` (findAccessibilityNodeInfosById,
// findFocusedAccessibilityNode, executeAccessibilityAction, ...). The provider
// is obtained from the XComponent with
// `OH_NativeXComponent_GetNativeAccessibilityProvider`.
//
// MoUI owns the semantics tree, so this file is a thin translation layer: the
// MoonBit side publishes a flat, generation-stamped array of nodes through
// `mbw_harmonyos_accessibility_publish`, and the ArkUI callbacks here read that
// array. Keeping the projection flat avoids a cross-language object graph and
// keeps every ArkUI element construction in one place.

#include <cstdint>
#include <cstring>

#if __has_include(<arkui/native_interface_accessibility.h>)
#include <arkui/native_interface_accessibility.h>
#define MBW_HARMONYOS_HAS_ARKUI_A11Y 1
#endif

#if __has_include(<ace/xcomponent/native_interface_xcomponent.h>)
#include <ace/xcomponent/native_interface_xcomponent.h>
#define MBW_HARMONYOS_HAS_XCOMPONENT 1
#endif

#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MBW_HARMONYOS_HAS_HILOG 1
#endif

#include <moonbit.h>

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

namespace {

static const unsigned int k_a11y_log_domain = 0x4D4F;
static const char *k_a11y_log_tag = "MoUIHarmony";

void log_a11y(const char *message, int value) {
#if defined(MBW_HARMONYOS_HAS_HILOG)
  OH_LOG_Print(
    LOG_APP,
    LOG_INFO,
    k_a11y_log_domain,
    k_a11y_log_tag,
    "%{public}s value=%{public}d",
    message,
    value
  );
#else
  (void)message;
  (void)value;
#endif
}

// One projected semantics node. `id` is the runtime node id truncated to the
// int64 ArkUI needs; `parent` is 0 for the root.
struct MbwA11yNode {
  int64_t id;
  int64_t parent;
  int32_t role;        // MbwA11yRole
  int32_t flags;       // bit set, see MbwA11yFlag
  int32_t child_count; // number of ids in the child array
  int32_t action_count;
  double left, top, right, bottom;
  const char *label;
  const char *value;
  const char *description;
};

// Role projection. ArkUI expects a component type string; the MoonBit side
// sends this small enum so the mapping stays in one C++ table.
enum MbwA11yRole {
  MBW_A11Y_ROLE_NONE = 0,
  MBW_A11Y_ROLE_BUTTON = 1,
  MBW_A11Y_ROLE_TEXT = 2,
  MBW_A11Y_ROLE_TEXT_FIELD = 3,
  MBW_A11Y_ROLE_CHECKBOX = 4,
  MBW_A11Y_ROLE_SWITCH = 5,
  MBW_A11Y_ROLE_SLIDER = 6,
  MBW_A11Y_ROLE_LIST = 7,
  MBW_A11Y_ROLE_LIST_ITEM = 8,
  MBW_A11Y_ROLE_IMAGE = 9,
  MBW_A11Y_ROLE_HEADING = 10,
  MBW_A11Y_ROLE_LINK = 11,
  MBW_A11Y_ROLE_SCROLL = 12,
  MBW_A11Y_ROLE_GROUP = 13,
};

enum MbwA11yFlag {
  MBW_A11Y_FLAG_FOCUSED = 1 << 0,
  MBW_A11Y_FLAG_SELECTED = 1 << 1,
  MBW_A11Y_FLAG_CHECKED = 1 << 2,
  MBW_A11Y_FLAG_ENABLED = 1 << 3,
  MBW_A11Y_FLAG_CLICKABLE = 1 << 4,
  MBW_A11Y_FLAG_EDITABLE = 1 << 5,
  MBW_A11Y_FLAG_SCROLLABLE = 1 << 6,
};

const char *component_type_for_role(int32_t role) {
  switch (role) {
    case MBW_A11Y_ROLE_BUTTON: return "Button";
    case MBW_A11Y_ROLE_TEXT: return "Text";
    case MBW_A11Y_ROLE_HEADING: return "Text";
    case MBW_A11Y_ROLE_LINK: return "Link";
    case MBW_A11Y_ROLE_TEXT_FIELD: return "TextInput";
    case MBW_A11Y_ROLE_CHECKBOX: return "Checkbox";
    case MBW_A11Y_ROLE_SWITCH: return "Toggle";
    case MBW_A11Y_ROLE_SLIDER: return "Slider";
    case MBW_A11Y_ROLE_LIST: return "List";
    case MBW_A11Y_ROLE_LIST_ITEM: return "ListItem";
    case MBW_A11Y_ROLE_IMAGE: return "Image";
    case MBW_A11Y_ROLE_SCROLL: return "Scroll";
    case MBW_A11Y_ROLE_GROUP: return "Group";
    default: return "Unknown";
  }
}

// Published snapshot. The MoonBit side owns the backing arrays and keeps them
// alive across the call; ArkUI only reads during a callback.
struct MbwA11ySnapshot {
  const MbwA11yNode *nodes;
  int32_t node_count;
  const int64_t *child_ids;
  int32_t child_count;
  const int32_t *action_kinds;
  int32_t action_count;
  int64_t root_id;
  int64_t focused_id;
  int64_t generation;
};

MbwA11ySnapshot g_snapshot = {nullptr, 0, nullptr, 0, nullptr, 0, 0, 0, 0};
bool g_provider_registered = false;
uintptr_t g_xcomponent_handle = 0;

// One pending semantics action. ArkUI delivers at most one action per callback
// and the host loop drains it on the next tick, so a single slot is enough. A
// new request overwrites an undrained one rather than growing a backlog.
struct MbwPendingA11yAction {
  int64_t element_id;
  int32_t action;
  int64_t generation;
  bool valid;
};
MbwPendingA11yAction g_pending_action = {0, 0, 0, false};

const MbwA11yNode *find_node(int64_t id) {
  for (int32_t i = 0; i < g_snapshot.node_count; ++i) {
    if (g_snapshot.nodes[i].id == id) {
      return &g_snapshot.nodes[i];
    }
  }
  return nullptr;
}

#if defined(MBW_HARMONYOS_HAS_ARKUI_A11Y)

// Fills one ArkUI element from a projected node plus its child slice.
void fill_element_info(
    const MbwA11yNode &node,
    ArkUI_AccessibilityElementInfo *info
) {
  if (info == nullptr) {
    return;
  }
  (void)OH_ArkUI_AccessibilityElementInfoSetElementId(info, node.id);
  (void)OH_ArkUI_AccessibilityElementInfoSetParentId(info, node.parent);
  (void)OH_ArkUI_AccessibilityElementInfoSetComponentType(
    info, component_type_for_role(node.role)
  );
  if (node.label != nullptr) {
    (void)OH_ArkUI_AccessibilityElementInfoSetContents(info, node.label);
  }
  if (node.value != nullptr && node.value[0] != '\0') {
    (void)OH_ArkUI_AccessibilityElementInfoSetAccessibilityText(
      info, node.value
    );
  }
  if (node.description != nullptr && node.description[0] != '\0') {
    (void)OH_ArkUI_AccessibilityElementInfoSetAccessibilityDescription(
      info, node.description
    );
  }
  ArkUI_AccessibleRect rect;
  rect.leftTopX = static_cast<int32_t>(node.left);
  rect.leftTopY = static_cast<int32_t>(node.top);
  rect.rightBottomX = static_cast<int32_t>(node.right);
  rect.rightBottomY = static_cast<int32_t>(node.bottom);
  (void)OH_ArkUI_AccessibilityElementInfoSetScreenRect(info, &rect);
  (void)OH_ArkUI_AccessibilityElementInfoSetVisible(info, true);
  (void)OH_ArkUI_AccessibilityElementInfoSetEnabled(
    info, (node.flags & MBW_A11Y_FLAG_ENABLED) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetClickable(
    info, (node.flags & MBW_A11Y_FLAG_CLICKABLE) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetEditable(
    info, (node.flags & MBW_A11Y_FLAG_EDITABLE) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetScrollable(
    info, (node.flags & MBW_A11Y_FLAG_SCROLLABLE) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetSelected(
    info, (node.flags & MBW_A11Y_FLAG_SELECTED) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetChecked(
    info, (node.flags & MBW_A11Y_FLAG_CHECKED) != 0
  );
  (void)OH_ArkUI_AccessibilityElementInfoSetFocused(info, node.id == g_snapshot.focused_id);
  (void)OH_ArkUI_AccessibilityElementInfoSetFocusable(info, true);
}

int32_t a11y_find_by_id(
    int64_t elementId,
    ArkUI_AccessibilitySearchMode mode,
    int32_t requestId,
    ArkUI_AccessibilityElementInfoList *list
) {
  (void)mode;
  (void)requestId;
  if (list == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_BAD_PARAMETER;
  }
  if (g_snapshot.node_count == 0) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_FAILED;
  }
  // ArkUI passes 0/-1 to mean "start from the root".
  const int64_t wanted = elementId <= 0 ? g_snapshot.root_id : elementId;
  const MbwA11yNode *node = find_node(wanted);
  if (node == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_FAILED;
  }
  ArkUI_AccessibilityElementInfo *info =
    OH_ArkUI_AddAndGetAccessibilityElementInfo(list);
  fill_element_info(*node, info);
  log_a11y("accessibility find by id", static_cast<int>(node->id & 0xFFFF));
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_find_by_text(
    int64_t elementId,
    const char *text,
    int32_t requestId,
    ArkUI_AccessibilityElementInfoList *list
) {
  (void)elementId;
  (void)requestId;
  if (list == nullptr || text == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_BAD_PARAMETER;
  }
  for (int32_t i = 0; i < g_snapshot.node_count; ++i) {
    const MbwA11yNode &node = g_snapshot.nodes[i];
    const bool label_match =
      node.label != nullptr && std::strstr(node.label, text) != nullptr;
    const bool value_match =
      node.value != nullptr && std::strstr(node.value, text) != nullptr;
    if (!label_match && !value_match) {
      continue;
    }
    ArkUI_AccessibilityElementInfo *info =
      OH_ArkUI_AddAndGetAccessibilityElementInfo(list);
    fill_element_info(node, info);
  }
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_find_focused(
    int64_t elementId,
    ArkUI_AccessibilityFocusType focusType,
    int32_t requestId,
    ArkUI_AccessibilityElementInfo *elementInfo
) {
  (void)elementId;
  (void)focusType;
  (void)requestId;
  const MbwA11yNode *node = find_node(g_snapshot.focused_id);
  if (node == nullptr) {
    node = find_node(g_snapshot.root_id);
  }
  if (node == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_FAILED;
  }
  fill_element_info(*node, elementInfo);
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_find_next_focus(
    int64_t elementId,
    ArkUI_AccessibilityFocusMoveDirection direction,
    int32_t requestId,
    ArkUI_AccessibilityElementInfo *elementInfo
) {
  (void)elementId;
  (void)direction;
  (void)requestId;
  if (elementInfo == nullptr || g_snapshot.node_count == 0) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_FAILED;
  }
  // Focus order follows the published array; the MoonBit side already emits
  // nodes in focus order, so the next entry is the next focusable node.
  for (int32_t i = 0; i < g_snapshot.node_count; ++i) {
    if ((g_snapshot.nodes[i].flags & MBW_A11Y_FLAG_FOCUSED) != 0) {
      const int32_t next = (i + 1) % g_snapshot.node_count;
      fill_element_info(g_snapshot.nodes[next], elementInfo);
      return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
    }
  }
  fill_element_info(g_snapshot.nodes[0], elementInfo);
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_execute_action(
    int64_t elementId,
    ArkUI_Accessibility_ActionType action,
    ArkUI_AccessibilityActionArguments *actionArguments,
    int32_t requestId
) {
  (void)actionArguments;
  (void)requestId;
  const MbwA11yNode *node = find_node(elementId);
  if (node == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_FAILED;
  }
  // ArkUI callbacks run on the platform UI thread and cannot re-enter the
  // MoonBit runtime, so the request is queued here and drained by the host loop
  // through mbw_harmonyos_accessibility_take_action. Returning SUCCESSFUL tells
  // ArkUI the action was accepted; a dropped queue entry simply never dispatches.
  g_pending_action.element_id = elementId;
  g_pending_action.action = static_cast<int32_t>(action);
  g_pending_action.generation = g_snapshot.generation;
  g_pending_action.valid = true;
  log_a11y("accessibility queue action", static_cast<int>(action));
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_clear_focus(void) {
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

int32_t a11y_cursor_position(
    int64_t elementId,
    int32_t requestId,
    int32_t *index
) {
  (void)elementId;
  (void)requestId;
  if (index == nullptr) {
    return ARKUI_ACCESSIBILITY_NATIVE_RESULT_BAD_PARAMETER;
  }
  *index = 0;
  return ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
}

ArkUI_AccessibilityProviderCallbacks g_callbacks = {
  a11y_find_by_id,
  a11y_find_by_text,
  a11y_find_focused,
  a11y_find_next_focus,
  a11y_execute_action,
  a11y_clear_focus,
  a11y_cursor_position,
};

#endif  // MBW_HARMONYOS_HAS_ARKUI_A11Y

}  // namespace

extern "C" {

// Sets the OH_NativeXComponent the provider should attach to. The NAPI module
// owns that pointer (`g_xcomponent`), so it hands it over once at init instead
// of MoonBit guessing a handle: the host channel only exposes the native window
// handle, which is a different object.
MOONBIT_FFI_EXPORT void mbw_harmonyos_accessibility_set_xcomponent(
    int64_t xcomponent_handle
) {
  g_xcomponent_handle = static_cast<uintptr_t>(xcomponent_handle);
}

// Registers the ArkUI accessibility provider against the XComponent recorded by
// mbw_harmonyos_accessibility_set_xcomponent. Returns 1 when registration
// succeeded.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_accessibility_register(void) {
#if defined(MBW_HARMONYOS_HAS_ARKUI_A11Y) && \
  defined(MBW_HARMONYOS_HAS_XCOMPONENT)
  if (g_xcomponent_handle == 0) {
    log_a11y("accessibility register no xcomponent", 0);
    return 0;
  }
  auto *component = reinterpret_cast<OH_NativeXComponent *>(g_xcomponent_handle);
  ArkUI_AccessibilityProvider *provider = nullptr;
  const int32_t got = OH_NativeXComponent_GetNativeAccessibilityProvider(
    component, &provider
  );
  if (got != 0 || provider == nullptr) {
    log_a11y(
      "accessibility provider unavailable, code", got
    );
    log_a11y(
      "accessibility provider null", provider == nullptr ? 1 : 0
    );
    return 0;
  }
  const int32_t registered = OH_ArkUI_AccessibilityProviderRegisterCallback(
    provider, &g_callbacks
  );
  g_provider_registered =
    registered == ARKUI_ACCESSIBILITY_NATIVE_RESULT_SUCCESSFUL;
  // The ArkUI result enum uses 0 for SUCCESSFUL, so log the boolean rather
  // than the raw code to keep the device evidence unambiguous.
  log_a11y("accessibility provider registered ok", g_provider_registered ? 1 : 0);
  return g_provider_registered ? 1 : 0;
#else
  log_a11y("accessibility unsupported build", 0);
  return 0;
#endif
}

// Publishes the current semantics snapshot. The MoonBit side keeps the backing
// arrays alive until the next publish, so ArkUI can read them synchronously
// from its callbacks.
MOONBIT_FFI_EXPORT void mbw_harmonyos_accessibility_publish(
    int64_t nodes_ptr,
    int32_t node_count,
    int64_t child_ids_ptr,
    int32_t child_count,
    int64_t action_kinds_ptr,
    int32_t action_count,
    int64_t root_id,
    int64_t focused_id,
    int64_t generation
) {
  g_snapshot.nodes =
    reinterpret_cast<const MbwA11yNode *>(static_cast<uintptr_t>(nodes_ptr));
  g_snapshot.node_count = node_count;
  g_snapshot.child_ids =
    reinterpret_cast<const int64_t *>(static_cast<uintptr_t>(child_ids_ptr));
  g_snapshot.child_count = child_count;
  g_snapshot.action_kinds = reinterpret_cast<const int32_t *>(
    static_cast<uintptr_t>(action_kinds_ptr)
  );
  g_snapshot.action_count = action_count;
  g_snapshot.root_id = root_id;
  g_snapshot.focused_id = focused_id;
  const bool generation_changed = g_snapshot.generation != generation;
  g_snapshot.generation = generation;
  // Log only on a new generation so a 60 Hz pump does not flood hilog.
  if (generation_changed) {
    log_a11y("accessibility published nodes", node_count);
  }
}

// Drains the pending ArkUI semantics action. Returns 1 and fills the out-params
// when an action was queued since the last call.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_accessibility_take_action(
    int64_t *element_id,
    int32_t *action,
    int64_t *generation
) {
  if (!g_pending_action.valid || element_id == nullptr || action == nullptr ||
      generation == nullptr) {
    return 0;
  }
  *element_id = g_pending_action.element_id;
  *action = g_pending_action.action;
  *generation = g_pending_action.generation;
  g_pending_action.valid = false;
  return 1;
}

// Generic text logger for host service requests, so a clipboard shortcut shows
// up in the device log even when no pixels change.
MOONBIT_FFI_EXPORT void mbw_harmonyos_log_text(
    moonbit_bytes_t tag,
    moonbit_bytes_t text
) {
#if defined(MBW_HARMONYOS_HAS_HILOG)
  const char *tag_text = reinterpret_cast<const char *>(tag);
  const char *message = reinterpret_cast<const char *>(text);
  if (tag_text == nullptr || message == nullptr) {
    return;
  }
  OH_LOG_Print(LOG_APP, LOG_INFO, k_a11y_log_domain, tag_text,
               "%{public}s", message);
#else
  (void)tag;
  (void)text;
#endif
}

// Device-log hook for the async image load evidence. MoonBit `println` output
// does not reach hilog on this platform, so the backend forwards its image
// status summary here.
MOONBIT_FFI_EXPORT void mbw_harmonyos_log_image_status(
    moonbit_bytes_t summary
) {
  const int32_t len = static_cast<int32_t>(Moonbit_array_length(summary));
  if (len <= 0) {
    return;
  }
#if defined(MBW_HARMONYOS_HAS_HILOG)
  OH_LOG_Print(
    LOG_APP,
    LOG_INFO,
    k_a11y_log_domain,
    k_a11y_log_tag,
    "images %{public}s",
    reinterpret_cast<const char *>(summary)
  );
#else
  (void)len;
#endif
}

// Reports whether the provider is registered and how many nodes are published,
// so a device log can prove the bridge is live.
MOONBIT_FFI_EXPORT int32_t mbw_harmonyos_accessibility_status(void) {
  return (g_provider_registered ? 1000000 : 0) + g_snapshot.node_count;
}


// Address shims: MoonBit has no portable pointer arithmetic, so the projection
// arrays hand their element addresses over here. The MoonBit side keeps the
// FixedArrays alive for the duration of the publish call.
// A MoonBit FixedArray crosses the FFI as an object pointer; the element data
// starts at that address for these unboxed element types.
MOONBIT_FFI_EXPORT uint64_t mbw_harmonyos_int64_address(void *array) {
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(array));
}

MOONBIT_FFI_EXPORT uint64_t mbw_harmonyos_int32_address(void *array) {
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(array));
}

MOONBIT_FFI_EXPORT uint64_t mbw_harmonyos_record_address(void *array) {
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(array));
}

}  // extern "C"
