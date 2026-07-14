///|
fn avif_bytes_has_brand_for_test(data : Bytes, brand : Bytes) -> Bool {
  let end = if data.length() < 64 { data.length() } else { 64 }
  let mut pos = 0
  while pos + brand.length() <= end {
    if data[pos:pos + brand.length()] == brand {
      return true
    }
    pos += 1
  }
  false
}

///|
extern "js" fn avif_test_read_dimensions(data : Bytes) -> Int =
  #| (data) => {
  #|   try {
  #|     if (typeof process === "object" && process?.versions?.node) {
  #|       const fs = require("node:fs");
  #|       const os = require("node:os");
  #|       const path = require("node:path");
  #|       const cp = require("node:child_process");
  #|       const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "image-mbt-avif-test-"));
  #|       const input = path.join(tmpdir, "input.avif");
  #|       fs.writeFileSync(input, Buffer.from(data));
  #|       try {
  #|         const out = cp.execFileSync("ffprobe", [
  #|           "-v",
  #|           "error",
  #|           "-show_entries",
  #|           "stream=width,height",
  #|           "-of",
  #|           "csv=p=0",
  #|           input,
  #|         ], {
  #|           encoding: "utf8",
  #|         });
  #|         const parts = out.trim().split(",");
  #|         const width = Number(parts[0] || "0");
  #|         const height = Number(parts[1] || "0");
  #|         return (width << 16) | height;
  #|       } finally {
  #|         fs.rmSync(tmpdir, { recursive: true, force: true });
  #|       }
  #|     }
  #|   } catch (_err) {}
  #|   return 0;
  #| }

///|
test "avif_encode writes loadable avif on js target" {
  let original : ImageData = {
    width: 4,
    height: 4,
    data: b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\xFF\xFF\x00\xFF\xFF\xFF\x80\x40\x20\xFF\x20\x40\x80\xFF\x10\x20\x30\xFF\x30\x20\x10\xFF\x44\x55\x66\xFF\xAA\xBB\xCC\xFF\x55\x66\x77\xFF\x77\x66\x55\xFF\x11\x22\x33\xFF\x33\x22\x11\xFF",
  }
  let avif = encode_avif(original)
  assert_true(avif.length() > 24)
  assert_eq(avif[4].to_int() & 0xFF, 0x66)
  assert_eq(avif[5].to_int() & 0xFF, 0x74)
  assert_eq(avif[6].to_int() & 0xFF, 0x79)
  assert_eq(avif[7].to_int() & 0xFF, 0x70)
  assert_true(avif_bytes_has_brand_for_test(avif, b"avif"))
  let packed = avif_test_read_dimensions(avif)
  assert_eq(packed >> 16, 4)
  assert_eq(packed & 0xFFFF, 4)
}

///|
test "avif_encode rejects transparent pixels in mvp" {
  let img : ImageData = {
    width: 4,
    height: 4,
    data: b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\xFF\x80\x00\xFF\xFF\x80\x80\x40\x20\xFF\x20\x40\x80\xFF\x10\x20\x30\xFF\x30\x20\x10\xFF\x00\x00\x00\x00\xAA\xBB\xCC\xFF\x55\x66\x77\xFF\x77\x66\x55\xFF\x11\x22\x33\xFF\x33\x22\x11\xFF",
  }
  let mut got_error = false
  try {
    let _ = encode_avif(img)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}
