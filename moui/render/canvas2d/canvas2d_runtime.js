// Canvas 2D runtime bridge for WeChat Mini Program Skyline engine.
// This file provides the JavaScript-side implementation of Canvas 2D rendering
// functions that are imported by the MoonBit wasm-gc module.

// Canvas context registry: maps canvas IDs to CanvasRenderingContext2D instances
const canvasContexts = {};

/**
 * Register a canvas element for use by the Canvas 2D renderer.
 * @param {string} canvasId - The canvas element ID.
 * @param {CanvasRenderingContext2D} ctx - The 2D rendering context.
 */
export function canvas2d_register(canvasId, ctx) {
  canvasContexts[canvasId] = ctx;
}

/**
 * Unregister a canvas element.
 * @param {string} canvasId - The canvas element ID.
 */
export function canvas2d_unregister(canvasId) {
  delete canvasContexts[canvasId];
}

/**
 * Render a sequence of DrawCommand objects to the Canvas 2D context.
 * Called from MoonBit via wasm import.
 *
 * @param {string} canvasId - The canvas element ID.
 * @param {Array} commands - Array of DrawCommand objects.
 * @param {number} logicalWidth - Logical canvas width.
 * @param {number} logicalHeight - Logical canvas height.
 * @param {number} scaleFactor - Device pixel ratio.
 */
export function canvas2d_render_commands(canvasId, commands, logicalWidth, logicalHeight, scaleFactor) {
  const ctx = canvasContexts[canvasId];
  if (!ctx) {
    return;
  }

  // Set up the canvas for the frame
  ctx.save();
  ctx.setTransform(scaleFactor, 0, 0, scaleFactor, 0, 0);

  // Process each command
  for (const cmd of commands) {
    applyCommand(ctx, cmd);
  }

  ctx.restore();
}

/**
 * Measure text using Canvas 2D measureText.
 * Called from MoonBit via wasm import.
 *
 * @param {string} text - The text to measure.
 * @param {number} fontSize - Font size in logical pixels.
 * @param {string} fontFamily - Font family name.
 * @param {number} fontWeight - Font weight (400 = normal, 700 = bold).
 * @param {number} fontStyle - Font style (0 = normal, 1 = italic).
 * @returns {{ width: number, height: number }} - Measured text size.
 */
export function canvas2d_measure_text(text, fontSize, fontFamily, fontWeight, fontStyle) {
  // Create an offscreen measurement canvas if needed
  if (!measureCanvas) {
    measureCanvas = createMeasureCanvas();
  }
  const ctx = measureCanvas.getContext('2d');
  const styleStr = fontStyle === 1 ? 'italic ' : '';
  const weightStr = fontWeight >= 700 ? 'bold' : 'normal';
  ctx.font = `${styleStr}${weightStr} ${fontSize}px ${fontFamily}`;
  const metrics = ctx.measureText(text);
  return {
    width: metrics.width,
    height: fontSize * 1.2, // Approximate line height
  };
}

let measureCanvas = null;

function createMeasureCanvas() {
  // In WeChat Mini Program, use wx.createOffscreenCanvas or fallback
  if (typeof wx !== 'undefined' && wx.createOffscreenCanvas) {
    return wx.createOffscreenCanvas({ type: '2d', width: 1, height: 1 });
  }
  // Fallback for browser environment
  if (typeof document !== 'undefined') {
    const canvas = document.createElement('canvas');
    canvas.width = 1;
    canvas.height = 1;
    return canvas;
  }
  return null;
}

function applyCommand(ctx, cmd) {
  const tag = cmd.tag || cmd[0];
  const args = cmd.args || cmd.slice(1);

  switch (tag) {
    case 'Clear':
      applyClear(ctx, args);
      break;
    case 'FillRect':
      applyFillRect(ctx, args);
      break;
    case 'StrokeRect':
      applyStrokeRect(ctx, args);
      break;
    case 'FillRoundedRect':
      applyFillRoundedRect(ctx, args);
      break;
    case 'StrokeRoundedRect':
      applyStrokeRoundedRect(ctx, args);
      break;
    case 'DrawText':
      applyDrawText(ctx, args);
      break;
    case 'DrawImage':
      applyDrawImage(ctx, args);
      break;
    case 'PushClip':
      applyPushClip(ctx, args);
      break;
    case 'PopClip':
      applyPopClip(ctx);
      break;
    case 'PushRoundedClip':
      applyPushRoundedClip(ctx, args);
      break;
    case 'PopRoundedClip':
      applyPopRoundedClip(ctx);
      break;
    case 'PushTransform':
      applyPushTransform(ctx, args);
      break;
    case 'PopTransform':
      applyPopTransform(ctx);
      break;
    case 'PushOpacity':
      applyPushOpacity(ctx, args);
      break;
    case 'PopOpacity':
      applyPopOpacity(ctx);
      break;
    case 'PushLayer':
      applyPushLayer(ctx, args);
      break;
    case 'PopLayer':
      applyPopLayer(ctx);
      break;
    case 'DrawPath':
      applyDrawPath(ctx, args);
      break;
    case 'DrawShadow':
      applyDrawShadow(ctx, args);
      break;
    case 'DrawShaderEffect':
      applyDrawShaderEffect(ctx, args);
      break;
    case 'PushFilter':
      applyPushFilter(ctx, args);
      break;
    case 'PopFilter':
      applyPopFilter(ctx);
      break;
    case 'BeginCachedLayer':
    case 'EndCachedLayer':
    case 'DrawCachedLayer':
      // Cached layers are handled at the host layer level
      break;
    default:
      // Unknown command — skip
      break;
  }
}

function applyClear(ctx, args) {
  const [r, g, b, a] = args;
  ctx.fillStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
}

function applyFillRect(ctx, args) {
  const [x, y, w, h, r, g, b, a] = args;
  ctx.fillStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.fillRect(x, y, w, h);
}

function applyStrokeRect(ctx, args) {
  const [x, y, w, h, r, g, b, a, strokeWidth] = args;
  ctx.strokeStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.lineWidth = strokeWidth;
  ctx.strokeRect(x, y, w, h);
}

function applyFillRoundedRect(ctx, args) {
  const [x, y, w, h, radius, r, g, b, a] = args;
  ctx.fillStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  roundRect(ctx, x, y, w, h, radius);
  ctx.fill();
}

function applyStrokeRoundedRect(ctx, args) {
  const [x, y, w, h, radius, r, g, b, a, strokeWidth] = args;
  ctx.strokeStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.lineWidth = strokeWidth;
  roundRect(ctx, x, y, w, h, radius);
  ctx.stroke();
}

function applyDrawText(ctx, args) {
  const [text, x, y, r, g, b, a, fontSize, fontFamily, fontWeight, fontStyle] = args;
  const styleStr = fontStyle === 1 ? 'italic ' : '';
  const weightStr = fontWeight >= 700 ? 'bold' : 'normal';
  ctx.font = `${styleStr}${weightStr} ${fontSize}px ${fontFamily}`;
  ctx.fillStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.fillText(text, x, y);
}

function applyDrawImage(ctx, args) {
  const [imageId, sx, sy, sw, sh, dx, dy, dw, dh] = args;
  const image = getImageById(imageId);
  if (image) {
    ctx.drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh);
  }
}

function applyPushClip(ctx, args) {
  const [x, y, w, h] = args;
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, w, h);
  ctx.clip();
}

function applyPopClip(ctx) {
  ctx.restore();
}

function applyPushRoundedClip(ctx, args) {
  const [x, y, w, h, radius] = args;
  ctx.save();
  roundRect(ctx, x, y, w, h, radius);
  ctx.clip();
}

function applyPopRoundedClip(ctx) {
  ctx.restore();
}

function applyPushTransform(ctx, args) {
  const [a, b, c, d, tx, ty] = args;
  ctx.save();
  ctx.transform(a, b, c, d, tx, ty);
}

function applyPopTransform(ctx) {
  ctx.restore();
}

function applyPushOpacity(ctx, args) {
  const [opacity] = args;
  ctx.save();
  ctx.globalAlpha = ctx.globalAlpha * opacity;
}

function applyPopOpacity(ctx) {
  ctx.restore();
}

function applyPushLayer(ctx, args) {
  const [opacity, blendMode] = args;
  ctx.save();
  if (opacity !== undefined) {
    ctx.globalAlpha = opacity;
  }
  if (blendMode !== undefined) {
    ctx.globalCompositeOperation = blendMode;
  }
}

function applyPopLayer(ctx) {
  ctx.restore();
}

function applyDrawPath(ctx, args) {
  const [pathCommands, r, g, b, a, strokeWidth, fillMode] = args;
  ctx.beginPath();
  for (const pathCmd of pathCommands) {
    applyPathCommand(ctx, pathCmd);
  }
  if (fillMode === 0 || fillMode === 2) { // Fill or FillAndStroke
    ctx.fillStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
    ctx.fill();
  }
  if (fillMode === 1 || fillMode === 2) { // Stroke or FillAndStroke
    ctx.strokeStyle = `rgba(${r*255},${g*255},${b*255},${a})`;
    ctx.lineWidth = strokeWidth;
    ctx.stroke();
  }
}

function applyPathCommand(ctx, cmd) {
  const [verb, ...args] = cmd;
  switch (verb) {
    case 'MoveTo':
      ctx.moveTo(args[0], args[1]);
      break;
    case 'LineTo':
      ctx.lineTo(args[0], args[1]);
      break;
    case 'QuadTo':
      ctx.quadraticCurveTo(args[0], args[1], args[2], args[3]);
      break;
    case 'CubicTo':
      ctx.bezierCurveTo(args[0], args[1], args[2], args[3], args[4], args[5]);
      break;
    case 'Arc':
      ctx.arc(args[0], args[1], args[2], args[3], args[4]);
      break;
    case 'Close':
      ctx.closePath();
      break;
  }
}

function applyDrawShadow(ctx, args) {
  const [x, y, w, h, radius, r, g, b, a, blur, offsetX, offsetY, spread] = args;
  ctx.save();
  ctx.shadowColor = `rgba(${r*255},${g*255},${b*255},${a})`;
  ctx.shadowBlur = blur;
  ctx.shadowOffsetX = offsetX;
  ctx.shadowOffsetY = offsetY;
  // Apply spread by adjusting the shadow shape
  const adjustedX = x - spread;
  const adjustedY = y - spread;
  const adjustedW = w + spread * 2;
  const adjustedH = h + spread * 2;
  roundRect(ctx, adjustedX, adjustedY, adjustedW, adjustedH, radius);
  ctx.fill();
  ctx.restore();
}

function applyDrawShaderEffect(ctx, args) {
  const [effectName, effectArgs, x, y, w, h] = args;
  switch (effectName) {
    case 'checker':
      drawChecker(ctx, x, y, w, h, effectArgs);
      break;
    case 'vignette':
      drawVignette(ctx, x, y, w, h, effectArgs);
      break;
    default:
      // Fallback: draw solid color
      ctx.fillStyle = '#ccc';
      ctx.fillRect(x, y, w, h);
      break;
  }
}

function applyPushFilter(ctx, args) {
  const [filterType, filterArgs] = args;
  ctx.save();
  switch (filterType) {
    case 'blur':
      ctx.filter = `blur(${filterArgs[0]}px)`;
      break;
    case 'saturate':
      ctx.filter = `saturate(${filterArgs[0]})`;
      break;
    case 'brightness':
      ctx.filter = `brightness(${filterArgs[0]})`;
      break;
    case 'contrast':
      ctx.filter = `contrast(${filterArgs[0]})`;
      break;
    default:
      break;
  }
}

function applyPopFilter(ctx) {
  ctx.restore();
}

function roundRect(ctx, x, y, w, h, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.arcTo(x + w, y, x + w, y + radius, radius);
  ctx.lineTo(x + w, y + h - radius);
  ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
  ctx.lineTo(x + radius, y + h);
  ctx.arcTo(x, y + h, x, y + h - radius, radius);
  ctx.lineTo(x, y + radius);
  ctx.arcTo(x, y, x + radius, y, radius);
  ctx.closePath();
}

// Image cache for drawImage
const imageCache = {};

function getImageById(imageId) {
  return imageCache[imageId] || null;
}

export function canvas2d_setImage(imageId, image) {
  imageCache[imageId] = image;
}

export function canvas2d_removeImage(imageId) {
  delete imageCache[imageId];
}

function drawChecker(ctx, x, y, w, h, args) {
  const [size, color1_r, color1_g, color1_b, color2_r, color2_g, color2_b] = args;
  const cols = Math.ceil(w / size);
  const rows = Math.ceil(h / size);
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const isEven = (row + col) % 2 === 0;
      ctx.fillStyle = isEven
        ? `rgb(${color1_r},${color1_g},${color1_b})`
        : `rgb(${color2_r},${color2_g},${color2_b})`;
      ctx.fillRect(x + col * size, y + row * size, size, size);
    }
  }
}

function drawVignette(ctx, x, y, w, h, args) {
  const [innerRadius, outerRadius, r, g, b, a] = args;
  const cx = x + w / 2;
  const cy = y + h / 2;
  // Simple vignette: draw concentric circles with decreasing opacity
  const steps = 20;
  for (let i = 0; i < steps; i++) {
    const t = i / steps;
    const radius = innerRadius + (outerRadius - innerRadius) * t;
    const alpha = a * (1 - t);
    ctx.fillStyle = `rgba(${r},${g},${b},${alpha})`;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();
  }
}