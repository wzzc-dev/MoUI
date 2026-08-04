///|
pub(all) struct ServiceError {
  code : String
  message : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ServiceTaskResult[T] {
  Success(T)
  Failure(ServiceError)
  Cancelled
} derive(Eq, Debug)

///|
pub struct ServiceTask[T] {
  key : String
  label : String
  start_fn : ((ServiceTaskResult[T]) -> Unit) -> (() -> Unit)?
}

///|
pub fn ServiceError::new(code~ : String, message~ : String) -> ServiceError {
  { code, message }
}

///|
pub fn ServiceError::unavailable(message : String) -> ServiceError {
  ServiceError::new(code="unavailable", message~)
}

///|
pub fn[T] ServiceTask::new(
  key~ : String,
  start~ : ((ServiceTaskResult[T]) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> ServiceTask[T] {
  { key, label, start_fn: start }
}

///|
pub fn[T] ServiceTask::succeed(
  key~ : String,
  value~ : T,
  label? : String = "",
) -> ServiceTask[T] {
  ServiceTask::new(key~, label~, start=complete => {
    complete(ServiceTaskResult::Success(value))
    None
  })
}

///|
pub fn[T] ServiceTask::fail(
  key~ : String,
  error~ : ServiceError,
  label? : String = "",
) -> ServiceTask[T] {
  ServiceTask::new(key~, label~, start=complete => {
    complete(ServiceTaskResult::Failure(error))
    None
  })
}

///|
pub fn[T] ServiceTask::cancelled(
  key~ : String,
  label? : String = "",
) -> ServiceTask[T] {
  ServiceTask::new(key~, label~, start=complete => {
    complete(ServiceTaskResult::Cancelled)
    None
  })
}

///|
pub fn[T] ServiceTask::key(self : ServiceTask[T]) -> String {
  self.key
}

///|
pub fn[T] ServiceTask::label(self : ServiceTask[T]) -> String {
  self.label
}

///|
pub fn[T] ServiceTask::start(
  self : ServiceTask[T],
  complete : (ServiceTaskResult[T]) -> Unit,
) -> (() -> Unit)? {
  (self.start_fn)(complete)
}

///|
pub fn[T, U] ServiceTask::map(
  self : ServiceTask[T],
  map : (T) -> U,
) -> ServiceTask[U] {
  ServiceTask::new(key=self.key, label=self.label, start=complete => {
    self.start(result => {
      match result {
        Success(value) => complete(ServiceTaskResult::Success(map(value)))
        Failure(error) => complete(ServiceTaskResult::Failure(error))
        Cancelled => complete(ServiceTaskResult::Cancelled)
      }
    })
  })
}

///|
pub fn[T, Msg] ServiceTask::effect(
  self : ServiceTask[T],
  map~ : (ServiceTaskResult[T]) -> Msg,
) -> @core.Effect[Msg] {
  @core.Effect::service_task(key=self.key, label=self.label, start=dispatch => {
    self.start(result => dispatch(map(result)))
  })
}

///|
fn[T] unavailable_task(key : String, capability : String) -> ServiceTask[T] {
  ServiceTask::fail(
    key~,
    error=ServiceError::unavailable(capability + " is unavailable"),
    label=capability,
  )
}
