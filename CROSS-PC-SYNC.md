# DSH Cross-PC Configuration and Tool Sync

Agent runbook for moving this Windows DSH desktop profile to another computer.
The profile mirror is a template, not the live profile. The live profile is
`%USERPROFILE%\.dsh\profiles\desktop`.

## What Moves

- Profile configuration: `profile/package.json`, `profile/cordis.patch.yml`,
  `profile/pnpm-lock.yaml`, `profile/pnpm-workspace.yaml`, and
  `profile/cordis.yml`.
- Global agent instructions: `global/AGENTS.md`. Review machine-specific paths
  before applying it on another computer.
- Self-authored source repositories, transferred separately from this mirror:
  `dsh-gitbash-tool` and `tavily-mcp-bundle`. The current public remotes are
  `https://github.com/anklecrusher/dsh-gitbash-tool.git` and
  `https://github.com/anklecrusher/tavily-mcp-bundle.git`.
- Registry and Git-hosted plugin dependencies are described by
  `package.json` and locked by `pnpm-lock.yaml`; install them again on the target.

## What Does Not Move Automatically

- `.dsh/.env`, `.dsh/.credentials.yaml`, API keys, OAuth tokens, or other
  credentials. Never commit, print, or copy secrets into this repository. Set
  credentials up securely on the target computer.
- `node_modules`, DSH runtimes, cache, temp files, timestamped backups, and
  plugin-manager state. Rebuild dependencies using the target DSH installation.
- Chat sessions, attachments, and external memory databases. These are data
  migrations, not profile migrations; handle them separately when requested.

## Safety Rules

1. Confirm the target OS. `@local/dsh-gitbash-tool` is Windows-only and requires
   Git for Windows / Git Bash. Do not assume this profile works unchanged on
   macOS or Linux.
2. Inspect `git status --short --branch` in the profile mirror and both local
   plugin repositories before transfer. Preserve uncommitted changes and
   unpushed commits. Never push or commit unless the user explicitly authorizes
   it.
3. Never blindly copy the entire `.dsh` directory over an existing target
   profile. Back up the target profile first and compare its configuration.
4. Never symlink the profile's `package.json` or `cordis.patch.yml`; DSH rewrites
   these files atomically. The self-authored plugin directories may be linked.
5. Never enable the native `tavily-mcp` row while `mcp-lazy` serves Tavily. Keep
   the `tavily-mcp` row disabled to prevent a duplicate server and extra tool
   schemas.
6. Keep plugin order and intentional `disabled` overrides intact. Do not use
   the market UI to toggle rows whose override semantics are documented here.

## Source Computer

1. Close DSH before capturing the final state so files are not changing during
   the copy.
2. Run the mirror's capture script from PowerShell:

   ```powershell
   & .\scripts\capture.ps1
   git diff -- profile global
   ```

3. Read every diff. Confirm it contains no secrets and preserves the disabled
   native `tavily-mcp` override. Do not commit automatically.
4. Inspect the source repositories too:

   ```powershell
   git -C <path-to-dsh-gitbash-tool> status --short --branch
   git -C <path-to-tavily-mcp-bundle> status --short --branch
   ```

   A normal clone will not include unpushed commits or uncommitted files. Report
   those to the user and agree how to transfer them; do not push on the user's
   behalf without authorization.
5. Transfer the profile mirror and both plugin source repositories using the
   user's approved Git remote or another secure method. For the current public
   repositories, a target agent can clone:

   ```text
   https://github.com/anklecrusher/dsh-profile-desktop.git
   https://github.com/anklecrusher/dsh-gitbash-tool.git
   https://github.com/anklecrusher/tavily-mcp-bundle.git
   ```

   Do not include `.env`, credentials, `node_modules`, caches, or runtime
   directories.

## Target Computer

1. Install the DSH desktop app and Git for Windows. Start DSH once so it creates
   `%USERPROFILE%\.dsh\profiles\desktop`, then close it before applying files.
2. Check out the profile mirror and both self-authored plugin repositories.
   Ensure Git Bash is available in a standard Git for Windows location. The
   current Bash plugin probes standard Git locations, Scoop, and `PATH`; its
   bundled patch does not require a hard-coded `bashPath`.
3. Resolve local links before installing dependencies. This profile currently
   uses absolute `link:` entries for:

   - `@local/dsh-gitbash-tool`
   - `@local/tavily-mcp`

   `package.json` **and** `pnpm-lock.yaml` contain these paths. Either recreate
   the same source paths on the target or edit both files in a target-specific
   checkout, then run the bundled DSH CLI install so pnpm validates/updates the
   lockfile. Do not commit target-only absolute paths back to the shared mirror.
4. Review `global/AGENTS.md` for paths, usernames, tool locations, and machine
   assumptions. The mirror's `apply.ps1` also copies this file and does not make
   a separate backup of the target `AGENTS.md`; preserve or adapt the target
   copy before applying.
5. Apply the reviewed profile with `scripts/apply.ps1`. It copies the five
   tracked profile files and global `AGENTS.md`; it does not install packages.
6. Install dependencies through the target desktop app's bundled CLI, not the
   standalone `dsh --profile desktop` command (the desktop profile is reserved):

   ```powershell
   & "<DSH install>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop install
   ```

   Confirm the CLI is operating on the `desktop` profile. Do not copy
   `node_modules` from the source computer.
7. Re-enter secrets on the target. For the current Tavily MCP, create
   `%USERPROFILE%\.dsh\.env` securely with `TAVILY_API_KEY`; never put the real
   value in this repository or in logs. DSH snapshots `.env` at launch, so
   restart after changing it. Re-authenticate credential-store integrations in
   DSH instead of copying `.credentials.yaml`.
8. Inspect every MCP entry in `profile/cordis.patch.yml`. Preserve non-secret
   endpoint/transport/timeouts and enabled/disabled state. For each local
   `stdio` server, verify its executable (Node, Python, Docker, etc.) exists on
   the target and update machine-specific command paths. Recreate required
   environment variables without revealing their values.
9. Review any absolute data paths. This profile currently points Mnemon at
   `D:\Users\ankle crusher\Documents\.mnemon`. If the user wants that memory
   data too, confirm it explicitly, back it up, transfer that data directory
   separately, and update `dataDir` for the target. Do not assume applying the
   profile copies Mnemon data.
10. Restart DSH. Verify bundle loading, run a harmless UTF-8 Bash check such as
    `printf '%s\n' '中文 UTF-8'`, and confirm configured MCPs initialize without
    duplicate-server warnings. Report any missing credentials or unavailable
    executables without exposing secrets.

## Machine-Specific MCP and Tool Rules

- The current Tavily setup is served through `dsh-mcp-lazy`; the native
  `tavily-mcp` row remains disabled. Keep this arrangement unless the user asks
  to redesign it.
- MCP server configuration can move in `cordis.patch.yml`; credentials and
  machine-installed executables cannot be assumed portable.
- The Git Bash implementation lives in its own repository and is referenced by
  the profile as a local bundle. Transfer that repository as well as the
  profile mirror.
- `tavily-mcp-bundle` is a configuration-only local bundle. It is still a
  separate source repository and must exist at the linked path even though it
  has no build step or runtime dependencies.
- If the request includes chat history, attachments, or Mnemon stores, treat
  each as a separate data migration and ask which data should move. Do not
  silently copy them as part of a profile sync.
