#!/usr/bin/env node
// Regression suite for the skill-tuner chapter. Three checks:
//   1. skills/skill-tuner/SKILL.md frontmatter parses with name + description.
//   2. No literal em-dash (U+2014) in any file under skill-tuner/.
//   3. No personal residue survived the extraction (a token blocklist).
// Dependency-free. Run: node skill-tuner/tests/test-skill-tuner-chapter.js

'use strict';

const fs = require('fs');
const path = require('path');

const chapterDir = path.resolve(__dirname, '..');
const skillMd = path.join(chapterDir, 'skills', 'skill-tuner', 'SKILL.md');
const thisFile = path.resolve(__filename);

// The em-dash is built from its code point, never typed as a literal, so this
// file can be scanned for it like every other file without matching itself.
const EM_DASH = String.fromCharCode(0x2014);

// Residue blocklist. Each entry is [label, regexp]. `mini` is whole-word so it
// does not fire on "minimum". This test file legitimately contains these terms
// as its own search patterns, so the residue scan skips it (stated in output).
const RESIDUE = [
  ['mini (whole word)', /\bmini\b/i],
  ['linkedin-pro', /linkedin-pro/i],
  ['agent-db', /agent-db/i],
  ['licao', /licao/i],
  ['sessao', /sessao/i],
  ['arieli', /arieli/i],
  ['beckham', /beckham/i],
  ['telegram', /telegram/i],
  ['chat_id', /chat_id/i],
  ['rocket', /rocket/i],
  ['honda', /honda/i],
  ['aline', /aline/i],
  ['madrid', /madrid/i],
  ['prague', /prague/i],
  // Markers of the three pieces cut during extraction (evidence collector,
  // headless launcher, notification integration) plus private-path fragments.
  // The chapter's de-personalization contract is that none of these ship;
  // this guards against a future edit reintroducing them. `thiago` is NOT
  // listed on purpose: the public repo slug `thiagoamaro91/warmstart` is
  // intentional identity that legitimately appears in the chapter files.
  ['moshi (whole word)', /\bmoshi\b/i],
  ['launchagent', /launchagent/i],
  ['com.thiago', /com\.thiago/i],
  ['claude-code-token', /claude-code-token/i],
  ['chat-id 6461016449', /6461016449/],
  ['/Users/ path', /\/Users\//],
  ['icloud path', /icloud/i],
  ['Mobile Documents path', /mobile documents/i],
];

let ran = 0;
let failed = 0;

function pass(name) {
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
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile()) out.push(full);
  }
  return out;
}

const files = walk(chapterDir);

// --- 1. SKILL.md frontmatter parses with name + description ---

(() => {
  const src = fs.readFileSync(skillMd, 'utf8');
  const m = src.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return fail('SKILL.md has a frontmatter block', 'no leading --- ... --- found');
  const fm = m[1];
  const name = fm.match(/^name:\s*(.+)$/m);
  const desc = fm.match(/^description:\s*(.+)$/m);
  if (!name || !name[1].trim()) return fail('SKILL.md frontmatter has name', 'name key missing or empty');
  if (!desc || !desc[1].trim()) return fail('SKILL.md frontmatter has description', 'description key missing or empty');
  if (name[1].trim() !== 'skill-tuner') {
    return fail('SKILL.md name is skill-tuner', `got ${JSON.stringify(name[1].trim())}`);
  }
  pass('SKILL.md frontmatter parses with name + description');
})();

// --- 2. No literal em-dash in any chapter file ---

(() => {
  const offenders = [];
  for (const f of files) {
    if (fs.readFileSync(f, 'utf8').includes(EM_DASH)) offenders.push(path.relative(chapterDir, f));
  }
  if (offenders.length) fail('no literal em-dash in chapter files', `found in: ${offenders.join(', ')}`);
  else pass(`no literal em-dash (U+2014) across ${files.length} chapter files`);
})();

// --- 3. No personal residue (this test file excluded, it holds the patterns) ---

(() => {
  const hits = [];
  for (const f of files) {
    if (path.resolve(f) === thisFile) continue;
    const src = fs.readFileSync(f, 'utf8');
    for (const [label, re] of RESIDUE) {
      if (re.test(src)) hits.push(`${path.relative(chapterDir, f)}: ${label}`);
    }
  }
  if (hits.length) fail('no personal residue in chapter files', hits.join('; '));
  else pass('no personal residue across chapter files (test file excluded: it holds the patterns)');
})();

// --- summary ---

console.log(`\n${ran - failed}/${ran} passed`);
process.exit(failed === 0 ? 0 : 1);
