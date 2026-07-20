#!/usr/bin/env node
// Reference integrity: a reference should be *followable*.
//
//   REF_BROKEN     a markdown link to a local path that resolves to nothing
//   REF_NOT_IN_GIT a markdown link to a file that exists but git does not track
//                  (gitignored/unstaged) — dangling for anyone who clones
//   UNLINKED_REF   a "§" section citation in prose with no accompanying link —
//                  a cheap, deterministic tell for a reference that points at
//                  something (often an external/internal spec) the reader can't
//                  follow. Info only: the fix is to LINK it (or confirm the
//                  target ships), never to strip the citation.
//
// Design notes:
//   - Only *markdown links* are resolved. Link targets are unambiguously
//     doc-relative and express intent ("follow this"). Inline-code mentions of
//     source paths are deliberately NOT resolved — they are repo-root-relative,
//     riddled with placeholders (`<dir>/x.yaml`, `pool/<blake3>.tar.zst`), and
//     resolving them heuristically produces mostly false positives. Stale
//     source citations are the content-drift lane's job.
//   - Only *git-tracked* docs are scanned. A gitignored working doc (e.g. under
//     docs/superpowers/) is not a project deliverable and is out of audit scope.
//   - This does NOT demand every reference be committed — some are legitimately
//     private/external. It surfaces dangling references for the author to
//     resolve in /docs-update (link, commit, or mark external). Never auto-fixes.
//
// Output: JSON {status, findings:[{code, severity, file, line, message}]}.
// Exit 0 = no findings, 1 = findings, 2 = internal error. Uses execFileSync
// (no shell) with fixed git arguments.

import MarkdownIt from 'markdown-it';
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, resolve, relative, join } from 'node:path';

const md = new MarkdownIt();

function git(args, cwd) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

function isExternal(t) {
  return /^[a-z]+:\/\//i.test(t) || t.startsWith('mailto:') || t.startsWith('#') || t.startsWith('tel:');
}

// Pull markdown-link targets and unlinked "§" citations from a file. `§` inside
// link text is skipped (it is already followable).
function extract(content) {
  const tokens = md.parse(content, {});
  const links = [];
  const sections = [];
  for (const b of tokens) {
    if (b.type !== 'inline' || !b.children) continue;
    const line = b.map ? b.map[0] + 1 : null;
    let linkDepth = 0;
    for (const c of b.children) {
      if (c.type === 'link_open') {
        linkDepth++;
        const href = (c.attrs || []).find((a) => a[0] === 'href');
        if (href) links.push({ target: href[1], line });
      } else if (c.type === 'link_close') {
        linkDepth = Math.max(0, linkDepth - 1);
      } else if (c.type === 'text' && linkDepth === 0 && c.content.includes('§')) {
        const m = c.content.match(/§\s*[\w.\-]*/);
        sections.push({ line, snippet: (m ? m[0] : '§').slice(0, 24) });
      }
    }
  }
  return { links, sections };
}

// Every ancestor directory of a tracked file — git tracks files, not dirs, so a
// link to a real directory (`module/agents/`) would otherwise look untracked.
function trackedDirsOf(tracked) {
  const dirs = new Set();
  for (const f of tracked) {
    let d = dirname(f);
    while (d && d !== '.') { dirs.add(d); d = dirname(d); }
  }
  return dirs;
}

export function analyzeFile(file, root, tracked) {
  const content = readFileSync(file, 'utf8');
  const findings = [];
  const seen = new Set();
  const trackedDirs = trackedDirsOf(tracked);
  const { links, sections } = extract(content);
  for (const ref of links) {
    const target = ref.target;
    if (!target || isExternal(target)) continue;
    const cleaned = target.replace(/[#].*$/, '');
    if (!cleaned) continue; // pure anchor
    const abs = resolve(dirname(file), cleaned);
    const rel = relative(root, abs);
    if (rel.startsWith('..')) continue;
    const key = 'L' + rel + '@' + ref.line;
    // A tracked file, or a directory that contains tracked files, is followable.
    if (seen.has(key) || tracked.has(rel) || trackedDirs.has(rel)) continue;
    seen.add(key);
    if (existsSync(abs)) {
      findings.push({
        code: 'REF_NOT_IN_GIT', severity: 'warning', line: ref.line,
        message: `link to \`${cleaned}\` — exists but is NOT git-tracked (gitignored/unstaged); commit it, or make it an explicit external link if intentionally private`,
      });
    } else {
      findings.push({
        code: 'REF_BROKEN', severity: 'warning', line: ref.line,
        message: `link to \`${cleaned}\` — no such file in the repo; fix the path or link the real target`,
      });
    }
  }
  for (const s of sections) {
    findings.push({
      code: 'UNLINKED_REF', severity: 'info', line: s.line,
      message: `section citation "${s.snippet}" has no link — verify the referenced section is followable and add a link (keep the citation)`,
    });
  }
  findings.sort((a, b) => (a.line || 0) - (b.line || 0));
  return findings;
}

function walkMd(target) {
  const st = statSync(target);
  if (st.isFile()) return target.endsWith('.md') ? [target] : [];
  const out = [];
  for (const e of readdirSync(target, { withFileTypes: true })) {
    if (e.name.startsWith('.')) continue;
    const p = join(target, e.name);
    if (e.isDirectory()) out.push(...walkMd(p));
    else if (e.isFile() && e.name.endsWith('.md')) out.push(p);
  }
  return out;
}

function main(argv) {
  const targets = argv.slice(2);
  if (targets.length === 0) {
    process.stderr.write('usage: check-refs.mjs <file-or-dir>...\n');
    process.exit(2);
  }
  const root = git(['rev-parse', '--show-toplevel']).trim();
  const tracked = new Set(git(['ls-files'], root).split('\n').filter(Boolean));
  const findings = [];
  for (const t of targets) for (const f of walkMd(t)) {
    const rel = relative(root, f);
    if (!tracked.has(rel)) continue; // only audit tracked docs (skips gitignored)
    for (const x of analyzeFile(f, root, tracked)) findings.push({ ...x, file: rel });
  }
  process.stdout.write(JSON.stringify({ status: findings.length ? 'findings' : 'ok', findings }, null, 2) + '\n');
  process.exit(findings.length ? 1 : 0);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { main(process.argv); }
  catch (e) { process.stderr.write('check-refs: internal error: ' + (e && e.stack ? e.stack : e) + '\n'); process.exit(2); }
}
