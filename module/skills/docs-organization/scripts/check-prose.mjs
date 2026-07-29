#!/usr/bin/env node
// Deterministic prose-scannability checks over a markdown AST.
//
// Replaces the LLM "readability" lane's job of *enumerating* violations: an
// LLM reading a 700-line file against a fuzzy word/size bar under-reports, and
// its recall degrades toward the end of long files. Counting words and line
// spans over structural regions is mechanical, so a parser does it exhaustively
// and reproducibly. The LLM is left only the judgment call it is actually good
// at (is this a genre where dense prose is the convention?). Sentence counting
// was tried and removed — segmentation is a hard NLP problem (see THRESHOLDS).
//
// Findings (all severity info — nudges, never blockers):
//   WALL_OF_TEXT    a top-level paragraph over the density threshold
//   DENSE_BULLET    a flat list item (no sub-list) whose body is over threshold
//   SPLIT_CANDIDATE the whole file, or one H2 section, over the size threshold
//
// Output: JSON {status, findings:[{code, severity, file, line, message}]} on
// stdout. Exit 0 = no findings, 1 = findings, 2 = internal error. Matches the
// contract of check-structure.sh / check-staleness.sh.
//
// Markdown structure is read from the markdown-it token stream, never from
// per-line regexes: fenced code, tables, blockquotes, and nested lists are
// distinguished by node type, so wrapped list bodies and indented code never
// masquerade as paragraphs (the false-positive class a hand-rolled scanner hits).

import MarkdownIt from './vendor/markdown-it.mjs';
import { readFileSync, statSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

// Thresholds. Word count and line span are the only *unambiguous* size metrics,
// so those are all this deterministic pass triggers on. A paragraph gets more
// slack than a bullet: a bullet is meant to be one scannable idea, so it trips
// sooner. Sentence-boundary segmentation is a genuinely hard NLP problem
// (abbreviations, decimals, initials, ellipses), so we deliberately do NOT
// count sentences here — that fuzzy "is the rhythm choppy / is this a
// dense-prose genre" judgment is deferred to the LLM lane, which only ever
// adjudicates the candidates this pass surfaces.
export const THRESHOLDS = {
  paragraphWords: 120,
  bulletWords: 90,
  fileLines: 600,
  sectionLines: 250,
};

const md = new MarkdownIt(); // default preset: tables and lists enabled.

function countWords(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function lineOf(token) {
  return token.map ? token.map[0] + 1 : null;
}

// Walk the flat token stream, tracking nesting, and pull out:
//   - top-level paragraphs (not inside a list item or blockquote)
//   - list items, with their DIRECT text and whether they hold a nested list
export function analyzeMarkdown(content) {
  const tokens = md.parse(content, {});
  const findings = [];

  // Depth counters so we know our structural context at each inline token.
  let listItemDepth = 0;
  let blockquoteDepth = 0;

  // Stack of open list items, so a nested list's text is attributed to the
  // inner item and the outer item is marked as "has a nested list".
  const itemStack = [];

  for (let ti = 0; ti < tokens.length; ti++) {
    const tok = tokens[ti];
    switch (tok.type) {
      case 'blockquote_open':
        blockquoteDepth++;
        break;
      case 'blockquote_close':
        blockquoteDepth--;
        break;
      case 'bullet_list_open':
      case 'ordered_list_open':
        // A list opening inside an item means that item is not flat.
        if (itemStack.length > 0) itemStack[itemStack.length - 1].hasNestedList = true;
        break;
      case 'list_item_open':
        listItemDepth++;
        itemStack.push({ line: lineOf(tok), text: '', hasNestedList: false });
        break;
      case 'list_item_close': {
        listItemDepth--;
        const item = itemStack.pop();
        // Only flag a flat item: one carrying its whole load as prose with no
        // sub-bullets to break it up. An item that already nests a list is
        // exactly the shape we want, however long.
        if (!item.hasNestedList) {
          const words = countWords(item.text);
          if (words >= THRESHOLDS.bulletWords) {
            findings.push({
              code: 'DENSE_BULLET',
              severity: 'info',
              line: item.line,
              message: `flat bullet ~${words} words; break into sub-bullets`,
            });
          }
        }
        break;
      }
      case 'inline': {
        // Attribute this text to the innermost open list item, if any.
        if (itemStack.length > 0) {
          itemStack[itemStack.length - 1].text += ' ' + tok.content;
        }
        break;
      }
      case 'paragraph_open': {
        // A genuine top-level paragraph: not in a list item, not in a
        // blockquote. Its text is the next inline token.
        if (listItemDepth === 0 && blockquoteDepth === 0) {
          const line = lineOf(tok);
          // The paragraph's inline content is the immediately following token.
          const inline = tokens[ti + 1];
          const text = inline && inline.type === 'inline' ? inline.content : '';
          const words = countWords(text);
          if (words >= THRESHOLDS.paragraphWords) {
            findings.push({
              code: 'WALL_OF_TEXT',
              severity: 'info',
              line,
              message: `paragraph ~${words} words unbroken; split at a topic seam`,
            });
          }
        }
        break;
      }
      default:
        break;
    }
  }

  // Size heuristics. Whole file first, then any oversized H2 section.
  const totalLines = content.split('\n').length;
  if (totalLines > THRESHOLDS.fileLines) {
    findings.push({
      code: 'SPLIT_CANDIDATE',
      severity: 'info',
      line: 1,
      message: `file is ${totalLines} lines (> ${THRESHOLDS.fileLines}); consider extracting detail into a linked sub-document (a README into docs/, a SKILL.md into reference/)`,
    });
  }

  // Section spans: from each H2 heading to the next heading of level <= 2.
  const headings = [];
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].type === 'heading_open') {
      const level = Number(tokens[i].tag.slice(1));
      const line = lineOf(tokens[i]);
      const title = tokens[i + 1] && tokens[i + 1].type === 'inline' ? tokens[i + 1].content : '';
      headings.push({ level, line, title });
    }
  }
  for (let i = 0; i < headings.length; i++) {
    if (headings[i].level !== 2) continue;
    let end = totalLines + 1;
    for (let j = i + 1; j < headings.length; j++) {
      if (headings[j].level <= 2) { end = headings[j].line; break; }
    }
    const span = end - headings[i].line;
    if (span > THRESHOLDS.sectionLines) {
      findings.push({
        code: 'SPLIT_CANDIDATE',
        severity: 'info',
        line: headings[i].line,
        message: `section "${headings[i].title}" spans ~${span} lines (> ${THRESHOLDS.sectionLines}); consider extracting it into a linked sub-document`,
      });
    }
  }

  findings.sort((a, b) => (a.line || 0) - (b.line || 0));
  return findings;
}

function walkMarkdownFiles(target) {
  const st = statSync(target);
  if (st.isFile()) return target.endsWith('.md') ? [target] : [];
  const out = [];
  for (const entry of readdirSync(target, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue; // skip dot-dirs (agent runtime spaces)
    const p = join(target, entry.name);
    if (entry.isDirectory()) out.push(...walkMarkdownFiles(p));
    else if (entry.isFile() && entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}

function main(argv) {
  const targets = argv.slice(2);
  if (targets.length === 0) {
    process.stderr.write('usage: check-prose.mjs <file-or-dir>...\n');
    process.exit(2);
  }
  const findings = [];
  for (const target of targets) {
    for (const file of walkMarkdownFiles(target)) {
      const content = readFileSync(file, 'utf8');
      for (const f of analyzeMarkdown(content)) findings.push({ ...f, file });
    }
  }
  const payload = {
    status: findings.length === 0 ? 'ok' : 'findings',
    findings,
  };
  process.stdout.write(JSON.stringify(payload, null, 2) + '\n');
  process.exit(findings.length === 0 ? 0 : 1);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    main(process.argv);
  } catch (e) {
    process.stderr.write('check-prose: internal error: ' + (e && e.stack ? e.stack : e) + '\n');
    process.exit(2);
  }
}
