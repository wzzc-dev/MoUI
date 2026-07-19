#import "MoUIMobileRuntimeBridge.h"

#include "../../../include/moui_embedding_api_v1.h"

const int32_t MOUIShellBridgeErrorIncompatibleABI = -1000;

namespace {

const moui_embedding_api_v1 *runtime_api() {
  static const moui_embedding_api_v1 *const api = [] {
    const moui_embedding_api_v1 *candidate =
        moui_embedding_get_api_v1();
    return moui_embedding_api_v1_is_compatible(candidate) ? candidate
                                                                : nullptr;
  }();
  return api;
}

moui_embedding_utf8_view_v1 utf8_view(NSString *value, NSData **storage) {
  NSData *data =
      [value dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
  *storage = data;
  return {
      static_cast<const uint8_t *>(data.bytes),
      static_cast<size_t>(data.length),
  };
}

MOUIShellRuntimeDataResult *copy_result(moui_embedding_utf8_buffer_v1 buffer) {
  NSData *data = nil;
  if (buffer.status == MOUI_EMBEDDING_API_STATUS_OK_V1 &&
      buffer.data != nullptr) {
    data = [NSData dataWithBytes:buffer.data length:buffer.length];
  }
  if (buffer.release != nullptr) {
    buffer.release(buffer.release_context, buffer.data, buffer.length);
  }
  return [[MOUIShellRuntimeDataResult alloc] initWithStatus:buffer.status
                                                        data:data];
}

} // namespace

@implementation MOUIShellRuntimeDataResult

- (instancetype)initWithStatus:(int32_t)status data:(NSData *)data {
  self = [super init];
  if (self != nil) {
    _status = status;
    _data = data;
  }
  return self;
}

@end

@implementation MOUIShellRuntimeBridge

+ (MOUIShellRuntimeBridge *)shared {
  static MOUIShellRuntimeBridge *bridge;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    bridge = [[MOUIShellRuntimeBridge alloc] init];
  });
  return bridge;
}

- (BOOL)compatible {
  return runtime_api() != nullptr;
}

- (int32_t)startWithAppArgument:(NSString *)appArgument
                       renderer:(NSString *)renderer {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  NSData *appStorage = nil;
  const int32_t initialized =
      api->initialize(utf8_view(appArgument, &appStorage));
  if (initialized != MOUI_EMBEDDING_API_RESULT_TRUE_V1)
    return initialized;
  NSData *rendererStorage = nil;
  const int32_t configured =
      api->configure_renderer(utf8_view(renderer, &rendererStorage));
  return configured;
}

- (int32_t)destroyApplication {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->destroy_application();
}

- (int32_t)detachSurface {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->detach_surface();
}

- (int32_t)attachSurfaceView:(UIView *)view
                       width:(int32_t)width
                      height:(int32_t)height
                       scale:(double)scale {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  const uint64_t handle = reinterpret_cast<uint64_t>((__bridge void *)view);
  return api->attach_surface(handle, width, height, scale);
}

- (int32_t)resizeWidth:(int32_t)width
                height:(int32_t)height
                 scale:(double)scale {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->resize(width, height, scale);
}

- (int32_t)dispatchPointerPhase:(int32_t)phase
                              x:(double)x
                              y:(double)y
                         timeMs:(double)timeMs {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->dispatch_pointer(phase, x, y, timeMs);
}

- (int32_t)dispatchScrollX:(double)x
                         y:(double)y
                    deltaX:(double)deltaX
                    deltaY:(double)deltaY
                     phase:(int32_t)phase {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  if (api->dispatch_scroll == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return api->dispatch_scroll(x, y, deltaX, deltaY, phase);
}

- (int32_t)frameTick:(double)timeMs {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->frame_tick(timeMs);
}

- (int32_t)renderFrame {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->render_frame();
}

- (MOUIShellRuntimeDataResult *)rendererStatusJSON {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr) {
    return [[MOUIShellRuntimeDataResult alloc]
        initWithStatus:MOUIShellBridgeErrorIncompatibleABI
                  data:nil];
  }
  return copy_result(api->renderer_status_json());
}

- (MOUIShellRuntimeDataResult *)takeHostUpdateEnvelopeJSON {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr) {
    return [[MOUIShellRuntimeDataResult alloc]
        initWithStatus:MOUIShellBridgeErrorIncompatibleABI
                  data:nil];
  }
  return copy_result(api->take_host_update_envelope_json());
}

- (int32_t)dispatchHostResponseEnvelopeJSON:(NSData *)json {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  const moui_embedding_utf8_view_v1 view = {
      static_cast<const uint8_t *>(json.bytes),
      static_cast<size_t>(json.length),
  };
  return api->dispatch_host_response_envelope(view);
}

- (int32_t)dispatchTextInputKind:(int32_t)kind
                            text:(NSString *)text
                           start:(int32_t)start
                             end:(int32_t)end {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  NSData *storage = nil;
  return api->dispatch_text_input(kind, utf8_view(text, &storage), start, end);
}

- (int32_t)dispatchCommandKind:(int32_t)kind {
  const moui_embedding_api_v1 *api = runtime_api();
  return api == nullptr ? MOUIShellBridgeErrorIncompatibleABI
                        : api->dispatch_command(kind);
}

- (int32_t)dispatchAccessibilityElement:(int32_t)element
                                 action:(int32_t)action
                                  value:(NSString *)value {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  NSData *storage = nil;
  return api->dispatch_accessibility(element, action,
                                     utf8_view(value, &storage));
}

- (int32_t)completeClipboardSessionGeneration:(int32_t)sessionGeneration
                                      request:(int32_t)requestId
                                         kind:(int32_t)kind
                                         text:(NSString *)text
                                        bytes:(NSData *)bytes {
  const moui_embedding_api_v1 *api = runtime_api();
  if (api == nullptr)
    return MOUIShellBridgeErrorIncompatibleABI;
  NSData *textStorage = nil;
  const moui_embedding_bytes_view_v1 bytesView = {
      static_cast<const uint8_t *>(bytes.bytes),
      static_cast<size_t>(bytes.length),
  };
  return api->complete_clipboard(sessionGeneration, requestId, kind,
                                 utf8_view(text, &textStorage), bytesView);
}

@end
