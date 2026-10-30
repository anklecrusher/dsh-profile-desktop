# ds-bot 0.1.4 (vendored tarball)

`profile/package.json` depends on `ds-bot` through an absolute `file:` specifier:

```jsonc
"ds-bot": "file:C:/Users/ankle crusher/.dsh/backups/ds-bot/ds-bot-0.1.4.tgz"
```

`ds-bot` is not installed from the npm registry, so pnpm needs that local tarball
to exist before `dsh plugin --profile desktop install` can resolve the dependency
graph. Vendoring it here is what makes a fresh clone installable.

- Upstream: <https://github.com/QingJ01/DS-Bot-App> (release `v0.1.4`, asset
  `ds-bot-0.1.4.tgz`; the release also publishes `SHA256SUMS`)
- Version: 0.1.4 (upgraded from 0.1.3 on 2026-10-30; the bundle patch and
  dependency list are unchanged between the two)
- License: Apache-2.0
- SHA-256: `1b0e5db000eda951fd21b7f300fea348f2569e540788b651b55820d64eb3c227`
  — matches the upstream `SHA256SUMS`
- Size: 620,621 bytes
- Copied from `%USERPROFILE%\.dsh\backups\ds-bot\ds-bot-0.1.4.tgz` on 2026-10-30.

## Why it is here

The tarball lives outside the profile, under `~\.dsh\backups\`, which is
git-ignored DSH state. Without a copy in this repository a clone cannot run
`plugin install` at all — pnpm fails on the missing `file:` target before it
installs anything else.

## Installing on the target machine

`scripts/apply.ps1` copies this tarball to
`%USERPROFILE%\.dsh\backups\ds-bot\ds-bot-0.1.4.tgz` when it is missing, which
is exactly the path `package.json` records, **provided the target user profile
is `C:\Users\ankle crusher`**.

If the target user name differs, edit the `ds-bot` specifier in
`profile/package.json` and the matching importer entry in
`profile/pnpm-lock.yaml` to the target's real path before installing — for
example `file:D:/Users/<name>/.dsh/backups/ds-bot/ds-bot-0.1.4.tgz`. Everything
else in the profile can stay untouched.

## Upgrading later

Download the new release asset plus `SHA256SUMS`, verify the hash, drop the
`.tgz` next to this README, remove the previous one, and run (from
`%USERPROFILE%\.dsh\profiles\desktop`, PowerShell so the spaces in the path
survive):

```powershell
dsh plugin --profile desktop add 'file:C:/Users/ankle crusher/.dsh/backups/ds-bot/ds-bot-<version>.tgz'
```

Then restart the desktop app so the new plugin code is loaded.