///|
pub(all) struct PlatformChannelRequest {
  channel : String
  operation : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub extend PlatformChannelRequest with Debug::{to_repr}

///|
pub extend PlatformChannelRequest with Eq::{not_equal, equal}

///|
pub extend PlatformChannelRequest with ToJson::{to_json}

///|
pub(all) enum PlatformChannelResponse {
  Ok(String)
  Unavailable(String)
  Error(String)
} derive(Eq, Debug, ToJson)

///|
pub extend PlatformChannelResponse with Debug::{to_repr}

///|
pub extend PlatformChannelResponse with Eq::{not_equal, equal}

///|
pub extend PlatformChannelResponse with ToJson::{to_json}

///|
pub fn PlatformChannelRequest::new(
  channel~ : String,
  operation~ : String,
  payload? : String = "",
) -> PlatformChannelRequest {
  { channel, operation, payload, }
}
