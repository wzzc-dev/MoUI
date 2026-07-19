///|
/// The only currently supported native-shell product profile.
pub(all) enum ShellProfile {
  Handheld
} derive(Eq, Debug, ToJson)

///|
pub fn ShellProfile::label(self : ShellProfile) -> String {
  match self {
    Handheld => "handheld"
  }
}

///|
/// Version negotiated by a MoUI embedding adapter and a native shell runner.
pub(all) struct EmbeddingApiVersion {
  major : Int
} derive(Eq, Debug, ToJson)

///|
pub fn embedding_api_version() -> EmbeddingApiVersion {
  { major: 1 }
}

///|
/// Version of managed and ejected runner layout metadata.
pub(all) struct RunnerApiVersion {
  major : Int
} derive(Eq, Debug, ToJson)

///|
pub fn runner_api_version() -> RunnerApiVersion {
  { major: 1 }
}
