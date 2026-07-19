# Tool landscape and provenance

Background for the skill: which Mermaid tool does what, why this skill exists in the shape it does,
and the sources behind it. Not needed for routine diagram work; read it when deciding tooling or
onboarding someone to the setup. Research verified 2026-06-26.

## The two-MCP split (this is the operational core)

Two MCP servers cover two different jobs. They complement, they do not compete:

| MCP server | Job | Writes to disk? | When |
|------------|-----|-----------------|------|
| **Mermaid Chart** (`validate_and_render_mermaid_diagram`) | One-shot syntax validation + render | No (returns inline SVG/PNG payload) | Before saving any diagram. Read only the `valid` field. |
| **claude-mermaid** (`mermaid_preview`, `mermaid_save`) | Live browser preview + white-background PNG/SVG/PDF export | Yes (`mermaid_save`) | When the diagram must embed in a white-page docx/pptx/PDF. |

claude-mermaid is what makes the docx/pptx workflow possible: `mermaid_save` with a white background
writes a white-bg image to disk, which Mermaid Chart cannot do (inline only). Both are optional: the
skill's judgment (structure, palette, gotchas) works without either, and `@mermaid-js/mermaid-cli`
covers validation and export from the command line.

### Installing claude-mermaid

- `npm install -g claude-mermaid`. Pulls Puppeteer + a pinned Chromium. If a system Chrome is
  already installed, `PUPPETEER_EXECUTABLE_PATH` can point at it to skip the bundled download.
- `claude mcp add --scope user mermaid claude-mermaid` registers it as the `mermaid` user MCP
  server.
- Live preview runs a local server on ports 3737-3747 while Claude Code is active; SVG live-reload,
  multiple concurrent previews, themes, pan/zoom.

## Why one folded skill instead of adopting third-party skills

Decision (2026-06-26): fold the best two third-party skills into ONE skill, plus a set of
accumulated rendering gotchas and this research, rather than clone-and-maintain. Reasons: single
source of truth, no low-star third-party maintenance risk, no per-clone palette edits, and the
house specifics (warm-dark gold, ELK >15, 60-30-10, the two-MCP workflow) live nowhere else.

### Source skills surveyed (six tools disambiguated; no official Anthropic Mermaid skill exists)

| Tool | Stars | Verdict | What was folded in |
|------|-------|---------|--------------------|
| `veelenga/claude-mermaid` (MCP server) | 174 | INSTALLED | The white-bg disk-export half of the workflow. |
| `mgranberry/mermaid-diagram-skill` | 4 | FOLDED IN | "Diagrams argue" philosophy, isomorphism/education tests, concept->pattern matrix, line-crossing reduction, classDef-with-color discipline. |
| `awesome-skills/mermaid-syntax-skill` | 13 | FOLDED IN | The v11 trap list: reserved words beyond `end`, markdown-by-default, linkStyle-hex-last, arrowless-edge bug, the `<br>` compatibility matrix. |
| `WH-2099/mermaid-skill` | 120 | SKIPPED | Breadth only (23 diagram types); no quality guidance. |
| `Agents365-ai/mermaid-skill` | 97 | SKIPPED | Vision self-check of rendered PNG is interesting but needs mmdc/Kroki and adds per-call friction. |
| `ccheney/robust-skills` mermaid | 48 | SKIPPED | Obsidian-aware + proactive, but minimal quality uplift over the above. |

Star counts are as surveyed on 2026-06-26.

### What the third-party skills did NOT cover (house-only, now in this skill)

- The warm-dark **gold** palette (all third-party recipes default to a blue `#3b82f6` primary).
- The **ELK renderer** rule for >15 nodes.
- The **60-30-10** colour ratio discipline.
- The **firm spec-leads-with-a-diagram** requirement and the Obsidian-native render path.
- The **two-MCP** validate-then-export workflow.
