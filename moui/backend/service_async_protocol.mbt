///|
pub(all) struct HostServiceRequestId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostPendingServiceRequest {
  id : HostServiceRequestId
  request : HostServiceRequest
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostCompletedServiceResponse {
  id : HostServiceRequestId
  request : HostServiceRequest
  response : HostServiceResponse
} derive(Eq, Debug, ToJson)

///|
pub fn HostServiceRequestId::new(value : Int) -> HostServiceRequestId {
  { value, }
}

///|
pub fn HostServiceResponse::is_pending(self : HostServiceResponse) -> Bool {
  match self {
    Pending(_) => true
    _ => false
  }
}
