import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { analyzeFile } from './check-refs.mjs';

const GENV = {
  ...process.env,
  GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_CONFIG_SYSTEM: '/dev/null',
  GIT_AUTHOR_NAME: 'check-refs-test',
  GIT_AUTHOR_EMAIL: 'check-refs-test@invalid',
  GIT_COMMITTER_NAME: 'check-refs-test',
  GIT_COMMITTER_EMAIL: 'check-refs-test@invalid',
};
const git = (root, ...args) => execFileSync('git', args, { cwd: root, env: GENV, encoding: 'utf8' });
const codes = (f) => f.map((x) => x.code);

function makeRepo(files, tracked) {
  const root = mkdtempSync(join(tmpdir(), 'check-refs-'));
  git(root, 'init', '-q');
  for (const [p, body] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), body);
  }
  for (const p of tracked) git(root, 'add', p);
  git(root, 'commit', '-q', '-m', 'init');
  const trackedSet = new Set(git(root, 'ls-files').split('\n').filter(Boolean));
  return { root, trackedSet };
}

test('a tracked link, an external URL, and an anchor are all clean', () => {
  const doc = 'See [arch](docs/arch.md), the [site](https://example.com), and [top](#intro).';
  const { root, trackedSet } = makeRepo(
    { 'README.md': doc, 'docs/arch.md': '# arch\n' },
    ['README.md', 'docs/arch.md'],
  );
  assert.deepEqual(analyzeFile(join(root, 'README.md'), root, trackedSet), []);
});

test('a link to a gitignored file flags REF_NOT_IN_GIT', () => {
  const { root, trackedSet } = makeRepo(
    {
      '.gitignore': 'docs/private/\n',
      'README.md': 'See the [spec](docs/private/spec.md).',
      'docs/private/spec.md': '# secret\n',
    },
    ['.gitignore', 'README.md'],
  );
  assert.deepEqual(codes(analyzeFile(join(root, 'README.md'), root, trackedSet)), ['REF_NOT_IN_GIT']);
});

test('a link to a nonexistent file flags REF_BROKEN', () => {
  const { root, trackedSet } = makeRepo({ 'README.md': 'See [gone](docs/gone.md).' }, ['README.md']);
  assert.deepEqual(codes(analyzeFile(join(root, 'README.md'), root, trackedSet)), ['REF_BROKEN']);
});

test('an inline-code source path is NOT flagged (mentions are not links)', () => {
  // The repo has no such file, but `internal/x.go` is a mention, not a link.
  const { root, trackedSet } = makeRepo({ 'README.md': 'The entry point is `internal/x.go`.' }, ['README.md']);
  assert.deepEqual(analyzeFile(join(root, 'README.md'), root, trackedSet), []);
});

test('a link to a tracked directory is followable (not flagged)', () => {
  const { root, trackedSet } = makeRepo(
    { 'README.md': 'See the [agents](module/agents/).', 'module/agents/a.md': '# a\n' },
    ['README.md', 'module/agents/a.md'],
  );
  assert.deepEqual(analyzeFile(join(root, 'README.md'), root, trackedSet), []);
});

test('a link to a gitignored directory flags REF_NOT_IN_GIT', () => {
  const { root, trackedSet } = makeRepo(
    {
      '.gitignore': 'build/\n',
      'README.md': 'See the [output](build/).',
      'build/out.md': '# out\n',
    },
    ['.gitignore', 'README.md'],
  );
  assert.deepEqual(codes(analyzeFile(join(root, 'README.md'), root, trackedSet)), ['REF_NOT_IN_GIT']);
});

test('a bare § citation with no link flags UNLINKED_REF', () => {
  const { root, trackedSet } = makeRepo({ 'README.md': 'This follows spec §10.9 E-3.' }, ['README.md']);
  assert.deepEqual(codes(analyzeFile(join(root, 'README.md'), root, trackedSet)), ['UNLINKED_REF']);
});

test('a § inside a resolvable link is not flagged', () => {
  const { root, trackedSet } = makeRepo(
    { 'README.md': 'See [§10.9](docs/arch.md).', 'docs/arch.md': '# arch\n' },
    ['README.md', 'docs/arch.md'],
  );
  assert.deepEqual(analyzeFile(join(root, 'README.md'), root, trackedSet), []);
});
