#!/usr/bin/env node
// Regression suite for the dispatch plugin's two hooks. Feeds recorded
// PreToolUse payloads (fixtures/*.json) to guard-agent-briefing.js and
// asserts exit codes and stderr content; then exercises inject-playbook.js.
// Run: node dispatch/hooks/tests/test-dispatch-hooks.js

'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const hooksDir = path.resolve(__dirname, '..');
const guard = path.join(hooksDir, 'guard-agent-briefing.js');
const injector = path.join(hooksDir, 'inject-playbook.js');
const fixturesDir = path.join(__dirname, 'fixtures');

let ran = 0;
let failed = 0;

function fixture(name) {
  return fs.readFileSync(path.join(fixturesDir, name), 'utf8');
}

function run(script, input, envOverrides = {}) {
  // Strip the toggle from the inherited env so the default-on path is what
  // gets tested regardless of the machine running the suite.
  const env = { ...process.env, ...envOverrides };
  if (!('DISPATCH_REQUIRE_MODEL_PIN' in envOverrides)) {
    delete env.DISPATCH_REQUIRE_MODEL_PIN;
  }
  return spawnSync(process.execPath, [script], { input, env, encoding: 'utf8' });
}

function check(name, res, wantStatus, stderrHas = [], stderrLacks = []) {
  ran += 1;
  const problems = [];
  if (res.status !== wantStatus) {
    problems.push(`exit ${res.status}, want ${wantStatus}`);
  }
  for (const s of stderrHas) {
    if (!res.stderr.includes(s)) problems.push(`stderr missing ${JSON.stringify(s)}`);
  }
  for (const s of stderrLacks) {
    if (res.stderr.includes(s)) problems.push(`stderr must not contain ${JSON.stringify(s)}`);
  }
  if (problems.length === 0) {
    console.log(`ok   ${name}`);
  } else {
    failed += 1;
    console.log(`FAIL ${name}: ${problems.join('; ')}`);
    if (res.stderr) console.log(`     stderr: ${res.stderr.split('\n')[0]}`);
  }
}

// --- guard-agent-briefing.js, model-pin rule (default on) ---

check('non-Agent tool passes through',
  run(guard, fixture('bash-tool.json')), 0);

check('short un-pinned dispatch blocked for the pin first',
  run(guard, fixture('agent-short-unpinned.json')), 2,
  ['model pin', 'DISPATCH_REQUIRE_MODEL_PIN']);

check('long briefing without a pin is still blocked',
  run(guard, fixture('agent-long-unpinned.json')), 2,
  ['model pin'], ['under-briefed']);

check('[brief-ok] never waives the pin',
  run(guard, fixture('agent-briefok-unpinned.json')), 2,
  ['model pin']);

check('Task (legacy tool name) is guarded like Agent',
  run(guard, fixture('task-short-unpinned.json')), 2,
  ['model pin']);

// --- guard-agent-briefing.js, briefing-length rule ---

check('short pinned dispatch blocked with the briefing template',
  run(guard, fixture('agent-short-pinned.json')), 2,
  ['under-briefed', 'OBJECTIVE', 'CONTEXT', 'SCOPE', 'OUTPUT', 'DONE', 'minimum 500']);

check('500+ char briefing with a pin passes',
  run(guard, fixture('agent-long-pinned.json')), 0);

check('[brief-ok] waives the length check',
  run(guard, fixture('agent-briefok-pinned.json')), 0);

check('Explore gets the 200-char minimum: 200+ passes',
  run(guard, fixture('explore-medium-pinned.json')), 0);

check('Explore gets the 200-char minimum: under 200 blocked',
  run(guard, fixture('explore-short-pinned.json')), 2,
  ['under-briefed', 'minimum 200', 'subagent_type=Explore']);

// --- guard-agent-briefing.js, length is CHARACTERS not bytes ---

check('167-char CJK prompt (501 UTF-8 bytes) is blocked: gate counts characters',
  run(guard, fixture('agent-unicode-charcount-pinned.json')), 2,
  ['under-briefed', 'minimum 500']);

check('499-char ASCII prompt blocked',
  run(guard, fixture('agent-ascii-499-pinned.json')), 2,
  ['under-briefed', 'minimum 500']);

check('501-char ASCII prompt passes',
  run(guard, fixture('agent-ascii-501-pinned.json')), 0);

check('Explore: 199-char prompt blocked',
  run(guard, fixture('explore-ascii-199-pinned.json')), 2,
  ['under-briefed', 'minimum 200']);

check('Explore: 201-char prompt passes',
  run(guard, fixture('explore-ascii-201-pinned.json')), 0);

// --- guard-agent-briefing.js, pin toggle off ---

for (const off of ['0', 'false', 'OFF']) {
  check(`DISPATCH_REQUIRE_MODEL_PIN=${off}: un-pinned long briefing passes`,
    run(guard, fixture('agent-long-unpinned.json'), { DISPATCH_REQUIRE_MODEL_PIN: off }), 0);
}

check('pin toggle off: length rule stays on',
  run(guard, fixture('agent-short-unpinned.json'), { DISPATCH_REQUIRE_MODEL_PIN: '0' }), 2,
  ['under-briefed'], ['model pin']);

check('pin toggle set to an unrelated value keeps the pin rule on',
  run(guard, fixture('agent-short-unpinned.json'), { DISPATCH_REQUIRE_MODEL_PIN: 'yes' }), 2,
  ['model pin']);

// --- guard-agent-briefing.js, fail-open stance ---

check('malformed JSON fails open',
  run(guard, 'this is not json'), 0);

check('empty stdin fails open',
  run(guard, ''), 0);

// --- inject-playbook.js ---

(() => {
  ran += 1;
  const res = run(injector, '', { CLAUDE_PLUGIN_ROOT: path.resolve(__dirname, '..', '..') });
  let out = null;
  try { out = JSON.parse(res.stdout); } catch { /* handled below */ }
  const ok = res.status === 0
    && out !== null
    && out.hookSpecificOutput
    && out.hookSpecificOutput.hookEventName === 'SessionStart'
    && out.hookSpecificOutput.additionalContext.includes('# Dispatch Playbook')
    && out.hookSpecificOutput.additionalContext.includes('OBJECTIVE');
  if (ok) {
    console.log('ok   injector emits the playbook as SessionStart additionalContext');
  } else {
    failed += 1;
    console.log(`FAIL injector emits the playbook: exit ${res.status}, stdout ${res.stdout.slice(0, 120)}`);
  }
})();

check('injector fails open when the playbook is missing',
  run(injector, '', { CLAUDE_PLUGIN_ROOT: fixturesDir }), 0);

// --- summary ---

console.log(`\n${ran - failed}/${ran} passed`);
process.exit(failed === 0 ? 0 : 1);
