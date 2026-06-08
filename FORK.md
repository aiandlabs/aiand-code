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

We track upstream's latest **published stable release** (the tagged `vX.Y.Z`
commit), **not** the `dev` tip. Upstream's `dev` carries dozens of unreleased,
bleeding-edge commits between releases (~38/day) — for `v1.16.2`, `dev` was
already **88 commits ahead** of the release commit. Shipping those under a
release label is how bleeding-edge breakage reaches our users. By merging only
the release tag, our `dev` advances in stable hops and `auto-release` ships
exactly what upstream blessed.

`.github/workflows/upstream-sync.yml` runs nightly (06:00 UTC) and on demand. It
resolves upstream's `releases/latest` tag, fetches it, and merges that tag (a
no-op on days upstream hasn't cut a new release):

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

> ⚠️ **Always merge sync PRs with a real merge commit — never "Squash and merge"
> (and never rebase).** The fork's whole sync model depends on `upstream/dev`
> staying an *ancestor* of `dev`. A squash collapses the upstream commits into one
> new SHA that shares no ancestry with upstream, so the next nightly sync treats
> all of them as new again and re-surfaces every conflict you already resolved
> (and GitHub's fork banner reads "N commits behind" for the whole history).
> Squash-merge is disabled repo-wide on `aiandlabs/aiand-code` to enforce this,
> but if it ever resurfaces: the fix is to force-push `dev` back to the real
> 2-parent merge commit (identical tree, zero conflicts) rather than re-merging.

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
| `.github/workflows/release.yml` | Reusable distribution pipeline (curl + GitHub Releases) |
| `.github/workflows/auto-release.yml` | Nightly: ships the upstream version when it bumps |
| `.github/workflows/fork-release.yml` | Manual: ships an `-aiand.N` uplift on the current base |
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

**Managed backend repoint (point the managed offering at aiand infra):**

| File | Our change | Merge guidance |
| --- | --- | --- |
| `packages/opencode/src/cli/cmd/account.ts` | `defaultConsoleUrl` → `https://api.aiand.com` (env-overridable via `OPENCODE_CONSOLE_URL`) | Keep our default + env read; take upstream changes around it. The login `[url]` arg still overrides at runtime |
| `packages/opencode/test/cli/account.test.ts` | Asserts the aiand default URL | Mirror whatever value `account.ts` uses |
| `packages/core/src/plugin/provider/opencode.ts` | Sets the `opencode` provider gateway baseURL → `https://api.aiand.com/v1` (env-overridable via `OPENCODE_GATEWAY_URL`); upstream resolves this from models.dev (`https://opencode.ai/zen/v1`) | Keep the one `request.body.baseURL` line + the const; take upstream changes to the rest of the plugin |
| `packages/core/src/models-dev.ts` | Default model catalog → `https://api.aiand.com/v1` (serves `/api.json`) instead of `https://models.dev` (env-overridable via `OPENCODE_MODELS_URL`) | Keep our default string on the `source` line; take upstream changes around it |
| `packages/opencode/src/provider/provider.ts` | `defaultModel` fallback **and** `defaultModelIDs` (which feeds the TUI's `provider_default`) prefer a free (zero-cost) model, so first-run users don't spend credits; later choice still remembered via `recent` | Keep the `free`-first filter in both; take upstream changes around them |

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
- **Platforms:** macOS + Linux only (no Windows). Windows users use WSL.

### Versioning: two change streams, one `dev`

We track upstream *and* ship our own changes, so releases come in two shapes —
both built from `dev`, both published as normal (non-prerelease) GitHub Releases:

| Tag | Meaning | Cut by |
| --- | --- | --- |
| `v1.15.13` | Upstream's version 1.15.13 + our standing fork delta (branding, the CLI rename), no new uplift | `auto-release` (nightly, automatic) |
| `v1.15.13-aiand.1`, `…-aiand.2` | The above **+ our N-th uplift** (a fork change shipped between upstream bumps) | `fork-release` (manual button) |

The `-aiand.N` counter is **scoped to the upstream base**, so it auto-resets when
upstream bumps (e.g. `1.15.14-aiand.1`). It is computed from existing release
tags at build time — **no counter is stored and we never edit
`packages/opencode/package.json`'s `version`**, which is what keeps the nightly
upstream-sync conflict-free.

Why this works without touching the install path:
- The `install` script resolves "latest" via GitHub's `/releases/latest`, which
  picks the most recent **non-prerelease** release by `created_at` — *not* by
  semver precedence. So a freshly published `…-aiand.N` immediately becomes what
  `curl | bash` serves, as long as we never pass `--prerelease`.
- `packages/script/src/index.ts` passes `OPENCODE_VERSION` through verbatim and
  keeps the channel `latest` for anything not starting with `0.0.0-`, so the
  suffix doesn't flip the build into a "preview" channel. `--version` then reports
  the exact upstream base + uplift, which is great for bug reports.

### Cutting releases

- **Upstream version (automatic):** nothing to do. `auto-release` runs nightly at
  07:00 UTC (1h after `upstream-sync`), reads `dev`'s version, and ships it if no
  release exists for that base yet.
- **Your own uplift (manual):** merge your change to `dev` (prefer *added* files —
  golden rule #1), then **Actions → fork-release → Run workflow**. It auto-computes
  the next `-aiand.N` for the current base, builds macOS + Linux, and publishes.
- **One-off explicit version:** **Actions → release → Run workflow** and type an
  exact version. `release.yml` is the reusable pipeline both of the above call.

All three create a draft release, build via `packages/opencode/script/build.ts`,
upload the archives, then un-draft. See git history / PRs for implementation detail.

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
