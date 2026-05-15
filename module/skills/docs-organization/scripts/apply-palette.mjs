// Given a palette JSON (one of the four shipped under
// reference/palettes/) and a mermaid source body (no init header, no
// classDefs), emit a full mermaid diagram with the init header +
// classDefs filled in for the chosen palette.
//
// Usage: node apply-palette.mjs <palette.json> <body.mmd> > <output.mmd>
//
// The body should reference sysA..sysF via the standard classDef names
// (`:::sysX` or `class X sysY`). The script appends classDef lines only
// for the names the body actually references — diagram types that don't
// support classDef (sequence, ER, journey, gantt, pie) get nothing
// appended and stay parseable.

import { readFileSync } from 'node:fs';

export function initHeader(palette) {
  // primaryTextColor is the EDGE-LABEL / CHART-TITLE color. Setting it to
  // the node text color (white) makes axis labels and chart titles vanish
  // on light backgrounds; setting it dark fixes that but makes default
  // node text dark too. We resolve that with a small themeCSS rule that
  // forces `.node .nodeLabel` to white, so any node without an explicit
  // classDef still gets white text on its palette fill.
  //
  // Per-diagram-type variables (pie*, git*, cScale*, entity*, etc.) are
  // set explicitly because mermaid's per-type theming pipelines ignore
  // most of the cluster/edge-label variables.
  const n = palette.nodes;
  const tw = n.sysA.text;
  const fills = [n.sysA.fill, n.sysB.fill, n.sysC.fill, n.sysD.fill, n.sysE.fill, n.sysF.fill];
  const themeCSS = `.node .nodeLabel{color:${tw}!important;fill:${tw}!important;}`;
  return [
    "%%{init: {'theme': 'base', 'themeVariables': {",
    `  'primaryColor': '${n.sysA.fill}',`,
    `  'primaryTextColor': '${palette.edgeLabel.text}',`,
    `  'primaryBorderColor': '${palette.cluster.border}',`,
    `  'lineColor': '${palette.cluster.border}',`,
    `  'edgeLabelBackground': '${palette.edgeLabel.bg}',`,
    `  'tertiaryColor': '${palette.cluster.fill}',`,
    `  'tertiaryTextColor': '${palette.canvasText}',`,
    `  'tertiaryBorderColor': '${palette.cluster.border}',`,
    `  'clusterBkg': '${palette.cluster.fill}',`,
    `  'clusterBorder': '${palette.cluster.border}',`,
    `  'titleColor': '${palette.canvasText}',`,
    `  'noteBkgColor': '${palette.edgeLabel.bg}',`,
    `  'noteTextColor': '${palette.edgeLabel.text}',`,
    `  'attributeBackgroundColorOdd': '${palette.edgeLabel.bg}',`,
    `  'attributeBackgroundColorEven': '#ffffff',`,
    `  'relationLabelColor': '${palette.edgeLabel.text}',`,
    `  'relationLabelBackground': '${palette.edgeLabel.bg}',`,
    `  'entityFillColor': '${n.sysA.fill}',`,
    `  'entityHeaderTextColor': '${n.sysA.text}',`,
    `  'entityHeaderColor': '${n.sysA.fill}',`,
    `  'altBackground': '${palette.edgeLabel.bg}',`,
    `  'pie1': '${fills[0]}','pie2': '${fills[1]}','pie3': '${fills[2]}',`,
    `  'pie4': '${fills[3]}','pie5': '${fills[4]}','pie6': '${fills[5]}',`,
    `  'pie7': '${fills[0]}','pie8': '${fills[1]}','pie9': '${fills[2]}',`,
    `  'pie10': '${fills[3]}','pie11': '${fills[4]}','pie12': '${fills[5]}',`,
    `  'pieSectionTextColor': '${tw}',`,
    `  'pieTitleTextColor': '${palette.canvasText}',`,
    `  'pieLegendTextColor': '${palette.canvasText}',`,
    `  'pieStrokeColor': '${palette.cluster.border}',`,
    `  'pieOuterStrokeColor': '${palette.cluster.border}',`,
    `  'git0': '${fills[0]}','git1': '${fills[1]}','git2': '${fills[2]}',`,
    `  'git3': '${fills[3]}','git4': '${fills[4]}','git5': '${fills[5]}',`,
    `  'git6': '${fills[0]}','git7': '${fills[1]}',`,
    `  'gitBranchLabel0': '${tw}','gitBranchLabel1': '${tw}','gitBranchLabel2': '${tw}',`,
    `  'gitBranchLabel3': '${tw}','gitBranchLabel4': '${tw}','gitBranchLabel5': '${tw}',`,
    `  'cScale0': '${fills[0]}','cScale1': '${fills[1]}','cScale2': '${fills[2]}',`,
    `  'cScale3': '${fills[3]}','cScale4': '${fills[4]}','cScale5': '${fills[5]}',`,
    `  'cScaleLabel0': '${tw}','cScaleLabel1': '${tw}','cScaleLabel2': '${tw}',`,
    `  'cScaleLabel3': '${tw}','cScaleLabel4': '${tw}','cScaleLabel5': '${tw}',`,
    `  'xyChart': {`,
    `    'plotColorPalette': '${fills.join(',')}',`,
    `    'titleColor': '${palette.canvasText}',`,
    `    'xAxisLabelColor': '${palette.canvasText}',`,
    `    'yAxisLabelColor': '${palette.canvasText}',`,
    `    'xAxisTitleColor': '${palette.canvasText}',`,
    `    'yAxisTitleColor': '${palette.canvasText}',`,
    `    'xAxisLineColor': '${palette.cluster.border}',`,
    `    'yAxisLineColor': '${palette.cluster.border}'`,
    `  },`,
    `  'fontFamily': 'system-ui, sans-serif'`,
    `}, 'themeCSS': '${themeCSS}'}}%%`,
  ].join('\n');
}

export function classDefs(palette, body) {
  const referenced = new Set();
  for (const name of Object.keys(palette.nodes)) {
    const inline = new RegExp(`:::${name}\\b`);
    const declared = new RegExp(`\\bclass\\s+[^\\n]+\\s+${name}\\b`);
    if (inline.test(body) || declared.test(body)) referenced.add(name);
  }
  if (referenced.size === 0) return '';
  const lines = [];
  for (const name of referenced) {
    const def = palette.nodes[name];
    lines.push(`  classDef ${name} fill:${def.fill},color:${def.text},stroke:${palette.cluster.border}`);
  }
  return lines.join('\n');
}

export function applyPalette(palette, body) {
  const trimmed = body.trimEnd();
  const defs = classDefs(palette, trimmed);
  return defs ? `${initHeader(palette)}\n${trimmed}\n${defs}\n` : `${initHeader(palette)}\n${trimmed}\n`;
}

function main() {
  const [paletteFile, bodyFile] = process.argv.slice(2);
  if (!paletteFile || !bodyFile) {
    console.error('usage: apply-palette.mjs <palette.json> <body.mmd>');
    process.exit(2);
  }
  const palette = JSON.parse(readFileSync(paletteFile, 'utf8'));
  const body = readFileSync(bodyFile, 'utf8');
  process.stdout.write(applyPalette(palette, body));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
