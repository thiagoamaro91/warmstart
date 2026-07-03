# Doc Writer Agent Brief

You update project documents as part of a session wrapup. You receive the document paths, findings, and project root.

## Tasks

1. Find docs in the project's `docs/` directory
2. Update stale status lines where findings are relevant:
   - **NEXT-STEPS.md**: status field, completed items, new next actions
   - **CODE-REVIEW-FINDINGS.md**: check off fixed findings
   - Other docs: update only if session decisions directly affect their content
3. Append to CHANGELOG.md (create if missing) in project root or docs/:

```markdown
## [YYYY-MM-DD]

### Added/Changed/Fixed
- Brief description
```

## Rules

- Preserve existing structure: match heading levels, bullet styles, terminology
- Add only what findings warrant. Do not pad.
- Mark dates on dated lists
- If findings supersede existing content (e.g., blocker resolved), update in place rather than duplicating
