#!/usr/bin/env node
// PreToolUse guard: enforce subagent dispatch discipline (dispatch playbook
// rules 1-2). Two failure modes it exists to stop:
//   a) one-line subagent prompts - the agent starts with zero conversation
//      context, so a thin prompt produces thin work;
//   b) every dispatch silently inheriting the session model, so cheap
//      mechanical tasks burn the expensive tier.
// Blocks (exit 2) with the briefing template on stderr so the model can
// re-issue immediately. Escape hatch: include [brief-ok] in the prompt for a
// deliberately tiny dispatch; it waives the length check only, never the pin.
//
// Written in Node, not bash: no jq or POSIX shell dependency, so it runs on
// Windows as-is. The only runtime it needs is a node executable on PATH.
//
// Config: set DISPATCH_REQUIRE_MODEL_PIN to "0", "false", or "off" to disable
// the model-pin rule. The briefing-length rule is the always-on core.
//
// Fails OPEN on unreadable or malformed input: a broken payload must not
// block all delegation in the session.

'use strict';

const fs = require('fs');

let raw;
try {
  raw = fs.readFileSync(0, 'utf8');
} catch {
  process.exit(0);
}

let input;
try {
  input = JSON.parse(raw);
} catch {
  process.exit(0);
}
if (typeof input !== 'object' || input === null) process.exit(0);

// The dispatch tool was named Task historically, Agent in current builds.
const tool = input.tool_name;
if (tool !== 'Task' && tool !== 'Agent') process.exit(0);

const toolInput = (typeof input.tool_input === 'object' && input.tool_input !== null)
  ? input.tool_input
  : {};
const prompt = typeof toolInput.prompt === 'string' ? toolInput.prompt : '';
const stype = (typeof toolInput.subagent_type === 'string' && toolInput.subagent_type !== '')
  ? toolInput.subagent_type
  : 'general-purpose';
const model = typeof toolInput.model === 'string' ? toolInput.model : '';

const pinToggle = process.env.DISPATCH_REQUIRE_MODEL_PIN || '';
const pinRequired = !/^(0|false|off)$/i.test(pinToggle);

// Model pin (dispatch playbook rule 2). Subagents inherit the session model
// when unpinned, so cheap work silently runs on the expensive tier; typed
// specialists carry a frontmatter pin, but the explicit param is still
// required so the pin is visible and auditable in the call itself. Checked
// BEFORE [brief-ok]: that escape waives briefing length only, never the pin.
if (pinRequired && model === '') {
  process.stderr.write(`BLOCKED: subagent dispatch without an explicit model pin (dispatch playbook rule 2).
Every Agent call must pass model: explicitly, typed specialists included.
  model: "haiku"  - mechanical work: extraction, reformatting, log scans, checklist sweeps
  model: "sonnet" - DEFAULT executor for code, reviews, research, standard multi-step tasks
  model: "opus"   - adversarial verification, judging other agents' output, architecture calls
For a typed specialist, pass the model its frontmatter already declares.
If the session tier is genuinely intended, pass that model explicitly - the
requirement is a visible, deliberate choice, never inheritance.
(To turn this rule off, set DISPATCH_REQUIRE_MODEL_PIN=0 in your environment.)
`);
  process.exit(2);
}

// Deliberate short dispatch, waved through by the orchestrator.
if (prompt.includes('[brief-ok]')) process.exit(0);

const len = [...prompt].length;

// Explore/Plan are read-only recon agents; short, precise prompts are more
// often legitimate there. Everything else must carry a real briefing.
const min = (stype === 'Explore' || stype === 'Plan') ? 200 : 500;

if (len < min) {
  process.stderr.write(`BLOCKED: under-briefed subagent dispatch (${len} chars, minimum ${min} for subagent_type=${stype}).
The subagent starts with ZERO conversation context: it has not seen the user's
request, prior tool results, or decisions made this session. Re-issue the
dispatch as a self-contained briefing (dispatch playbook rule 1):
  1. OBJECTIVE - one verifiable goal.
  2. CONTEXT  - why the task exists, decisions already made, exact file paths,
                and PASTED snippets/data. Never "as discussed" or "the file above".
  3. SCOPE    - what NOT to touch (write boundaries, sibling workstreams).
  4. OUTPUT   - exact shape of the final message; it is the ONLY thing returned.
  5. DONE     - how the agent verifies its own work before returning.
If a tiny prompt is genuinely right here, add [brief-ok] to the prompt.
`);
  process.exit(2);
}

process.exit(0);
