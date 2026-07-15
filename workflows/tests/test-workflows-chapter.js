#!/usr/bin/env node
// Regression test for the workflows chapter. Dependency-free Node.
// Run: node workflows/tests/test-workflows-chapter.js
//
// Checks:
//  1. examples/review-fanout.workflow.js parses as a Workflow script.
//     A Workflow script is neither plain CommonJS nor a plain ES module: it
//     combines `export const meta` (ESM only) with top-level `await`/`return`
//     (illegal in an ES module, illegal in CommonJS respectively), so a raw
//     `node --check` cannot validate it either way. We instead strip the
//     `export` keyword and compile the remaining body with the AsyncFunction
//     constructor, which parses top-level await/return without executing.
//  2. its `meta` block is a pure literal with a name and description.
//  3. skills/fanout-review/SKILL.md frontmatter parses with name + description.
//  4. no literal em-dash (U+2014) in any chapter file.
//  5. no disallowed private terms leak into the chapter (this test file is
//     excluded from that scan, since it must contain the banned list itself).

'use strict';

const fs = require('fs');
const path = require('path');

const chapterDir = path.resolve(__dirname, '..');
const scriptPath = path.join(chapterDir, 'examples', 'review-fanout.workflow.js');
const skillPath = path.join(chapterDir, 'skills', 'fanout-review', 'SKILL.md');
const selfPath = path.resolve(__filename);

let failed = 0;
function ok(name) { console.log('ok   - ' + name); }
function fail(name, detail) { failed++; console.log('FAIL - ' + name + (detail ? ': ' + detail : '')); }
function check(name, cond, detail) { if (cond) ok(name); else fail(name, detail); }

// Walk the chapter directory, returning absolute file paths.
function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}

// Extract a balanced {...} object literal that follows a marker string.
function extractObjectLiteral(src, marker) {
  const at = src.indexOf(marker);
  if (at === -1) return null;
  const start = src.indexOf('{', at);
  if (start === -1) return null;
  let depth = 0;
  for (let i = start; i < src.length; i++) {
    const c = src[i];
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return src.slice(start, i + 1); }
  }
  return null;
}

// --- 1. workflow script parses as a Workflow script -----------------------
let scriptSrc = '';
try {
  scriptSrc = fs.readFileSync(scriptPath, 'utf8');
  const body = scriptSrc.replace(/\bexport\s+const\s+meta\b/, 'const meta');
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  // Constructing parses/validates the body (top-level await + return) without
  // running it, so no agent()/parallel() call fires.
  new AsyncFunction(body);
  ok('workflow script parses (AsyncFunction compile, not executed)');
} catch (e) {
  fail('workflow script parses', e.message);
}

// --- 2. meta block is a pure literal with name + description --------------
try {
  const lit = extractObjectLiteral(scriptSrc, 'export const meta');
  check('meta object literal is present', !!lit);
  if (lit) {
    const meta = new Function('return (' + lit + ')')();
    check('meta.name is a non-empty string', typeof meta.name === 'string' && meta.name.length > 0, JSON.stringify(meta.name));
    check('meta.description is a non-empty string', typeof meta.description === 'string' && meta.description.length > 0);
  }
} catch (e) {
  fail('meta block evaluates as a pure literal', e.message);
}

// --- 3. SKILL.md frontmatter parses with name + description ---------------
try {
  const skill = fs.readFileSync(skillPath, 'utf8');
  const m = skill.match(/^---\n([\s\S]*?)\n---/);
  check('SKILL.md has YAML frontmatter', !!m);
  if (m) {
    const fm = m[1];
    const name = fm.match(/^name:\s*(.+)$/m);
    const desc = fm.match(/^description:\s*(.+)$/m);
    check('SKILL.md frontmatter has a name', !!name && name[1].trim().length > 0);
    check('SKILL.md frontmatter has a description', !!desc && desc[1].trim().length > 0);
  }
} catch (e) {
  fail('SKILL.md frontmatter parses', e.message);
}

// --- 4. no literal em-dash anywhere in the chapter -----------------------
const EM_DASH = String.fromCharCode(0x2014);
const allFiles = walk(chapterDir);
const emDashHits = [];
for (const f of allFiles) {
  const text = fs.readFileSync(f, 'utf8');
  if (text.indexOf(EM_DASH) !== -1) emDashHits.push(path.relative(chapterDir, f));
}
check('no literal em-dash (U+2014) in any chapter file', emDashHits.length === 0, emDashHits.join(', '));

// --- 5. no disallowed private terms leak into the chapter ----------------
// The scan excludes this test file, which necessarily contains the list.
const banned = [
  { label: 'mini (whole word)', re: /\bmini\b/i },
  { label: 'linkedin-pro', re: /linkedin-pro/i },
  { label: 'agent-db', re: /agent-db/i },
  { label: 'licao', re: /licao/i },
  { label: 'sessao', re: /sessao/i },
  { label: 'arieli', re: /arieli/i },
  { label: 'beckham', re: /beckham/i },
  { label: 'telegram', re: /telegram/i },
  { label: 'chat_id', re: /chat_id/i },
  { label: 'rocket', re: /rocket/i },
  { label: 'honda', re: /honda/i },
  { label: 'aline', re: /aline/i },
  { label: 'madrid', re: /madrid/i },
  { label: 'prague', re: /prague/i },
];
const leaks = [];
for (const f of allFiles) {
  if (path.resolve(f) === selfPath) continue;
  const text = fs.readFileSync(f, 'utf8');
  for (const b of banned) {
    if (b.re.test(text)) leaks.push(path.relative(chapterDir, f) + ' :: ' + b.label);
  }
}
check('no disallowed private terms in the chapter', leaks.length === 0, leaks.join('; '));

console.log('');
console.log(failed === 0 ? 'ALL PASS' : (failed + ' CHECK(S) FAILED'));
process.exit(failed === 0 ? 0 : 1);
