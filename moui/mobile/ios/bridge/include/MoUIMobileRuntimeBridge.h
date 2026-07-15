#ifndef MOUI_MOBILE_RUNTIME_BRIDGE_H
#define MOUI_MOBILE_RUNTIME_BRIDGE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const int32_t MOUIMobileBridgeErrorIncompatibleABI;

@interface MOUIMobileRuntimeDataResult : NSObject

@property(nonatomic, readonly) int32_t status;
@property(nonatomic, readonly, nullable) NSData *data;

- (instancetype)initWithStatus:(int32_t)status
                          data:(nullable NSData *)data
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

/*
 * The bridge owns no UIKit lifecycle. It only negotiates ABI v1, dispatches
 * function-table calls, and copies/releases length-driven data at the language
 * boundary. Swift owns scenes, views, frame pacing, and host adapters.
 */
@interface MOUIMobileRuntimeBridge : NSObject

@property(class, nonatomic, readonly) MOUIMobileRuntimeBridge *shared;
@property(nonatomic, readonly) BOOL compatible;

- (int32_t)startWithAppArgument:(NSString *)appArgument
                       renderer:(NSString *)renderer;
- (int32_t)destroyApplication;
- (int32_t)detachSurface;
- (int32_t)attachSurfaceView:(UIView *)view
                       width:(int32_t)width
                      height:(int32_t)height
                       scale:(double)scale;
- (int32_t)resizeWidth:(int32_t)width
                height:(int32_t)height
                 scale:(double)scale;
- (int32_t)dispatchPointerPhase:(int32_t)phase
                              x:(double)x
                              y:(double)y
                         timeMs:(double)timeMs;
- (int32_t)dispatchScrollX:(double)x
                         y:(double)y
                    deltaX:(double)deltaX
                    deltaY:(double)deltaY
                     phase:(int32_t)phase;
- (int32_t)frameTick:(double)timeMs;
- (int32_t)renderFrame;

- (MOUIMobileRuntimeDataResult *)rendererStatusJSON;
- (MOUIMobileRuntimeDataResult *)takeHostUpdateEnvelopeJSON;
- (int32_t)dispatchHostResponseEnvelopeJSON:(NSData *)json;
- (int32_t)dispatchTextInputKind:(int32_t)kind
                            text:(NSString *)text
                           start:(int32_t)start
                             end:(int32_t)end;
- (int32_t)dispatchCommandKind:(int32_t)kind;
- (int32_t)dispatchAccessibilityElement:(int32_t)element
                                 action:(int32_t)action
                                  value:(NSString *)value;
- (int32_t)completeClipboardSessionGeneration:(int32_t)sessionGeneration
                                      request:(int32_t)requestId
                                         kind:(int32_t)kind
                                         text:(NSString *)text
                                        bytes:(NSData *)bytes;

@end

NS_ASSUME_NONNULL_END

#endif
