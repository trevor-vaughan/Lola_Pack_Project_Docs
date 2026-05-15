// Validate a complete mermaid theme against legibility constraints.
//
// Constraints checked:
//   1. Every node fill clears 4.5:1 against its paired node text     (AA text)
//   2. Every node fill clears 3:1   against #ffffff (light bg)        (graphical)
//   3. Every node fill clears 3:1   against #1e1e1e (dark bg)         (graphical)
//   4. Cluster fill clears 4.5:1 against cluster title text           (AA text)
//   5. Cluster fill is distinguishable from every node fill (Δ ≥ 1.5:1)
//   6. Text-on-canvas (chart titles, axes) clears 4.5:1 against BOTH bgs
//   7. Edge label text clears 4.5:1 against edge label background
//   8. Cluster border clears 3:1 against BOTH bgs (visible on either page color)
//
// Usage: node validate-palette.mjs <palette.json>

import { contrastRatio } from './contrast.mjs';
import { readFileSync } from 'node:fs';

const LIGHT = '#ffffff';
const DARK = '#1e1e1e';
const TEXT_AA = 4.5;          // text inside a node (small label)
const TEXT_AA_LARGE = 3.0;    // chart titles, cluster headers (typically ≥18pt or ≥14pt bold)
const GRAPH_AA = 3.0;         // graphical objects vs background
const FILL_DELTA_MIN = 1.5;

function check(label, ratio, threshold) {
  const pass = ratio >= threshold;
  const mark = pass ? 'PASS' : 'FAIL';
  return { label, ratio: ratio.toFixed(2), threshold, pass, line: `  [${mark}] ${label}: ${ratio.toFixed(2)}:1 (need ≥ ${threshold}:1)` };
}

export function validate(palette) {
  const results = [];
  const mode = palette.mode || 'both'; // 'both' | 'light' | 'dark'
  const checkLight = mode === 'both' || mode === 'light';
  const checkDark  = mode === 'both' || mode === 'dark';

  // 1. Node fill vs node text (AA)
  for (const [name, def] of Object.entries(palette.nodes)) {
    results.push(check(`node.${name} text vs fill`, contrastRatio(def.fill, def.text), TEXT_AA));
  }

  // 2-3. Node fill vs page bg (graphical)
  for (const [name, def] of Object.entries(palette.nodes)) {
    if (checkLight) results.push(check(`node.${name} fill vs light bg`, contrastRatio(def.fill, LIGHT), GRAPH_AA));
    if (checkDark)  results.push(check(`node.${name} fill vs dark bg`,  contrastRatio(def.fill, DARK),  GRAPH_AA));
  }

  // 4. Cluster fill vs cluster title text (AA Large — cluster headers are typically rendered large)
  if (palette.cluster.fill !== 'transparent') {
    results.push(check('cluster title vs cluster fill', contrastRatio(palette.cluster.fill, palette.cluster.title), TEXT_AA_LARGE));
  } else {
    // For transparent clusters, title sits on the page bg.
    if (checkLight) results.push(check('cluster title vs light bg', contrastRatio(palette.cluster.title, LIGHT), TEXT_AA_LARGE));
    if (checkDark)  results.push(check('cluster title vs dark bg',  contrastRatio(palette.cluster.title, DARK),  TEXT_AA_LARGE));
  }

  // 5. Cluster fill ≠ any node fill (visual differentiation)
  if (palette.cluster.fill !== 'transparent') {
    for (const [name, def] of Object.entries(palette.nodes)) {
      results.push(check(`cluster fill vs node.${name} fill`, contrastRatio(palette.cluster.fill, def.fill), FILL_DELTA_MIN));
    }
  }

  // 6. Text-on-canvas (titles, axis labels) — AA Large
  if (checkLight) results.push(check('canvas text vs light bg', contrastRatio(palette.canvasText, LIGHT), TEXT_AA_LARGE));
  if (checkDark)  results.push(check('canvas text vs dark bg',  contrastRatio(palette.canvasText, DARK),  TEXT_AA_LARGE));

  // 7. Edge label
  results.push(check('edge label text vs edge label bg', contrastRatio(palette.edgeLabel.text, palette.edgeLabel.bg), TEXT_AA));

  // 8. Cluster border visible on enforced bgs
  if (checkLight) results.push(check('cluster border vs light bg', contrastRatio(palette.cluster.border, LIGHT), GRAPH_AA));
  if (checkDark)  results.push(check('cluster border vs dark bg',  contrastRatio(palette.cluster.border, DARK),  GRAPH_AA));

  return results;
}

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('usage: validate-palette.mjs <palette.json>');
    process.exit(2);
  }
  const palette = JSON.parse(readFileSync(file, 'utf8'));
  console.log(`\n=== ${palette.name} ===`);
  if (palette.description) console.log(palette.description);
  const results = validate(palette);
  for (const r of results) console.log(r.line);
  const fails = results.filter(r => !r.pass);
  console.log(`\n${results.length - fails.length}/${results.length} checks passed`);
  if (fails.length) process.exit(1);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
