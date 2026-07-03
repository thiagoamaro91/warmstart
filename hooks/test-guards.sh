#!/usr/bin/env bash
# Regression tests for the PreToolUse guard hooks. Run from the repo as:
#   bash hooks/test-guards.sh
# Run it via the file path (not an inline command) so the outer invocation does
# not itself contain destructive strings that would trip the live guard.
#
# Em-dash test inputs use the JSON unicode escape backslash-u-2-0-1-4, which jq
# decodes to the em-dash character at runtime. The test file therefore contains
# no literal em-dash and stays consistent with the rule it helps enforce.
cd "$(dirname "$0")" || exit 1

pass=0; fail=0
check() { # $1=label $2=actual $3=want
  if [ "$2" = "$3" ]; then echo "  PASS  $1 (exit $2)"; pass=$((pass+1));
  else echo "  FAIL  $1 (exit $2, want $3)"; fail=$((fail+1)); fi
}

echo "================ syntax check ================"
for s in block-em-dash.sh block-destructive-bash.sh guard-memory-size.sh; do
  bash -n "$s" && echo "  OK: $s"
done

echo ""
echo "================ EM-DASH GUARD ================"
printf '%s' '{"tool_name":"Write","tool_input":{"content":"clean text with a - hyphen"}}'                              | ./block-em-dash.sh >/dev/null 2>&1; check "clean Write allowed"       $? 0
printf '%s' '{"tool_name":"Write","tool_input":{"content":"has an em\u2014dash here"}}'                              | ./block-em-dash.sh >/dev/null 2>&1; check "em-dash Write blocked"      $? 2
printf '%s' '{"tool_name":"Edit","tool_input":{"new_string":"before\u2014after"}}'                                  | ./block-em-dash.sh >/dev/null 2>&1; check "em-dash Edit blocked"       $? 2
printf '%s' '{"tool_name":"MultiEdit","tool_input":{"edits":[{"new_string":"ok"},{"new_string":"bad\u2014here"}]}}' | ./block-em-dash.sh >/dev/null 2>&1; check "em-dash MultiEdit blocked" $? 2
printf '%s' '{"tool_name":"Edit","tool_input":{"new_string":"en\u2013dash is fine"}}'                               | ./block-em-dash.sh >/dev/null 2>&1; check "en-dash U+2013 allowed"    $? 0
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}'                                                      | ./block-em-dash.sh >/dev/null 2>&1; check "Bash tool ignored"        $? 0

echo ""
echo "================ DESTRUCTIVE BASH GUARD ================"
printf '%s' '{"tool_input":{"command":"rm -rf /tmp/foo"}}'        | ./block-destructive-bash.sh >/dev/null 2>&1; check "rm -rf blocked"               $? 2
printf '%s' '{"tool_input":{"command":"rm -fr build"}}'           | ./block-destructive-bash.sh >/dev/null 2>&1; check "rm -fr blocked"               $? 2
printf '%s' '{"tool_input":{"command":"find . -name x -delete"}}' | ./block-destructive-bash.sh >/dev/null 2>&1; check "find -delete blocked"         $? 2
printf '%s' '{"tool_input":{"command":"git clean -fdx"}}'         | ./block-destructive-bash.sh >/dev/null 2>&1; check "git clean -fdx blocked"       $? 2
printf '%s' '{"tool_input":{"command":"rm file.txt"}}'            | ./block-destructive-bash.sh >/dev/null 2>&1; check "rm no -rf allowed"            $? 0
printf '%s' '{"tool_input":{"command":"git clean -n"}}'           | ./block-destructive-bash.sh >/dev/null 2>&1; check "git clean -n dry-run allowed" $? 0
printf '%s' '{"tool_input":{"command":"chmod -R 755 dir"}}'       | ./block-destructive-bash.sh >/dev/null 2>&1; check "chmod -R allowed"             $? 0
printf '%s' '{"tool_input":{"command":"ls -la"}}'                 | ./block-destructive-bash.sh >/dev/null 2>&1; check "ls allowed"                   $? 0

echo ""
echo "================ MEMORY-SIZE GUARD ================"
gms=./guard-memory-size.sh
line230=$(printf 'a%.0s' $(seq 1 230))
line300=$(printf 'b%.0s' $(seq 1 300))
line200=$(printf 'c%.0s' $(seq 1 200))
big=$(for _ in $(seq 1 200); do printf '%s\n' "$line200"; done)   # ~40KB, each line 200 chars

printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"MEMORY.md","content":"- [T](f.md) - hook"}}' | $gms >/dev/null 2>&1; check "normal MEMORY.md Write allowed"  $? 0
jq -nc --arg c "$line230" '{tool_name:"Write",tool_input:{file_path:"MEMORY.md",content:$c}}'            | $gms >/dev/null 2>&1; check "over-long line Write blocked"   $? 2
jq -nc --arg c "$big"     '{tool_name:"Write",tool_input:{file_path:"MEMORY.md",content:$c}}'            | $gms >/dev/null 2>&1; check "oversized (>24KB) Write blocked" $? 2
jq -nc --arg c "$line300" '{tool_name:"Write",tool_input:{file_path:"notes.md",content:$c}}'             | $gms >/dev/null 2>&1; check "non-MEMORY.md file ignored"     $? 0
jq -nc --arg s "$line230" '{tool_name:"Edit",tool_input:{file_path:"MEMORY.md",new_string:$s}}'          | $gms >/dev/null 2>&1; check "over-long line Edit blocked"    $? 2

# stateful Edit-growth path (needs a real near-cap file on disk)
tmp=$(mktemp -d)
near=$(for _ in $(seq 1 119); do printf '%s\n' "$line200"; done)   # ~23.9KB, just under the 24000 cap
printf '%s' "$near" > "$tmp/MEMORY.md"
jq -nc --arg fp "$tmp/MEMORY.md" --arg o "x"        --arg n "$big" '{tool_name:"Edit",tool_input:{file_path:$fp,old_string:$o,new_string:$n}}' | $gms >/dev/null 2>&1; check "Edit growing file past cap blocked" $? 2
jq -nc --arg fp "$tmp/MEMORY.md" --arg o "$line200" --arg n "z"    '{tool_name:"Edit",tool_input:{file_path:$fp,old_string:$o,new_string:$n}}' | $gms >/dev/null 2>&1; check "size-reducing Edit allowed"        $? 0
rm -r "$tmp"
echo ""
echo "================ TOTAL: $pass passed, $fail failed ================"
[ "$fail" -eq 0 ]
