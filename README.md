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

## Why the profile files are copied, not linked

This applies **only** to the five config files in `profile/`. Plugin code is
linked — see [Self-authored plugins](#self-authored-plugins).

Skill entrypoints under `.codex\skills` use junctions, per
`_workspace\link-map.md`. **Do not do that for these config files.** DSH writes
them through `@deepseek-ai/dsh-atomic-write`, which writes a temp sibling and
renames it over the target. Its own source documents the consequence:

> The rename also replaces a symlinked target itself instead of writing through
> to its referent.

Measured on this machine (Node 24.21.0, DSH 0.2.0-rc.2):

| Method | Result |
| --- | --- |
| Hard link (`mklink /H`) | **Link silently severed.** The profile gets a fresh file; the E: source keeps the old bytes; link count drops to 1. |
| Directory junction (`mklink /J`) | Passes through correctly — the write lands in the source directory. |

A hardlink would desynchronise on the first market toggle and you would not
notice. A junction does work, but then the whole profile directory — including
`node_modules` — would live inside the repo. Copies keep the tracked set at five
files and make drift detectable by hash.

The distinction that matters: **DSH only rewrites files it owns**
(`package.json`, `cordis.patch.yml`). It never writes into a bundle's source
directory, so linking a *plugin's* directory is safe.

## Self-authored plugins

A plugin you write yourself is **not** stored in this repository's `profile/`
directory. It gets its own repository under
`E:\GitHubWorkspace\own\opensource\<plugin-name>\`, and this repository only
records that the profile depends on it, by absolute path:

```jsonc
// profile/package.json
"dependencies": {
  "@local/my-plugin": "link:E:/GitHubWorkspace/own/opensource/my-plugin"
},
"dsh": { "profile": { "bundles": [ /* ... */ "@local/my-plugin" ] } }
```

pnpm turns that `link:` into a directory symlink inside the profile's
`node_modules`:

```
C:\...\.dsh\profiles\desktop\node_modules\@local\my-plugin
        -> E:\GitHubWorkspace\own\opensource\my-plugin
```

This works. Both existing `@local/*` bundles are exactly this shape, and the
source on `E:` is the only copy — verified 2026-10-04.

### Why this is safe here, when the profile files are not

The reason config files must be copied and never linked (above) does not apply
to a plugin's **own** files. `writeFileAtomic` only ever rewrites
`package.json` and `cordis.patch.yml` — the files DSH owns. It never writes into
a bundle's source directory, so a symlink to `E:` is never renamed over. What
DSH does with a bundle directory is resolve and read it, and
`packageDirFromAnchor` uses `createRequire(...).resolve.paths(...)`, which
follows symlinks normally.

Rule of thumb:

| Path | Strategy |
| --- | --- |
| `profiles/desktop/package.json`, `cordis.patch.yml` | **copy** — DSH rewrites these |
| `node_modules/@local/<your-plugin>` | **symlink** — DSH only reads it |

### Anatomy of a self-authored plugin

`dsh-gitbash-tool` is the reference implementation; copy its shape.

```
my-plugin/
├── package.json          # name, and dsh.bundle.patch pointing at the patch file
├── cordis.patch.yml      # what rows to insert into the profile
├── entry.js              # cache-busting entry (see below)
├── index.js              # the actual implementation
├── test-harness.mjs      # offline test harness
└── README.md
```

Minimum `package.json`:

```json
{
  "name": "@local/my-plugin",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "main": "./entry.js",
  "exports": { ".": "./entry.js" },
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

Minimum `cordis.patch.yml`:

```yaml
- insert:
    - id: my-plugin
      name: '@local/my-plugin'
```

### The cache-busting entry point

Node caches ES modules by resolved URL for the whole process lifetime. Cordis
re-runs a plugin's `apply` on reload but cannot force a re-import, so editing
`index.js` has no effect until the app restarts. `dsh-gitbash-tool/entry.js`
works around this by importing the implementation through a unique
`?t=<timestamp>` URL on each activation. Reuse that file's approach.

### Registering a new self-authored plugin

```powershell
# 1. create and commit the plugin repo
cd E:\GitHubWorkspace\own\opensource
mkdir my-plugin; cd my-plugin
# ... author package.json, cordis.patch.yml, index.js, entry.js ...
git init; git add -A; git commit -m "Add my-plugin"

# 2. add it to the profile (desktop is reserved — use the app's own CLI)
& "D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd" `
    plugin --profile desktop add "@local/my-plugin@link:E:/GitHubWorkspace/own/opensource/my-plugin"

# 3. record it here
& .\scripts\capture.ps1
git diff                # expect: package.json (dependency + bundle row) and pnpm-lock.yaml
git add -A; git commit -m "Add my-plugin to the desktop profile"

# 4. restart the desktop app
```

Editing the plugin afterwards needs no profile changes — the symlink means the
profile already sees your edits. Toggle the plugin row (or restart) to reload.

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
| 9 | `dsh-mnemon` | npm | 0.5.23 | Layered cross-session memory. 17 sub-components. See below. |
| 10 | `dsh-better-sidebar` | npm | 0.24.1 | Right-sidebar workbench: file tree, editor, terminal, Git, side chat, subagent view. Requires DSH ≥ 0.2.0-rc.1. |

`dsh-better-sidebar` registers its tabs into **DSH's own right sidebar** (since
its v0.19.0) rather than drawing a panel of its own, so it augments the shipped
UI instead of replacing it. Its `cordis.patch.yml` carries a `!!js` guard that
disables its row when another enabled bundle already mounts the same package —
relevant only if an aggregate bundle is ever added, and that bundle would have
to come *before* this one in `dsh.profile.bundles` for the guard to see it.

Layers 3 and 4 resolve by absolute path (`link:E:\...`), so this file set only
works on this machine as-is.

## dsh-mnemon and its CLI

`dsh-mnemon` works in three layers. Only the third needs the `mnemon` CLI.

| Layer | Stored at | Needs CLI |
| --- | --- | --- |
| Runtime Memory (`USER.md` / `MEMORY.md`) | `~\.mnemon\runtime\` | no |
| Project Documents | `~\.mnemon\documents\` | no |
| Memory Spaces (graph, long-term) | `~\.mnemon\data\` | **yes** |

Storage root is `~\.mnemon` (the `global` default). It does not touch the
workspace, so it never collides with a project's own notes.

### mnemon CLI

Installed 2026-10-04 at
`C:\Users\ankle crusher\AppData\Local\Programs\mnemon\mnemon.exe` (v0.2.10,
Apache-2.0, a 13.8 MB Go binary — no Node runtime needed).

That directory is deliberate: `findMnemonCommand` in
`dsh-mnemon-source-memory-spaces/native-cli.js` searches, in order,

1. the `cliPath` setting,
2. `$MNEMON_CLI_PATH`,
3. `PATH` for `mnemon.exe` / `mnemon.cmd`,
4. `%GOBIN%\mnemon.exe`, `%GOPATH%\bin\mnemon.exe`,
   **`%LOCALAPPDATA%\Programs\mnemon\mnemon.exe`**, `%ProgramFiles%\mnemon\mnemon.exe`.

Option 4 is why no `PATH` edit was needed. Verify with:

```powershell
node --input-type=module -e "import {findMnemonCommand} from 'dsh-mnemon-source-memory-spaces/native-cli'; console.log(findMnemonCommand({}))"
```

To upgrade, replace that `mnemon.exe` — or install the npm wrapper
(`npm i -g @mnemon-dev/mnemon`) and let discovery find it on `PATH` instead.

### Idle checkpoint review — the token cost

`dsh-mnemon` runs a background maintenance subagent after a turn completes and
the session goes idle. Defaults, from `DEFAULT_IDLE_REVIEW` in
`dsh-mnemon/lib/index.js`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `idleReviewMs` | `30000` | idle time before the review fires |
| `idleReview.enabled` | `true` | on by default |
| `idleReview.minIntervalMs` | `300000` | ≥5 min between reviews |
| `idleReview.maxPerSession` | `20` | cap per session |
| `idleReview.maxContextChars` | `24000` | inherited checkpoint size cap |
| `idleReview.maxTokens` | `4096` | output budget for the reviewer |
| `idleReview.provider` | `spawn` | child agent type (`fork` costs far more) |

Observed cost on this machine with `deepseek-v4.1-flash`: three consecutive
reviews reported **16.7 K / 86.2 K / 72.3 K** input tokens. The 86 K case is a
full inherited context; the reviewer's own output is capped at 4 K.

To cut the cost, in order of effect:

1. `idleReview.enabled: false` — stops it entirely; memory still works via the
   manual **Save to memory** button and agent-called tools.
2. Raise `minIntervalMs` (e.g. `1800000` for 30 min) and lower
   `maxPerSession`.
3. Lower `maxContextChars` — less inherited context, cheaper and blunter.

Set these under the `mnemon` row's config in `profile/cordis.patch.yml`.

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
