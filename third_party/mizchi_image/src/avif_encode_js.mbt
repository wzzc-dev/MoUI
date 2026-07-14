///|

///|
fn image_has_non_opaque_alpha(img : ImageData) -> Bool {
  let pixel_count = img.width * img.height
  for i in 0..<pixel_count {
    if (img.data[i * 4 + 3].to_int() & 0xFF) != 0xFF {
      return true
    }
  }
  false
}

///|
extern "js" fn ffi_encode_avif_js(
  width : Int,
  height : Int,
  rgba : Bytes,
  png : Bytes,
) -> Bytes =
  #| (width, height, rgba, png) => {
  #|   const empty = new Uint8Array(0);
  #|   const decodeBase64 = (base64) => {
  #|     if (typeof Buffer !== "undefined") {
  #|       return new Uint8Array(Buffer.from(base64, "base64"));
  #|     }
  #|     if (typeof atob === "function") {
  #|       const binary = atob(base64);
  #|       const out = new Uint8Array(binary.length);
  #|       for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  #|       return out;
  #|     }
  #|     return empty;
  #|   };
  #|   try {
  #|     if (typeof document === "object" && typeof ImageData !== "undefined") {
  #|       const canvas = document.createElement("canvas");
  #|       canvas.width = width;
  #|       canvas.height = height;
  #|       const ctx = canvas.getContext("2d");
  #|       if (!ctx) return empty;
  #|       const image = new ImageData(new Uint8ClampedArray(rgba), width, height);
  #|       ctx.putImageData(image, 0, 0);
  #|       const url = canvas.toDataURL("image/avif");
  #|       if (typeof url !== "string" || !url.startsWith("data:image/avif")) {
  #|         return empty;
  #|       }
  #|       const comma = url.indexOf(",");
  #|       if (comma < 0) return empty;
  #|       return decodeBase64(url.slice(comma + 1));
  #|     }
  #|     if (typeof process === "object" && process?.versions?.node) {
  #|       const fs = require("node:fs");
  #|       const os = require("node:os");
  #|       const path = require("node:path");
  #|       const cp = require("node:child_process");
  #|       const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "image-mbt-avif-"));
  #|       const input = path.join(tmpdir, "input.png");
  #|       const output = path.join(tmpdir, "output.avif");
  #|       fs.writeFileSync(input, Buffer.from(png));
  #|       try {
  #|         cp.execFileSync("ffmpeg", [
  #|           "-y",
  #|           "-i",
  #|           input,
  #|           "-pix_fmt",
  #|           "yuv444p",
  #|           output,
  #|         ], {
  #|           stdio: "pipe",
  #|         });
  #|         if (!fs.existsSync(output)) return empty;
  #|         return new Uint8Array(fs.readFileSync(output));
  #|       } finally {
  #|         fs.rmSync(tmpdir, { recursive: true, force: true });
  #|       }
  #|     }
  #|   } catch (_err) {}
  #|   return empty;
  #| }

///|
pub fn encode_avif(img : ImageData) -> Bytes raise EncodeError {
  validate_rgba8_image(img)
  if image_has_non_opaque_alpha(img) {
    raise InvalidData("AVIF js MVP currently only supports opaque images")
  }
  let png = encode_png(img)
  let avif = ffi_encode_avif_js(img.width, img.height, img.data, png)
  if avif.is_empty() {
    raise InvalidData(
      "AVIF encoding failed on js target: requires browser canvas AVIF support or ffmpeg",
    )
  }
  avif
}
