import { inflateSync } from "node:zlib";

const paeth = (a, b, c) => {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
};

export const decodePng8 = buffer => {
  if (buffer.toString("ascii", 1, 4) !== "PNG") {
    throw new Error("screenshot is not a PNG");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idat = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    const data = buffer.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4;
  }

  if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
    throw new Error(`unsupported PNG screenshot format bitDepth=${bitDepth} colorType=${colorType}`);
  }

  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = inflateSync(Buffer.concat(idat));
  const pixels = Buffer.alloc(width * height * 4);
  let rawOffset = 0;
  const previous = Buffer.alloc(stride);
  const current = Buffer.alloc(stride);

  for (let y = 0; y < height; y += 1) {
    const filter = raw[rawOffset];
    rawOffset += 1;
    raw.copy(current, 0, rawOffset, rawOffset + stride);
    rawOffset += stride;

    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? current[x - channels] : 0;
      const up = previous[x];
      const upLeft = x >= channels ? previous[x - channels] : 0;
      if (filter === 1) {
        current[x] = (current[x] + left) & 0xff;
      } else if (filter === 2) {
        current[x] = (current[x] + up) & 0xff;
      } else if (filter === 3) {
        current[x] = (current[x] + Math.floor((left + up) / 2)) & 0xff;
      } else if (filter === 4) {
        current[x] = (current[x] + paeth(left, up, upLeft)) & 0xff;
      } else if (filter !== 0) {
        throw new Error(`unsupported PNG filter ${filter}`);
      }
    }

    for (let x = 0; x < width; x += 1) {
      const src = x * channels;
      const dst = (y * width + x) * 4;
      pixels[dst] = current[src];
      pixels[dst + 1] = current[src + 1];
      pixels[dst + 2] = current[src + 2];
      pixels[dst + 3] = channels === 4 ? current[src + 3] : 255;
    }

    current.copy(previous);
  }

  return { width, height, data: pixels };
};
