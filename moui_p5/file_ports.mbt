///|
/// Host byte I/O used by `Sketch` image loading and saving.
///
/// The p5 addon keeps no filesystem dependency of its own: the host installs
/// `FilePorts` backed by host file APIs (native filesystem reads on native,
/// browser storage on Web, an in-memory map in tests, ...). Ports that reject every
/// operation (`FilePorts::none`) keep wasm hosts on the previous "cannot read
/// or write files" behavior instead of failing to build.
pub struct FilePorts {
  load : (String) -> Bytes?
  save : (String, Bytes) -> Bool
}

///|
/// Builds ports from a loader and a saver.
///
/// `load` returns `None` when the path cannot be read; `save` returns false
/// when the path cannot be written. Implementations report failures through
/// those return values instead of raising, so sketch code never needs to
/// catch host errors.
pub fn FilePorts::new(
  load~ : (String) -> Bytes?,
  save~ : (String, Bytes) -> Bool,
) -> FilePorts {
  { load, save, }
}

///|
/// Ports that reject every operation, for hosts without file I/O.
pub fn FilePorts::none() -> FilePorts {
  {
    load: fn(_path : String) { None },
    save: fn(_path : String, _bytes : Bytes) { false },
  }
}

///|
/// Reads `path` through the installed loader, or `None` when it rejects.
pub fn FilePorts::load(self : FilePorts, path : String) -> Bytes? {
  (self.load)(path)
}

///|
/// Writes `bytes` to `path` through the installed saver.
pub fn FilePorts::save(self : FilePorts, path : String, bytes : Bytes) -> Bool {
  (self.save)(path, bytes)
}

///|
/// Process-wide fallback ports. Host entrypoints install the concrete
/// implementation once; sketches created afterwards inherit it.
let global_file_ports : Ref[FilePorts?] = Ref(None)

///|
/// Installs the ports inherited by sketches created after this call.
pub fn set_default_file_ports(ports : FilePorts) -> Unit {
  global_file_ports.val = Some(ports)
}

///|
/// Removes the installed ports; later sketches inherit `FilePorts::none`.
pub fn clear_default_file_ports() -> Unit {
  global_file_ports.val = None
}

///|
/// The ports installed with `set_default_file_ports`, or `FilePorts::none`.
pub fn default_file_ports() -> FilePorts {
  match global_file_ports.val {
    Some(ports) => ports
    None => FilePorts::none()
  }
}
