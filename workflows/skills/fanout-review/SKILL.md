---
name: fanout-review
description: Use when the user asks for a fan-out code or document review, a multi-agent review, an adversarially verified review, or says "review this with finders and skeptics" or "run the fanout review". Fans out cheap finder agents across review dimensions in parallel, dedupes their findings, then upholds each finding only if it survives refutation by a majority of expensive skeptic agents. Runs the bundled review-fanout workflow via the Workflow tool. Multi-agent and costs real tokens, so use it when a single review pass is not enough, not for a quick inline read.
---

# fanout-review

Run the bundled fan-out-and-verify review workflow. One agent checking its own work grades its
own homework; this skill instead uses independent finders and adversarial verifiers so that
mistakes one pass would rationalize are caught by another.

This skill runs a Workflow script. The Workflow tool only executes when the user has opted into
multi-agent orchestration, and the fan-out spends real tokens (many agents, and the verify phase
runs on the expensive tier). Use it when the review is worth that, not for a quick inline check.

## How to run it

1. Gather the review target. Put the code, diff, or document to review (or a precise pointer to
   it, such as file paths plus the relevant excerpts) into a single string.

2. Call the `Workflow` tool with:
   - `scriptPath`: `${CLAUDE_PLUGIN_ROOT}/examples/review-fanout.workflow.js`
   - `args`: a JSON object `{ "target": "<the material to review>" }`. Optionally add
     `"dimensions": ["correctness", "security", ...]` to override the default review dimensions
     (correctness, security, error-handling, performance, readability).

3. The workflow returns `{ findings, upheld }`. `findings` is every unique candidate after
   dedupe; `upheld` is the subset that survived adversarial verification, each with its
   `upheldVotes` out of `skeptics`. Report the `upheld` list as the reviewed result, and mention
   how many candidates were dropped during verification.

## What the workflow does

- Find phase: one cheap (`haiku`) finder agent per review dimension, in parallel. Each finder
  reports only problems in its one dimension.
- Dedupe: findings from every dimension are merged by normalized title, so the same issue raised
  by two finders becomes one candidate.
- Verify phase: each candidate is handed to three independent skeptic agents on the expensive
  (`opus`) tier, each prompted to REFUTE it. A candidate is upheld only if at least two of the
  three cannot refute it.

The anatomy of the script, install, and honesty notes on cost live in the plugin README.
