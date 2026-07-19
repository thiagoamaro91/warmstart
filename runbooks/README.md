# runbooks

**Skills as plain-text runbooks: two procedure skills you can read in full before you ever run
them.**

## The idea

A Claude Code skill is not clever tech. It is a procedure written down once, in plain text, so the
model executes it the same way every time instead of being re-briefed from scratch in every
session; the same reason teams write runbooks for humans. That is the whole trick, and it is the
same thesis as the rest of this marketplace: durable behavior lives in legible files.

This plugin ships two such runbooks, picked because they are pure procedure: no hooks, no scripts,
no state, markdown all the way down. Open either SKILL.md and you have read the entire mechanism.

## What's inside

### forcing-questions

Adversarial demand interrogation for "is this worth building" decisions. Before any design work
starts, it walks the idea through up to six forcing questions, asked one at a time: demand
reality, status quo, desperate specificity, narrowest wedge, observation and surprise, future-fit.
It carries explicit anti-sycophancy rules (no "that could work", no "interesting approach"; take a
position and state what evidence would flip it) and ends with a verdict: build the wedge, reshape
the idea, or do not build, plus one concrete assignment. Forked from the gstack `office-hours`
skill's YC-style product diagnostic core, stripped to the methodology.

Use it when a new product, feature, tool, or automation is proposed and the demand is unproven.
It is deliberately uncomfortable; that is the point.

### spec-diagram

Specs that lead with a picture, and diagrams that argue instead of display. The rule it enforces:
every spec, design doc, or technical plan opens with an embedded Mermaid block, architecture
first, prose as backup. Around that rule it packs the working knowledge that makes the diagrams
actually render and actually communicate:

- a concept-to-pattern matrix (fan-out, convergence, cycle, assembly line...) and two structural
  tests, so the shape carries the meaning;
- the warm-dark gold palette (`references/palette.md`): pastel fills that survive both a dark
  editor canvas and a white docx page, with a 60-30-10 colour discipline;
- the Mermaid v11 syntax-trap list (`references/syntax-gotchas.md`): reserved words,
  markdown-by-default labels, the `<br>` compatibility matrix, subgraph traps;
- a validate-then-export workflow, with the ELK renderer rule for large graphs.

Two MCP servers (Mermaid Chart for validation, claude-mermaid for white-background export) are
**optional**; `npx @mermaid-js/mermaid-cli` covers both jobs from the command line, and the
judgment half of the skill needs no tooling at all. See
`skills/spec-diagram/references/tool-landscape.md` for the split and the provenance of every
folded source.

## Install

In Claude Code, add this repo as a plugin marketplace (skip if you already added it) and install
the plugin:

```
/plugin install runbooks@warmstart
```

If the marketplace is not added yet, first:

```
/plugin marketplace add thiagoamaro91/warmstart
```

Restart Claude Code. The two skills load automatically and trigger on their descriptions; you can
also invoke them directly (`/runbooks:forcing-questions`, `/runbooks:spec-diagram`). No hooks, no
prerequisites, nothing to configure.

## Relation to warmstart

warmstart (the founding plugin in this marketplace) guards what a session remembers; dispatch
guards what one agent hands to another. runbooks is the third angle: the procedures themselves,
shipped as skills. All three install independently; take any subset.
