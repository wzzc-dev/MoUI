///|
/// Root facade: high-frequency app-loop kernel types from `moui/core`.
/// Geometry/graphics/text/state sugar stay in `moui/{geometry,graphics,text,state}`.
/// Apps import `wzzc-dev/moui` and use `@moui.View` etc. so `@app` remains the
/// shared example package alias. See `docs/moui-app-package-boundary.md`.

///|
pub using @core {type View}

///|
pub using @core {type Program}

///|
pub using @core {type ProgramCommand}

///|
pub using @core {type Effect}

///|
pub using @core {type Subscription}

///|
pub using @core {type Theme}

///|
pub using @core {type Environment}

///|
pub using @core {type ViewEnvironment}

///|
pub using @core {type ControlledValue}

///|
pub using @core {type ScrollRequest}

///|
pub using @core {type FocusRequest}

///|
pub using @core {type SemanticId}
