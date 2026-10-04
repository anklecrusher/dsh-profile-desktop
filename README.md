# dsh-profile-desktop

Source of truth for the **DSH `desktop` profile** on this machine.

DSH writes to `%USERPROFILE%\.dsh\profiles\desktop` freely — the plugin market,
the plugin manager and `dsh plugin` all rewrite `cordis.patch.yml` and
`package.json` in place. This repository keeps the reviewed state of those files
under git so a bad write can be seen and reverted.

- **Live profile:** `C:\Users\ankle crusher\.dsh\profiles\desktop`
- **This repo:** `E:\GitHubWorkspace\own\opensource\dsh-profile-desktop`
- **Tracked:** the `profile/` directory — five config files, ~56 KB total
- **Not tracked:** `node_modules/` (42 MB, 122 packages), `*.bak-*`, `*.pre-*`,
  `.plugin-manager/`, `.dsh-market/discovery-compatibility-v1.json`

## Sync workflow

Edit here first, then push to the live profile. To pick up a change DSH made,
capture it back.

```powershell
# repo -> live profile  (apply reviewed state)
pwsh.exe -NoLogo -NoProfile -Command "& 'E:\GitHubWorkspace\own\opensource\dsh-profile-desktop\scripts\apply.ps1'"

# live profile -> repo  (capture what DSH changed, then review with git diff)
pwsh.exe -NoLogo -NoProfile -Command "& 'E:\GitHubWorkspace\own\opensource\dsh-profile-desktop\scripts\capture.ps1'"
```

`capture.ps1` never commits. Read `git diff` before you do — that diff is the
only warning you get that the market rewrote something.

**Restart the desktop app after applying.** Plugin rows load at boot.
`cordis.patch.yml` is hot-reloaded (a patch edit took effect without a restart
on 2026-10-04), but bundle membership in `package.json` is not.

## Why copies and not links

Skill entrypoints under `.codex\skills` use junctions, per
`_workspace\link-map.md`. **Do not do that for these files.** DSH writes config
through `@deepseek-ai/dsh-atomic-write`, which writes a temp sibling and renames
it over the target. Its own source documents the consequence:

> The rename also replaces a symlinked target itself instead of writing through
> to its referent.

Measured on this machine (Node 24.21.0, DSH 0.2.0-rc.2):

| Method | Result |
| --- | --- |
| Hard link (`mklink /H`) | **Link silently severed.** The profile gets a fresh file; the E: source keeps the old bytes; link count drops to 1. |
| Directory junction (`mklink /J`) | Passes through correctly — the write lands in the source directory. |

So a hardlink would desynchronise on the first market toggle and you would not
notice. Junction-per-directory works, but the whole profile directory would then
live inside the repo including `node_modules`, so this repo uses copies.

## Installed bundles

Load order is `dsh.profile.bundles` in `profile/package.json`. Later layers
override earlier ones.

| # | Bundle | Source | Version | Why |
| --- | --- | --- | --- | --- |
| 1 | `@deepseek-ai/dsh-base` | host | 0.2.0-rc.2 | Shipped core |
| 2 | `@deepseek-ai/dsh-web-app` | host | 0.2.0-rc.2 | Web GUI |
| 3 | `@local/dsh-gitbash-tool` | link → `own/opensource/dsh-gitbash-tool` | 1.0.0 | Real POSIX Git Bash tool for Windows. Replaces the disabled `tool-bash`. |
| 4 | `@local/tavily-mcp` | link → `own/opensource/tavily-mcp-bundle` | 1.0.0 | Config-only bundle; contributes the native Tavily MCP row that **layer 7 disables**. |
| 5 | `dsh-notify-me` | `github:chromoany/dsh-notify-me#8f836ad1` | 1.5.3 | Turn-completion notifications. Pinned to a commit, not a tag. |
| 6 | `dsh-at-file` | npm | 0.6.3 | Codex-style `@file` mentions in the composer. |
| 7 | `dsh-mcp-lazy` | npm | 0.4.1 | Lazy MCP gateway — the only path that should serve Tavily. |
| 8 | `dshmarket` | npm | 1.66.8 | In-GUI plugin market. Writes to `cordis.patch.yml`. |
| 9 | `dsh-mnemon` | npm | 0.5.23 | Layered cross-session memory. 17 sub-components. |

Layers 3 and 4 resolve by absolute path (`link:E:\...`), so this file set only
works on this machine as-is.

## Tavily: read this before touching it

Tavily is served through **`dsh-mcp-lazy` only**. The native row that
`@local/tavily-mcp` contributes is disabled by the override at the bottom of
`profile/cordis.patch.yml`:

```yaml
- id: tavily-mcp
  disabled: true
```

### Why

`@deepseek-ai/dsh-mcp-client` registers all five Tavily tools as native tools.
Their schemas enter **every** request (measured against the live server,
`tavily-mcp 4.0.4`):

| Tool | Schema |
| --- | --- |
| `tavily_search` | 3,119 B (~780 tok) |
| `tavily_crawl` | 2,081 B (~520 tok) |
| `tavily_map` | 1,394 B (~348 tok) |
| `tavily_extract` | 937 B (~234 tok) |
| `tavily_research` | 816 B (~204 tok) |
| **total** | **8,347 B ≈ 2,087 tok/request** |

`dsh-mcp-lazy` keeps one fixed `mcp` tool (~1,525 B ≈ 381 tok) in front of them
and connects the server on first use. **Saving ≈ 1,706 tokens per request.**

The model calls `mcp({ tool: "tavily__tavily_search", args: {...} })`.
Tool names behind the gateway are `tavily__<name>`.

### The trap

**Disabling `@local/tavily-mcp` in the dsh-market UI deletes the override.** The
market's toggle means "make this bundle enabled" and rewrites the row to
`disabled: false`, or removes the disable entirely. Its log said:

```
{"event":"toggle","detail":"@local/tavily-mcp -> on: fiber=true"}
{"event":"patch","detail":"enabled row tavily-mcp in cordis.patch.yml"}
```

With both paths live the gateway reports on every status call:

```
⚠ 1 server (tavily) is configured both here and in
  @deepseek-ai/dsh-mcp-client ... Remove it from one of the two.
```

and the token saving is silently lost. Recovery: restore the `tavily-mcp:
disabled: true` row (this repo has it), then restart.

Control Tavily through the `mcp-lazy` row instead — set `disabled: true` on a
*server entry* there (`servers[].disabled`), or raise its `idleTimeout`.

### Credentials

The API key comes from `%USERPROFILE%\.dsh\.env` as `TAVILY_API_KEY`, read into
`process.env` at boot. A key saved through the credentials UI is **not**
visible here — the credentials store is deliberately never materialised into the
environment. `.env` is frozen at launch: restart after editing it.

No secret is stored in this repository.

## Known traps

**pnpm withholds versions younger than 24 hours.** `dsh plugin add <pkg>` can
silently resolve an older release; if that older release predates a peer-range
update, DSH then refuses the install as incompatible. This happened with
`dsh-mcp-lazy` (0.4.0 rejected, 0.4.1 accepted) and `dsh-mnemon` (0.5.24 was
10.8 h old, so 0.5.23 installed instead — peer ranges verified identical first).
Fix: pin the version explicitly, `add <pkg>@<version>`.

**DSH gates installs on peer ranges.** In `@deepseek-ai/dsh-app-boot`'s
`evaluatePluginCompatibility`, only peers named `@deepseek-ai/dsh` or
`@deepseek-ai/dsh-*` are checked, with `includePrerelease: true`. `cordis` and
`schemastery` are not gated. A rejected install rolls back `package.json`,
`pnpm-lock.yaml` and `node_modules` automatically.

**The `desktop` profile is reserved.** Bare `dsh --profile desktop <anything>`
fails with *"profile desktop is managed exclusively by the Electron
application"*. Only the desktop app's own bundled CLI can manage it:

```
"D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop <cmd>
```

## Recovery

```powershell
cd "C:\Users\ankle crusher\.dsh\profiles\desktop"
git -C "E:\GitHubWorkspace\own\opensource\dsh-profile-desktop" show HEAD:profile/cordis.patch.yml > cordis.patch.yml
git -C "E:\GitHubWorkspace\own\opensource\dsh-profile-desktop" show HEAD:profile/package.json   > package.json
```

Then restart the app. To drop a plugin entirely:

```
dsh plugin --profile desktop remove <pkg>
```

`node_modules` is rebuilt from `package.json` + `pnpm-lock.yaml`; it is never
recovered from this repo.
