# mizchi/image

Image codec primitives for MoonBit. Core codecs have no external dependencies except `mizchi/zlib`; the AVIF js-target MVP uses browser AVIF canvas support or local `ffmpeg`.

## Features

- **PNG** decode / encode (RGBA8, adaptive row filtering)
- **BMP** decode / encode
- **JPEG** baseline decode / encode
- **GIF** encode (single-frame, indexed palette, binary transparency)
- **WebP** lossless encode (still image)
- **ICO** encode (single-image, PNG payload)
- **AVIF** encode (js target MVP, opaque still image)
- **Resize** with Nearest / Bilinear / Bicubic interpolation

All decoded images are normalized to `ImageData` (RGBA8 buffer).

## Install

```bash
moon add mizchi/image
```

## Usage

```moonbit
// PNG decode → resize → encode
let img = @image.decode_png(png_bytes)
let resized = @image.resize(img, 128, 128, Bilinear)
let out = @image.encode_png(resized)

// JPEG encode (quality defaults to 85)
let jpg = @image.encode_jpeg(resized)

// GIF encode (<= 256 colors, alpha 0/255 only)
let gif = @image.encode_gif(resized)

// WebP lossless encode
let webp = @image.encode_webp(resized)

// ICO encode (single PNG-backed icon, <= 256x256)
let ico = @image.encode_ico(resized)

// AVIF encode (js target MVP, opaque images only)
let avif = @image.encode_avif(resized)

// Stream decode (PNG/BMP auto detect)
let rows : Array[Bytes] = []
let info = @image.decode_image_stream(
  image_bytes,
  on_row=fn(_y, row) { rows.push(row) },
)
inspect((info.format, info.width, info.height))
```

## API

```
pub fn decode_png(Bytes) -> ImageData raise DecodeError
pub fn decode_png_stream(Bytes, on_row~ : (Int, Bytes) -> Unit) -> IhdrData raise DecodeError
pub fn decode_image_stream(Bytes, on_row~ : (Int, Bytes) -> Unit) -> StreamImageInfo raise DecodeError
pub fn encode_png(ImageData) -> Bytes raise EncodeError
pub fn decode_bmp(Bytes) -> ImageData raise DecodeError
pub fn decode_bmp_stream(Bytes, on_row~ : (Int, Bytes) -> Unit) -> (Int, Int) raise DecodeError
pub fn encode_bmp(ImageData) -> Bytes raise EncodeError
pub fn decode_jpeg(Bytes) -> ImageData raise DecodeError
pub fn encode_jpeg(ImageData, quality? : Int = 85) -> Bytes raise EncodeError
pub fn encode_gif(ImageData) -> Bytes raise EncodeError
pub fn encode_webp(ImageData) -> Bytes raise EncodeError
pub fn encode_ico(ImageData) -> Bytes raise EncodeError
pub fn encode_avif(ImageData) -> Bytes raise EncodeError
pub fn resize(ImageData, Int, Int, ResizeMethod) -> ImageData raise EncodeError
```

### Types

```
pub(all) struct ImageData { width : Int; height : Int; data : Bytes }
pub(all) enum ResizeMethod { Nearest; Bilinear; Bicubic }
```

## Support

| Feature | Decode | Encode | Targets | Notes |
|---|---|---|---|---|
| PNG | yes | yes | `js` / `native` / `wasm-gc` | RGBA8 normalize, stream decode |
| BMP | yes | yes | `js` / `native` / `wasm-gc` | decode: 24/32-bit, encode: 32-bit BGRA |
| JPEG | yes | yes | `js` / `native` / `wasm-gc` | baseline only |
| GIF | no | yes | `js` / `native` / `wasm-gc` | single-frame, `<=256` colors, alpha `0/255` only |
| WebP | no | yes | `js` / `native` / `wasm-gc` | lossless still-image encoder |
| ICO | no | yes | `js` / `native` / `wasm-gc` | single PNG payload, `<=256x256` |
| AVIF | no | yes | `js` | opaque images only, requires browser AVIF canvas support or local `ffmpeg` |
| Resize | n/a | n/a | `js` / `native` / `wasm-gc` | Nearest / Bilinear / Bicubic |

## License

Apache-2.0
