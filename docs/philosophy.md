# The philosophy

Boris Cherny (creator and head of Claude Code) put the shift in one line: *"I don't prompt Claude
anymore. I have loops running that prompt Claude and figuring out what to do. My job is to write
loops."* That is the behavioral change this project is built around: you stop being the person who
hand-issues each prompt, and instead you author the system that issues them for you.

## The naming, straight

"Loop engineering" is not an Anthropic term. It is a community label, coined by Addy Osmani (Google)
in June 2026, building on a Peter Steinberger post and the Cherny quote above. A full-text sweep of
Anthropic's own engineering posts, Building Effective Agents, Writing Tools for Agents, Effective
Context Engineering, Effective Harnesses for Long-Running Agents, Harness Design for Long-Running
Apps, and the Multi-Agent Research System post, turns up zero occurrences of the phrase. If you go
looking for an official Anthropic "loop engineering playbook," you will not find one.

Anthropic's own name for this discipline is **context engineering**, defined as *"the set of
strategies for curating and maintaining the optimal set of tokens (information) during LLM
inference,"* and framed as *"the natural progression of prompt engineering"* [S3].

The architectural primitive underneath both labels is the **agent loop**. Anthropic's definition of an
agent centers on the model directing its own tool use in a loop, with no human in the middle issuing
each step [S3], and it distinguishes *workflows* (LLMs and tools orchestrated through predefined code
paths) from *agents* (LLMs dynamically directing their own process) [S1]. The loop describes how
agents work; it isn't a branded method. The ground truth that drives each iteration comes from tool
results, not from the model's own reasoning.

Practical consequence: treat "loop engineering" as a useful slogan for the mindset, but read
Anthropic's *context engineering* and *harness* posts for the actual technique. Those are the primary
sources; the blog label is downstream commentary.

## The four pillars

### Pillar 1: Tools as an agent-computer interface (ACI) [S1][S2]

Anthropic defines tools as *"a new kind of software which reflects a contract between deterministic
systems and non-deterministic agents"* and says to *"invest just as much effort in creating good
agent-computer interfaces (ACI)"* as teams historically spent on human-computer interfaces [S2]. In
Building Effective Agents they note they *"spent more time optimizing our tools than the overall
prompt"* [S1]. The concrete, verified practices:

- **Poka-yoke the tools.** *"Change the arguments so that it is harder to make mistakes."* Make error
  states structurally hard to reach rather than documenting them away [S2].
- **Naming has a measurable effect.** Anthropic found *"selecting between prefix- and suffix-based
  namespacing to have non-trivial effects on our tool-use evaluations"* [S2]. This was measured on
  their own Slack/Asana MCP servers, and the source recommends running your own evals rather than
  assuming the result generalizes.
- **Return semantic language, not opaque IDs.** Resolving *"arbitrary alphanumeric UUIDs to more
  semantically meaningful and interpretable language... significantly improves Claude's precision in
  retrieval tasks by reducing hallucinations"* [S2].
- **Write real tool docs.** *"A good tool definition often includes example usage, edge cases, input
  format requirements"* [S2].

### Pillar 2: Just-in-time context [S3][S6]

Context engineering is bidirectional: it covers what you *add* (retrieval, pre-loading) and what you
*remove* (compaction, pruning, clearing tool results) with equal weight, across the whole lifetime of
the context window, not just the opening prompt [S3]. The guiding heuristic is *"the smallest possible
set of high-signal tokens that maximize the likelihood of the desired outcome"* [S3].

The canonical example Anthropic gives is **Claude Code itself**: *"CLAUDE.md files are naively dropped
into context up front, while primitives like glob and grep allow it to navigate its environment and
retrieve files just-in-time, effectively bypassing the issues of stale indexing and complex syntax
trees"* [S3]. Static memory for the always-needed, dynamic retrieval for everything else. For
long-horizon agents, external memory becomes mandatory: in the multi-agent research system, *"the
LeadResearcher begins by ... saving its plan to Memory to persist the context, since if the context
window exceeds 200,000 tokens it will be truncated and it is important to retain the plan"* [S6].

### Pillar 3: Harness and persistent artifacts [S4][S3]

For work that spans multiple agent sessions, compaction alone is not enough: *"compaction ... doesn't
always pass perfectly clear instructions to the next agent"* [S4]. Anthropic's harness uses
structured, machine-readable persistent artifacts instead:

- a **JSON feature list** where each feature carries a `passes` boolean, and the agent is prompted to
  *"edit this file only by changing the status of a passes field"* [S4];
- a plain-text running-log file [S4];
- **descriptive git commits**, with new sessions told to *"read the git logs and progress files to get
  up to speed on what was recently worked on"* [S4].

These give each new session just-in-time orientation without replaying the entire prior transcript.
Compaction is *"the first lever,"* not the whole answer [S3].

### Pillar 4: Generator / evaluator separation [S5][S6]

A single agent grading its own work is systematically too lenient: solo agents *"confidently praise
the work, even when, to a human observer, the quality is obviously mediocre"* [S5]. The fix is a
**standalone evaluator agent**, because *"tuning a standalone evaluator to be skeptical turns out to
be far more tractable than making a generator critical of its own work"* [S5]. A smaller version of
the same idea runs inside subagents in the research system: *"subagents also plan, then use
interleaved thinking after tool results to evaluate quality, identify gaps, and refine their next
query"* [S6]. This is described specifically for Anthropic's coding and research harnesses, not
asserted as a universal law for all agent systems.

## What it is NOT: claims the verifier killed

Every claim above went through an adversarial verification pass: a claim needed two of three
independent reviewers to refute it before it was thrown out. Roughly a third of the plausible-sounding
claims floating around did not survive that pass. The notable kills, so you do not repeat them as
fact:

- **"Fewer tools always beat more tools."** The strong consolidation claim (a single combined tool
  beating granular tools on held-out evals) was not supported as stated.
- **"A fixed 6-step per-session loop."** There is no canonical numbered loop sequence in the primary
  sources; the steps people cite are illustrative, not prescribed.
- **"Tool-description rewriting cut task time 40%"** and **"token usage explains 80% of performance
  variance."** Both are hallucinated specifics with no primary support.
- **"Context reset beats compaction"** and the **"GAN-style generator/evaluator"** framing. Both trace
  to a third-party metaphor rather than an Anthropic claim. Treat "reset vs. compact" as an open
  question, not settled guidance.

Roughly a third of the plausible-sounding claims in circulation did not survive verification. The
slogan attracts confident over-specification. Anchor on the primary Anthropic posts, not the
commentary layer built on top of them.

## A closing note on how this doc itself was checked

Pillar 4 says a generator should not grade its own work. The claims in this document were themselves
checked the same way: put through a separate, skeptical verification pass, with 25 candidate claims
reviewed by three independent refute-by-default reviewers, 16 confirmed and 9 killed. That is
generator/evaluator separation applied to the writing of a philosophy doc, not just to code.

## Sources

Primary (Anthropic engineering / research):

- [S1] Building Effective Agents (Dec 2024) - https://www.anthropic.com/research/building-effective-agents
- [S2] Writing Tools for Agents (Sep 11 2025) - https://www.anthropic.com/engineering/writing-tools-for-agents
- [S3] Effective Context Engineering for AI Agents (Sep 29 2025) - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- [S4] Effective Harnesses for Long-Running Agents - https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- [S5] Harness Design for Long-Running Apps - https://www.anthropic.com/engineering/harness-design-long-running-apps
- [S6] Multi-Agent Research System (Jun 2025) - https://www.anthropic.com/engineering/multi-agent-research-system

Label origin (secondary / blog):

- [S7] Addy Osmani, "Loop Engineering" (Jun 2026) - https://addyosmani.com/blog/loop-engineering/
- [S8] The New Stack, "Loop Engineering" - https://thenewstack.io/loop-engineering/
