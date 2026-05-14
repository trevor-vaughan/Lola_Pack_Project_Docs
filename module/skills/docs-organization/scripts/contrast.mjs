// WCAG 2.1 contrast ratio math.
// References: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
//             https://www.w3.org/TR/WCAG21/#dfn-relative-luminance

export function parseHex(hex) {
  if (typeof hex !== 'string') throw new Error(`not a string: ${hex}`);
  const m = /^#([0-9a-f]{6}|[0-9a-f]{3})$/i.exec(hex);
  if (!m) throw new Error(`malformed hex: ${hex}`);
  const h = m[1];
  if (h.length === 3) {
    return {
      r: parseInt(h[0] + h[0], 16),
      g: parseInt(h[1] + h[1], 16),
      b: parseInt(h[2] + h[2], 16),
    };
  }
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  };
}

function channelLuminance(c) {
  const v = c / 255;
  return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

export function relativeLuminance({ r, g, b }) {
  return 0.2126 * channelLuminance(r)
    + 0.7152 * channelLuminance(g)
    + 0.0722 * channelLuminance(b);
}

export function contrastRatio(hexA, hexB) {
  const La = relativeLuminance(parseHex(hexA));
  const Lb = relativeLuminance(parseHex(hexB));
  const lighter = Math.max(La, Lb);
  const darker = Math.min(La, Lb);
  return (lighter + 0.05) / (darker + 0.05);
}
