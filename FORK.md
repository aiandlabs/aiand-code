# Maintaining `aiand-code` (a fork of opencode)

`aiand-code` is a fork of [opencode](https://github.com/anomalyco/opencode) (MIT
licensed — the upstream `LICENSE` stays intact). We track upstream closely and
sync **nightly**, so every change we make on top of upstream is a potential merge
conflict we pay for on every sync. This document is the map of what we've changed
and the playbook for keeping the fork mergeable.

> This is a **public** repository. Everything here is world-readable. Never put
> secrets, tokens, or private infrastructure details in this file or anywhere in
> the repo — use GitHub Actions secrets instead.

---

## How the sync works

`.github/workflows/upstream-sync.yml` runs nightly (06:00 UTC) and on demand:

- **Clean merge** → opens a PR (`chore/upstream-sync`) and enables auto-merge;
  existing CI gates it and it lands itself.
- **Conflicts** → opens the same PR with conflict markers committed and a
  `CONFLICTS` label, for you to resolve by hand:
  ```
  git fetch origin chore/upstream-sync
  git checkout chore/upstream-sync
  # fix conflict markers, then:
  git add -A && git commit && git push
  ```

Conflicts will only ever appear in the files listed below. If a sync conflicts in
a file **not** on this list, something new diverged — add it here.

---

## The golden rules

1. **Prefer adding files over modifying upstream files.** A new file we own
   (e.g. `script/brand/*`, the release/sync workflows) only conflicts if upstream
   later creates the same path — effectively never. A modified upstream file
   conflicts whenever upstream touches the same lines.
2. **Keep edits to upstream files small and localized.** Isolate our change to a
   clearly-marked constant/block so a 3-way merge can resolve around it. See the
   `BINARY` constant in `packages/opencode/script/build.ts` for the pattern.
3. **Don't do blind find/replace renames.** The functional `opencode` → `aiand`
   rename is deliberately staged (see *Deferred rename* below). Widening it
   widens the conflict surface — only do it with intent.
4. **When upstream wins, take upstream.** For anything that isn't ours by design
   (logic, deps, lockfile), prefer upstream's version and re-apply our small delta
   on top, rather than hand-merging line by line.

---

## Divergence inventory

Regenerate this list any time with:

```bash
git fetch upstream
git diff upstream/dev --name-status \
  | grep -vEi '\.(png|svg|icns|ico|jpg|jpeg|webp|gif|woff2?|ttf|otf|ds_store)$'
```

As of this writing: **231 files** diverge from `upstream/dev` — **207 binary
artwork** files and **24 code/text** files.

### A. Files we added (low conflict risk)

These have no upstream counterpart; they only conflict if upstream creates the
same path.

| File | Purpose |
| --- | --- |
| `.github/workflows/upstream-sync.yml` | The nightly sync workflow itself |
| `.github/workflows/release.yml` | Our distribution pipeline (curl + GitHub Releases) |
| `script/brand/generate.sh` | Brand asset generator (logos, icons, favicons) |
| `script/brand/build-wordmark.cjs` | Wordmark SVG builder |
| `script/brand/ico.mjs` | `.ico` / `.icns` generator |
| `script/brand/.gitignore` | Ignores brand generator scratch output |
| `FORK.md`, `CLAUDE.md` | This doc + the agent pointer to it |

### B. Upstream files we modified (the real maintenance burden)

These conflict whenever upstream edits the same regions. Grouped by why we touched
them.

**Distribution / packaging** — see [DISTRIBUTION](#distribution-curl--github-releases):

| File | Our change | Merge guidance |
| --- | --- | --- |
| `install` | Repointed to `aiandlabs/aiand-code` releases; install dir `~/.aiand-code/bin`; binary/command `aiand-code`; rebranded banner | Keep our `APP`/`REPO`/`INSTALL_DIR` and the `aiand-code` strings; take upstream's improvements to download/detection logic |
| `packages/opencode/script/build.ts` | Added `BINARY` constant + `OPENCODE_BUILD_OS` filter; binary/archive named via `BINARY` | Keep the `BINARY` const and the two filter lines; take upstream changes to build internals |
| `packages/opencode/package.json` | `bin` entry → `aiand-code` (name stays `opencode`) | Keep our `bin`; take everything else from upstream |
| `bun.lock` | Reflects the `bin` rename | **Don't hand-merge.** Take upstream's lockfile, then run `bun install` to re-apply |

**Branding (Phase 1 — artwork & display names):**

| File | Our change |
| --- | --- |
| `packages/opencode/src/cli/logo.ts` | TUI logo / wordmark |
| `packages/opencode/src/cli/cmd/tui/app.tsx` | TUI title / display name |
| `packages/opencode/src/cli/cmd/tui/attention.ts` | Display-name anchor |
| `packages/ui/src/components/logo.tsx` / `logo.css` | Web logo component + styles |
| `packages/ui/src/components/favicon.tsx` | Favicon component |
| `packages/ui/src/assets/favicon/site.webmanifest` | App name in manifest |
| `packages/app/src/app.tsx` | Display-name anchor |
| `packages/desktop/electron-builder.config.ts` | `productName` (appId/publish are *deferred* — see below) |
| `packages/desktop/src/renderer/index.html` / `loading.html` | Window `<title>` / loading screen |
| `README.md` | Fork README |
| `sst.config.ts`, `infra/lake.ts`, `infra/stats.ts` | Infra naming |

> Merge guidance for branding files: our change is almost always a **string/asset
> swap**, not logic. On conflict, take upstream's structure/logic and re-apply our
> brand string or asset reference. If upstream restructures a logo component, port
> our asset reference into the new structure.

### C. Binary artwork (207 files)

Brand assets replacing opencode's, across `packages/desktop` (~150 icons:
`.icns`/`.ico`/PNG), `packages/console`, `packages/ui`, `packages/web`,
`packages/docs`, `packages/stats`, `packages/app`.

> Merge guidance: upstream rarely changes these. On a binary conflict, keep ours:
> `git checkout --ours <path> && git add <path>`. Only reconcile if upstream
> changed an asset's **dimensions/format** that a component now depends on.
> Regenerate from masters with `script/brand/generate.sh` rather than editing
> binaries by hand.

---

## Distribution (curl + GitHub Releases)

We ship **one** channel: prebuilt binaries attached to a GitHub Release, installed
via the `install` script. We deliberately do **not** publish to npm, Docker,
Homebrew, AUR, or the desktop auto-updater — upstream's `publish.yml` does all
that and stays gated off on this fork (`if: github.repository == 'anomalyco/opencode'`).

- **Binary / command:** `aiand-code` (we reserve the shorter `aiand` for a future
  umbrella CLI that can dispatch `aiand code …`).
- **Install:** `curl -fsSL https://raw.githubusercontent.com/aiandlabs/aiand-code/dev/install | bash`
- **Cut a release:** Actions → **release** → Run workflow → enter a version
  (e.g. `1.0.0`). It creates a draft release, builds macOS + Linux binaries via
  `packages/opencode/script/build.ts`, uploads the archives, then publishes.
- **Platforms:** macOS + Linux only (no Windows). Windows users use WSL.

See git history / PRs for the original implementation discussion.

---

## Deferred rename (Phase 2 — intentionally NOT done)

The fork is rebranded at the **artwork and CLI-command** level only. The deeper
functional rename is deliberately deferred because each piece needs a
back-compat decision and widens the merge-conflict surface. Still `opencode` on
purpose:

- npm scope `@opencode-ai/*` and the workspace package name `opencode`
  (the `web` package depends on it by that name)
- env-var prefix `OPENCODE_*`
- config dirs `~/.config/opencode` and `.opencode`
- domains `opencode.ai` / `opencode.com`
- electron `appId` / URL schemes / auto-update `publish` owner+repo
- internal user-agent / i18n strings

Do **not** sweep these in a single pass. Each is its own scoped change with a
migration story (e.g. read both `~/.aiand-code` and `~/.opencode`).
