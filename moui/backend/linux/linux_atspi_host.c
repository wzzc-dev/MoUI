#ifdef __linux__

#include <gio/gio.h>
#include <glib.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct MouiAtspiNode MouiAtspiNode;
struct MouiAtspiNode {
  GArray *registrations;
  guint64 window_id;
  guint64 id;
  guint64 generation;
  guint role;
  gchar *semantic_id;
  gchar *role_name;
  gchar *name;
  gchar *value;
  gchar *description;
  guint state;
  gboolean focused;
  gboolean selected;
  gboolean checked;
  gboolean mixed;
  gboolean disabled;
  gboolean editable;
  gboolean readonly;
  gboolean multiline;
  gboolean password;
  gdouble current;
  gdouble minimum;
  gdouble maximum;
  gdouble increment;
  gint selection_start;
  gint selection_end;
  gint caret;
  gint row_index;
  gint row_count;
  gint row_span;
  gint column_index;
  gint column_count;
  gint column_span;
  gint set_size;
  gint set_position;
  guint actions;
  gint live;
  gboolean live_atomic;
  gdouble frame_x;
  gdouble frame_y;
  gdouble frame_width;
  gdouble frame_height;
  gchar *parent_path;
  GPtrArray *children;
  GPtrArray *labelled_by;
  GPtrArray *described_by;
  GPtrArray *controls;
  GPtrArray *error_message;
  GPtrArray *active_descendant;
};

typedef struct {
  guint64 id;
  guint64 generation;
  guint64 root;
  guint64 focused;
  guint64 semantic_focused;
  guint64 previous_focused;
  gboolean structure_changed;
  GQueue *actions;
} MouiAtspiWindow;

static GDBusConnection *g_connection = NULL;
static GHashTable *g_nodes = NULL;
static GHashTable *g_windows = NULL;
static GMainContext *g_context = NULL;
static gboolean g_ready = FALSE;
static GMutex g_lock;

static void free_node(gpointer data);

static const gchar *k_xml =
    "<node>"
    "<interface name='org.a11y.atspi.Accessible'>"
    "<method name='GetRole'><arg type='u' direction='out'/></method>"
    "<method name='GetRoleName'><arg type='s' direction='out'/></method>"
    "<method name='GetState'><arg type='au' direction='out'/></method>"
    "<method name='GetAttributes'><arg type='a{ss}' direction='out'/></method>"
    "<method name='GetApplication'><arg type='(so)' direction='out'/></method>"
    "<method name='GetParent'><arg type='(so)' direction='out'/></method>"
    "<method name='GetChildAtIndex'><arg type='i' direction='in'/><arg type='(so)' direction='out'/></method>"
    "<method name='GetChildren'><arg type='a(so)' direction='out'/></method>"
    "<method name='GetIndexInParent'><arg type='i' direction='out'/></method>"
    "<method name='GetRelationSet'><arg type='a(ua(so))' direction='out'/></method>"
    "<method name='GetToolkitName'><arg type='s' direction='out'/></method>"
    "<method name='GetToolkitVersion'><arg type='s' direction='out'/></method>"
    "<method name='GetAtspiVersion'><arg type='s' direction='out'/></method>"
    "<method name='GetLocale'><arg type='s' direction='out'/></method>"
    "</interface>"
    "<interface name='org.a11y.atspi.Event.Object'>"
    "<signal name='PropertyChange'><arg type='s'/><arg type='v'/></signal>"
    "<signal name='StateChanged'><arg type='s'/><arg type='b'/></signal>"
    "<signal name='ChildrenChanged'><arg type='s'/><arg type='(so)'/></signal>"
    "<signal name='Focus'><arg type='b'/></signal>"
    "<signal name='TextChanged'><arg type='s'/><arg type='i'/></signal>"
    "</interface>"
    "<interface name='org.a11y.atspi.Component'>"
    "<method name='GetExtents'><arg type='u' direction='in'/><arg type='(dddd)' direction='out'/></method>"
    "<method name='GetPosition'><arg type='u' direction='in'/><arg type='(dd)' direction='out'/></method>"
    "<method name='GetSize'><arg type='(dd)' direction='out'/></method>"
    "<method name='GetLayer'><arg type='u' direction='out'/></method>"
    "<method name='GetMDIZOrder'><arg type='i' direction='out'/></method>"
    "<method name='GrabFocus'><arg type='b' direction='out'/></method>"
    "<method name='GetAlpha'><arg type='d' direction='out'/></method>"
    "</interface>"
    "<interface name='org.a11y.atspi.Action'>"
    "<method name='GetActions'><arg type='a(ssss)' direction='out'/></method>"
    "<method name='DoAction'><arg type='i' direction='in'/><arg type='b' direction='out'/></method>"
    "<method name='GetKeyBinding'><arg type='i' direction='in'/><arg type='s' direction='out'/></method>"
    "</interface>"
    "<interface name='org.a11y.atspi.Value'>"
    "<method name='GetCurrentValue'><arg type='d' direction='out'/></method>"
    "<method name='GetMinimumValue'><arg type='d' direction='out'/></method>"
    "<method name='GetMaximumValue'><arg type='d' direction='out'/></method>"
    "<method name='GetMinimumIncrement'><arg type='d' direction='out'/></method>"
    "<method name='SetCurrentValue'><arg type='d' direction='in'/><arg type='b' direction='out'/></method>"
    "</interface>"
    "<interface name='org.a11y.atspi.Text'>"
    "<method name='GetText'><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='s' direction='out'/></method>"
    "<method name='GetCharacterCount'><arg type='i' direction='out'/></method>"
    "<method name='GetCaretOffset'><arg type='i' direction='out'/></method>"
    "<method name='SetCaretOffset'><arg type='i' direction='in'/><arg type='b' direction='out'/></method>"
    "</interface>"
    "<interface name='org.a11y.atspi.Selection'>"
    "<method name='GetNSelections'><arg type='i' direction='out'/></method>"
    "<method name='GetSelection'><arg type='i' direction='in'/><arg type='(ii)' direction='out'/></method>"
    "<method name='ClearSelection'><arg type='b' direction='out'/></method>"
    "</interface>"
    "</node>";

static GDBusNodeInfo *g_node_info = NULL;

static gchar *path_for(guint64 window_id, guint64 id) {
  return g_strdup_printf("/org/moui/Accessibility/w%llu/n%llu",
                         (unsigned long long)window_id,
                         (unsigned long long)id);
}

static MouiAtspiNode *node_for_path(const gchar *path) {
  return g_nodes ? g_hash_table_lookup(g_nodes, path) : NULL;
}

static void free_window(gpointer data) {
  MouiAtspiWindow *window = data;
  if (!window) return;
  if (window->actions) g_queue_free_full(window->actions, g_free);
  g_free(window);
}

static MouiAtspiWindow *window_for(guint64 window_id, gboolean create) {
  if (!g_windows) return NULL;
  MouiAtspiWindow *window = g_hash_table_lookup(g_windows, &window_id);
  if (window || !create) return window;
  guint64 *key = g_new(guint64, 1);
  *key = window_id;
  window = g_new0(MouiAtspiWindow, 1);
  window->id = window_id;
  window->actions = g_queue_new();
  g_hash_table_insert(g_windows, key, window);
  return window;
}

static const gchar *bus_name(void) {
  const gchar *name = g_connection ? g_dbus_connection_get_unique_name(g_connection) : NULL;
  return name ? name : "";
}

static gchar *bytes_text(moonbit_bytes_t bytes) {
  return g_strndup((const gchar *)bytes, (gsize)Moonbit_array_length(bytes));
}

static GPtrArray *id_paths(guint64 window_id, const gchar *ids) {
  GPtrArray *paths = g_ptr_array_new_with_free_func(g_free);
  gchar **parts = g_strsplit(ids ? ids : "", ",", -1);
  for (gchar **part = parts; part && *part; ++part) {
    if (**part) {
      g_ptr_array_add(paths,
                      path_for(window_id, g_ascii_strtoull(*part, NULL, 10)));
    }
  }
  g_strfreev(parts);
  return paths;
}

/* method_call owns g_lock while constructing a generation-pinned request. */
static gboolean enqueue_action_locked(MouiAtspiNode *node, const gchar *kind,
                                      const gchar *value) {
  if (!node || !kind) return FALSE;
  MouiAtspiWindow *window = window_for(node->window_id, FALSE);
  if (!window || !window->actions) return FALSE;
  gchar *escaped = g_strescape(value ? value : "", NULL);
  gchar *payload = g_strdup_printf(
      "{\"node_id\":\"%llu\",\"generation\":\"%llu\","
      "\"kind\":\"%s\",\"value\":\"%s\"}",
      (unsigned long long)node->id,
      (unsigned long long)node->generation, kind, escaped ? escaped : "");
  g_free(escaped);
  while (g_queue_get_length(window->actions) >= 256) {
    g_free(g_queue_pop_head(window->actions));
  }
  g_queue_push_tail(window->actions, payload);
  return TRUE;
}

static GVariant *empty_pair(void) {
  return g_variant_new("((so))", "", "/");
}

static void return_children(GDBusMethodInvocation *invocation,
                            MouiAtspiNode *node) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a(so)"));
  if (node && node->children) {
    for (guint i = 0; i < node->children->len; ++i) {
      const gchar *path = g_ptr_array_index(node->children, i);
      g_variant_builder_add(&builder, "(so)", bus_name(), path);
    }
  }
  g_dbus_method_invocation_return_value(invocation,
                                        g_variant_new("(a(so))", &builder));
}

static guint state_mask(MouiAtspiNode *node) {
  guint state = 0;
  if (!node) return state;
  if (node->disabled) state |= 1u << 0;
  if (node->focused) state |= 1u << 1;
  if (node->selected) state |= 1u << 2;
  if (node->checked) state |= 1u << 3;
  if (node->mixed) state |= 1u << 4;
  if (node->readonly) state |= 1u << 5;
  if (node->editable) state |= 1u << 6;
  if (node->multiline) state |= 1u << 7;
  if (node->password) state |= 1u << 8;
  return state;
}

static const gchar *action_name(guint bit) {
  switch (bit) {
  case 0: return "activate";
  case 1: return "focus";
  case 2: return "set_text";
  case 3: return "submit";
  case 4: return "scroll_forward";
  case 5: return "select";
  case 6: return "expand";
  case 7: return "collapse";
  case 8: return "dismiss";
  case 9: return "increment";
  case 10: return "decrement";
  case 11: return "set_numeric_value";
  case 12: return "set_selection";
  case 13: return "show_menu";
  default: return "";
  }
}

/* Values from the AT-SPI relation enum. Keep this table local to the native
 * adapter; the neutral DTO intentionally does not depend on AT-SPI headers. */
enum {
  kRelationLabelledBy = 2,
  kRelationControllerFor = 4,
  kRelationDescribedBy = 16,
  kRelationErrorMessage = 20,
};

static guint role_code(const gchar *role) {
  if (g_strcmp0(role, "alert") == 0) return 2;
  if (g_strcmp0(role, "check box") == 0) return 7;
  if (g_strcmp0(role, "dialog") == 0) return 16;
  if (g_strcmp0(role, "entry") == 0) return 29;
  if (g_strcmp0(role, "image") == 0) return 26;
  if (g_strcmp0(role, "link") == 0) return 88;
  if (g_strcmp0(role, "list") == 0) return 30;
  if (g_strcmp0(role, "list item") == 0) return 31;
  if (g_strcmp0(role, "progress bar") == 0) return 41;
  if (g_strcmp0(role, "push button") == 0) return 42;
  if (g_strcmp0(role, "radio button") == 0) return 43;
  if (g_strcmp0(role, "separator") == 0) return 49;
  if (g_strcmp0(role, "slider") == 0) return 50;
  if (g_strcmp0(role, "table") == 0) return 54;
  if (g_strcmp0(role, "table cell") == 0) return 55;
  if (g_strcmp0(role, "table row") == 0) return 89;
  if (g_strcmp0(role, "tree") == 0) return 66;
  if (g_strcmp0(role, "tree item") == 0) return 67;
  if (g_strcmp0(role, "status") == 0) return 48;
  return 38;
}

static void add_relation(GVariantBuilder *relations, guint relation_type,
                         GPtrArray *targets) {
  if (!targets || targets->len == 0) return;
  GVariantBuilder target_builder;
  g_variant_builder_init(&target_builder, G_VARIANT_TYPE("a(so)"));
  for (guint i = 0; i < targets->len; ++i) {
    g_variant_builder_add(&target_builder, "(so)", bus_name(),
                          (gchar *)g_ptr_array_index(targets, i));
  }
  g_variant_builder_add(relations, "(u@a(so))", relation_type,
                        g_variant_builder_end(&target_builder));
}

static void method_call(GDBusConnection *connection, const gchar *sender,
                        const gchar *object_path, const gchar *interface_name,
                        const gchar *method_name, GVariant *parameters,
                        GDBusMethodInvocation *invocation, gpointer user_data) {
  (void)connection; (void)sender; (void)user_data;
  g_mutex_lock(&g_lock);
  MouiAtspiNode *node = node_for_path(object_path);
  if (!node) {
    g_mutex_unlock(&g_lock);
    g_dbus_method_invocation_return_dbus_error(invocation,
                                               "org.a11y.atspi.Error", "object unavailable");
    return;
  }
  if (g_strcmp0(interface_name, "org.a11y.atspi.Accessible") == 0) {
    if (g_strcmp0(method_name, "GetRole") == 0)
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", node->role));
    else if (g_strcmp0(method_name, "GetRoleName") == 0)
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", node->role_name));
    else if (g_strcmp0(method_name, "GetState") == 0) {
      GVariantBuilder states; g_variant_builder_init(&states, G_VARIANT_TYPE("au"));
      g_variant_builder_add(&states, "u", state_mask(node));
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(au)", &states));
    } else if (g_strcmp0(method_name, "GetAttributes") == 0) {
      GVariantBuilder attributes; g_variant_builder_init(&attributes, G_VARIANT_TYPE("a{ss}"));
      g_variant_builder_add(&attributes, "{ss}", "semantic-id", node->semantic_id);
      g_variant_builder_add(&attributes, "{ss}", "name", node->name);
      if (node->description && *node->description)
        g_variant_builder_add(&attributes, "{ss}", "description", node->description);
      if (node->live == 1)
        g_variant_builder_add(&attributes, "{ss}", "live", "polite");
      else if (node->live == 2)
        g_variant_builder_add(&attributes, "{ss}", "live", "assertive");
      if (node->live_atomic)
        g_variant_builder_add(&attributes, "{ss}", "atomic", "true");
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(a{ss})", &attributes));
    } else if (g_strcmp0(method_name, "GetApplication") == 0) {
      MouiAtspiWindow *window = window_for(node->window_id, FALSE);
      gchar *root_path = window ? path_for(window->id, window->root) : NULL;
      g_dbus_method_invocation_return_value(
          invocation, g_variant_new("((so))", bus_name(), root_path ? root_path : "/"));
      g_free(root_path);
    }
    else if (g_strcmp0(method_name, "GetParent") == 0)
      g_dbus_method_invocation_return_value(invocation, node->parent_path ? g_variant_new("((so))", bus_name(), node->parent_path) : g_variant_new("((so))", "", "/"));
    else if (g_strcmp0(method_name, "GetChildAtIndex") == 0) {
      gint index = 0; g_variant_get(parameters, "(i)", &index);
      if (!node->children || index < 0 || (guint)index >= node->children->len)
        g_dbus_method_invocation_return_value(invocation, empty_pair());
      else g_dbus_method_invocation_return_value(invocation, g_variant_new("((so))", bus_name(), (gchar *)g_ptr_array_index(node->children, index)));
    } else if (g_strcmp0(method_name, "GetChildren") == 0) return_children(invocation, node);
    else if (g_strcmp0(method_name, "GetIndexInParent") == 0) {
      gint index = -1;
      if (node->parent_path) {
        MouiAtspiNode *parent = node_for_path(node->parent_path);
        if (parent && parent->children) for (guint i = 0; i < parent->children->len; ++i) if (g_strcmp0(g_ptr_array_index(parent->children, i), object_path) == 0) index = (gint)i;
      }
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(i)", index));
    } else if (g_strcmp0(method_name, "GetRelationSet") == 0) {
      GVariantBuilder relations; g_variant_builder_init(&relations, G_VARIANT_TYPE("a(ua(so))"));
      add_relation(&relations, kRelationLabelledBy, node->labelled_by);
      add_relation(&relations, kRelationDescribedBy, node->described_by);
      add_relation(&relations, kRelationControllerFor, node->controls);
      add_relation(&relations, kRelationErrorMessage, node->error_message);
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(a(ua(so)))", &relations));
    } else if (g_strcmp0(method_name, "GetToolkitName") == 0 || g_strcmp0(method_name, "GetToolkitVersion") == 0 || g_strcmp0(method_name, "GetAtspiVersion") == 0 || g_strcmp0(method_name, "GetLocale") == 0)
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", "moui"));
  } else if (g_strcmp0(interface_name, "org.a11y.atspi.Component") == 0) {
    if (g_strcmp0(method_name, "GetExtents") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("((dddd))", node->frame_x, node->frame_y, node->frame_width, node->frame_height));
    else if (g_strcmp0(method_name, "GetPosition") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("((dd))", node->frame_x, node->frame_y));
    else if (g_strcmp0(method_name, "GetSize") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("((dd))", node->frame_width, node->frame_height));
    else if (g_strcmp0(method_name, "GetLayer") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", 0u));
    else if (g_strcmp0(method_name, "GetMDIZOrder") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(i)", 0));
    else if (g_strcmp0(method_name, "GrabFocus") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(b)", enqueue_action_locked(node, "focus", "")));
    else if (g_strcmp0(method_name, "GetAlpha") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(d)", 1.0));
  } else if (g_strcmp0(interface_name, "org.a11y.atspi.Action") == 0) {
    if (g_strcmp0(method_name, "GetActions") == 0) {
      GVariantBuilder actions; g_variant_builder_init(&actions, G_VARIANT_TYPE("a(ssss)"));
      for (guint i = 0; i < 14; ++i) if (node->actions & (1u << i)) g_variant_builder_add(&actions, "(ssss)", action_name(i), action_name(i), "", "");
      g_dbus_method_invocation_return_value(invocation, g_variant_new("(a(ssss))", &actions));
    } else if (g_strcmp0(method_name, "DoAction") == 0) {
      gint requested = -1;
      gint advertised = 0;
      const gchar *kind = NULL;
      g_variant_get(parameters, "(i)", &requested);
      for (guint bit = 0; bit < 14; ++bit) {
        if (!(node->actions & (1u << bit))) continue;
        if (advertised == requested) { kind = action_name(bit); break; }
        advertised += 1;
      }
      g_dbus_method_invocation_return_value(
          invocation, g_variant_new("(b)", enqueue_action_locked(node, kind, "")));
    } else if (g_strcmp0(method_name, "GetKeyBinding") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", ""));
  } else if (g_strcmp0(interface_name, "org.a11y.atspi.Value") == 0) {
    if (g_strcmp0(method_name, "GetCurrentValue") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(d)", node->current));
    else if (g_strcmp0(method_name, "GetMinimumValue") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(d)", node->minimum));
    else if (g_strcmp0(method_name, "GetMaximumValue") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(d)", node->maximum));
    else if (g_strcmp0(method_name, "GetMinimumIncrement") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(d)", node->increment));
    else if (g_strcmp0(method_name, "SetCurrentValue") == 0) {
      gdouble value = 0.0;
      gchar buffer[G_ASCII_DTOSTR_BUF_SIZE];
      g_variant_get(parameters, "(d)", &value);
      g_ascii_dtostr(buffer, sizeof(buffer), value);
      g_dbus_method_invocation_return_value(
          invocation, g_variant_new("(b)",
              (node->actions & (1u << 11)) &&
              enqueue_action_locked(node, "set_numeric_value", buffer)));
    }
  } else if (g_strcmp0(interface_name, "org.a11y.atspi.Text") == 0) {
    if (g_strcmp0(method_name, "GetText") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", node->value));
    else if (g_strcmp0(method_name, "GetCharacterCount") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(i)", (gint)g_utf8_strlen(node->value, -1)));
    else if (g_strcmp0(method_name, "GetCaretOffset") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(i)", node->caret));
    else if (g_strcmp0(method_name, "SetCaretOffset") == 0) {
      gint offset = -1;
      gchar buffer[64];
      g_variant_get(parameters, "(i)", &offset);
      g_snprintf(buffer, sizeof(buffer), "%d,%d", offset, offset);
      g_dbus_method_invocation_return_value(
          invocation, g_variant_new("(b)",
              (node->actions & (1u << 12)) &&
              enqueue_action_locked(node, "set_selection", buffer)));
    }
  } else if (g_strcmp0(interface_name, "org.a11y.atspi.Selection") == 0) {
    if (g_strcmp0(method_name, "GetNSelections") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("(i)", node->selection_start >= 0 ? 1 : 0));
    else if (g_strcmp0(method_name, "GetSelection") == 0) g_dbus_method_invocation_return_value(invocation, g_variant_new("((ii))", node->selection_start, node->selection_end));
    else if (g_strcmp0(method_name, "ClearSelection") == 0)
      g_dbus_method_invocation_return_value(
          invocation, g_variant_new("(b)",
              (node->actions & (1u << 12)) &&
              enqueue_action_locked(node, "set_selection", "0,0")));
  }
  g_mutex_unlock(&g_lock);
}

static const GDBusInterfaceVTable k_vtable = {
    .method_call = method_call,
    .get_property = NULL,
    .set_property = NULL,
};

static gboolean ensure_bus(void) {
  if (g_ready) return TRUE;
  GError *error = NULL;
  g_context = g_main_context_default();
  g_connection = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
  if (!g_connection) { g_clear_error(&error); return FALSE; }
  g_nodes = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, free_node);
  g_windows = g_hash_table_new_full(g_int64_hash, g_int64_equal, g_free,
                                    free_window);
  g_node_info = g_dbus_node_info_new_for_xml(k_xml, &error);
  if (!g_node_info) { g_clear_error(&error); return FALSE; }
  g_ready = TRUE;
  return TRUE;
}

static void free_node(gpointer data) {
  MouiAtspiNode *node = data;
  if (!node) return;
  if (node->registrations && g_connection) {
    for (guint i = 0; i < node->registrations->len; ++i) {
      guint registration = g_array_index(node->registrations, guint, i);
      if (registration) g_dbus_connection_unregister_object(g_connection, registration);
    }
    g_array_free(node->registrations, TRUE);
  }
  g_free(node->semantic_id); g_free(node->role_name); g_free(node->name); g_free(node->value); g_free(node->description); g_free(node->parent_path);
  if (node->children) g_ptr_array_free(node->children, TRUE);
  if (node->labelled_by) g_ptr_array_free(node->labelled_by, TRUE);
  if (node->described_by) g_ptr_array_free(node->described_by, TRUE);
  if (node->controls) g_ptr_array_free(node->controls, TRUE);
  if (node->error_message) g_ptr_array_free(node->error_message, TRUE);
  if (node->active_descendant) g_ptr_array_free(node->active_descendant, TRUE);
  g_free(node);
}

static void install_node(MouiAtspiNode *node) {
  gchar *path = path_for(node->window_id, node->id);
  GError *error = NULL;
  node->registrations = g_array_new(FALSE, FALSE, sizeof(guint));
  for (guint i = 0; g_node_info && g_node_info->interfaces[i]; ++i) {
    guint registration = g_dbus_connection_register_object(g_connection, path, g_node_info->interfaces[i], &k_vtable, NULL, NULL, &error);
    if (registration) g_array_append_val(node->registrations, registration);
    g_clear_error(&error);
  }
  g_hash_table_replace(g_nodes, path, node);
}

static void remove_window_nodes(guint64 window_id) {
  if (!g_nodes) return;
  GHashTableIter iter;
  gpointer key = NULL;
  gpointer value = NULL;
  g_hash_table_iter_init(&iter, g_nodes);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    MouiAtspiNode *node = value;
    if (node && node->window_id == window_id) g_hash_table_iter_remove(&iter);
  }
}

static void rebuild_parents(guint64 window_id) {
  GHashTableIter iter;
  gpointer key = NULL;
  gpointer value = NULL;
  g_hash_table_iter_init(&iter, g_nodes);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    MouiAtspiNode *node = value;
    if (!node || node->window_id != window_id) continue;
    g_clear_pointer(&node->parent_path, g_free);
  }
  g_hash_table_iter_init(&iter, g_nodes);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    MouiAtspiNode *parent = value;
    if (!parent || parent->window_id != window_id || !parent->children) continue;
    gchar *parent_path = path_for(window_id, parent->id);
    for (guint index = 0; index < parent->children->len; ++index) {
      MouiAtspiNode *child = node_for_path(g_ptr_array_index(parent->children, index));
      if (child && !child->parent_path) child->parent_path = g_strdup(parent_path);
    }
    g_free(parent_path);
  }
}

MOONBIT_FFI_EXPORT int32_t moui_linux_atspi_attach(void) {
  return ensure_bus() ? 1 : 0;
}

MOONBIT_FFI_EXPORT int32_t moui_linux_atspi_begin(
    uint64_t window_id, int32_t full, uint64_t generation, uint64_t root,
    uint64_t focused, uint64_t semantic_focused) {
  if (!ensure_bus()) return 0;
  g_mutex_lock(&g_lock);
  MouiAtspiWindow *window = window_for(window_id, TRUE);
  if (full) remove_window_nodes(window_id);
  window->generation = generation;
  window->root = root;
  window->previous_focused = window->focused;
  window->focused = focused;
  window->semantic_focused = semantic_focused;
  g_mutex_unlock(&g_lock);
  return 1;
}

MOONBIT_FFI_EXPORT void moui_linux_atspi_upsert(
    uint64_t window_id, uint64_t node_id, uint64_t generation,
    moonbit_bytes_t semantic_id, moonbit_bytes_t role, moonbit_bytes_t name,
    moonbit_bytes_t value, moonbit_bytes_t description, uint32_t state,
    int32_t checked, int32_t numeric_flags, double current, double minimum,
    double maximum, double increment, int32_t selection_start,
    int32_t selection_end, int32_t caret, int32_t row_index,
    int32_t row_count, int32_t row_span, int32_t column_index,
    int32_t column_count, int32_t column_span, int32_t set_size,
    int32_t set_position, uint32_t actions, int32_t live,
    int32_t live_atomic, double frame_x, double frame_y, double frame_width,
    double frame_height, moonbit_bytes_t children, moonbit_bytes_t labelled_by,
    moonbit_bytes_t described_by, moonbit_bytes_t controls,
    moonbit_bytes_t error_message, moonbit_bytes_t active_descendant) {
  if (!ensure_bus()) return;
  gchar *path = path_for(window_id, node_id);
  gchar *semantic_id_text = bytes_text(semantic_id);
  gchar *role_text = bytes_text(role);
  gchar *name_text = bytes_text(name);
  gchar *value_text = bytes_text(value);
  gchar *description_text = bytes_text(description);
  gchar *children_text = bytes_text(children);
  gchar *labelled_by_text = bytes_text(labelled_by);
  gchar *described_by_text = bytes_text(described_by);
  gchar *controls_text = bytes_text(controls);
  gchar *error_message_text = bytes_text(error_message);
  gchar *active_descendant_text = bytes_text(active_descendant);

  g_mutex_lock(&g_lock);
  MouiAtspiWindow *window = window_for(window_id, TRUE);
  MouiAtspiNode *node = node_for_path(path);
  gboolean inserted = node == NULL;
  if (!node) {
    node = g_new0(MouiAtspiNode, 1);
    node->window_id = window_id;
    node->id = node_id;
    install_node(node);
  }
  g_free(node->semantic_id);
  g_free(node->role_name);
  g_free(node->name);
  g_free(node->value);
  g_free(node->description);
  node->generation = generation;
  node->semantic_id = semantic_id_text;
  node->role_name = role_text;
  node->role = role_code(role_text);
  node->name = name_text;
  node->value = value_text;
  node->description = description_text;
  node->state = state;
  node->disabled = (state & 1u) != 0;
  node->focused = (state & 2u) != 0;
  node->selected = (state & 4u) != 0;
  node->readonly = (state & 32u) != 0;
  node->editable = (state & 64u) != 0;
  node->multiline = (state & 128u) != 0;
  node->password = (state & 256u) != 0;
  node->checked = checked == 1;
  node->mixed = checked == 2;
  if (numeric_flags & 1) node->current = current;
  if (numeric_flags & 2) node->minimum = minimum;
  if (numeric_flags & 4) node->maximum = maximum;
  if (numeric_flags & 8) node->increment = increment;
  node->selection_start = selection_start;
  node->selection_end = selection_end;
  node->caret = caret;
  node->row_index = row_index;
  node->row_count = row_count;
  node->row_span = row_span;
  node->column_index = column_index;
  node->column_count = column_count;
  node->column_span = column_span;
  node->set_size = set_size;
  node->set_position = set_position;
  node->actions = actions;
  node->live = live;
  node->live_atomic = live_atomic != 0;
  node->frame_x = frame_x;
  node->frame_y = frame_y;
  node->frame_width = frame_width;
  node->frame_height = frame_height;
  if (node->children) g_ptr_array_free(node->children, TRUE);
  if (node->labelled_by) g_ptr_array_free(node->labelled_by, TRUE);
  if (node->described_by) g_ptr_array_free(node->described_by, TRUE);
  if (node->controls) g_ptr_array_free(node->controls, TRUE);
  if (node->error_message) g_ptr_array_free(node->error_message, TRUE);
  if (node->active_descendant) g_ptr_array_free(node->active_descendant, TRUE);
  node->children = id_paths(window_id, children_text);
  node->labelled_by = id_paths(window_id, labelled_by_text);
  node->described_by = id_paths(window_id, described_by_text);
  node->controls = id_paths(window_id, controls_text);
  node->error_message = id_paths(window_id, error_message_text);
  node->active_descendant = id_paths(window_id, active_descendant_text);
  if (inserted && window) window->structure_changed = TRUE;
  g_mutex_unlock(&g_lock);

  g_free(children_text);
  g_free(labelled_by_text);
  g_free(described_by_text);
  g_free(controls_text);
  g_free(error_message_text);
  g_free(active_descendant_text);
  g_free(path);
}

MOONBIT_FFI_EXPORT void moui_linux_atspi_remove(uint64_t window_id,
                                                uint64_t node_id) {
  if (!g_ready) return;
  gchar *path = path_for(window_id, node_id);
  g_mutex_lock(&g_lock);
  MouiAtspiWindow *window = window_for(window_id, FALSE);
  if (g_hash_table_remove(g_nodes, path) && window) {
    window->structure_changed = TRUE;
  }
  g_mutex_unlock(&g_lock);
  g_free(path);
}

MOONBIT_FFI_EXPORT void moui_linux_atspi_end(uint64_t window_id) {
  if (!g_ready) return;
  g_mutex_lock(&g_lock);
  MouiAtspiWindow *window = window_for(window_id, FALSE);
  if (window) {
    rebuild_parents(window_id);
    if (window->focused != window->previous_focused) {
      if (window->previous_focused) {
        gchar *old_path = path_for(window_id, window->previous_focused);
        g_dbus_connection_emit_signal(g_connection, NULL, old_path,
                                      "org.a11y.atspi.Event.Object", "Focus",
                                      g_variant_new("(b)", FALSE), NULL);
        g_free(old_path);
      }
      if (window->focused) {
        gchar *new_path = path_for(window_id, window->focused);
        g_dbus_connection_emit_signal(g_connection, NULL, new_path,
                                      "org.a11y.atspi.Event.Object", "Focus",
                                      g_variant_new("(b)", TRUE), NULL);
        g_free(new_path);
      }
    }
    window->structure_changed = FALSE;
  }
  g_mutex_unlock(&g_lock);
  if (g_context) {
    while (g_main_context_pending(g_context))
      g_main_context_iteration(g_context, FALSE);
  }
}

MOONBIT_FFI_EXPORT void moui_linux_atspi_announce(
    uint64_t window_id, uint64_t node_id, int32_t live, int32_t atomic,
    moonbit_bytes_t text) {
  if (!g_ready) return;
  gchar *path = path_for(window_id, node_id);
  gchar *text_value = bytes_text(text);
  g_dbus_connection_emit_signal(
      g_connection, NULL, path, "org.a11y.atspi.Event.Object", "TextChanged",
      g_variant_new("(si)", live == 2 ? "assertive" : "polite",
                    (gint)g_utf8_strlen(text_value, -1)),
      NULL);
  (void)atomic;
  g_free(text_value);
  g_free(path);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t
moui_linux_atspi_take_action(uint64_t window_id) {
  g_mutex_lock(&g_lock);
  MouiAtspiWindow *window = window_for(window_id, FALSE);
  gchar *action = window && window->actions
                      ? g_queue_pop_head(window->actions)
                      : NULL;
  g_mutex_unlock(&g_lock);
  if (!action) return moonbit_make_bytes(0, 0);
  gsize length = strlen(action);
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  if (length) memcpy(result, action, length);
  g_free(action);
  return result;
}

MOONBIT_FFI_EXPORT void moui_linux_atspi_dispose(uint64_t window_id) {
  if (!g_ready) return;
  g_mutex_lock(&g_lock);
  remove_window_nodes(window_id);
  if (g_windows) g_hash_table_remove(g_windows, &window_id);
  g_mutex_unlock(&g_lock);
}

#else
#include <moonbit.h>
#include <stdint.h>
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc23-extensions"
#endif
MOONBIT_FFI_EXPORT int32_t moui_linux_atspi_attach(void) { return 0; }
MOONBIT_FFI_EXPORT int32_t moui_linux_atspi_begin(uint64_t,int32_t,uint64_t,uint64_t,uint64_t,uint64_t) { return 0; }
MOONBIT_FFI_EXPORT void moui_linux_atspi_upsert(uint64_t,uint64_t,uint64_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,uint32_t,int32_t,int32_t,double,double,double,double,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t,uint32_t,int32_t,int32_t,double,double,double,double,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t,moonbit_bytes_t) {}
MOONBIT_FFI_EXPORT void moui_linux_atspi_remove(uint64_t,uint64_t) {}
MOONBIT_FFI_EXPORT void moui_linux_atspi_end(uint64_t) {}
MOONBIT_FFI_EXPORT void moui_linux_atspi_announce(uint64_t,uint64_t,int32_t,int32_t,moonbit_bytes_t) {}
MOONBIT_FFI_EXPORT moonbit_bytes_t moui_linux_atspi_take_action(uint64_t) { return moonbit_make_bytes(0, 0); }
MOONBIT_FFI_EXPORT void moui_linux_atspi_dispose(uint64_t) {}
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
#endif
