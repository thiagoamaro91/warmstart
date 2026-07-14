#!/usr/bin/env node
// SessionStart hook: inject the dispatch playbook as additional context, so
// the session knows the dispatch rules without the user editing CLAUDE.md.
// The guard hook enforces rules 1-2 either way; this injection is what lets
// the model get the dispatch right on the first try instead of after a block.
//
// Fails OPEN (silent, exit 0) if the playbook file is unreadable: a missing
// doc must not break session start.

'use strict';

const fs = require('fs');
const path = require('path');

const root = process.env.CLAUDE_PLUGIN_ROOT || path.resolve(__dirname, '..');

let playbook;
try {
  playbook = fs.readFileSync(path.join(root, 'docs', 'dispatch-playbook.md'), 'utf8');
} catch {
  process.exit(0);
}

process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'SessionStart',
    additionalContext:
      'The dispatch plugin is active. Follow its playbook when dispatching subagents '
      + '(rules 1-2 are enforced by a PreToolUse guard):\n\n'
      + playbook,
  },
}));
process.exit(0);
