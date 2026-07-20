import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyzeMarkdown, THRESHOLDS } from './check-prose.mjs';

const codes = (findings) => findings.map((f) => f.code);

test('clean short prose yields no findings', () => {
  const md = `# Title\n\nA short paragraph. Two sentences only.\n\n- a tight bullet\n- another one\n`;
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('long top-level paragraph flags WALL_OF_TEXT with its line', () => {
  const words = Array(THRESHOLDS.paragraphWords + 5).fill('word').join(' ');
  const md = `# Title\n\nintro line here\n\n${words}.\n`;
  const findings = analyzeMarkdown(md);
  const wt = findings.filter((f) => f.code === 'WALL_OF_TEXT');
  assert.equal(wt.length, 1);
  assert.equal(wt[0].line, 5); // the long paragraph starts on line 5
});

test('flat dense bullet flags DENSE_BULLET', () => {
  const body = Array(THRESHOLDS.bulletWords + 5).fill('word').join(' ');
  const md = `- **Lead.** ${body}.\n- short one\n`;
  const findings = analyzeMarkdown(md);
  assert.deepEqual(codes(findings), ['DENSE_BULLET']);
  assert.equal(findings[0].line, 1);
});

test('a bullet broken into short sub-bullets is NOT flagged (the escape hatch)', () => {
  const md =
    `- **Lead.** intro then details:\n` +
    `  - first point is short and scannable\n` +
    `  - second point is short and scannable\n` +
    `  - third point is short and scannable\n`;
  // The outer item holds a nested list (the desired shape) and its own text is
  // short; each inner item is short. No DENSE_BULLET.
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('a long sub-bullet is still flagged (nesting does not exempt inner prose)', () => {
  const body = Array(THRESHOLDS.bulletWords + 20).fill('word').join(' ');
  const md = `- **Lead.** details:\n  - ${body}.\n  - a short sibling\n`;
  assert.deepEqual(codes(analyzeMarkdown(md)), ['DENSE_BULLET']);
});

test('a short bullet with code spans is not flagged', () => {
  const md = `- Uses \`v1.2.3\`, \`a.b.c\`, \`x.y.z\`, and \`p.q.r\` together.\n`;
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('abbreviation-heavy short prose is not flagged (no sentence counting)', () => {
  // Peppered with abbreviations that would wreck any regex sentence counter.
  // Because we trigger on word count only, this ~45-word paragraph is clean —
  // the fuzzy sentence-rhythm judgment is the LLM lane's job, not ours.
  const md =
    'The pipeline has stages, e.g. fetch, verify, and emit. Configure it via ' +
    'flags, i.e. the documented ones, or via the file. Compare vs. the old ' +
    'tool. The U.S. deployment differs. See sec. 3.2 for details. It works.\n';
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('code fences and tables are excluded from prose counting', () => {
  const longWords = Array(THRESHOLDS.paragraphWords + 30).fill('word').join(' ');
  const md =
    '# Title\n\n```\n' + longWords + '. ' + longWords + '.\n```\n\n' +
    '| col | ' + longWords + ' |\n|---|---|\n| a | b |\n';
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('a long blockquote is excluded like a list', () => {
  const words = Array(THRESHOLDS.paragraphWords + 10).fill('word').join(' ');
  const md = `> ${words}.\n`;
  assert.deepEqual(analyzeMarkdown(md), []);
});

test('a file over the line budget flags SPLIT_CANDIDATE at line 1', () => {
  const md = '# Title\n\n' + Array(THRESHOLDS.fileLines + 5).fill('filler line').join('\n') + '\n';
  const findings = analyzeMarkdown(md);
  const sc = findings.filter((f) => f.code === 'SPLIT_CANDIDATE' && f.line === 1);
  assert.equal(sc.length, 1);
});

test('an oversized H2 section flags SPLIT_CANDIDATE at the heading', () => {
  const filler = Array(THRESHOLDS.sectionLines + 10).fill('filler line').join('\n');
  const md = `# Doc\n\n## Big Section\n\n${filler}\n\n## Small Section\n\ndone.\n`;
  const findings = analyzeMarkdown(md);
  const sc = findings.find((f) => f.code === 'SPLIT_CANDIDATE' && f.message.includes('Big Section'));
  assert.ok(sc, 'expected a SPLIT_CANDIDATE naming the Big Section');
  assert.equal(sc.line, 3);
});
