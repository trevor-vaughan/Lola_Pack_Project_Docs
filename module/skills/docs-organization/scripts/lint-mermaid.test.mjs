import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { lintDiagram, extractMermaidBlocks, walk } from './lint-mermaid.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const fixture = (name) =>
  readFileSync(join(here, '__fixtures__', name), 'utf8');

test('lintDiagram: good.mmd has no findings', async () => {
  const findings = await lintDiagram(fixture('good.mmd'));
  assert.deepEqual(findings, []);
});

test('lintDiagram: missing-header.mmd flags MISSING_HOUSE_STYLE_HEADER', async () => {
  const findings = await lintDiagram(fixture('missing-header.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'MISSING_HOUSE_STYLE_HEADER');
});

test('lintDiagram: legacy-header.mmd flags LEGACY_HOUSE_STYLE_HEADER warning', async () => {
  const findings = await lintDiagram(fixture('legacy-header.mmd'));
  const legacy = findings.find((f) => f.code === 'LEGACY_HOUSE_STYLE_HEADER');
  assert.ok(legacy, 'expected LEGACY_HOUSE_STYLE_HEADER finding');
  assert.equal(legacy.severity, 'warning');
  assert.match(legacy.message, /clusterBkg/);
  assert.match(legacy.message, /primaryTextColor/);
});

test('lintDiagram: bad-syntax.mmd flags SYNTAX_ERROR and stops', async () => {
  const findings = await lintDiagram(fixture('bad-syntax.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'SYNTAX_ERROR');
});

test('lintDiagram: inline-class.mmd flags INLINE_CLASS_NOT_SUPPORTED with fix suggestion', async () => {
  const findings = await lintDiagram(fixture('inline-class.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'INLINE_CLASS_NOT_SUPPORTED');
  assert.equal(findings[0].severity, 'blocker');
  assert.match(findings[0].message, /class web sysA/);
  assert.equal(findings[0].line, 14);
});

// --- merval syntax constraints ---
// These fixtures lock the rules in reference/mermaid-house-style.md
// ("Syntax constraints") to enforced behavior. If merval bumps its grammar
// and one of these constraints disappears or changes, the test fails
// loudly instead of letting the documentation drift silently.

test('lintDiagram: unquoted-colon.mmd flags SYNTAX_ERROR (colons in [] need quoting)', async () => {
  const findings = await lintDiagram(fixture('unquoted-colon.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'SYNTAX_ERROR');
});

test('lintDiagram: unquoted-comma.mmd flags SYNTAX_ERROR (commas in {} need quoting)', async () => {
  const findings = await lintDiagram(fixture('unquoted-comma.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'SYNTAX_ERROR');
});

test('lintDiagram: stadium-shape.mmd flags SYNTAX_ERROR (([text]) shape unsupported)', async () => {
  const findings = await lintDiagram(fixture('stadium-shape.mmd'));
  assert.equal(findings.length, 1);
  assert.equal(findings[0].code, 'SYNTAX_ERROR');
});

test('lintDiagram: quoted-punctuation.mmd passes (quoted : , ( ) are accepted)', async () => {
  const findings = await lintDiagram(fixture('quoted-punctuation.mmd'));
  assert.deepEqual(findings, []);
});

test('lintDiagram: permissive-syntax.mmd passes (/, ?, <br/> work unquoted)', async () => {
  const findings = await lintDiagram(fixture('permissive-syntax.mmd'));
  assert.deepEqual(findings, []);
});

test('lintDiagram: extracts classDef entries from good.mmd', async () => {
  // Internal sanity check: the parser should see the sysA classDef.
  // We verify indirectly via a Task 5 test, but this test confirms
  // the diagram parses cleanly with no spurious findings.
  const findings = await lintDiagram(fixture('good.mmd'));
  assert.equal(findings.length, 0);
});

test('lintDiagram: low-contrast.mmd flags LOW_CONTRAST_TEXT and LOW_CONTRAST_DARK_BG', async () => {
  const findings = await lintDiagram(fixture('low-contrast.mmd'));
  const codes = findings.map((f) => f.code);
  assert.ok(codes.includes('LOW_CONTRAST_TEXT'),
    `expected LOW_CONTRAST_TEXT in ${codes.join(',')}`);
  assert.ok(codes.includes('LOW_CONTRAST_DARK_BG'),
    `expected LOW_CONTRAST_DARK_BG in ${codes.join(',')}`);
  const textFinding = findings.find((f) => f.code === 'LOW_CONTRAST_TEXT');
  assert.equal(textFinding.severity, 'blocker');
});

test('lintDiagram: wrong-classname.mmd flags UNAPPROVED_CLASSNAME', async () => {
  const findings = await lintDiagram(fixture('wrong-classname.mmd'));
  const unapproved = findings.find((f) => f.code === 'UNAPPROVED_CLASSNAME');
  assert.ok(unapproved, 'expected UNAPPROVED_CLASSNAME finding');
  assert.equal(unapproved.severity, 'warning');
  assert.match(unapproved.message, /myCustomClass/);
});

test('lintDiagram: borderline-contrast.mmd flags LOW_CONTRAST_TEXT just below AA', async () => {
  // Fixture uses fill #7a7a7a with white text.
  // text vs fill: 4.29:1, just below the AA threshold of 4.5 — fails.
  // fill vs light bg: 4.29:1, above the 3.0 threshold — passes.
  // fill vs dark bg: 3.88:1, above the 3.0 threshold — passes.
  // Only LOW_CONTRAST_TEXT should fire.
  const findings = await lintDiagram(fixture('borderline-contrast.mmd'));
  const codes = findings.map((f) => f.code);
  assert.ok(codes.includes('LOW_CONTRAST_TEXT'),
    `expected LOW_CONTRAST_TEXT (text just below AA), got ${codes.join(',')}`);
  assert.ok(!codes.includes('LOW_CONTRAST_LIGHT_BG'),
    `fill vs light bg passes 3.0; should not fire`);
  assert.ok(!codes.includes('LOW_CONTRAST_DARK_BG'),
    `fill vs dark bg passes 3.0; should not fire`);
});

test('extractMermaidBlocks: returns whole file for .mmd', () => {
  const blocks = extractMermaidBlocks('flowchart LR\n  A --> B', 'foo.mmd');
  assert.equal(blocks.length, 1);
  assert.equal(blocks[0].source, 'flowchart LR\n  A --> B');
});

test('extractMermaidBlocks: pulls fenced blocks from .md', () => {
  const md = [
    '# Doc',
    '',
    'Some prose.',
    '',
    '```mermaid',
    'flowchart LR',
    '  A --> B',
    '```',
    '',
    'More prose.',
    '',
    '```mermaid',
    'sequenceDiagram',
    '  A->>B: hi',
    '```',
  ].join('\n');
  const blocks = extractMermaidBlocks(md, 'foo.md');
  assert.equal(blocks.length, 2);
  assert.match(blocks[0].source, /flowchart LR/);
  assert.match(blocks[1].source, /sequenceDiagram/);
});

test('extractMermaidBlocks: returns empty for .md with no mermaid blocks', () => {
  assert.deepEqual(extractMermaidBlocks('# Just prose\nNo diagrams.', 'foo.md'), []);
});

import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';

// --- scope: walk() excludes agent-runtime spaces ---
// Per docs-organization SKILL.md ("Scope of audit"), directory traversal
// must skip dot-directories, node_modules, and LLM-configuration files
// (CLAUDE.md, AGENTS.md, GEMINI.md, .cursorrules).
test('walk: skips LLM-config files and agent-runtime dirs in directory mode', () => {
  const work = mkdtempSync(join(tmpdir(), 'walk-scope-test-'));
  try {
    writeFileSync(join(work, 'guide.md'), '# guide');
    writeFileSync(join(work, 'CLAUDE.md'), '# claude');
    writeFileSync(join(work, 'AGENTS.md'), '# agents');
    writeFileSync(join(work, 'GEMINI.md'), '# gemini');
    writeFileSync(join(work, '.cursorrules'), 'rules');
    mkdirSync(join(work, '.hidden'));
    writeFileSync(join(work, '.hidden', 'sneaky.md'), '# sneaky');
    mkdirSync(join(work, 'node_modules'));
    writeFileSync(join(work, 'node_modules', 'evil.md'), '# evil');

    const files = walk(work).map((p) => p.replace(work + '/', '')).sort();
    assert.deepEqual(files, ['guide.md'],
      `expected only guide.md, got: ${files.join(', ')}`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('walk: skips __fixtures__ during directory traversal', () => {
  // Test fixtures intentionally include broken diagrams. They are test
  // inputs, not project documentation, so directory traversal must skip
  // them — same principle as node_modules and dot-directories.
  const work = mkdtempSync(join(tmpdir(), 'walk-fixtures-test-'));
  try {
    writeFileSync(join(work, 'real-doc.md'), '# real');
    mkdirSync(join(work, '__fixtures__'));
    writeFileSync(join(work, '__fixtures__', 'broken.mmd'), 'intentionally broken');

    const files = walk(work).map((p) => p.replace(work + '/', '')).sort();
    assert.deepEqual(files, ['real-doc.md'],
      `expected only real-doc.md, got: ${files.join(', ')}`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('walk: still returns explicit file even if its basename is LLM-config', () => {
  // When a user explicitly names a file, we lint it. The scope filter
  // applies during directory traversal, not when a single file is given.
  const work = mkdtempSync(join(tmpdir(), 'walk-explicit-test-'));
  try {
    const explicit = join(work, 'CLAUDE.md');
    writeFileSync(explicit, '# explicitly requested');
    const files = walk(explicit);
    assert.deepEqual(files, [explicit]);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
