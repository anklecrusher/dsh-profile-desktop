# DSH Cross-PC Configuration and Tool Sync

Agent runbook for moving this Windows DSH **desktop** installation to another
computer. The profile mirror is a template, not the live profile. The live
profile is `%USERPROFILE%\.dsh\profiles\desktop`.

Read "Machine inventory outside this repo" before assuming a clone is enough.
As of 2026-10-27 all seven self-authored source repositories have public remotes,
so a clone-based migration is possible — but they are separate repositories, not
part of this one, and every credential still has to be re-entered by hand.

## What this repo carries

| Path | What it is | Portable as-is? |
| --- | --- | --- |
| `profile/package.json` | 24 bundle rows, 20 dependencies | no — seven absolute `link:` / `file:` specs |
| `profile/cordis.patch.yml` | the entire patch layer: model providers, MCP servers, mnemon, ds-bot mobile bridge, image-gen | mostly — holds a few machine paths |
| `profile/pnpm-lock.yaml` | exact dependency graph | no — same absolute paths as `package.json` |
| `profile/pnpm-workspace.yaml` | pnpm settings incl. `minimumReleaseAgeExclude` | yes |
| `profile/cordis.yml` | loader root (empty array) | yes |
| `global/AGENTS.md` | user-global agent instructions, applied to every session | review machine paths first |
| `vendor/ds-bot/ds-bot-0.1.3.tgz` | the only registry-less dependency; `apply.ps1` restores it | yes |
| `scripts/apply.ps1`, `scripts/capture.ps1` | repo ↔ live profile sync | yes |

## What does NOT move automatically

### Secrets — re-enter on the target, never commit

| Where | Names |
| --- | --- |
| `%USERPROFILE%\.dsh\.env` | `TAVILY_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `DEEPSEEK_API_KEY` |
| DSH credentials store (`.credentials.yaml`) | `BEEAPI_API_KEY`, `BEEAPI_ANTHROPIC_API_KEY`, `QWEN_TOKEN_PLAN_CN_API_KEY`, `DSH_IMAGE_GEN_OPENAI_COMPAT_KEY`, `ANTIGRAVITY_OAUTH_1` |
| Cloudflare tunnel (ds-bot mobile bridge) | `%USERPROFILE%\.cloudflared\cert.pem`, `<tunnel-id>.json`, `config.yml` |

`.env` is snapshotted at launch — restart after editing it. The credentials store
is deliberately never materialised into `process.env`, which is why Tavily and
GitHub read `.env` while the model routes and image-gen read the store.

### Self-authored bundles and tools — separate repositories

The profile references these by absolute path; the code lives in its own
repositories. All seven have public remotes as of 2026-10-27.

| Bundle | Local path under `E:\GitHubWorkspace\own\opensource\` | Remote | State 2026-10-27 |
| --- | --- | --- | --- |
| `@local/dsh-gitbash-tool` | `dsh-gitbash-tool` | `anklecrusher/dsh-gitbash-tool` | pushed |
| `@local/tavily-mcp` | `tavily-mcp-bundle` | `anklecrusher/tavily-mcp-bundle` | pushed |
| `@local/dsh-beeapi-replay-compat` | `dsh-beeapi-replay-compat` | `anklecrusher/dsh-beeapi-replay-compat` | committed + pushed 2026-10-27 |
| `@local/dsh-mole-tool` | `dsh-mole-tool` | `anklecrusher/dsh-mole-tool` | pushed 2026-10-27 |
| `@local/dsh-latex-tool` | `dsh-latex-tool` | `anklecrusher/dsh-latex-tool` | pushed 2026-10-27 |
| `@local/windows-mcp` | `windows-mcp-bundle` | `anklecrusher/windows-mcp-bundle` | committed + pushed 2026-10-27 |
| OpenDesign MCP bridge (not a bundle) | `open-design-mcp-bridge` | `anklecrusher/open-design-mcp-bridge` | pushed 2026-10-27 |
| `ds-bot` 0.1.3 | vendored in this repo | upstream `QingJ01/DS-Bot-App` | tarball committed here |

`dsh-mcp-lazy`'s `open-design` entry also needs `D:\OpenDesign` (the GUI app) and
the bridge's own patch step (`patch-opendesign-clm.mjs`) applied to that install.

### Other DSH profiles

| Profile | What it is | Portable? |
| --- | --- | --- |
| `desktop` | the one this repo mirrors | as described here |
| `open-design` | OpenDesign's headless DSH runtime profile. Depends on `file:D:/OpenDesign/resources/open-design/agent-runtimes/deepseek-harness/open-design-dsh-runtime-0.1.0.tgz` | only where OpenDesign is installed; its patch layer still defaults to the `beeapi` route |
| `web` | empty two-bundle profile created by the standalone CLI | not used; recreate or ignore |

### Local executables the profile assumes

| What | Where on this machine | Note |
| --- | --- | --- |
| DSH desktop | `D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness` | 0.2.1-rc.3 — note the `D:` install root |
| Node | `C:\Users\ankle crusher\scoop\apps\nodejs-lts\current\node.exe` (24.21.0) | absolute path inside the `open-design` MCP row |
| Git Bash | `C:\Users\ankle crusher\scoop\apps\git\current\bin\bash.exe` | plugin probes standard Git for Windows, Scoop and PATH; no `bashPath` pinned |
| TeX Live 2026 | `D:\Program Files (x86)\texlive\2026\bin\windows` | `latex_doctor` probes; ctex projects need xelatex |
| Mole `mo` | `C:\Users\ankle crusher\scoop\shims\mo.exe` | `mole-tool` probes |
| mnemon CLI | npm wrapper `@mnemon-dev/mnemon` on PATH, v0.2.13 | the Go binary under `%LOCALAPPDATA%` once documented in README is gone |
| cloudflared | `C:\Users\ankle crusher\scoop\shims\cloudflared` | plus the tunnel files under `~\.cloudflared` |
| OpenDesign | `D:\OpenDesign` | install, then patch per `open-design-mcp-bridge/README.md` |
| Python 3.13.2 | `D:\Program Files\python.exe` | `PYTHONUTF8=1` is set; see `global/AGENTS.md` |

### User environment variables (`HKCU\Environment`)

- `PYTHONUTF8=1` — critical: without it Python writes GBK on a zh-CN console and
  Git Bash output is mojibake.
- `PATH` entries the tools depend on: the Scoop `nodejs-lts` root and `bin`,
  `%USERPROFILE%\.local\bin`, `scoop\shims`, OfficeCLI, TeX Live, the Ego install.
- The same registry key holds unrelated secret-bearing variables. Do **not**
  bulk-copy or print the environment block; re-create only the two items above.
- The script that originally fixed this machine's user `PATH` (append the Scoop
  Node directory while preserving `REG_EXPAND_SZ`, then broadcast
  `WM_SETTINGCHANGE`) is `%USERPROFILE%\.dsh\backups\fix-user-path.py`.

### Skills

DSH discovers persistent skills under `%USERPROFILE%\.agents\skills`; Codex uses
`%USERPROFILE%\.codex\skills`. Both are junction farms whose sources live under
`E:\GitHubWorkspace`, so they need a separate transfer (or fresh junctions).

| `.agents\skills` entry (DSH) | Source |
| --- | --- |
| `academic-figure-style` | `own/opensource/codex-skills/skills/academic-figure-style` |
| `agent-reach` | `external/upstream/agent-reach` |
| `ego-browser` | `C:\Users\ankle crusher\.local\share\ego\ego-skills` (not on `E:`) |
| `humanizer` | `external/upstream/humanizer` |
| `interview-qbank-builder` | `own/opensource/interview-qbank-builder` |
| `officecli` | `external/upstream/OfficeCLI/skills/officecli` |
| `ppt-master` | `external/upstream/ppt-master/skills/ppt-master` |
| `word-comment-author` | `own/opensource/codex-skills/skills/word-comment-author` |

`latex-project-workflow` is not a junction — the `@local/dsh-latex-tool` plugin
serves it. `.codex\skills` additionally carries `ajian-content-illustrations`,
`browser-skill`, `codex-image-studio`, `gpt-image-2-style-library`,
`idea-validation-agent`, `pdf`, `playwright`, `project-health-audit`,
`storage-analyzer`, `thread-handoff`, `workflow-to-skill` and others; see
`E:\GitHubWorkspace\_workspace\link-map.md` for the authoritative table.

### Data — a migration decision, not a profile sync

| Store | Path | Size / content |
| --- | --- | --- |
| Chat sessions | `%USERPROFILE%\.dsh\sessions` | conversations |
| Attachments | `%USERPROFILE%\.dsh\attachments`, `.dsh\cache\attachments` | uploaded files |
| Workspaces / pinning | `%USERPROFILE%\.dsh\storages\workspace.json` | 7 workspaces, 24 archived sessions |
| Reminders | `%USERPROFILE%\.dsh\storages\schedule.json` | scheduled tasks |
| ds-bot state | `%USERPROFILE%\.dsh\bot` | 4 bots, 1 group room, memories, mobile `bridge.json` |
| Mnemon | `D:\Users\ankle crusher\Documents\.mnemon` | `data/`, `documents/`, `runtime/` (runtime memory, documents, spaces) |
| Mnemon CLI default | `C:\Users\ankle crusher\.mnemon` | created by CLI calls without `--data-dir`; **not** the configured store |
| UI preferences | `%APPDATA%\@deepseek-ai\dsh-desktop` | window state, renderer storage |
| Regenerable | `.dsh\cache`, `.dsh\dsh-runtimes`, `.dsh\speech-to-text`, `node_modules` | do not copy |

### Residue from uninstalled plugins

`dsh-chat-import` (0.25.2) was installed on 2026-10-05 and uninstalled on
2026-10-20. Nothing in the profile references it any more: `dsh plugin --profile
desktop list` reports exactly the 20 dependencies in `package.json`, there is no
bundle row and no patch entry, and the README was corrected. The single leftover
is its old data directory `%USERPROFILE%\.dsh\dsh-chat-import\` (`ignores.json`,
`imports.json`, `scan-cache.json`), which is safe to delete.

## Source computer

1. Close DSH before capturing the final state so files are not changing during
   the copy.
2. Run the mirror's capture script from PowerShell:

   ```powershell
   & .\scripts\capture.ps1
   git diff -- profile global
   ```

3. Read every diff. Confirm it contains no secrets and preserves the disabled
   native `tavily-mcp` override. Do not commit automatically.
4. Check **every** source repository before transferring:

   ```powershell
   foreach ($p in 'dsh-gitbash-tool','tavily-mcp-bundle','dsh-beeapi-replay-compat',
                  'dsh-mole-tool','dsh-latex-tool','windows-mcp-bundle',
                  'open-design-mcp-bridge') {
     git -C "E:\GitHubWorkspace\own\opensource\$p" status --short --branch
   }
   ```

   Before 2026-10-27 five of these existed only on this machine (two had no
   commits at all); they are now pushed. Re-check anyway: any local change that
   is not pushed would be missing on the target. Never push on the user's behalf
   without authorization.
5. Commit the reviewed profile capture in this repo, then push this repo and
   every plugin repository that has local changes.

## Target computer

1. Install the DSH desktop app (0.2.1-rc.3 or newer) and Git for Windows. Start
   DSH once so it creates `%USERPROFILE%\.dsh\profiles\desktop`, then close it.
2. Clone this repo and the six self-authored repositories it links to:

   ```powershell
   git clone https://github.com/anklecrusher/dsh-profile-desktop.git
   foreach ($p in 'dsh-gitbash-tool','tavily-mcp-bundle','windows-mcp-bundle',
                  'dsh-beeapi-replay-compat','dsh-mole-tool','dsh-latex-tool',
                  'open-design-mcp-bridge') {
     git clone "https://github.com/anklecrusher/$p.git" "E:\GitHubWorkspace\own\opensource\$p"
   }
   ```

   `ds-bot` needs nothing here — its tarball is committed in this repo.
3. Recreate the absolute paths. `package.json` and `pnpm-lock.yaml` contain, in
   total, seven machine paths:

   ```text
   link:E:/GitHubWorkspace/own/opensource/dsh-gitbash-tool
   link:E:/GitHubWorkspace/own/opensource/tavily-mcp-bundle
   link:E:/GitHubWorkspace/own/opensource/windows-mcp-bundle
   link:E:/GitHubWorkspace/own/opensource/dsh-beeapi-replay-compat
   link:E:/GitHubWorkspace/own/opensource/dsh-mole-tool
   link:E:/GitHubWorkspace/own/opensource/dsh-latex-tool
   file:C:/Users/ankle crusher/.dsh/backups/ds-bot/ds-bot-0.1.3.tgz
   ```

   If the target keeps the same drive layout and user name, nothing changes. If
   not, edit both files in the target checkout — **never commit target-only
   paths back to this mirror**.
4. Restore the vendored tarball. `scripts/apply.ps1` copies
   `vendor/ds-bot/ds-bot-0.1.3.tgz` to `%USERPROFILE%\.dsh\backups\ds-bot\` when
   it is missing, which matches the recorded path when the user is
   `ankle crusher`. Otherwise place it wherever step 3 points.
5. Review `global/AGENTS.md` for paths, user name and tool locations. `apply.ps1`
   copies it into place without a separate backup.
6. Apply the reviewed profile:

   ```powershell
   & .\scripts\apply.ps1
   ```

   It copies the five profile files, `AGENTS.md`, and the ds-bot tarball; it never
   installs packages and never commits.
7. Install dependencies through the target desktop app's bundled CLI, not the
   standalone `dsh --profile desktop` command (that profile is reserved):

   ```powershell
   & "<DSH install>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop install
   ```

   Use the same `<DSH install>` path only as an example — on this machine it is
   `D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness\...`.
8. Re-enter secrets: `.env` with the three names above, then the credentials store
   through **Settings → Account → Credentials** with the five names above. Never
   copy `.credentials.yaml` or print key values.
9. Review every MCP entry in `profile/cordis.patch.yml`. Preserve the
   non-secret endpoint/transport/timeouts and the enabled/disabled state. For
   each local `stdio` server verify the executable exists and update
   machine-specific commands: the `open-design` row pins an absolute Node path
   and reads `D:\OpenDesign`; `mnemon` pins `dataDir`.
10. Restore the ds-bot mobile bridge if it is wanted: reinstall `cloudflared`,
    put `cert.pem`, the tunnel `<uuid>.json` and `config.yml` back under
    `%USERPROFILE%\.cloudflared\`, fix the `credentials-file` path there if the
    user name differs, then `cloudflared service install` (elevated). The
    `publicUrl` in the `bot` patch row must match the hostname in `config.yml`.
    A backup copy of all three files, plus short restore/revoke notes, sits in
    `%USERPROFILE%\.dsh\backups\cloudflared\`.
11. Recreate the skill junctions listed above (or clone the sources and let the
    links point at them), install the mnemon CLI (`npm i -g @mnemon-dev/mnemon`),
    and copy whatever data from the table the user wants.
12. Restart DSH and verify:
    - the app boots with 24 bundles and no compatibility errors
    - `dsh plugin --profile desktop list` reports 20 packages
    - a harmless UTF-8 check: `printf '%s\n' '中文 UTF-8'`
    - a model turn works on the default route (`qwen-token-plan-cn`,
      `deepseek-v4.1-flash`) — if it fails, `QWEN_TOKEN_PLAN_CN_API_KEY` is missing
    - `mcp` connects to tavily/github on first use, and no duplicate-server warning
    - `latex_doctor`, `mole_status`, `mnemon` and a `winmcp` screenshot all answer
    - ds-bot starts and the mobile bridge is reachable at the tunnel hostname

## Machine-specific MCP and tool rules

- Tavily is served through `dsh-mcp-lazy` only; the native `tavily-mcp` row stays
  disabled. Enabling it in the market UI deletes that override and costs about
  1,706 tokens per request. Details in README.md.
- `open-design` goes through the same lazy gateway, with an absolute Node path
  because the desktop app's PATH lacks Scoop's Node.
- `windows-mcp` deliberately uses the **native** MCP client, not the lazy
  gateway: the gateway renders images as text and kills screenshots.
- `ds-bot`'s mobile bridge only starts when `enabled: true` **and** `publicUrl`
  (or a cert path) is set. With the tunnel terminating TLS, the Cloudflare
  ingress must be `http://127.0.0.1:8788`.
- Never symlink `package.json` or `cordis.patch.yml`; DSH rewrites them with
  atomic replace. Plugin directories may be linked — that is the intended design.
- Do not blindly copy the whole `.dsh` directory over an existing target profile.
  Back up the target profile first and compare its configuration.