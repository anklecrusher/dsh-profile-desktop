# Agent notes

Rules for any agent working in this repository. Human-facing documentation is
in [README.md](README.md).

## What this repo is

A git mirror of the reviewed state of the DSH `desktop` profile. It is **not**
the live configuration — DSH reads
`%USERPROFILE%\.dsh\profiles\desktop`, and that copy is what actually runs.

## Rules

1. **Never store a secret here.** Credentials belong in
   `%USERPROFILE%\.dsh\.env` and are referenced indirectly, e.g.
   `!!js '`Bearer ${process.env.TAVILY_API_KEY}`'`. Check before every commit:
   `rg -n "sk-|tvly-|Bearer [A-Za-z0-9]" profile/`

2. **Never commit straight from `capture.ps1` output.** Read `git diff` first.
   The whole point of this repo is that DSH rewrites these files silently; a
   diff is the only warning. Committing without reading defeats it.

3. **Do not replace the profile config files with links.** DSH writes
   `package.json` and `cordis.patch.yml` via `@deepseek-ai/dsh-atomic-write`
   (temp file + rename), which replaces a symlinked target instead of writing
   through it. A hardlink here would desynchronise on the first market toggle.
   Details and measurements are in README.md.

   **This is not a ban on links in general.** A self-authored plugin lives in
   its own repo under `own/opensource/` and is referenced with `link:E:/...` in
   `profile/package.json` — that is the intended design, and both `@local/*`
   bundles already work that way. DSH only rewrites the files it owns, never a
   bundle's source directory. See "Self-authored plugins" in README.md.

4. **Do not add `node_modules/` or `*.bak-*` / `*.pre-*` to the repo.** They are
   ignored on purpose. `node_modules` is rebuilt from `pnpm-lock.yaml`; the
   timestamped backups are DSH's own recovery aids, not history.

5. **`link:E:\...` specs are machine-specific.** `@local/dsh-gitbash-tool` and
   `@local/tavily-mcp` resolve by absolute path. Cloning this repo elsewhere
   needs those paths to exist, or those two bundles edited out.

6. **For cross-computer migration, read [CROSS-PC-SYNC.md](CROSS-PC-SYNC.md)
   first.** It covers the profile, self-authored Bash tool, MCP configuration,
   plugin source repositories, machine-specific paths and secrets. Never
   commit or push migration changes unless the user explicitly asks.

## When DSH changes something

```powershell
& .\scripts\capture.ps1     # pull live state in (never commits)
git diff                    # read it — this is the review step
git add -A; git commit      # then record it
```

`capture.ps1` warns when the `tavily-mcp` disable override has gone missing,
because that specific edit silently costs ~1,706 tokens per request. If the
warning fires, restore the row rather than committing its removal.

## When applying a change

```powershell
& .\scripts\apply.ps1       # repo -> live profile
```

Then **restart the desktop app**. `dsh.profile.bundles` is read at boot;
`cordis.patch.yml` is hot-reloaded but bundle membership is not.
