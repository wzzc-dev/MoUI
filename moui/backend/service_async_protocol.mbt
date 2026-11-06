///|
#derive(Eq, Debug, ToJson)
pub(all) struct HostServiceRequestId {
  value : Int32
}

///|
pub extend HostServiceRequestId with Debug::{to_repr}

///|
pub extend HostServiceRequestId with Eq::{not_equal, equal}

///|
pub extend HostServiceRequestId with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct HostPendingServiceRequest {
  id : HostServiceRequestId
  request : HostServiceRequest
}

///|
pub extend HostPendingServiceRequest with Debug::{to_repr}

///|
pub extend HostPendingServiceRequest with Eq::{not_equal, equal}

///|
pub extend HostPendingServiceRequest with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct HostCompletedServiceResponse {
  id : HostServiceRequestId
  request : HostServiceRequest
  response : HostServiceResponse
}

///|
pub extend HostCompletedServiceResponse with Debug::{to_repr}

///|
pub extend HostCompletedServiceResponse with Eq::{not_equal, equal}

///|
pub extend HostCompletedServiceResponse with ToJson::{to_json}

///|
pub fn HostServiceRequestId::new(value : Int32) -> HostServiceRequestId {
  { value, }
}

///|
pub fn HostServiceResponse::is_pending(self : HostServiceResponse) -> Bool {
  match self {
    Pending(_) => true
    _ => false
  }
}
