///|
/// An immutable, canonical declaration identity.
///
/// Keys compare their complete encoded bytes. Hashing is only an acceleration
/// used by hashed containers before exact equality; it is not identity.
pub struct DeclarationKey {
  priv bytes : Bytes
} derive(Eq, Hash, Debug)

///|
/// Cache behavior for one declaration channel.
pub(all) enum DeclarationChannel {
  /// The channel never changes for a reused view identity.
  Constant
  /// The channel changes exactly when its canonical key changes.
  Exact(DeclarationKey)
  /// The channel must be treated as changed on every reconciliation.
  Uncacheable
} derive(Eq)

///|
/// The four independently declared invalidation channels for a view node.
pub struct ViewDeclaration {
  layout : DeclarationChannel
  paint : DeclarationChannel
  semantics : DeclarationChannel
  platform : DeclarationChannel
} derive(Eq)

///|
/// Effective changes between two declarations.
///
/// A layout change always implies paint, semantics, and platform changes.
pub struct DeclarationChanges {
  layout : Bool
  paint : Bool
  semantics : Bool
  platform : Bool
} derive(Eq, Debug)

///|
fn declaration_key_frame(tag : Byte, payload : Bytes) -> DeclarationKey {
  let output = Buffer(size_hint=1 + 8 + payload.length())
  output.write_byte(tag)
  output.write_uint64_be(payload.length().to_uint64())
  output.write_bytes(payload)
  { bytes: output.to_bytes() }
}

///|
fn declaration_key_write_framed(output : Buffer, value : Bytes) -> Unit {
  output.write_uint64_be(value.length().to_uint64())
  output.write_bytes(value)
}

///|
/// Builds a key for a boolean value.
pub fn DeclarationKey::bool(value : Bool) -> DeclarationKey {
  declaration_key_frame(1, if value { b"\x01" } else { b"\x00" })
}

///|
/// Builds a key for an exact signed 32-bit `Int` value.
pub fn DeclarationKey::int(value : Int) -> DeclarationKey {
  let payload = Buffer(size_hint=4)
  payload.write_int_be(value)
  declaration_key_frame(2, payload.to_bytes())
}

///|
/// Builds a key for an exact unsigned 32-bit `UInt` value.
pub fn DeclarationKey::uint(value : UInt) -> DeclarationKey {
  let payload = Buffer(size_hint=4)
  payload.write_uint_be(value)
  declaration_key_frame(3, payload.to_bytes())
}

///|
/// Builds a key for an exact signed 64-bit integer value.
pub fn DeclarationKey::int64(value : Int64) -> DeclarationKey {
  let payload = Buffer(size_hint=8)
  payload.write_int64_be(value)
  declaration_key_frame(4, payload.to_bytes())
}

///|
/// Builds a key for an exact unsigned 64-bit integer value.
pub fn DeclarationKey::uint64(value : UInt64) -> DeclarationKey {
  declaration_key_frame(5, value.to_be_bytes())
}

///|
/// Builds a bit-exact IEEE-754 key. This distinguishes signed zero and NaN
/// payloads as well as adjacent finite values.
pub fn DeclarationKey::double(value : Double) -> DeclarationKey {
  declaration_key_frame(6, value.reinterpret_as_uint64().to_be_bytes())
}

///|
/// Builds a key from the value's exact UTF-8 encoding without a BOM.
pub fn DeclarationKey::string(value : String) -> DeclarationKey {
  declaration_key_frame(7, @utf8.encode(value[:], bom=false))
}

///|
/// Builds a key from immutable bytes.
pub fn DeclarationKey::bytes(value : Bytes) -> DeclarationKey {
  declaration_key_frame(8, value)
}

///|
/// Builds an option key. Presence and the complete child key are framed.
pub fn DeclarationKey::option(value : DeclarationKey?) -> DeclarationKey {
  let payload = Buffer()
  match value {
    None => payload.write_byte(0)
    Some(value) => {
      payload.write_byte(1)
      declaration_key_write_framed(payload, value.bytes)
    }
  }
  declaration_key_frame(9, payload.to_bytes())
}

///|
/// Builds an ordered array key from complete child keys.
pub fn DeclarationKey::array(values : Array[DeclarationKey]) -> DeclarationKey {
  let payload = Buffer()
  payload.write_uint64_be(values.length().to_uint64())
  for value in values {
    declaration_key_write_framed(payload, value.bytes)
  }
  declaration_key_frame(10, payload.to_bytes())
}

///|
/// Builds a record key. `type_tag` identifies the declared record type;
/// fields are encoded in the supplied declaration order, including each field
/// name and complete child key.
pub fn DeclarationKey::record(
  type_tag~ : String,
  fields~ : Array[(String, DeclarationKey)],
) -> DeclarationKey {
  let payload = Buffer()
  declaration_key_write_framed(payload, @utf8.encode(type_tag[:], bom=false))
  payload.write_uint64_be(fields.length().to_uint64())
  for field in fields {
    declaration_key_write_framed(payload, @utf8.encode(field.0[:], bom=false))
    declaration_key_write_framed(payload, field.1.bytes)
  }
  declaration_key_frame(11, payload.to_bytes())
}

///|
/// Declares four channels that remain constant for a reused view identity.
pub fn ViewDeclaration::constant() -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Constant,
    paint=Constant,
    semantics=Constant,
    platform=Constant,
  )
}

///|
/// Declares four channels that must be recomputed on every reconciliation.
pub fn ViewDeclaration::uncacheable() -> ViewDeclaration {
  ViewDeclaration::channels(
    layout=Uncacheable,
    paint=Uncacheable,
    semantics=Uncacheable,
    platform=Uncacheable,
  )
}

///|
/// Declares cache behavior independently for all four channels.
pub fn ViewDeclaration::channels(
  layout~ : DeclarationChannel,
  paint~ : DeclarationChannel,
  semantics~ : DeclarationChannel,
  platform~ : DeclarationChannel,
) -> ViewDeclaration {
  { layout, paint, semantics, platform }
}

///|
pub fn ViewDeclaration::layout(self : ViewDeclaration) -> DeclarationChannel {
  self.layout
}

///|
pub fn ViewDeclaration::paint(self : ViewDeclaration) -> DeclarationChannel {
  self.paint
}

///|
pub fn ViewDeclaration::semantics(self : ViewDeclaration) -> DeclarationChannel {
  self.semantics
}

///|
pub fn ViewDeclaration::platform(self : ViewDeclaration) -> DeclarationChannel {
  self.platform
}

///|
fn DeclarationChannel::changed_from(
  self : DeclarationChannel,
  previous : DeclarationChannel,
) -> Bool {
  match (self, previous) {
    (Constant, Constant) => false
    (Exact(current), Exact(previous)) => current != previous
    _ => true
  }
}

///|
/// Classifies effective invalidation from `previous` to this declaration.
pub fn ViewDeclaration::changes_from(
  self : ViewDeclaration,
  previous : ViewDeclaration,
) -> DeclarationChanges {
  let layout = self.layout.changed_from(previous.layout)
  {
    layout,
    paint: layout || self.paint.changed_from(previous.paint),
    semantics: layout || self.semantics.changed_from(previous.semantics),
    platform: layout || self.platform.changed_from(previous.platform),
  }
}

///|
pub fn DeclarationChanges::layout(self : DeclarationChanges) -> Bool {
  self.layout
}

///|
pub fn DeclarationChanges::paint(self : DeclarationChanges) -> Bool {
  self.paint
}

///|
pub fn DeclarationChanges::semantics(self : DeclarationChanges) -> Bool {
  self.semantics
}

///|
pub fn DeclarationChanges::platform(self : DeclarationChanges) -> Bool {
  self.platform
}

///|
pub fn DeclarationChanges::is_clean(self : DeclarationChanges) -> Bool {
  !self.layout && !self.paint && !self.semantics && !self.platform
}
