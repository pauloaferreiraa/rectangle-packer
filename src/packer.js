function fit(areaWidth, areaHeight, pieceWidth, pieceHeight) {
  if (pieceWidth <= 0 || pieceHeight <= 0 || areaWidth < pieceWidth || areaHeight < pieceHeight) return 0;
  return Math.floor(areaWidth / pieceWidth) * Math.floor(areaHeight / pieceHeight);
}

function candidateSplits(totalLength, step1, step2) {
  const splits = new Set();
  for (const step of [step1, step2]) {
    for (let m = 1; m * step < totalLength; m++) splits.add(m * step);
  }
  return [...splits].sort((a, b) => a - b);
}

function genPieces(areaWidth, areaHeight, pieceWidth, pieceHeight, band, offsetX = 0, offsetY = 0) {
  const pieces = [];
  const cols = Math.floor(areaWidth / pieceWidth);
  const rows = Math.floor(areaHeight / pieceHeight);
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      pieces.push({
        x: offsetX + col * pieceWidth,
        y: offsetY + row * pieceHeight,
        pieceWidth,
        pieceHeight,
        band,
        gridRow: row,
        gridCol: col
      });
    }
  }
  return pieces;
}

export function pack(outerWidth, outerHeight, innerWidth, innerHeight) {
  const orientations = [[innerWidth, innerHeight], [innerHeight, innerWidth]];
  const hSplits = candidateSplits(outerHeight, innerHeight, innerWidth);
  const vSplits = candidateSplits(outerWidth, innerWidth, innerHeight);

  let best = { count: 0, params: { strategy: 'none' } };
  const consider = (count, params) => { if (count > best.count) best = { count, params }; };

  consider(fit(outerWidth, outerHeight, innerWidth, innerHeight),
    { strategy: 'uniform_a', pieceWidth: innerWidth, pieceHeight: innerHeight });
  consider(fit(outerWidth, outerHeight, innerHeight, innerWidth),
    { strategy: 'uniform_b', pieceWidth: innerHeight, pieceHeight: innerWidth });

  for (const split of hSplits) {
    for (const [pw1, ph1] of orientations) {
      for (const [pw2, ph2] of orientations) {
        consider(
          fit(outerWidth, split, pw1, ph1) + fit(outerWidth, outerHeight - split, pw2, ph2),
          { strategy: 'h_split', split, pw1, ph1, pw2, ph2 }
        );
      }
    }
  }

  for (const split of vSplits) {
    for (const [pw1, ph1] of orientations) {
      for (const [pw2, ph2] of orientations) {
        consider(
          fit(split, outerHeight, pw1, ph1) + fit(outerWidth - split, outerHeight, pw2, ph2),
          { strategy: 'v_split', split, pw1, ph1, pw2, ph2 }
        );
      }
    }
  }

  return buildResult(outerWidth, outerHeight, best.count, best.params);
}

function buildResult(outerWidth, outerHeight, count, params) {
  let pieces = [];
  let splitAt = null;
  let splitAxis = null;

  switch (params.strategy) {
    case 'uniform_a':
    case 'uniform_b':
      pieces = genPieces(outerWidth, outerHeight, params.pieceWidth, params.pieceHeight, 0);
      break;
    case 'h_split':
      pieces = [
        ...genPieces(outerWidth, params.split, params.pw1, params.ph1, 1),
        ...genPieces(outerWidth, outerHeight - params.split, params.pw2, params.ph2, 2, 0, params.split)
      ];
      splitAt = params.split;
      splitAxis = 'h';
      break;
    case 'v_split':
      pieces = [
        ...genPieces(params.split, outerHeight, params.pw1, params.ph1, 1),
        ...genPieces(outerWidth - params.split, outerHeight, params.pw2, params.ph2, 2, params.split, 0)
      ];
      splitAt = params.split;
      splitAxis = 'v';
      break;
  }

  return { count, pieces, strategy: params.strategy, splitAt, splitAxis };
}

// SVG string with cm units for Illustrator download
const MARGIN = 1.0;
const SW = 0.05;
const SW_THIN = 0.03;
const COLOR_BORDER = '#000000';
const COLOR_BAND1 = '#0066CC';
const COLOR_BAND2 = '#CC0000';
const COLOR_SPLIT = '#999999';
const COLOR_DIM = '#666666';
const FONT_PIECE = 0.5;
const FONT_DIM = 0.45;

function f(val) {
  return val % 1 === 0 ? String(Math.round(val)) : parseFloat(val.toFixed(4)).toString();
}

export function generateSvgString(outerWidth, outerHeight, result) {
  const docW = outerWidth + 2 * MARGIN;
  const docH = outerHeight + 2 * MARGIN;
  const lines = [];

  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${f(docW)}cm" height="${f(docH)}cm" viewBox="0 0 ${f(docW)} ${f(docH)}">`);
  lines.push(`<rect x="${f(MARGIN)}" y="${f(MARGIN)}" width="${f(outerWidth)}" height="${f(outerHeight)}" fill="none" stroke="${COLOR_BORDER}" stroke-width="${SW}"/>`);

  for (const piece of result.pieces) {
    const color = piece.band === 2 ? COLOR_BAND2 : COLOR_BAND1;
    const px = MARGIN + piece.x;
    const py = MARGIN + piece.y;
    lines.push(`<rect x="${f(px)}" y="${f(py)}" width="${f(piece.pieceWidth)}" height="${f(piece.pieceHeight)}" fill="none" stroke="${color}" stroke-width="${SW}"/>`);
    if (piece.pieceWidth >= 1.5 && piece.pieceHeight >= 1.0) {
      const label = `${f(piece.pieceWidth)}×${f(piece.pieceHeight)}`;
      const cx = px + piece.pieceWidth / 2;
      const cy = py + piece.pieceHeight / 2;
      lines.push(`<text x="${f(cx)}" y="${f(cy)}" text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size="${FONT_PIECE}" fill="${color}">${label}</text>`);
    }
  }

  if (result.splitAxis && result.splitAt !== null) {
    if (result.splitAxis === 'h') {
      const sy = MARGIN + result.splitAt;
      lines.push(`<line x1="${f(MARGIN)}" y1="${f(sy)}" x2="${f(MARGIN + outerWidth)}" y2="${f(sy)}" stroke="${COLOR_SPLIT}" stroke-width="${SW_THIN}" stroke-dasharray="0.2,0.15"/>`);
    } else {
      const sx = MARGIN + result.splitAt;
      lines.push(`<line x1="${f(sx)}" y1="${f(MARGIN)}" x2="${f(sx)}" y2="${f(MARGIN + outerHeight)}" stroke="${COLOR_SPLIT}" stroke-width="${SW_THIN}" stroke-dasharray="0.2,0.15"/>`);
    }
  }

  const x1 = MARGIN, x2 = MARGIN + outerWidth;
  const yDim = MARGIN + outerHeight + 0.55;
  lines.push(`<line x1="${f(x1)}" y1="${f(yDim)}" x2="${f(x2)}" y2="${f(yDim)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<line x1="${f(x1)}" y1="${f(yDim - 0.2)}" x2="${f(x1)}" y2="${f(yDim + 0.2)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<line x1="${f(x2)}" y1="${f(yDim - 0.2)}" x2="${f(x2)}" y2="${f(yDim + 0.2)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<text x="${f((x1 + x2) / 2)}" y="${f(yDim + 0.35)}" text-anchor="middle" font-family="sans-serif" font-size="${FONT_DIM}" fill="${COLOR_DIM}">${f(outerWidth)} cm</text>`);

  const y1 = MARGIN, y2 = MARGIN + outerHeight;
  const xDim = MARGIN + outerWidth + 0.55;
  const dimCY = (y1 + y2) / 2;
  lines.push(`<line x1="${f(xDim)}" y1="${f(y1)}" x2="${f(xDim)}" y2="${f(y2)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<line x1="${f(xDim - 0.2)}" y1="${f(y1)}" x2="${f(xDim + 0.2)}" y2="${f(y1)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<line x1="${f(xDim - 0.2)}" y1="${f(y2)}" x2="${f(xDim + 0.2)}" y2="${f(y2)}" stroke="${COLOR_DIM}" stroke-width="${SW_THIN}"/>`);
  lines.push(`<text x="${f(xDim + 0.35)}" y="${f(dimCY)}" text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size="${FONT_DIM}" fill="${COLOR_DIM}" transform="rotate(90,${f(xDim + 0.35)},${f(dimCY)})">${f(outerHeight)} cm</text>`);

  lines.push('</svg>');
  return lines.join('\n');
}
