#!/usr/bin/env node
// Regression suite for the `autonomous` chapter. Three checks over every file
// under autonomous/:
//   1. skills/autonomous/SKILL.md frontmatter parses and carries name + description.
//   2. No literal em-dash (U+2014) anywhere in the chapter.
//   3. No personal or private-infra residue: a sanitization sweep for a list of
//      forbidden tokens (case-insensitive; the host-name token matches only as a
//      whole word so it does not trip on "minimum" or "minimal").
// The forbidden tokens are built from fragments on purpose, so this test file,
// which lives under autonomous/, never contains a contiguous forbidden literal
// and therefore never trips its own sweep.
// Run: node autonomous/tests/test-autonomous-chapter.js

'use strict';

const fs = require('fs');
const path = require('path');

const chapterRoot = path.resolve(__dirname, '..');

let ran = 0;
let failed = 0;

function ok(name) {
  ran += 1;
  console.log(`ok   ${name}`);
}

function fail(name, detail) {
  ran += 1;
  failed += 1;
  console.log(`FAIL ${name}: ${detail}`);
}

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walk(full));
    } else if (entry.isFile()) {
      out.push(full);
    }
  }
  return out;
}

const files = walk(chapterRoot);

// --- Check 1: SKILL.md frontmatter parses and has name + description ---

(() => {
  const skillPath = path.join(chapterRoot, 'skills', 'autonomous', 'SKILL.md');
  if (!fs.existsSync(skillPath)) {
    fail('SKILL.md exists', `not found at ${skillPath}`);
    return;
  }
  const text = fs.readFileSync(skillPath, 'utf8');
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) {
    fail('SKILL.md frontmatter parses', 'no --- delimited frontmatter block found');
    return;
  }
  const block = m[1];
  const hasName = /^name:\s*\S+/m.test(block);
  // description may be a folded scalar (`description: >-`) so accept a bare key.
  const hasDescription = /^description:\s*(\S|>|\|)/m.test(block);
  if (hasName && hasDescription) {
    ok('SKILL.md frontmatter parses and has name + description');
  } else {
    fail('SKILL.md frontmatter has name + description',
      `name=${hasName} description=${hasDescription}`);
  }
})();

// --- Check 2: no literal em-dash (U+2014) in any chapter file ---

(() => {
  const emDash = String.fromCharCode(0x2014);
  const offenders = [];
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    if (text.includes(emDash)) offenders.push(path.relative(chapterRoot, f));
  }
  if (offenders.length === 0) {
    ok('no literal em-dash (U+2014) in any chapter file');
  } else {
    fail('no literal em-dash (U+2014)', `found in ${offenders.join(', ')}`);
  }
})();

// --- Check 3: sanitization sweep ---

(() => {
  // Each needle is assembled from fragments so the contiguous literal never
  // appears in this source file (and so this test never trips its own sweep).
  // The first entry is word-boundaried; the rest match as case-insensitive
  // substrings. Labels are reconstructed from the fragments at runtime.
  const wholeWord = [
    ['mi', 'ni'],
  ];
  const substrings = [
    ['linked', 'in-pro'],
    ['agent', '-db'],
    ['lic', 'ao'],
    ['sess', 'ao'],
    ['ari', 'eli'],
    ['beck', 'ham'],
    ['tele', 'gram'],
    ['chat', '_id'],
    ['rock', 'et'],
    ['hon', 'da'],
    ['ali', 'ne'],
    ['mad', 'rid'],
    ['pra', 'gue'],
  ];

  const patterns = [];
  for (const frags of wholeWord) {
    const token = frags.join('');
    patterns.push({ label: token, re: new RegExp('\\b' + token + '\\b', 'i') });
  }
  for (const frags of substrings) {
    const token = frags.join('');
    patterns.push({ label: token, re: new RegExp(token, 'i') });
  }

  const hits = [];
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    const lines = text.split('\n');
    for (const p of patterns) {
      for (let i = 0; i < lines.length; i += 1) {
        if (p.re.test(lines[i])) {
          hits.push(`${path.relative(chapterRoot, f)}:${i + 1} [${p.label}] ${lines[i].trim()}`);
        }
      }
    }
  }
  if (hits.length === 0) {
    ok('sanitization sweep: no forbidden tokens in the chapter');
  } else {
    fail('sanitization sweep', `\n     ${hits.join('\n     ')}`);
  }
})();

// --- summary ---

console.log(`\n${ran - failed}/${ran} passed`);
process.exit(failed === 0 ? 0 : 1);
