# Changelog

**English** | [한국어](CHANGELOG.ko.md)

## v1.8 (2026-10-29)

- Kanban board: `docs/tandem/board/index.html` reloads `board-data.js` from the same folder every 3 seconds and shows To do, In progress, Built, Review, Test, Done, and Blocked. Double-click to open; no server needed. Cards show the agent, model, run count, time, and tokens (from runs.jsonl).
- New tool `board.ps1 add|move|note|remove|list|sync|open`. It writes `board.json` and `board-data.js` atomically under a lock.
- Who moves what: the agent that did the work moves only to Built; review verdicts, Test, Done, and Blocked belong to the lead (the manager in claude-main). codex-run and claude-run move cards to In progress at start (Review for R2), Built on success, and Blocked on STOPPED, and write the R2 verdict line into the note. Solo-mode workers (tandem-worker-*, implementer, researcher) move their card to Built when they finish.
- Upgrade: rerun the installer. It adds `tandem/tools/board.ps1` and `docs/tandem/board/index.html` and updates the two wrappers, the worker and manager agents, and the delegation, lead-charter, and tasks docs.

## v1.7 (2026-10-28)

- Run table: the new `run-table.ps1 -Task <ID>` builds a kind, agent, model, task, status, time, and tokens table with a total (cache included) from `runs.jsonl`. With nothing delegated it prints a one-row "none" table. The lead always ends interim and completion reports with it (stated as an exception to concise-report rule 3).
- `runs.jsonl` gains `kind`, `agent`, `title`, and `duration_s`. codex-run, claude-run, and batch-run record them automatically (`-Agent` sets the name); the lead logs them for native subagent calls. A card's first line is `# <ID> <one-line title>`. Older records and the `tokens: {"total": N}` form are still read. Unknown Codex subagent tokens are filled from the Codex session file by session.
- Upgrade: rerun the installer. It adds `tandem/tools/run-table.ps1` and updates the CLAUDE.md and AGENTS.md blocks, the lead-charter, delegation, log, and tasks docs, and the three wrappers.

## v1.6 (2026-10-27)

- R2 verdict schema: one line per finding, `F1 [confirmed|needs_validation|rejected]`. confirmed requires evidence and severity, needs_validation names the unverified fact without a severity, rejected gives the reason. The new `review-check.ps1` validates the format and missing R3 answers (`fixed|disputed|deferred`); wrappers run it after R2, add a `review=` line to the summary, and record `findings` in `runs.jsonl`. The finder never verifies (finder/verifier separation borrowed from cloudflare/security-audit-skill).
- Installer `-Plan` (preview that writes nothing) and `-Clean` (moves TANDEM files the current mode does not install to `tandem/.backup/<timestamp>/`, then removes them). Leftovers from a mode switch and user-edited files are now reported; previously only manifest-matching files were removed and the rest stayed silently.
- Failure lessons carry an `(xN)` count. The new `lessons.ps1 -Tags` returns at most three lines, highest count first. Promote lessons at `(x3)`. Still nothing is loaded at session start.
- Session-start hook notices are cut at 800 characters (`hook.max_chars`, env `TANDEM_HOOK_MAX_CHARS`). `TANDEM_HOOK_OFF=1` or `hook.enabled=false` makes the hook do nothing.
- Upgrade: re-run the installer. It adds `tandem/tools/review-check.ps1` and `lessons.ps1` and updates the reviewer, critic, delegation, lessons, tasks, reports, and log docs. Files you edited come out as `.new`.

## v1.5 (2026-10-19)

- Wrappers resume related sessions; `-NewSession` starts a fresh one. `runs.jsonl` records `resumed` and cumulative `thread_total`; `claude-run` no longer uses `--no-session-persistence`.
- Added `batch-run.ps1` and `docs/batch.md` for repeated items: one session per batch, fixed instructions on the first turn only.
- The token report now shows cache rates, single-turn Codex sessions, and main status-check calls. Its count of single-turn sessions with at least 20k uncached tokens helps spot repeated fixed blocks; two diagnoses flag one-call sessions and excess status checks.
- Measured with a 20k-token prompt: a new session in another folder cached 0, a new session in the same folder cached 7k, and resumed turns 2–3 cached 99% of turn input; `--ephemeral` cannot resume.

## v1.4 (2026-10-19)

- Added tier tables and a manager default one tier below the lead; `claude-main` config.toml now defaults to mid. Added the fable alias.
- Gated top-tier wrapper runs with `-EscalatedFrom` and `-Reason`; Jev no longer chooses the top tier. Reports now include top-tier use counts.
- R2 uses the mid tier in a separate read-only session. Reviewer and critic profiles default to mid.

## v1.3 - 2026-10-14

### Added

- Failure lessons: when a worker stops after the same failure three times, its summary starts with `STOPPED:`. The wrappers log the run as `stopped` and keep that line in the summary. The card writer records a one-line lesson in `<docs>/lessons/lessons.md` and greps it by tag before writing the next card. Nothing is loaded at session start.
- `/tandem-tokens` now shows session start cost (first request context) and session length (average and max) for Claude and Codex. Numbers only, no new warnings.
- README note on OpenAI's official `codex-plugin-cc`: TANDEM does not need it, and on Windows it has open issues (#57, #295) as of 2026-10-14.

### Changed

- Blind review: R2 reviewers get only the card, a changes file, and the output path. No R1 conversation or self-assessment. The new `tandem/tools/diff.ps1` writes the changes file (including new untracked files, without touching the git index); the wrappers attach it automatically on `-Round R2`.
- `codex-run.ps1` and `claude-run.ps1` reject unsafe `-Model`/`-Effort` values and paths containing `"` with a `status=fail` line, closing a cmd.exe command injection path.

### Upgrade notes

- Re-run the installer. It adds `<docs>/lessons/README.md`; untouched files are replaced, locally edited ones come as `.new`.

## v1.2.1 - 2026-10-14

### Fixed

- `check.ps1`, `codex-run.ps1`, `claude-run.ps1`, `jev.ps1`, and `manifest.ps1` now set console output to UTF-8. Under Windows PowerShell 5.1 their non-ASCII output (for example Korean summaries from `codex-run.ps1`) was emitted in the OEM code page (cp949 on Korean Windows) and appeared garbled when read by Bash or Claude Code. `token-report.ps1` already did this.

## v1.2 - 2026-10-13

### Added

- `-NoJev` saves an off state with no Jev prompts, notices, or calls; `-UseJev` restores it.
- Jev gives clear, localized notices for insufficient OpenRouter credits and invalid keys; session-start checks repeat the last issue until a successful call.
- An optional `-Endpoint` argument supports local Jev response tests.

### Changed

- Everything TANDEM shows - installer, one-line bootstrap, tool output, reports, notices - now uses only the language you chose (`-Lang` or config). Before a language is set, the Windows display language is used.
- HTTP 402 and 401 now fall back to the routing table with a specific reason. Main agents tell the user once per session; subagents pass the notice through.
- The README explains Jev setup, data sent, estimated cost, and fallback behavior.

### Upgrade notes

- Re-run the installer to receive v1.2 files. Locally edited installed files may be written as `.new`; merge them through `/tandem`.

## v1.1 - 2026-10-13

### Added

- Four modes: `claude-main`, `codex-main`, `claude-solo`, and `codex-solo`; `-Lang ko|en` selects installation language.
- Fingerprint-based updates through `tandem/manifest.json` and session-start notices for newer versions and missing Jev keys.
- Optional Jev routing decisions, `/tandem-tokens` usage reports and waste diagnostics, and `codex-run`/`claude-run` wrappers that wait without repeated polling, log runs automatically, and record tokens.
- Karpathy-inspired working rules: rule 4 applies only to workers. Lead rules cover language, decision points, concise reports, session continuity, and delegation.

### Changed

- Unspecified Claude subagents use `sonnet` instead of `inherit` via `CLAUDE_CODE_SUBAGENT_MODEL`.
- Templates moved to `tandem/templates/<lang>/`; `tandem/config.json` is the source of model IDs.
- v1.1 supports Windows; the macOS/Linux scripts remain from v1.0 and are unsupported.

### Fixed

- Removed the `boot.ps1` BOM that broke `iwr | iex` in Windows PowerShell 5.1.
- Prevented a Codex login status message on stderr from stopping installation in PowerShell 5.1.
- Fixed tag-based installation returning 404 and removed BOMs from generated installation files.

### Security & privacy

- The Jev key is stored only in the user environment variable. When Jev is used, only the task card's objective, constraints, and completion conditions, up to 6,000 characters, are sent to OpenRouter/TypeSafe.
- `-JevKey` can leave the key in command history; interactive entry is recommended.

### Upgrade notes

- Re-run the same one-line installer to upgrade from v1.0: that installation has no update notice. The v1.0 config is upgraded automatically.
- Files installed by v1.0 have no fingerprints, so updates may appear as `.new` files. Merge them through `/tandem`.

### Known limitations

- A live Jev call remains untested because no key was available. Codex and Claude session-start notice display has not been confirmed in a live session.
- The `codex login` browser flow and winget installation remain untested. Full `/tandem` adaptation has not been exercised in a real project in all four modes.

## v1.0 - 2026-09-28

- First public release: one-line installation, Claude lead with Codex workers, G1/G2 user gates, task cards, three-round discussion, and run logs.
