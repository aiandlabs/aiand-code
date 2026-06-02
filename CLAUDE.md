# CLAUDE.md

This repo (`aiand-code`) is a **fork of opencode** that syncs from upstream
nightly. Before changing anything that diverges from upstream, read
[`FORK.md`](./FORK.md) — it is the source of truth for:

- what we've changed vs. upstream and why (the divergence inventory)
- how the nightly `upstream-sync` works and how to resolve sync conflicts
- the golden rules for keeping the fork mergeable (prefer adding files over
  modifying upstream files; keep edits small and localized)
- the distribution pipeline (`release.yml` → GitHub Releases → the `install` script)
- the **deferred** `opencode` → `aiand` functional rename — what is still
  `opencode` on purpose, so you don't blindly find/replace it

This is a **public** repository: never commit secrets or tokens; use GitHub
Actions secrets.

For upstream's general contributor/agent guidance, see `AGENTS.md`.
