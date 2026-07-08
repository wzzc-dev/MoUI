///|
pub(all) struct PlatformChannelRequest {
  channel : String
  operation : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PlatformChannelResponse {
  Ok(String)
  Unavailable(String)
  Error(String)
} derive(Eq, Debug, ToJson)

///|
pub struct PlatformChannelHandler {
  priv channel : String
  priv handle : (PlatformChannelRequest) -> PlatformChannelResponse
}

///|
pub struct PlatformChannelRegistry {
  priv mut handlers : Array[PlatformChannelHandler]
}

///|
pub fn PlatformChannelRequest::new(
  channel~ : String,
  operation~ : String,
  payload? : String = "",
) -> PlatformChannelRequest {
  { channel, operation, payload }
}

///|
pub fn PlatformChannelHandler::new(
  channel~ : String,
  handle~ : (PlatformChannelRequest) -> PlatformChannelResponse,
) -> PlatformChannelHandler {
  { channel, handle }
}

///|
pub fn PlatformChannelRegistry::new() -> PlatformChannelRegistry {
  { handlers: [] }
}

///|
pub fn PlatformChannelRegistry::register(
  self : PlatformChannelRegistry,
  handler : PlatformChannelHandler,
) -> Unit {
  self.handlers = self.handlers.filter(existing => {
    existing.channel != handler.channel
  })
  self.handlers.push(handler)
}

///|
pub fn PlatformChannelRegistry::can_dispatch(
  self : PlatformChannelRegistry,
  channel : String,
) -> Bool {
  self.handlers.any(handler => handler.channel == channel)
}

///|
pub fn PlatformChannelRegistry::dispatch(
  self : PlatformChannelRegistry,
  request : PlatformChannelRequest,
) -> PlatformChannelResponse {
  for handler in self.handlers {
    if handler.channel == request.channel {
      return (handler.handle)(request)
    }
  }
  PlatformChannelResponse::Unavailable(
    "platform channel is unavailable: " + request.channel,
  )
}

///|
pub fn HostServiceBridge::register_channel(
  self : HostServiceBridge,
  handler : PlatformChannelHandler,
) -> Unit {
  self.channels.register(handler)
}

///|
pub fn HostServiceBridge::dispatch_channel(
  self : HostServiceBridge,
  request : PlatformChannelRequest,
) -> PlatformChannelResponse {
  self.channels.dispatch(request)
}
