# Should dsh-archive-manager be installed? (evaluated 2026-10-04)

**No — its core function duplicates what DSH already ships.** Installed:
`dsh-archive-manager` is not tracked in `profile/package.json`.

Candidate: [`MichengAI/dsh-archive-manager`](https://github.com/MichengAI/dsh-archive-manager)
(`@michengai/dsh-archive-manager@1.0.11`, Apache-2.0, 98★, 173,954 npm
downloads/month). It is a competent plugin and it does pass the compatibility
gate. The problem is scope overlap, not quality.

## DSH already archives sessions, and the UI is shipped

`@deepseek-ai/dsh-api-session-controller` contains `ArchivedSessionGate`, which
gates every `agent/pre-step` on whether the session (or an ancestor in its
subagent lineage) is archived. `@deepseek-ai/dsh-client-ui-workspace` is a
**466-reference** archive UI. Its own strings:

```
Archive / Archive session / Unarchive / Archived only / Hide archived
"Archived sessions cannot be opened. Unarchive it to view."
"Session stopped and archived."
Stop and archive this session?
archive.confirm.subagents / .schedules / .jobs / .turn
```

So a user can already archive a session, stop-and-archive it with pending-work
warnings, filter to archived-only, and unarchive. Nothing in the plugin's
headline promise — "把暂时不用的会话收起来，需要时再找回" — is missing from the
shipped host.

## What the plugin genuinely adds

Ranked by how much it actually matters here:

1. **Full-text search over archived sessions** (title *and* body), with date /
   project / favourite filters. DSH's native archive UI does not search bodies.
2. **Preview without unarchiving** — the host explicitly refuses to open an
   archived session; the plugin renders the last 8 messages, or ±the first hit.
3. **Batch operations** — restore/delete whole projects or select-all-filtered,
   with progress and per-item retry.
4. **Turn counts per session, favourites, idle-archive candidates.**
5. **Diagnostics/repair for legacy session logs.**

Items 1–3 are the real argument. Everything else is polish.

## Why that is not enough to install it now

- **Cost is not zero.** It adds a second session-list surface beside DSH's own
  archive view, and it reads session logs in batches of 20 with no persistent
  full-text index — the README warns long sessions take a while.
- **The gap is narrow.** It only matters once there is a large body of archived
  sessions worth searching, and this profile has none yet.
- **Its own README is honest about the limit**: "未建立持久化全文索引" and "尚无可
  承诺的会话数量上限或响应时延".

## Revisit when

Any of these becomes true: archived sessions accumulate past roughly
fifty-ish and finding one by title stops working; a need appears to read an
archived conversation without unarchiving it; or a session log refuses to load
and needs the repair path.

Install then, through the normal workflow:

```powershell
& "D:\Users\ankle crusher\AppData\Local\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd" `
    plugin --profile desktop add @michengai/dsh-archive-manager
& .\scripts\capture.ps1
git diff
```

## Gate check (already done, for the record)

Its peer ranges list every supported DSH version explicitly, ending at
`0.2.0-rc.2`, and `@deepseek-ai/dsh-*` peers are the only ones DSH gates.
Zero runtime dependencies, no install-time lifecycle hooks. It would install
cleanly — the objection is purely that the capability is already there.
