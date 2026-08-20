#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#endif

typedef void (*moui_linux_webview_event_trampoline_t)(
    void *closure, uint64_t native_surface, int32_t kind, moonbit_bytes_t id,
    moonbit_bytes_t url, moonbit_bytes_t detail, int32_t flag);

static moui_linux_webview_event_trampoline_t g_event_trampoline = NULL;
static void *g_event_closure = NULL;

static moonbit_bytes_t moui_linux_webview_make_bytes(const char *text) {
  if (text == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(bytes, text, len);
  }
  return bytes;
}

static char *moui_linux_webview_bytes_to_cstr(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  char *text = (char *)calloc((size_t)len + 1, 1);
  if (text == NULL) {
    return NULL;
  }
  if (len > 0) {
    memcpy(text, bytes, (size_t)len);
  }
  text[len] = '\0';
  return text;
}

static void moui_linux_webview_emit(uint64_t surface, int32_t kind,
                                    const char *id, const char *url,
                                    const char *detail, int32_t flag) {
  if (g_event_trampoline == NULL || g_event_closure == NULL) {
    return;
  }
  g_event_trampoline(g_event_closure, surface, kind,
                     moui_linux_webview_make_bytes(id),
                     moui_linux_webview_make_bytes(url),
                     moui_linux_webview_make_bytes(detail), flag);
}

#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
typedef struct MOUILinuxWebView {
  uint64_t parent_surface;
  char *id;
  char *desired_url;
  char *current_url;
  int32_t policy;
  GtkWidget *offscreen_window;  // Changed from 'window' to 'offscreen_window'
  WebKitWebView *webview;
  int seen;
  int visible;
  int allow_next_navigation;
  int navigation_pending;
  int width;   // Track current size for rendering
  int height;
  double background_red;
  double background_green;
  double background_blue;
  double background_alpha;
  char *cancelled_url;  // URL of the navigation replaced by a newer one
  struct MOUILinuxWebView *next;
} MOUILinuxWebView;

static void parse_background_color(const char *text, double *red,
                                   double *green, double *blue,
                                   double *alpha) {
  *red = 1.0;
  *green = 1.0;
  *blue = 1.0;
  *alpha = 1.0;
  if (text != NULL && sscanf(text, "%lf,%lf,%lf,%lf", red, green, blue,
                              alpha) == 4) {
    if (*red < 0.0) *red = 0.0;
    if (*red > 1.0) *red = 1.0;
    if (*green < 0.0) *green = 0.0;
    if (*green > 1.0) *green = 1.0;
    if (*blue < 0.0) *blue = 0.0;
    if (*blue > 1.0) *blue = 1.0;
    if (*alpha < 0.0) *alpha = 0.0;
    if (*alpha > 1.0) *alpha = 1.0;
  }
}

static MOUILinuxWebView *g_views = NULL;
static int g_gtk_initialized = 0;

static char lower_ascii_char(char ch) {
  if (ch >= 'A' && ch <= 'Z') {
    return (char)(ch - 'A' + 'a');
  }
  return ch;
}

static int starts_with_scheme(const char *url, const char *scheme) {
  if (url == NULL || scheme == NULL) {
    return 0;
  }
  size_t scheme_len = strlen(scheme);
  if (strlen(url) < scheme_len) {
    return 0;
  }
  for (size_t index = 0; index < scheme_len; ++index) {
    if (lower_ascii_char(url[index]) != scheme[index]) {
      return 0;
    }
  }
  return 1;
}

static int webview_policy_allows(int32_t policy, const char *url) {
  if (policy == 2) {
    return 1;
  }
  if (starts_with_scheme(url, "http:") || starts_with_scheme(url, "https:")) {
    return 1;
  }
  return policy == 0 && starts_with_scheme(url, "file:");
}

static int ensure_gtk(void) {
  if (!g_gtk_initialized) {
    int argc = 0;
    char **argv = NULL;
    if (!gtk_init_check(&argc, &argv)) {
      return 0;
    }
    g_gtk_initialized = 1;
  }
  return 1;
}

static MOUILinuxWebView *find_view(uint64_t surface, const char *id) {
  for (MOUILinuxWebView *view = g_views; view != NULL; view = view->next) {
    if (view->parent_surface == surface && strcmp(view->id, id) == 0) {
      return view;
    }
  }
  return NULL;
}

static void linux_webview_load_controlled(MOUILinuxWebView *view,
                                          const char *url) {
  if (view == NULL || view->webview == NULL || url == NULL || url[0] == '\0') {
    return;
  }
  if (!webview_policy_allows(view->policy, url)) {
    moui_linux_webview_emit(view->parent_surface, 4, view->id, url,
                            "WebView navigation policy blocked URL", 0);
    return;
  }
  int desired_changed =
      view->desired_url == NULL || strcmp(view->desired_url, url) != 0;
  if (!desired_changed && view->navigation_pending) {
    return;
  }
  if (!desired_changed && view->current_url != NULL &&
      strcmp(view->current_url, url) == 0) {
    return;
  }
  // Record the URL being replaced so stale WEBKIT_LOAD_FINISHED events
  // (already queued in the GTK event loop) can be identified and skipped.
  if (view->desired_url != NULL) {
    free(view->cancelled_url);
    view->cancelled_url = strdup(view->desired_url);
  }
  free(view->desired_url);
  view->desired_url = strdup(url);
  view->allow_next_navigation = 1;
  view->navigation_pending = 1;
  webkit_web_view_load_uri(view->webview, url);
}

static gboolean on_decide_policy(WebKitWebView *webview,
                                 WebKitPolicyDecision *decision,
                                 WebKitPolicyDecisionType decision_type,
                                 gpointer user_data) {
  (void)webview;
  MOUILinuxWebView *view = (MOUILinuxWebView *)user_data;
  if (decision_type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
    return FALSE;
  }
  WebKitNavigationPolicyDecision *nav =
      WEBKIT_NAVIGATION_POLICY_DECISION(decision);
  WebKitNavigationAction *action =
      webkit_navigation_policy_decision_get_navigation_action(nav);
  WebKitURIRequest *request = webkit_navigation_action_get_request(action);
  const char *uri = webkit_uri_request_get_uri(request);
  fprintf(stderr, "[webview-debug] on_decide_policy uri=%s allow_next=%d\n",
          uri ? uri : "(null)", view->allow_next_navigation);
  // Skip internal WebKit navigations (about:blank) — no event emitted.
  // These are WebKit housekeeping loads that would otherwise overwrite
  // the model's address field with an internal URI.
  if (uri != NULL && strcmp(uri, "about:blank") == 0) {
    return FALSE;
  }
  if (!webview_policy_allows(view->policy, uri)) {
    view->allow_next_navigation = 0;
    view->navigation_pending = 0;
    webkit_policy_decision_ignore(decision);
    moui_linux_webview_emit(view->parent_surface, 4, view->id, uri,
                            "WebView navigation policy blocked URL", 0);
    return TRUE;
  }
  if (view->allow_next_navigation) {
    view->allow_next_navigation = 0;
    moui_linux_webview_emit(view->parent_surface, 1, view->id, uri, "", 0);
    return FALSE;
  }
  webkit_policy_decision_ignore(decision);
  moui_linux_webview_emit(view->parent_surface, 0, view->id, uri, "", 0);
  return TRUE;
}

static void on_load_changed(WebKitWebView *webview, WebKitLoadEvent load_event,
                            gpointer user_data) {
  MOUILinuxWebView *view = (MOUILinuxWebView *)user_data;
  const char *uri = webkit_web_view_get_uri(webview);
  fprintf(stderr, "[webview-debug] on_load_changed event=%d uri=%s\n",
          load_event, uri ? uri : "(null)");
  // Drop events with a NULL, empty, or internal URI. The initial
  // about:blank load that WebKitGTK fires automatically after widget
  // creation has no meaningful URI. When the real URL is loaded
  // immediately afterward the about:blank events may carry "about:blank"
  // or a NULL URI. Emitting any navigation event for such internal URIs
  // would overwrite the model's address field.
  if (uri == NULL || uri[0] == '\0' || strcmp(uri, "about:blank") == 0) {
    fprintf(stderr, "[webview-debug] on_load_changed DROPPED event=%d\n",
            load_event);
    if (load_event == WEBKIT_LOAD_FINISHED) {
      view->navigation_pending = 0;
    }
    return;
  }
  switch (load_event) {
  case WEBKIT_LOAD_COMMITTED:
    fprintf(stderr, "[webview-debug] on_load_changed COMMITTED uri=%s cancelled_url=%s\n",
            uri, view->cancelled_url ? view->cancelled_url : "(null)");
    // Skip stale COMMITTED events from a navigation that was replaced
    // by a newer one (e.g., initial page commit arriving after the user
    // navigated elsewhere).
    if (view->cancelled_url != NULL &&
        strcmp(view->cancelled_url, uri) == 0) {
      free(view->cancelled_url);
      view->cancelled_url = NULL;
      break;
    }
    free(view->current_url);
    view->current_url = strdup(uri);
    moui_linux_webview_emit(view->parent_surface, 2, view->id, uri, "", 0);
    break;
  case WEBKIT_LOAD_FINISHED: {
    fprintf(stderr, "[webview-debug] on_load_changed FINISHED uri=%s cancelled_url=%s\n",
            uri, view->cancelled_url ? view->cancelled_url : "(null)");
    view->navigation_pending = 0;
    // Skip stale WEBKIT_LOAD_FINISHED events from a navigation that was
    // replaced by a newer one (e.g., initial page load finishing after
    // the user navigated elsewhere). Only skip if the URL matches exactly.
    if (view->cancelled_url != NULL &&
        strcmp(view->cancelled_url, uri) == 0) {
      free(view->cancelled_url);
      view->cancelled_url = NULL;
      break;
    }
    free(view->cancelled_url);
    view->cancelled_url = NULL;
    moui_linux_webview_emit(view->parent_surface, 3, view->id, uri, "", 0);
    break;
  }
  default:
    break;
  }
}

static gboolean on_load_failed(WebKitWebView *webview, WebKitLoadEvent event,
                               char *uri, GError *error, gpointer user_data) {
  (void)webview;
  (void)event;
  MOUILinuxWebView *view = (MOUILinuxWebView *)user_data;
  view->navigation_pending = 0;
  moui_linux_webview_emit(view->parent_surface, 4, view->id, uri,
                          error ? error->message : "WebKitGTK load failed", 0);
  return FALSE;
}

static void on_title_changed(GObject *object, GParamSpec *pspec,
                             gpointer user_data) {
  (void)pspec;
  MOUILinuxWebView *view = (MOUILinuxWebView *)user_data;
  const char *title = webkit_web_view_get_title(WEBKIT_WEB_VIEW(object));
  moui_linux_webview_emit(view->parent_surface, 5, view->id, "", title, 0);
}

static void on_history_changed(GObject *object, GParamSpec *pspec,
                               gpointer user_data) {
  (void)pspec;
  MOUILinuxWebView *view = (MOUILinuxWebView *)user_data;
  WebKitWebView *webview = WEBKIT_WEB_VIEW(object);
  moui_linux_webview_emit(view->parent_surface, 6, view->id, "", "",
                          webkit_web_view_can_go_back(webview) ? 1 : 0);
  moui_linux_webview_emit(view->parent_surface, 7, view->id, "", "",
                          webkit_web_view_can_go_forward(webview) ? 1 : 0);
}

typedef struct MOUILinuxJavaScriptRequest {
  uint64_t parent_surface;
  char *id;
  char *request_id;
} MOUILinuxJavaScriptRequest;

static void javascript_request_free(MOUILinuxJavaScriptRequest *request) {
  if (request == NULL) {
    return;
  }
  free(request->id);
  free(request->request_id);
  free(request);
}

static void on_javascript_finished(GObject *object, GAsyncResult *result,
                                   gpointer user_data) {
  MOUILinuxJavaScriptRequest *request =
      (MOUILinuxJavaScriptRequest *)user_data;
  GError *error = NULL;
#if WEBKIT_CHECK_VERSION(2, 40, 0)
  JSCValue *js_value = webkit_web_view_evaluate_javascript_finish(
      WEBKIT_WEB_VIEW(object), result, &error);
#else
  WebKitJavascriptResult *js_result = webkit_web_view_run_javascript_finish(
      WEBKIT_WEB_VIEW(object), result, &error);
#endif
  if (error != NULL) {
    moui_linux_webview_emit(request->parent_surface, 8, request->id,
                            request->request_id, error->message,
                            error->code);
    g_error_free(error);
    javascript_request_free(request);
    return;
  }
  char *value = NULL;
#if WEBKIT_CHECK_VERSION(2, 40, 0)
  if (js_value != NULL) {
    value = jsc_value_to_string(js_value);
    g_object_unref(js_value);
  }
#else
  if (js_result != NULL) {
    JSCValue *js_value = webkit_javascript_result_get_js_value(js_result);
    if (js_value != NULL) {
      value = jsc_value_to_string(js_value);
    }
    webkit_javascript_result_unref(js_result);
  }
#endif
  moui_linux_webview_emit(request->parent_surface, 8, request->id,
                          request->request_id, value ? value : "", 0);
  g_free(value);
  javascript_request_free(request);
}

static MOUILinuxWebView *ensure_view(uint64_t surface, const char *id,
                                     const char *background) {
  MOUILinuxWebView *view = find_view(surface, id);
  if (view != NULL) {
    return view;
  }
  if (!ensure_gtk()) {
    return NULL;
  }
  view = (MOUILinuxWebView *)calloc(1, sizeof(MOUILinuxWebView));
  if (view == NULL) {
    return NULL;
  }
  view->parent_surface = surface;
  view->id = strdup(id ? id : "");

  // Create offscreen window for rendering to memory
  view->offscreen_window = gtk_offscreen_window_new();
  view->webview = WEBKIT_WEB_VIEW(webkit_web_view_new());
  gtk_container_add(GTK_CONTAINER(view->offscreen_window), GTK_WIDGET(view->webview));
  parse_background_color(background, &view->background_red, &view->background_green,
                         &view->background_blue, &view->background_alpha);
  webkit_web_view_set_background_color(
      view->webview,
      &(GdkRGBA){view->background_red, view->background_green,
                 view->background_blue, view->background_alpha});

  // Show the widget hierarchy (but window stays offscreen)
  gtk_widget_show_all(view->offscreen_window);

  g_signal_connect(view->webview, "decide-policy", G_CALLBACK(on_decide_policy),
                   view);
  g_signal_connect(view->webview, "load-changed", G_CALLBACK(on_load_changed),
                   view);
  g_signal_connect(view->webview, "load-failed", G_CALLBACK(on_load_failed),
                   view);
  g_signal_connect(view->webview, "notify::title", G_CALLBACK(on_title_changed),
                   view);
  g_signal_connect(view->webview, "notify::can-go-back",
                   G_CALLBACK(on_history_changed), view);
  g_signal_connect(view->webview, "notify::can-go-forward",
                   G_CALLBACK(on_history_changed), view);
  view->next = g_views;
  g_views = view;
  return view;
}
#endif

MOONBIT_FFI_EXPORT
void moui_linux_webview_install_event_callback(
    moui_linux_webview_event_trampoline_t trampoline, void *closure) {
  if (g_event_closure != NULL) {
    moonbit_decref(g_event_closure);
  }
  g_event_trampoline = trampoline;
  g_event_closure = closure;
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_available(void) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  return ensure_gtk() ? 1 : 0;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_pump(int32_t max_iterations) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  if (!g_gtk_initialized && !ensure_gtk()) {
    return 0;
  }
  int32_t iterations = 0;
  int32_t limit = max_iterations <= 0 ? 1 : max_iterations;
  while (iterations < limit && g_main_context_pending(NULL)) {
    g_main_context_iteration(NULL, FALSE);
    iterations++;
  }
  return iterations;
#else
  (void)max_iterations;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_has_active_work(void) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  if (g_gtk_initialized && g_main_context_pending(NULL)) {
    return 1;
  }
  for (MOUILinuxWebView *view = g_views; view != NULL; view = view->next) {
    if (view->visible || view->navigation_pending) {
      return 1;
    }
  }
  return 0;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int64_t moui_linux_webview_next_tick_ms(int32_t delay_ms) {
#if defined(CLOCK_MONOTONIC)
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
    int64_t now_ms =
        ((int64_t)ts.tv_sec * 1000) + ((int64_t)ts.tv_nsec / 1000000);
    return now_ms + (delay_ms <= 0 ? 1 : delay_ms);
  }
#endif
  return delay_ms <= 0 ? 1 : delay_ms;
}

MOONBIT_FFI_EXPORT
void moui_linux_webview_platform_views_begin(uint64_t wl_surface) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  for (MOUILinuxWebView *view = g_views; view != NULL; view = view->next) {
    if (view->parent_surface == wl_surface) {
      view->seen = 0;
    }
  }
#else
  (void)wl_surface;
#endif
}

MOONBIT_FFI_EXPORT
void moui_linux_webview_sync(uint64_t wl_display, uint64_t wl_surface,
                             moonbit_bytes_t id, moonbit_bytes_t url,
                             moonbit_bytes_t title, moonbit_bytes_t background,
                             moonbit_bytes_t scheme, int32_t policy, double x,
                             double y, double width, double height) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  (void)wl_display;
  (void)title;
  (void)x;  // Position not needed for offscreen rendering
  (void)y;

  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  char *url_text = moui_linux_webview_bytes_to_cstr(url);
  char *background_text = moui_linux_webview_bytes_to_cstr(background);
  (void)scheme;
  if (id_text == NULL || url_text == NULL) {
    free(id_text);
    free(url_text);
    free(background_text);
    return;
  }
  MOUILinuxWebView *view = ensure_view(wl_surface, id_text, background_text);
  if (view != NULL) {
    view->seen = 1;
    view->policy = policy;
    parse_background_color(background_text, &view->background_red,
                           &view->background_green, &view->background_blue,
                           &view->background_alpha);
    webkit_web_view_set_background_color(
        view->webview,
        &(GdkRGBA){view->background_red, view->background_green,
                   view->background_blue, view->background_alpha});
    view->visible = width > 0.0 && height > 0.0;

    // Update size for offscreen rendering
    int new_width = (int)width;
    int new_height = (int)height;
    if (view->width != new_width || view->height != new_height) {
      view->width = new_width;
      view->height = new_height;
      // Resize the offscreen window
      gtk_window_resize(GTK_WINDOW(view->offscreen_window), new_width, new_height);
      gtk_widget_set_size_request(GTK_WIDGET(view->webview), new_width, new_height);
    }

    // Only set initial URL on first creation. All subsequent URL changes
    // are driven by commands (LoadUrl, GoBack, GoForward), not sync.
    // This prevents stale NavigationCommitted events from the initial load
    // from overwriting the user's intended URL.
    if (view->desired_url == NULL) {
      linux_webview_load_controlled(view, url_text);
    }
  }
  free(id_text);
  free(url_text);
  free(background_text);
#else
  (void)wl_display;
  (void)wl_surface;
  (void)id;
  (void)url;
  (void)title;
  (void)background;
  (void)scheme;
  (void)policy;
  (void)x;
  (void)y;
  (void)width;
  (void)height;
#endif
}

MOONBIT_FFI_EXPORT
void moui_linux_webview_platform_views_end(uint64_t wl_surface) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  // In offscreen mode, just mark unseen views as invisible
  for (MOUILinuxWebView *view = g_views; view != NULL; view = view->next) {
    if (view->parent_surface == wl_surface && !view->seen) {
      view->visible = 0;
    }
  }
#else
  (void)wl_surface;
#endif
}

MOONBIT_FFI_EXPORT
void moui_linux_webview_platform_views_dispose(uint64_t wl_surface) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  MOUILinuxWebView **cursor = &g_views;
  while (*cursor != NULL) {
    MOUILinuxWebView *view = *cursor;
    if (view->parent_surface == wl_surface) {
      *cursor = view->next;
      if (view->offscreen_window) {
        gtk_widget_destroy(view->offscreen_window);
      }
      free(view->id);
      free(view->desired_url);
      free(view->current_url);
      free(view->cancelled_url);
      free(view);
    } else {
      cursor = &view->next;
    }
  }
#else
  (void)wl_surface;
#endif
}

MOONBIT_FFI_EXPORT
void moui_linux_webview_command(uint64_t wl_surface, moonbit_bytes_t id,
                                int32_t command, moonbit_bytes_t text,
                                moonbit_bytes_t detail) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  MOUILinuxWebView *view = find_view(wl_surface, id_text);
  free(id_text);
  if (view == NULL || view->webview == NULL) {
    return;
  }
  switch (command) {
  case 0: {
    char *url = moui_linux_webview_bytes_to_cstr(text);
    linux_webview_load_controlled(view, url);
    free(url);
    break;
  }
  case 1:
    webkit_web_view_reload(view->webview);
    break;
  case 2:
    webkit_web_view_stop_loading(view->webview);
    break;
  case 3:
    webkit_web_view_go_back(view->webview);
    break;
  case 4:
    webkit_web_view_go_forward(view->webview);
    break;
  case 5: {
    char *script = moui_linux_webview_bytes_to_cstr(text);
    char *request_id = moui_linux_webview_bytes_to_cstr(detail);
    MOUILinuxJavaScriptRequest *request =
        (MOUILinuxJavaScriptRequest *)calloc(1, sizeof(MOUILinuxJavaScriptRequest));
    if (request != NULL) {
      request->parent_surface = view->parent_surface;
      request->id = strdup(view->id ? view->id : "");
      request->request_id = strdup(request_id ? request_id : "");
#if WEBKIT_CHECK_VERSION(2, 40, 0)
      webkit_web_view_evaluate_javascript(view->webview, script ? script : "",
                                          -1, NULL, NULL, NULL,
                                          on_javascript_finished, request);
#else
      webkit_web_view_run_javascript(view->webview, script, NULL,
                                     on_javascript_finished, request);
#endif
    } else {
      moui_linux_webview_emit(view->parent_surface, 8, view->id,
                              request_id ? request_id : "",
                              "JavaScript request allocation failed", 1);
    }
    free(script);
    free(request_id);
    break;
  }
  default:
    break;
  }
#else
  (void)text;
  (void)detail;
  if (command == 0) {
    char *id_text = moui_linux_webview_bytes_to_cstr(id);
    moui_linux_webview_emit(
        wl_surface, 4, id_text ? id_text : "", "",
        "Linux WebKitGTK native bridge is unavailable", 0);
    free(id_text);
  } else {
    (void)id;
    (void)wl_surface;
  }
#endif
}

// Wrapper struct to return surface data to MoonBit
typedef struct {
  void* surface_ptr;     // cairo_surface_t* cast to void*
  int32_t width;
  int32_t height;
  int32_t stride;        // Row bytes
} MOUIWebViewSurfaceData;

// Get surface pointer for a webview (offscreen rendering)
MOONBIT_FFI_EXPORT
uint64_t moui_linux_webview_get_surface_ptr(
    uint64_t wl_surface,
    moonbit_bytes_t id
) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  MOUILinuxWebView *view = find_view(wl_surface, id_text);
  free(id_text);

  if (view == NULL || view->offscreen_window == NULL || !view->visible) {
    return 0;
  }

  cairo_surface_t *surface = gtk_offscreen_window_get_surface(
      GTK_OFFSCREEN_WINDOW(view->offscreen_window));

  if (surface == NULL) {
    return 0;
  }

  return (uint64_t)(uintptr_t)surface;
#else
  (void)wl_surface;
  (void)id;
  return 0;
#endif
}

// Get surface width for a webview
MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_get_surface_width(
    uint64_t wl_surface,
    moonbit_bytes_t id
) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  MOUILinuxWebView *view = find_view(wl_surface, id_text);
  free(id_text);

  if (view == NULL || view->offscreen_window == NULL || !view->visible) {
    return 0;
  }

  return view->width;
#else
  (void)wl_surface;
  (void)id;
  return 0;
#endif
}

// Get surface height for a webview
MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_get_surface_height(
    uint64_t wl_surface,
    moonbit_bytes_t id
) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  MOUILinuxWebView *view = find_view(wl_surface, id_text);
  free(id_text);

  if (view == NULL || view->offscreen_window == NULL || !view->visible) {
    return 0;
  }

  return view->height;
#else
  (void)wl_surface;
  (void)id;
  return 0;
#endif
}

// Get surface stride for a webview
MOONBIT_FFI_EXPORT
int32_t moui_linux_webview_get_surface_stride(
    uint64_t wl_surface,
    moonbit_bytes_t id
) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  char *id_text = moui_linux_webview_bytes_to_cstr(id);
  MOUILinuxWebView *view = find_view(wl_surface, id_text);
  free(id_text);

  if (view == NULL || view->offscreen_window == NULL || !view->visible) {
    return 0;
  }

  cairo_surface_t *surface = gtk_offscreen_window_get_surface(
      GTK_OFFSCREEN_WINDOW(view->offscreen_window));

  if (surface == NULL) {
    return 0;
  }

  return cairo_image_surface_get_stride(surface);
#else
  (void)wl_surface;
  (void)id;
  return 0;
#endif
}

// Get pixel data from cairo surface
MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_linux_webview_get_surface_pixels(void* surface_ptr) {
#if defined(MOUI_LINUX_ENABLE_WEBKITGTK)
  if (surface_ptr == NULL) {
    return moonbit_make_bytes(0, 0);
  }

  cairo_surface_t *surface = (cairo_surface_t*)surface_ptr;
  cairo_surface_flush(surface);  // Ensure all drawing is complete

  unsigned char *data = cairo_image_surface_get_data(surface);
  int stride = cairo_image_surface_get_stride(surface);
  int height = cairo_image_surface_get_height(surface);
  int size = stride * height;

  moonbit_bytes_t bytes = moonbit_make_bytes(size, 0);
  if (data != NULL && size > 0) {
    memcpy(bytes, data, size);
  }
  return bytes;
#else
  (void)surface_ptr;
  return moonbit_make_bytes(0, 0);
#endif
}
