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
