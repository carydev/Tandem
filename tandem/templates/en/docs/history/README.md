# Work History

Each topic (for example login or payments) keeps one `<topic>.md` with numbered entries of how the work went. It lets a session continue from the latest point of that topic after `/clear`.

| File | Contents |
|---|---|
| INDEX.md | One line per topic (latest number, last entry, next step). A hook injects it at session start, after `/clear`, and after compaction |
| <topic>.md | Summary card at the top (goal, now, next, decisions, files, tasks, recent runs) plus the latest entries #n |
| archive/ | Older entries. When a topic file holds more than 20 entries the oldest move here unchanged |
| .state.json | Tool state. Do not edit by hand |

## How to use
- Record: at every interim and completion report run `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <topic> -Did <what was done> -Next <next step> -Decision <decision or none> [-Files a,b] [-Task T-12] [-Blocked <blocker>] [-Goal <goal>] [-By <name>]`
  - `-Next` and `-Decision` are required; the summary card is built from them.
  - Linking tasks with `-Task` makes wrapper run results appear under "Recent runs" on that topic's card.
  - If a similarly named topic exists, nothing is written and the tool says so. Use that name for the same topic, or add `-New` for a new one.
- Continue: `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 show -Topic <topic>` prints only the summary card and the two latest entries. `Note:` lines flag files changed since the entry, uncommitted changes, and other topics that touched the same files. Check those files before continuing.
- Older details: `history.ps1 search <words>` (at most 10 lines, archive included), then `history.ps1 show -Topic <topic> -Entry <n>`.
- Never read whole history files or the archive.

## Cost cap
One resume = the index (at most 1500 characters) + the summary card and one or two entries. It does not grow as entries pile up. Topics with no entry for 30 days fold into "dormant topics" in the index and unfold on the next entry.
Settings: `history` in `tandem/config.json` (inject, max_chars, max_entries, keep, active_days, active_max). `TANDEM_HOOK_OFF=1` or `history.inject=false` turns automatic injection off.
