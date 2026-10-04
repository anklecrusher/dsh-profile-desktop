# mnemon storage relocation (2026-10-04)

`dsh-mnemon`'s store was moved from the default `~\.mnemon` to an explicit
`D:` path by the user, not by the tool.

```yaml
# profile/cordis.patch.yml, the `mnemon` row
- id: mnemon
  name: dsh-mnemon
  config:
    storageScope: custom
    dataDir: D:\Users\ankle crusher\Documents\.mnemon
```

## Why it is `custom` + `dataDir`, not `workspace`

`dataDir` is only honoured when `storageScope` is `custom`; the two are set
together on purpose. `workspace` scope would put a `.mnemon` inside every
registered DSH workspace, which is the opposite of what is wanted here.

## What was migrated

`storageScope: custom` applies to the **whole root** at once — Runtime,
Documents, Memory Spaces and `state/`. Changing it therefore orphans whatever
sat under the old root.

On 2026-10-04, `D:\...\.mnemon` already held one document that the idle
checkpoint review had written after the move, so the relocation was a **merge**,
not a copy:

| Document | Bytes | Origin |
| --- | --- | --- |
| `dsh-desktop-profile-version-controlled-mirror-sy-d122503a.md` | 7,381 | copied in from `C:` |
| `dsh-workspace-instruction-loading-and-where-plug-a910ff6e.md` | 7,897 | copied in from `C:` |
| `dsh-profile-mirror-tracking-global-agents-md-app-eba64886.md` | 5,933 | already on `D:` |

Merged `documents/index.json` validated against mnemon's own
`parseDocumentIndex` rules: unique non-empty ids, `status` in
`active|archived`, filenames matching `^[a-zA-Z0-9._-]+\.md$` and equal to their
own basename, all metadata fields present and correctly typed, and every
`relativePath` resolving to an existing file.

The old root was **renamed, not deleted**:

```
C:\Users\ankle crusher\.mnemon
  -> C:\Users\ankle crusher\.mnemon.migrated-to-D-20261004-221249
```

Delete that directory once D: has been observed working for a while.

## Editing the store by hand is safe here

`readCurrentDocuments(root)` re-reads `documents/index.json` from disk on every
call — there is no in-memory index cache — so an external edit is picked up
without restarting. Note what it does **not** do: it verifies that each
`relativePath` exists, but never re-checks `contentHash` against the file bytes.
`contentHash` covers normalised body content, not raw bytes, so it will not
match a plain `sha256sum` of the `.md` file; that is expected and not a sign of
corruption.

## Runtime memory was empty on both sides

`runtime/memories.json` held zero entries and `USER.md` / `MEMORY.md` were both
0 bytes in the old root, so nothing was lost by the move. Both idle checkpoint
reviews so far chose the **Document** layer; the reviewer records each fact in
one layer only and refuses `target=memory` once a Document is created in the
same pass.
