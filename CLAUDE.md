@AGENTS.md

# Claude Code

- `AGENTS.md` is the shared source of agent instructions for both Codex and Claude Code.
- Before implementation, also read `docs/DECISIONS.md` and the task-relevant documents referenced by `AGENTS.md`.
- Do not use auto-memory or inferred preferences to override an explicit project decision or the Owner Approval Gate.

## Impeccable

- Impeccable is the approved design authority for visual/UI craft.
- Install/configure it at project scope as documented; in Claude Code its command form is `/impeccable ...`.
- Run `/impeccable init` when first establishing design context, and read `docs/UI_DESIGN_GOVERNANCE.md` before UI work.
- Visual decisions are delegated to Impeccable, but product/financial/security/permission behavior still requires the Owner Approval Gate.

