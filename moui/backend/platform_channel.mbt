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
pub fn PlatformChannelRequest::new(
  channel~ : String,
  operation~ : String,
  payload? : String = "",
) -> PlatformChannelRequest {
  { channel, operation, payload }
}
