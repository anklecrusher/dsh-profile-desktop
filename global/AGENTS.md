# Global agent instructions

Applies to every DSH session on this machine, in every workspace. Loaded from
`$DSH_HOME/AGENTS.md` (`C:\Users\ankle crusher\.dsh\AGENTS.md`) by
`@deepseek-ai/dsh-agent-instructions` before any project-level `AGENTS.md`.

This file is for rules that are true everywhere. Project-specific rules belong
in that project's own `AGENTS.md`.

## Working with this user

- **Reply in Chinese.** Code, identifiers, config keys, file paths and quoted
  source stay in their original form.
- **Answer first, then justify.** Lead with the conclusion; put evidence after.
  The user reads the top of the message and stops when the answer is clear.
- **Evidence over assertion.** Before claiming something works, check it. Read
  the actual source, run the actual command, inspect the actual file. When a
  claim has been verified, say so; when it has not, say that too. The user has
  repeatedly caught reasoning errors that a check would have prevented.
- **Correct yourself in the open.** If something said earlier turns out to be
  wrong, say so plainly and restate. Do not quietly move on.
- **Do not commit or push without asking.** Local edits and local commits are
  fine when asked. Pushing to a remote is not.

## Scratch files and cleanup

**Leave no intermediate artifacts behind.** A finished task should add only what
the user asked for — not a trail of probe scripts, dumps, extracted trees and
scratch directories. The user has said plainly that leftovers after every task
are not acceptable, so treat cleanup as part of the task, not an optional extra.

**Confine scratch work to one directory per task**, created under the system
temp:

```bash
SCRATCH="${TMPDIR:-/tmp}/dsh-<topic>"; mkdir -p "$SCRATCH"
```

Put asar extracts, schema dumps, probe scripts, downloaded fixtures, throwaway
profiles, test venvs and every other by-product there. Do **not** scatter them
across the workspace, a project root, `$DSH_HOME`, or the profile directory —
those are the places the user has to look at afterwards, and they are where the
mess has actually accumulated. On this machine Git Bash maps `/tmp` to
`%TEMP%`, so both spellings reach the same place.

**Remove the scratch directory before reporting the task done**, and clean up as
you go rather than only at the end: a temp profile, a spawned server, a test venv
or an extracted tree should go as soon as the step needing it has finished, so a
long task does not accumulate.

**Never delete these** — they are deliverables or load-bearing, not scratch:

- the artifact the user asked for (plugin, bundle, document, report)
- anything the user named or asked to keep
- environments and installs a deliverable depends on (e.g. a conda env)
- tracked content of a git repository

**State what you removed.** One line in the final message naming the scratch
paths deleted, plus any by-product deliberately kept and why. If a probe script
looks genuinely reusable, ask before keeping it rather than leaving it in place.

## DSH plugin management

Every plugin installed on this machine is administered through the
version-controlled profile mirror described below. Follow this for **all**
plugin installs, upgrades and removals — including ones the user performs
through the market UI, which must then be captured.

### The profile is `desktop`, and it is reserved

```
dsh --profile desktop <anything>       # FAILS: "managed exclusively by the Electron application"
```

Use the desktop app's own bundled CLI instead:

```powershell
& "D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd" `
    plugin --profile desktop <add|remove|list|update> <package>
```

### The mirror

| | |
| --- | --- |
| Live profile | `C:\Users\ankle crusher\.dsh\profiles\desktop` |
| Tracked mirror | `E:\GitHubWorkspace\own\opensource\dsh-profile-desktop` |
| Bundles list | `profile/package.json` → `dsh.profile.bundles` |

```powershell
& 'E:\GitHubWorkspace\own\opensource\dsh-profile-desktop\scripts\apply.ps1'    # repo -> live
& 'E:\GitHubWorkspace\own\opensource\dsh-profile-desktop\scripts\capture.ps1'  # live -> repo
```

### Install workflow

1. Install (CLI above, or the market UI).
2. `capture.ps1`
3. `git diff` — **read it.** DSH and the market rewrite these files silently;
   the diff is the only warning. Commit only what you understand.
4. Restart the desktop app. `dsh.profile.bundles` is read at boot.

### Traps that have already cost real time

**pnpm withholds versions younger than 24 hours.** `add <pkg>` can silently
resolve an older release, which may then fail DSH's peer gate. Seen with
`dsh-mcp-lazy` (0.4.0 rejected, 0.4.1 accepted) and `dsh-mnemon` (0.5.24 was
10.8 h old, so 0.5.23 installed). Pin `<pkg>@<version>` when this bites.

**DSH gates installs on peer ranges.** `evaluatePluginCompatibility` checks only
`@deepseek-ai/dsh` / `@deepseek-ai/dsh-*` peers with `includePrerelease: true`.
`cordis` and `schemastery` are not gated. A rejected install rolls itself back.

**The market's bundle toggle deletes hand-written overrides.** Its "enable"
semantics rewrote `@local/tavily-mcp` to enabled and stripped the
`disabled: true` override, silently re-enabling a second Tavily path and losing
~1,706 tokens/request. `capture.ps1` warns when that line is missing. Do not
disable `@local/tavily-mcp` from the market UI.

**Never link the profile's config files.** DSH writes `package.json` and
`cordis.patch.yml` through `writeFileAtomic` (temp file + rename), which
replaces a symlinked target rather than writing through it — a hardlink is
severed without error. **This does not apply to plugin directories**, which DSH
only reads: self-authored plugins are referenced with `link:E:/...` and that is
the intended design.

## Self-authored plugins

Source lives in its own repository under
`E:\GitHubWorkspace\own\opensource\<plugin>\`, never inside the profile mirror.
The profile references it by absolute path:

```jsonc
// profile/package.json
"dependencies": { "@local/my-plugin": "link:E:/GitHubWorkspace/own/opensource/my-plugin" }
```

`@local/dsh-gitbash-tool` is the reference implementation — copy its shape
(`entry.js` cache-busting import, `cordis.patch.yml` with an `insert` row,
`test-harness.mjs`). Full anatomy and the registration workflow are in
`E:\GitHubWorkspace\own\opensource\dsh-profile-desktop\README.md`.

## Workspace conventions

`E:\GitHubWorkspace` is the long-term source of record for skills, plugins and
projects. Layout and rules: `_workspace\README.md`, `_workspace\link-map.md`.

- Owned projects → `own\opensource\` or `own\private\`
- Upstream clones → `external\upstream\`; forks → `external\forks\`
- Each project directory is its own git repository; the workspace root is not
- Prefer the scripts in `_workspace\scripts\` for skill/plugin entrypoint work
- Do not invent a target directory for a new project; ask

## Memory

`dsh-mnemon` provides cross-session memory (`~\.mnemon`, global scope, so it
never writes into a workspace). The `mnemon` CLI is installed at
`%LOCALAPPDATA%\Programs\mnemon\mnemon.exe`.

Note the division of labour: **this file and project `AGENTS.md` files are
injected deterministically every turn; mnemon's Project Documents are retrieved
only when searched.** A rule that must always apply belongs in an `AGENTS.md`,
not only in mnemon. Mnemon is for accumulating context, not for guaranteeing it.

## Web search and GitHub

Two remote extension servers sit behind the lazy gateway (package
`dsh-mcp-lazy`, row id `mcp-lazy`). Their tool metadata is cached on disk at
`~/.dsh/storages/mcp-lazy/cache.json`, so `search`/`describe` work in a **fresh session
with no prior connect** — reach for these first, never a web UI or a browser.

### Search: built-in `web_search` first (DeepSeek Search API), Tavily as backup

```js
web_search({ queries: ["..."] })            // default channel
```

`web_search` and `web_fetch` are wired to `@deepseek-ai/dsh-web-deepseek-api`
since 2026-10-23: `POST https://api.deepseek.com/v1/tools/search` and
`/v1/tools/fetch`, billed $0.75 per 1,000 successful requests (not per result,
and not per token). They authenticate with `DEEPSEEK_API_KEY` from
`$DSH_HOME/.env`, on api.deepseek.com — independent of the beeapi chat route.

Reach for `web_search` first. Measured over 10 mixed zh/en queries on
2026-10-23: 0.47 s/query, 76% of results carry a publication date, and each
result carries `rerank_score` and `authority`; Tavily took 4.18 s and dated 0%.

Fall back to Tavily only when one of these is true:

- **The result set is dominated by one site.** DeepSeek averaged 2.9 of 10
  results on a repeated domain, with one query at 5/10 from a single host.
- **The fact needs a second opinion.** The two engines share almost nothing —
  measured domain overlap Jaccard 0.07 — so Tavily is a genuinely independent
  view, not a duplicate.
- **DeepSeek fails** (402 balance, 429 rate limit, 5xx).

```js
mcp({ server: "tavily", tool: "tavily_search",
      args: { query: "...", max_results: 6, search_depth: "advanced" } })
```

- Cost: the gateway adds ~16-20 tokens per tool name plus a one-time discovery
  call, so for a single known URL plain `curl` is still cheaper.
  `tavily_research` is a deep-research call and can run for minutes
  (`toolCallTimeoutMs` is 180000).
- `web_fetch` now goes through the DeepSeek Fetch API and returns page Markdown.
  If it fails on a specific site, fall back to `curl https://r.jina.ai/<url>`.
- Both search tools draw from separate accounts, so one running out of balance
  does not disable the other.

### GitHub goes through the official MCP server

```js
mcp({ server: "github", tool: "get_me", args: {} })
```

49 tools, reachable as `github__<name>` (`list_issues`, `issue_read`,
`list_pull_requests`, `pull_request_read`, `search_code`, `list_commits`,
`get_file_contents`, ...).

- Endpoint `https://api.githubcopilot.com/mcp/`; bearer PAT read from
  `GITHUB_PERSONAL_ACCESS_TOKEN` in `$DSH_HOME/.env` — the same token the
  `gh` CLI holds (account `anklecrusher`). There is no OAuth support in the
  gateway, so a plaintext bearer PAT is the only path.
- **Do not** follow the DSH docs example and install
  `@modelcontextprotocol/server-github`: that package is deprecated on npm.
  The hosted endpoint above is the replacement.
- Writes (`issue_write`, `create_pull_request`, `merge_pull_request`,
  `create_or_update_file`, `push_files`, ...) take effect **immediately with no
  approval prompt**. Name the repo and the action before mutating anything, and
  default to read-only.
- Do not call `connect` as a ritual. Only connect when the cache is cold, i.e.
  right after a server was added.

### Tool-call shape — a mistake already made once

`server` and `tool` are two separate fields:

```js
mcp({ server: "github", tool: "list_issues", args: {...} })   // correct
mcp({ tool: "github__list_issues", args: {...} })             // WRONG
```

Omitting `server` does not raise an error — the gateway answers with a plain
status summary, which reads like a successful call. If a call returns a server
list instead of data, this is why.

> Names here were verified by character code, not by display: this UI can render
> `mcp` as "extension". Trust the bytes in `node_modules/` and `cache.json`.
