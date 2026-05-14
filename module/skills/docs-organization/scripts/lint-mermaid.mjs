import { contrastRatio } from './contrast.mjs';
import { readFileSync, statSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const LIGHT_BG = '#ffffff';
const DARK_BG = '#1e1e1e';
const APPROVED_CLASSNAMES = new Set([
  'sysA', 'sysB', 'sysC', 'sysD', 'sysE', 'sysF', 'edgeLabel',
]);
// LLM-configuration files describe agent behavior, not the project, and
// are excluded from documentation audits per docs-organization SKILL.md
// ("Scope of audit"). Applies to directory traversal only — an explicit
// file argument is still honored.
const LLM_CONFIG_BASENAMES = new Set([
  'CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.cursorrules',
]);
const CONTRAST_TEXT = 4.5;   // WCAG AA for text
const CONTRAST_BG = 3.0;     // WCAG threshold for non-text graphical objects

// Lazy-load merval. When the pack is installed into someone's AI assistant
// via `lola install`, node_modules/ won't be present until they run
// `npm install` in the scripts directory. Return null in that case so the
// caller can emit a helpful error instead of crashing on import.
let _validateMermaid;
async function getValidateMermaid() {
  if (_validateMermaid !== undefined) return _validateMermaid;
  try {
    const mod = await import('@aj-archipelago/merval');
    _validateMermaid = mod.validateMermaid;
  } catch {
    _validateMermaid = null;
  }
  return _validateMermaid;
}

function scriptsDir() {
  return dirname(fileURLToPath(import.meta.url));
}

export function extractInitBlock(source) {
  const m = /%%\{\s*init\s*:\s*([\s\S]*?)\}%%/.exec(source);
  return m ? m[0] : null;
}

export function extractClassDefs(source) {
  const out = [];
  const re = /^\s*classDef\s+(\w+)[ \t]+(.+)$/gm;
  let m;
  while ((m = re.exec(source)) !== null) {
    const name = m[1];
    const body = m[2];
    const fill = /fill:\s*(#[0-9a-fA-F]+)/.exec(body)?.[1] ?? null;
    const color = /color:\s*(#[0-9a-fA-F]+)/.exec(body)?.[1] ?? null;
    out.push({ name, fill, color });
  }
  return out;
}

export async function lintDiagram(source) {
  const findings = [];

  const validateMermaid = await getValidateMermaid();
  if (!validateMermaid) {
    findings.push({
      code: 'MERVAL_NOT_INSTALLED',
      severity: 'blocker',
      message:
        'The merval package is required but not installed. From the ' +
        `docs-organization scripts directory (${scriptsDir()}) run: ` +
        'npm install',
    });
    return findings;
  }

  const v = validateMermaid(source);
  if (!v.isValid) {
    const err = v.errors?.[0];
    if (!err) {
      findings.push({
        code: 'SYNTAX_ERROR',
        severity: 'blocker',
        message: 'Diagram failed validation (no error details available).',
      });
      return findings;
    }
    findings.push({
      code: 'SYNTAX_ERROR',
      severity: 'blocker',
      line: err.line,
      column: err.column,
      message: err.message,
      suggestion: err.suggestion,
    });
    return findings;
  }

  if (!extractInitBlock(source)) {
    findings.push({
      code: 'MISSING_HOUSE_STYLE_HEADER',
      severity: 'blocker',
      message:
        'Diagram is missing the %%{init}%% house-style header. See ' +
        'module/skills/docs-organization/reference/mermaid-house-style.md.',
    });
  }

  for (const def of extractClassDefs(source)) {
    if (!APPROVED_CLASSNAMES.has(def.name)) {
      findings.push({
        code: 'UNAPPROVED_CLASSNAME',
        severity: 'warning',
        message:
          `classDef "${def.name}" is not in the approved set. ` +
          `Use one of: ${[...APPROVED_CLASSNAMES].join(', ')}.`,
      });
      continue;
    }

    if (def.fill && def.color) {
      const textVsFill = contrastRatio(def.fill, def.color);
      if (textVsFill < CONTRAST_TEXT) {
        findings.push({
          code: 'LOW_CONTRAST_TEXT',
          severity: 'blocker',
          message:
            `classDef "${def.name}": text ${def.color} on fill ${def.fill} ` +
            `is ${textVsFill.toFixed(2)}:1 — needs >= ${CONTRAST_TEXT}:1 (AA).`,
        });
      }
    }

    if (def.fill) {
      const fillVsLight = contrastRatio(def.fill, LIGHT_BG);
      const fillVsDark = contrastRatio(def.fill, DARK_BG);
      if (fillVsLight < CONTRAST_BG) {
        findings.push({
          code: 'LOW_CONTRAST_LIGHT_BG',
          severity: 'blocker',
          message:
            `classDef "${def.name}": fill ${def.fill} vs light bg ${LIGHT_BG} ` +
            `is ${fillVsLight.toFixed(2)}:1 — needs >= ${CONTRAST_BG}:1.`,
        });
      }
      if (fillVsDark < CONTRAST_BG) {
        findings.push({
          code: 'LOW_CONTRAST_DARK_BG',
          severity: 'blocker',
          message:
            `classDef "${def.name}": fill ${def.fill} vs dark bg ${DARK_BG} ` +
            `is ${fillVsDark.toFixed(2)}:1 — needs >= ${CONTRAST_BG}:1.`,
        });
      }
    }
  }
  return findings;
}

export function extractMermaidBlocks(content, filename) {
  if (filename.endsWith('.mmd')) {
    return [{ source: content, blockIndex: 0 }];
  }
  const blocks = [];
  const re = /```mermaid\s*\n([\s\S]*?)```/g;
  let m;
  let idx = 0;
  while ((m = re.exec(content)) !== null) {
    blocks.push({ source: m[1].trimEnd(), blockIndex: idx++ });
  }
  return blocks;
}

export function walk(target) {
  const out = [];
  const stat = statSync(target);
  if (stat.isFile()) {
    if (target.endsWith('.mmd') || target.endsWith('.md')) out.push(target);
    return out;
  }
  for (const entry of readdirSync(target, { withFileTypes: true })) {
    if (entry.name.startsWith('.') || entry.name === 'node_modules') continue;
    if (entry.name === '__fixtures__') continue;
    if (LLM_CONFIG_BASENAMES.has(entry.name)) continue;
    const p = join(target, entry.name);
    out.push(...walk(p));
  }
  return out;
}

async function main(argv) {
  const targets = argv.slice(2);
  if (targets.length === 0) {
    console.error('usage: lint-mermaid.mjs <file-or-dir>...');
    process.exit(2);
  }

  const results = [];
  for (const target of targets) {
    for (const file of walk(target)) {
      const content = readFileSync(file, 'utf8');
      const blocks = extractMermaidBlocks(content, file);
      for (const block of blocks) {
        const findings = await lintDiagram(block.source);
        if (findings.length > 0) {
          results.push({ file, blockIndex: block.blockIndex, findings });
        }
      }
    }
  }

  const blockerCount = results.reduce(
    (acc, r) => acc + r.findings.filter((f) => f.severity === 'blocker').length,
    0,
  );

  process.stdout.write(
    JSON.stringify(
      {
        status: results.length === 0 ? 'ok' : 'findings',
        blockerCount,
        results,
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(blockerCount > 0 ? 1 : 0);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main(process.argv).catch((e) => {
    console.error('lint-mermaid: unexpected error:', e);
    process.exit(2);
  });
}
