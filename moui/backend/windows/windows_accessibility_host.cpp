#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#ifndef interface
// Some MoonBit MSVC invocations do not inherit the COM interface macro from
// the SDK precompiled headers. UI Automation's generated headers use it for
// their forward declarations, so provide the C++ spelling when absent.
#define interface struct
#endif
#include <UIAutomation.h>
#include <Uiautomationcoreapi.h>
#include <oleauto.h>
#include <moonbit.h>
#include <stdint.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace {

constexpr UINT kWmGetObject = 0x003d;
constexpr uint64_t kActionActivate = 1ULL << 0;
constexpr uint64_t kActionFocus = 1ULL << 1;
constexpr uint64_t kActionSetText = 1ULL << 2;
constexpr uint64_t kActionScroll = 1ULL << 4;
constexpr uint64_t kActionSelect = 1ULL << 5;
constexpr uint64_t kActionExpand = 1ULL << 6;
constexpr uint64_t kActionCollapse = 1ULL << 7;
constexpr uint64_t kActionIncrement = 1ULL << 9;
constexpr uint64_t kActionDecrement = 1ULL << 10;
constexpr uint64_t kActionSetNumeric = 1ULL << 11;

struct NodeData {
  uint64_t id = 0;
  uint64_t generation = 0;
  std::string semantic_id;
  std::string role;
  std::string label;
  std::string value;
  std::string description;
  uint64_t state = 0;
  int checked = -1;
  int numeric_flags = 0;
  double current = 0;
  double minimum = 0;
  double maximum = 0;
  double step = 0;
  int text_flags = 0;
  int selection_start = -1;
  int selection_end = -1;
  int caret = -1;
  int row_index = -1;
  int row_count = -1;
  int row_span = -1;
  int column_index = -1;
  int column_count = -1;
  int column_span = -1;
  int set_size = -1;
  int set_position = -1;
  uint64_t actions = 0;
  int live = 0;
  bool live_atomic = false;
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  std::vector<uint64_t> children;
  std::vector<uint64_t> labelled_by;
  std::vector<uint64_t> described_by;
  std::vector<uint64_t> controls;
  std::vector<uint64_t> error_message;
  std::vector<uint64_t> active_descendant;
};

class MouiUiaProvider;

struct WindowBridge {
  HWND hwnd = nullptr;
  uint64_t generation = 0;
  uint64_t root = 0;
  uint64_t focused = 0;
  uint64_t semantic_focused = 0;
  uint64_t previous_focused = 0;
  bool updating_full = false;
  bool structure_changed = false;
  std::map<uint64_t, NodeData> nodes;
  std::map<uint64_t, MouiUiaProvider *> providers;
  std::deque<std::string> actions;
};

std::recursive_mutex g_mutex;
std::map<HWND, std::unique_ptr<WindowBridge>> g_windows;
bool g_hook_install_attempted = false;
bool g_hook_installed = false;

using NativeMessageHook = int32_t (*)(uint64_t, uint32_t, uint64_t, int64_t,
                                      uint64_t *, void *);
using InstallNativeMessageHook = void (*)(NativeMessageHook, void *);

static std::wstring utf8_to_wide(const std::string &value) {
  if (value.empty()) return {};
  int length = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                   static_cast<int>(value.size()), nullptr, 0);
  if (length <= 0) return {};
  std::wstring result(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      &result[0], length);
  return result;
}

static std::string wide_to_utf8(const wchar_t *value) {
  if (!value) return {};
  int wide_length = static_cast<int>(wcslen(value));
  if (wide_length == 0) return {};
  int length = WideCharToMultiByte(CP_UTF8, 0, value, wide_length, nullptr, 0,
                                   nullptr, nullptr);
  std::string result(static_cast<size_t>(std::max(0, length)), '\0');
  if (length > 0) {
    WideCharToMultiByte(CP_UTF8, 0, value, wide_length, &result[0], length,
                        nullptr, nullptr);
  }
  return result;
}

static std::string bytes_string(moonbit_bytes_t bytes) {
  if (!bytes) return {};
  int32_t length = static_cast<int32_t>(Moonbit_array_length(bytes));
  return length > 0
             ? std::string(reinterpret_cast<const char *>(bytes),
                           static_cast<size_t>(length))
             : std::string();
}

static std::vector<uint64_t> parse_ids(moonbit_bytes_t bytes) {
  std::vector<uint64_t> ids;
  std::string source = bytes_string(bytes);
  size_t offset = 0;
  while (offset < source.size()) {
    size_t end = source.find(',', offset);
    std::string token = source.substr(offset, end - offset);
    if (!token.empty()) {
      char *tail = nullptr;
      unsigned long long value = strtoull(token.c_str(), &tail, 10);
      if (tail && *tail == '\0' && value != 0) ids.push_back(value);
    }
    if (end == std::string::npos) break;
    offset = end + 1;
  }
  return ids;
}

static std::string json_escape(const std::string &value) {
  std::ostringstream out;
  for (unsigned char ch : value) {
    switch (ch) {
      case '\\': out << "\\\\"; break;
      case '"': out << "\\\""; break;
      case '\n': out << "\\n"; break;
      case '\r': out << "\\r"; break;
      case '\t': out << "\\t"; break;
      default:
        if (ch < 0x20) {
          const char *hex = "0123456789abcdef";
          out << "\\u00" << hex[ch >> 4] << hex[ch & 0xf];
        } else {
          out << static_cast<char>(ch);
        }
    }
  }
  return out.str();
}

static NodeData *node_for(HWND hwnd, uint64_t node_id) {
  auto window = g_windows.find(hwnd);
  if (window == g_windows.end()) return nullptr;
  auto node = window->second->nodes.find(node_id);
  return node == window->second->nodes.end() ? nullptr : &node->second;
}

static WindowBridge *window_for(HWND hwnd) {
  auto found = g_windows.find(hwnd);
  return found == g_windows.end() ? nullptr : found->second.get();
}

static uint64_t parent_id(WindowBridge *window, uint64_t child) {
  if (!window) return 0;
  for (const auto &entry : window->nodes) {
    const auto &children = entry.second.children;
    if (std::find(children.begin(), children.end(), child) != children.end())
      return entry.first;
  }
  return 0;
}

static CONTROLTYPEID control_type(const NodeData &node) {
  const std::string &role = node.role;
  if (role == "button") return UIA_ButtonControlTypeId;
  if (role == "checkbox" || role == "switch") return UIA_CheckBoxControlTypeId;
  if (role == "radio") return UIA_RadioButtonControlTypeId;
  if (role == "slider") return UIA_SliderControlTypeId;
  if (role == "progress") return UIA_ProgressBarControlTypeId;
  if (role == "text_field") return UIA_EditControlTypeId;
  if (role == "text" || role == "heading" || role == "status" ||
      role == "alert") return UIA_TextControlTypeId;
  if (role == "link") return UIA_HyperlinkControlTypeId;
  if (role == "image") return UIA_ImageControlTypeId;
  if (role == "list") return UIA_ListControlTypeId;
  if (role == "list_item" || role == "option") return UIA_ListItemControlTypeId;
  if (role == "grid" || role == "table") return UIA_DataGridControlTypeId;
  if (role == "row") return UIA_DataItemControlTypeId;
  if (role == "cell") return UIA_DataItemControlTypeId;
  if (role == "tree") return UIA_TreeControlTypeId;
  if (role == "tree_item") return UIA_TreeItemControlTypeId;
  if (role == "scroll_view") return UIA_PaneControlTypeId;
  if (role == "menu") return UIA_MenuControlTypeId;
  if (role == "combo_box") return UIA_ComboBoxControlTypeId;
  if (role == "tab") return UIA_TabItemControlTypeId;
  if (role == "separator") return UIA_SeparatorControlTypeId;
  if (role == "dialog") return UIA_WindowControlTypeId;
  return UIA_GroupControlTypeId;
}

static void enqueue_action(HWND hwnd, uint64_t node_id, const char *kind,
                           const std::string &value = {}) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd);
  NodeData *node = node_for(hwnd, node_id);
  if (!window || !node) return;
  std::ostringstream out;
  out << "{\"node_id\":\"" << node_id << "\",\"generation\":\""
      << node->generation << "\",\"kind\":\"" << kind
      << "\",\"value\":\"" << json_escape(value) << "\"}";
  while (window->actions.size() >= 256) window->actions.pop_front();
  window->actions.push_back(out.str());
}

static HRESULT require_action(HWND hwnd, uint64_t node_id, uint64_t action) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  NodeData *node = node_for(hwnd, node_id);
  if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
  return (node->actions & action) ? S_OK : UIA_E_NOTSUPPORTED;
}

class MouiUiaProvider final : public IRawElementProviderSimple,
                              public IRawElementProviderFragment,
                              public IRawElementProviderFragmentRoot,
                              public IInvokeProvider,
                              public IToggleProvider,
                              public IValueProvider,
                              public IRangeValueProvider,
                              public IExpandCollapseProvider,
                              public ISelectionItemProvider,
                              public IScrollProvider {
 public:
  MouiUiaProvider(HWND hwnd, uint64_t node_id)
      : hwnd_(hwnd), node_id_(node_id) {}

  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs_; }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG result = --refs_;
    if (!result) delete this;
    return result;
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
    if (!out) return E_INVALIDARG;
    *out = nullptr;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    WindowBridge *window = window_for(hwnd_);
    if (!node || !window) return UIA_E_ELEMENTNOTAVAILABLE;
    if (iid == __uuidof(IUnknown) || iid == __uuidof(IRawElementProviderSimple))
      *out = static_cast<IRawElementProviderSimple *>(this);
    else if (iid == __uuidof(IRawElementProviderFragment))
      *out = static_cast<IRawElementProviderFragment *>(this);
    else if (iid == __uuidof(IRawElementProviderFragmentRoot) &&
             node_id_ == window->root)
      *out = static_cast<IRawElementProviderFragmentRoot *>(this);
    else if (iid == __uuidof(IInvokeProvider) &&
             (node->actions & kActionActivate))
      *out = static_cast<IInvokeProvider *>(this);
    else if (iid == __uuidof(IToggleProvider) && node->checked >= 0 &&
             (node->actions & kActionActivate))
      *out = static_cast<IToggleProvider *>(this);
    else if (iid == __uuidof(IValueProvider) &&
             (node->actions & kActionSetText))
      *out = static_cast<IValueProvider *>(this);
    else if (iid == __uuidof(IRangeValueProvider) && node->numeric_flags)
      *out = static_cast<IRangeValueProvider *>(this);
    else if (iid == __uuidof(IExpandCollapseProvider) &&
             (node->actions & (kActionExpand | kActionCollapse)))
      *out = static_cast<IExpandCollapseProvider *>(this);
    else if (iid == __uuidof(ISelectionItemProvider) &&
             (node->actions & kActionSelect))
      *out = static_cast<ISelectionItemProvider *>(this);
    else if (iid == __uuidof(IScrollProvider) &&
             (node->actions & kActionScroll))
      *out = static_cast<IScrollProvider *>(this);
    else
      return E_NOINTERFACE;
    AddRef();
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_ProviderOptions(ProviderOptions *value) override {
    if (!value) return E_INVALIDARG;
    *value = ProviderOptions_ServerSideProvider;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE GetPatternProvider(PATTERNID pattern,
                                                IUnknown **value) override {
    if (!value) return E_INVALIDARG;
    *value = nullptr;
    if (pattern == UIA_InvokePatternId)
      return QueryInterface(__uuidof(IInvokeProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_TogglePatternId)
      return QueryInterface(__uuidof(IToggleProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_ValuePatternId)
      return QueryInterface(__uuidof(IValueProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_RangeValuePatternId)
      return QueryInterface(__uuidof(IRangeValueProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_ExpandCollapsePatternId)
      return QueryInterface(__uuidof(IExpandCollapseProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_SelectionItemPatternId)
      return QueryInterface(__uuidof(ISelectionItemProvider),
                            reinterpret_cast<void **>(value));
    if (pattern == UIA_ScrollPatternId)
      return QueryInterface(__uuidof(IScrollProvider),
                            reinterpret_cast<void **>(value));
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE GetPropertyValue(PROPERTYID property,
                                              VARIANT *value) override {
    if (!value) return E_INVALIDARG;
    VariantInit(value);
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    if (property == UIA_ControlTypePropertyId) {
      value->vt = VT_I4;
      value->lVal = control_type(*node);
    } else if (property == UIA_NamePropertyId) {
      value->vt = VT_BSTR;
      value->bstrVal = SysAllocString(utf8_to_wide(node->label).c_str());
    } else if (property == UIA_AutomationIdPropertyId) {
      value->vt = VT_BSTR;
      value->bstrVal = SysAllocString(utf8_to_wide(node->semantic_id).c_str());
    } else if (property == UIA_HelpTextPropertyId) {
      value->vt = VT_BSTR;
      value->bstrVal = SysAllocString(utf8_to_wide(node->description).c_str());
    } else if (property == UIA_IsEnabledPropertyId) {
      value->vt = VT_BOOL;
      value->boolVal = (node->state & 2) ? VARIANT_FALSE : VARIANT_TRUE;
    } else if (property == UIA_HasKeyboardFocusPropertyId) {
      value->vt = VT_BOOL;
      value->boolVal = (node->state & 1) ? VARIANT_TRUE : VARIANT_FALSE;
    } else if (property == UIA_IsKeyboardFocusablePropertyId) {
      value->vt = VT_BOOL;
      value->boolVal = (node->actions & kActionFocus) ? VARIANT_TRUE
                                                     : VARIANT_FALSE;
    } else if (property == UIA_IsPasswordPropertyId) {
      value->vt = VT_BOOL;
      value->boolVal = (node->state & 1024) ? VARIANT_TRUE : VARIANT_FALSE;
    } else if (property == UIA_IsRequiredForFormPropertyId) {
      value->vt = VT_BOOL;
      value->boolVal = (node->state & 64) ? VARIANT_TRUE : VARIANT_FALSE;
    } else if (property == UIA_PositionInSetPropertyId &&
               node->set_position >= 0) {
      value->vt = VT_I4;
      value->lVal = node->set_position;
    } else if (property == UIA_SizeOfSetPropertyId && node->set_size >= 0) {
      value->vt = VT_I4;
      value->lVal = node->set_size;
    } else if (property == UIA_AriaRolePropertyId) {
      value->vt = VT_BSTR;
      value->bstrVal = SysAllocString(utf8_to_wide(node->role).c_str());
    } else if (property == UIA_LiveSettingPropertyId) {
      value->vt = VT_I4;
      value->lVal = node->live == 2 ? Assertive : node->live == 1 ? Polite : Off;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(
      IRawElementProviderSimple **value) override {
    if (!value) return E_INVALIDARG;
    *value = nullptr;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    WindowBridge *window = window_for(hwnd_);
    if (!window) return UIA_E_ELEMENTNOTAVAILABLE;
    if (node_id_ == window->root)
      return UiaHostProviderFromHwnd(hwnd_, value);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Navigate(NavigateDirection direction,
                                     IRawElementProviderFragment **value) override;

  HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY **value) override {
    if (!value) return E_INVALIDARG;
    int runtime_id[3] = {UiaAppendRuntimeId,
                         static_cast<int>(node_id_ & 0x7fffffff),
                         static_cast<int>((node_id_ >> 31) & 0x7fffffff)};
    SAFEARRAY *result = SafeArrayCreateVector(VT_I4, 0, 3);
    if (!result) return E_OUTOFMEMORY;
    for (LONG i = 0; i < 3; ++i) SafeArrayPutElement(result, &i, &runtime_id[i]);
    *value = result;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    UINT dpi = GetDpiForWindow(hwnd_);
    double scale = dpi > 0 ? static_cast<double>(dpi) / 96.0 : 1.0;
    POINT origin = {0, 0};
    ClientToScreen(hwnd_, &origin);
    value->left = origin.x + node->x * scale;
    value->top = origin.y + node->y * scale;
    value->width = node->width * scale;
    value->height = node->height * scale;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY **value) override {
    if (!value) return E_INVALIDARG;
    *value = nullptr;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE SetFocus() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionFocus);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "focus");
    PostMessageW(hwnd_, WM_NULL, 0, 0);
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_FragmentRoot(
      IRawElementProviderFragmentRoot **value) override;

  HRESULT STDMETHODCALLTYPE ElementProviderFromPoint(
      double x, double y, IRawElementProviderFragment **value) override;

  HRESULT STDMETHODCALLTYPE GetFocus(IRawElementProviderFragment **value) override;

  HRESULT STDMETHODCALLTYPE Invoke() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionActivate);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "activate");
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Toggle() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionActivate);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "activate");
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_ToggleState(ToggleState *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    *value = node->checked == 2 ? ToggleState_Indeterminate
             : node->checked == 1 ? ToggleState_On
                                  : ToggleState_Off;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE SetValue(LPCWSTR value) override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionSetText);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "set_text", wide_to_utf8(value));
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_Value(BSTR *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    *value = SysAllocString(utf8_to_wide(node->value).c_str());
    return *value ? S_OK : E_OUTOFMEMORY;
  }

  HRESULT STDMETHODCALLTYPE get_IsReadOnly(BOOL *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    const bool action_read_only = node->numeric_flags
        ? !(node->actions & kActionSetNumeric)
        : !(node->actions & kActionSetText);
    *value = ((node->state & 128) || action_read_only) ? TRUE : FALSE;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE SetValue(double value) override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionSetNumeric);
    if (FAILED(supported)) return supported;
    std::ostringstream text;
    text.precision(17);
    text << value;
    enqueue_action(hwnd_, node_id_, "set_numeric_value", text.str());
    return S_OK;
  }

  HRESULT numeric_value(double *value, int flag, double NodeData::*field) {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    *value = (node->numeric_flags & flag) ? node->*field : 0.0;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE get_Value(double *value) override {
    return numeric_value(value, 1, &NodeData::current);
  }
  HRESULT STDMETHODCALLTYPE get_Maximum(double *value) override {
    return numeric_value(value, 4, &NodeData::maximum);
  }
  HRESULT STDMETHODCALLTYPE get_Minimum(double *value) override {
    return numeric_value(value, 2, &NodeData::minimum);
  }
  HRESULT STDMETHODCALLTYPE get_LargeChange(double *value) override {
    return numeric_value(value, 8, &NodeData::step);
  }
  HRESULT STDMETHODCALLTYPE get_SmallChange(double *value) override {
    return numeric_value(value, 8, &NodeData::step);
  }

  HRESULT STDMETHODCALLTYPE Expand() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionExpand);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "expand");
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Collapse() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionCollapse);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "collapse");
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_ExpandCollapseState(
      ExpandCollapseState *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    *value = (node->state & 16) ? ExpandCollapseState_Expanded
                               : ExpandCollapseState_Collapsed;
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE Select() override {
    HRESULT supported = require_action(hwnd_, node_id_, kActionSelect);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, "select");
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE AddToSelection() override { return Select(); }
  HRESULT STDMETHODCALLTYPE RemoveFromSelection() override {
    // The neutral contract currently exposes only Select. Do not report a
    // successful UIA operation that cannot be represented by the runtime.
    return UIA_E_NOTSUPPORTED;
  }
  HRESULT STDMETHODCALLTYPE get_IsSelected(BOOL *value) override {
    if (!value) return E_INVALIDARG;
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    NodeData *node = node_for(hwnd_, node_id_);
    if (!node) return UIA_E_ELEMENTNOTAVAILABLE;
    *value = (node->state & 4) ? TRUE : FALSE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_SelectionContainer(
      IRawElementProviderSimple **value) override;

  HRESULT STDMETHODCALLTYPE Scroll(ScrollAmount horizontal,
                                   ScrollAmount vertical) override {
    const char *action = nullptr;
    if (vertical == ScrollAmount_LargeIncrement ||
        vertical == ScrollAmount_SmallIncrement) {
      action = "scroll_down";
    }
    else if (vertical == ScrollAmount_LargeDecrement ||
             vertical == ScrollAmount_SmallDecrement) {
      action = "scroll_up";
    }
    else if (horizontal == ScrollAmount_LargeIncrement ||
             horizontal == ScrollAmount_SmallIncrement) {
      action = "scroll_right";
    }
    else if (horizontal == ScrollAmount_LargeDecrement ||
             horizontal == ScrollAmount_SmallDecrement) {
      action = "scroll_left";
    }
    if (!action) return UIA_E_NOTSUPPORTED;
    HRESULT supported = require_action(hwnd_, node_id_, kActionScroll);
    if (FAILED(supported)) return supported;
    enqueue_action(hwnd_, node_id_, action);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetScrollPercent(double, double) override {
    return UIA_E_NOTSUPPORTED;
  }
  HRESULT STDMETHODCALLTYPE get_HorizontalScrollPercent(double *value) override {
    if (!value) return E_INVALIDARG;
    *value = -1.0;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_HorizontalViewSize(double *value) override {
    if (!value) return E_INVALIDARG;
    *value = 100.0;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_VerticalScrollPercent(double *value) override {
    if (!value) return E_INVALIDARG;
    *value = -1.0;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_VerticalViewSize(double *value) override {
    if (!value) return E_INVALIDARG;
    *value = 100.0;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_HorizontallyScrollable(BOOL *value) override {
    if (!value) return E_INVALIDARG;
    *value = TRUE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_VerticallyScrollable(BOOL *value) override {
    if (!value) return E_INVALIDARG;
    *value = TRUE;
    return S_OK;
  }

  HWND hwnd() const { return hwnd_; }
  uint64_t node_id() const { return node_id_; }

 private:
  ~MouiUiaProvider() = default;
  std::atomic<ULONG> refs_{1};
  HWND hwnd_;
  uint64_t node_id_;
};

static MouiUiaProvider *provider_for(WindowBridge *window, uint64_t id) {
  if (!window || !id || window->nodes.find(id) == window->nodes.end())
    return nullptr;
  auto found = window->providers.find(id);
  if (found != window->providers.end()) return found->second;
  auto *provider = new MouiUiaProvider(window->hwnd, id);
  window->providers[id] = provider;
  return provider;
}

HRESULT MouiUiaProvider::Navigate(NavigateDirection direction,
                                  IRawElementProviderFragment **value) {
  if (!value) return E_INVALIDARG;
  *value = nullptr;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd_);
  NodeData *node = node_for(hwnd_, node_id_);
  if (!window || !node) return UIA_E_ELEMENTNOTAVAILABLE;
  uint64_t target = 0;
  if (direction == NavigateDirection_Parent) {
    target = parent_id(window, node_id_);
  } else if (direction == NavigateDirection_FirstChild && !node->children.empty()) {
    target = node->children.front();
  } else if (direction == NavigateDirection_LastChild && !node->children.empty()) {
    target = node->children.back();
  } else if (direction == NavigateDirection_NextSibling ||
             direction == NavigateDirection_PreviousSibling) {
    uint64_t parent = parent_id(window, node_id_);
    NodeData *parent_node = node_for(hwnd_, parent);
    if (parent_node) {
      auto current = std::find(parent_node->children.begin(),
                               parent_node->children.end(), node_id_);
      if (current != parent_node->children.end()) {
        if (direction == NavigateDirection_NextSibling &&
            current + 1 != parent_node->children.end())
          target = *(current + 1);
        if (direction == NavigateDirection_PreviousSibling &&
            current != parent_node->children.begin())
          target = *(current - 1);
      }
    }
  }
  MouiUiaProvider *provider = provider_for(window, target);
  if (provider) {
    provider->AddRef();
    *value = static_cast<IRawElementProviderFragment *>(provider);
  }
  return S_OK;
}

HRESULT MouiUiaProvider::get_FragmentRoot(
    IRawElementProviderFragmentRoot **value) {
  if (!value) return E_INVALIDARG;
  *value = nullptr;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd_);
  if (!window || !node_for(hwnd_, node_id_)) return UIA_E_ELEMENTNOTAVAILABLE;
  MouiUiaProvider *root = provider_for(window, window->root);
  if (root) {
    root->AddRef();
    *value = static_cast<IRawElementProviderFragmentRoot *>(root);
  }
  return S_OK;
}

HRESULT MouiUiaProvider::ElementProviderFromPoint(
    double x, double y, IRawElementProviderFragment **value) {
  if (!value) return E_INVALIDARG;
  *value = nullptr;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd_);
  if (!window) return UIA_E_ELEMENTNOTAVAILABLE;
  MouiUiaProvider *best = provider_for(window, window->root);
  double best_area = HUGE_VAL;
  for (auto &entry : window->nodes) {
    MouiUiaProvider *candidate = provider_for(window, entry.first);
    UiaRect rect{};
    if (candidate && SUCCEEDED(candidate->get_BoundingRectangle(&rect)) &&
        x >= rect.left && y >= rect.top && x <= rect.left + rect.width &&
        y <= rect.top + rect.height) {
      double area = rect.width * rect.height;
      if (area <= best_area) {
        best = candidate;
        best_area = area;
      }
    }
  }
  if (best) {
    best->AddRef();
    *value = static_cast<IRawElementProviderFragment *>(best);
  }
  return S_OK;
}

HRESULT MouiUiaProvider::GetFocus(IRawElementProviderFragment **value) {
  if (!value) return E_INVALIDARG;
  *value = nullptr;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd_);
  if (!window) return UIA_E_ELEMENTNOTAVAILABLE;
  MouiUiaProvider *provider = provider_for(window, window->focused);
  if (provider) {
    provider->AddRef();
    *value = static_cast<IRawElementProviderFragment *>(provider);
  }
  return S_OK;
}

HRESULT MouiUiaProvider::get_SelectionContainer(
    IRawElementProviderSimple **value) {
  if (!value) return E_INVALIDARG;
  *value = nullptr;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  WindowBridge *window = window_for(hwnd_);
  if (!window || !node_for(hwnd_, node_id_)) return UIA_E_ELEMENTNOTAVAILABLE;
  MouiUiaProvider *parent = provider_for(window, parent_id(window, node_id_));
  if (parent) {
    parent->AddRef();
    *value = static_cast<IRawElementProviderSimple *>(parent);
  }
  return S_OK;
}

static int32_t native_message_hook(uint64_t raw_hwnd, uint32_t message,
                                   uint64_t wparam, int64_t lparam,
                                   uint64_t *result, void *) {
  if (message != kWmGetObject || !result) return 0;
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  MouiUiaProvider *root = window ? provider_for(window, window->root) : nullptr;
  if (!root) return 0;
  *result = static_cast<uint64_t>(UiaReturnRawElementProvider(
      hwnd, static_cast<WPARAM>(wparam), static_cast<LPARAM>(lparam), root));
  return 1;
}

static bool ensure_hook() {
  if (g_hook_install_attempted) return g_hook_installed;
  g_hook_install_attempted = true;
  HMODULE process = GetModuleHandleW(nullptr);
  auto install = reinterpret_cast<InstallNativeMessageHook>(
      process ? GetProcAddress(process, "mbw_install_native_message_hook")
              : nullptr);
  if (!install) return false;
  HRESULT initialized = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return false;
  install(native_message_hook, nullptr);
  g_hook_installed = true;
  return true;
}

static void release_window(std::unique_ptr<WindowBridge> window) {
  if (!window) return;
  for (auto &entry : window->providers) entry.second->Release();
  window->providers.clear();
}

}  // namespace

extern "C" MOONBIT_FFI_EXPORT int32_t
moui_windows_accessibility_attach(uint64_t raw_hwnd) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  if (!raw_hwnd || !ensure_hook()) return 0;
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  if (!IsWindow(hwnd)) return 0;
  if (!window_for(hwnd)) {
    auto window = std::make_unique<WindowBridge>();
    window->hwnd = hwnd;
    g_windows[hwnd] = std::move(window);
  }
  return 1;
}

extern "C" MOONBIT_FFI_EXPORT int32_t moui_windows_accessibility_begin(
    uint64_t raw_hwnd, int32_t full, uint64_t generation, uint64_t root,
    uint64_t focused, uint64_t semantic_focused) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  if (!window) return 0;
  window->previous_focused = window->focused;
  window->generation = generation;
  window->root = root;
  window->focused = focused;
  window->semantic_focused = semantic_focused;
  window->updating_full = full != 0;
  if (window->updating_full) {
    for (auto &entry : window->providers) entry.second->Release();
    window->providers.clear();
    window->nodes.clear();
    window->structure_changed = true;
  }
  return 1;
}

extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_remove(
    uint64_t raw_hwnd, uint64_t node_id) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  if (!window) return;
  auto provider = window->providers.find(node_id);
  if (provider != window->providers.end()) {
    provider->second->Release();
    window->providers.erase(provider);
  }
  window->nodes.erase(node_id);
  window->structure_changed = true;
}

extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_upsert(
    uint64_t raw_hwnd, uint64_t node_id, uint64_t generation,
    moonbit_bytes_t semantic_id, moonbit_bytes_t role, moonbit_bytes_t label,
    moonbit_bytes_t value, moonbit_bytes_t description, uint64_t state_flags,
    int32_t checked, int32_t numeric_flags, double numeric_current,
    double numeric_min, double numeric_max, double numeric_step,
    int32_t text_flags, int32_t selection_start, int32_t selection_end,
    int32_t caret, int32_t row_index, int32_t row_count, int32_t row_span,
    int32_t column_index, int32_t column_count, int32_t column_span,
    int32_t set_size, int32_t set_position, uint64_t action_flags,
    int32_t live, int32_t live_atomic, double frame_x, double frame_y,
    double frame_width, double frame_height, moonbit_bytes_t children,
    moonbit_bytes_t labelled_by, moonbit_bytes_t described_by,
    moonbit_bytes_t controls, moonbit_bytes_t error_message,
    moonbit_bytes_t active_descendant) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  if (!window) return;
  bool inserted = window->nodes.find(node_id) == window->nodes.end();
  NodeData &node = window->nodes[node_id];
  node.id = node_id;
  node.generation = generation;
  node.semantic_id = bytes_string(semantic_id);
  node.role = bytes_string(role);
  node.label = bytes_string(label);
  node.value = bytes_string(value);
  node.description = bytes_string(description);
  node.state = state_flags;
  node.checked = checked;
  node.numeric_flags = numeric_flags;
  node.current = numeric_current;
  node.minimum = numeric_min;
  node.maximum = numeric_max;
  node.step = numeric_step;
  node.text_flags = text_flags;
  node.selection_start = selection_start;
  node.selection_end = selection_end;
  node.caret = caret;
  node.row_index = row_index;
  node.row_count = row_count;
  node.row_span = row_span;
  node.column_index = column_index;
  node.column_count = column_count;
  node.column_span = column_span;
  node.set_size = set_size;
  node.set_position = set_position;
  node.actions = action_flags;
  node.live = live;
  node.live_atomic = live_atomic != 0;
  node.x = frame_x;
  node.y = frame_y;
  node.width = frame_width;
  node.height = frame_height;
  node.children = parse_ids(children);
  node.labelled_by = parse_ids(labelled_by);
  node.described_by = parse_ids(described_by);
  node.controls = parse_ids(controls);
  node.error_message = parse_ids(error_message);
  node.active_descendant = parse_ids(active_descendant);
  if (inserted) window->structure_changed = true;
}

extern "C" MOONBIT_FFI_EXPORT void
moui_windows_accessibility_end(uint64_t raw_hwnd) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  if (!window) return;
  MouiUiaProvider *root = provider_for(window, window->root);
  if (window->structure_changed && root) {
    UiaRaiseStructureChangedEvent(root, StructureChangeType_ChildrenInvalidated,
                                  nullptr, 0);
    window->structure_changed = false;
  }
  if (window->focused != window->previous_focused) {
    MouiUiaProvider *focused = provider_for(window, window->focused);
    if (focused) UiaRaiseAutomationEvent(focused, UIA_AutomationFocusChangedEventId);
  }
}

extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_announce(
    uint64_t raw_hwnd, uint64_t node_id, int32_t live, int32_t,
    moonbit_bytes_t text) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  MouiUiaProvider *provider = window ? provider_for(window, node_id) : nullptr;
  if (!provider) return;
  std::wstring wide = utf8_to_wide(bytes_string(text));
  BSTR display = SysAllocString(wide.c_str());
  BSTR activity = SysAllocString(L"moui.live");
  UiaRaiseNotificationEvent(provider, NotificationKind_Other,
                            live == 2 ? NotificationProcessing_ImportantMostRecent
                                      : NotificationProcessing_MostRecent,
                            display, activity);
  SysFreeString(display);
  SysFreeString(activity);
}

extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moui_windows_accessibility_take_action(uint64_t raw_hwnd) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  WindowBridge *window = window_for(hwnd);
  if (!window || window->actions.empty()) return moonbit_make_bytes(0, 0);
  std::string action = std::move(window->actions.front());
  window->actions.pop_front();
  moonbit_bytes_t result = moonbit_make_bytes(static_cast<int32_t>(action.size()), 0);
  if (!action.empty()) memcpy(result, action.data(), action.size());
  return result;
}

extern "C" MOONBIT_FFI_EXPORT void
moui_windows_accessibility_dispose(uint64_t raw_hwnd) {
  std::lock_guard<std::recursive_mutex> lock(g_mutex);
  HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw_hwnd));
  auto found = g_windows.find(hwnd);
  if (found == g_windows.end()) return;
  std::unique_ptr<WindowBridge> window = std::move(found->second);
  g_windows.erase(found);
  release_window(std::move(window));
}

#else

#include <moonbit.h>
#include <stdint.h>

extern "C" MOONBIT_FFI_EXPORT int32_t
moui_windows_accessibility_attach(uint64_t) { return 0; }
extern "C" MOONBIT_FFI_EXPORT int32_t moui_windows_accessibility_begin(
    uint64_t, int32_t, uint64_t, uint64_t, uint64_t, uint64_t) { return 0; }
extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_remove(
    uint64_t, uint64_t) {}
extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_upsert(
    uint64_t, uint64_t, uint64_t, moonbit_bytes_t, moonbit_bytes_t,
    moonbit_bytes_t, moonbit_bytes_t, moonbit_bytes_t, uint64_t, int32_t,
    int32_t, double, double, double, double, int32_t, int32_t, int32_t,
    int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t,
    int32_t, uint64_t, int32_t, int32_t, double, double, double, double,
    moonbit_bytes_t, moonbit_bytes_t, moonbit_bytes_t, moonbit_bytes_t,
    moonbit_bytes_t, moonbit_bytes_t) {}
extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_end(uint64_t) {}
extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_announce(
    uint64_t, uint64_t, int32_t, int32_t, moonbit_bytes_t) {}
extern "C" MOONBIT_FFI_EXPORT moonbit_bytes_t
moui_windows_accessibility_take_action(uint64_t) {
  return moonbit_make_bytes(0, 0);
}
extern "C" MOONBIT_FFI_EXPORT void moui_windows_accessibility_dispose(uint64_t) {}

#endif
