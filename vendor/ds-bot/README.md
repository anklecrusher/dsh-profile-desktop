# ds-bot 0.1.3 (vendored tarball)

`profile/package.json` depends on `ds-bot` through an absolute `file:` specifier:

```jsonc
"ds-bot": "file:C:/Users/ankle crusher/.dsh/backups/ds-bot/ds-bot-0.1.3.tgz"
```

`ds-bot` is not installed from the npm registry, so pnpm needs that local tarball
to exist before `dsh plugin --profile desktop install` can resolve the dependency
graph. Vendoring it here is what makes a fresh clone installable.

- Upstream: <https://github.com/QingJ01/DS-Bot-App> (`ds-bot/` directory)
- Version: 0.1.3
- License: Apache-2.0
- SHA-256: `ab65ce3033a88890c3410c371aa7a2fc8c88f96437f4620889128b6a7b1c5b1f`
- Copied from `%USERPROFILE%\.dsh\backups\ds-bot\ds-bot-0.1.3.tgz` on 2026-10-27.

## Why it is here

The tarball lives outside the profile, under `~\.dsh\backups\`, which is
git-ignored DSH state. Without a copy in this repository a clone cannot run
`plugin install` at all — pnpm fails on the missing `file:` target before it
installs anything else.

## Installing on the target machine

`scripts/apply.ps1` copies this tarball to
`%USERPROFILE%\.dsh\backups\ds-bot\ds-bot-0.1.3.tgz` when it is missing, which
is exactly the path `package.json` records, **provided the target user profile
is `C:\Users\ankle crusher`**.

If the target user name differs, edit the `ds-bot` specifier in
`profile/package.json` and the matching importer entry in
`profile/pnpm-lock.yaml` to the target's real path before installing — for
example `file:D:/Users/<name>/.dsh/backups/ds-bot/ds-bot-0.1.3.tgz`. Everything
else in the profile can stay untouched.