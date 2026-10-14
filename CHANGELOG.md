# Changelog

**English** | [한국어](CHANGELOG.ko.md)

## v1.3 - 2026-10-14

### Added

- Failure lessons: when a worker stops after the same failure three times, its summary starts with `STOPPED:`. The wrappers log the run as `stopped` and keep that line in the summary. The card writer records a one-line lesson in `<docs>/lessons/lessons.md` and greps it by tag before writing the next card. Nothing is loaded at session start.
- `/tandem-tokens` now shows session start cost (first request context) and session length (average and max) for Claude and Codex. Numbers only, no new warnings.
- README note on OpenAI's official `codex-plugin-cc`: TANDEM does not need it, and on Windows it has open issues (#57, #295) as of 2026-10-14.

### Changed

- Blind review: R2 reviewers get only the card, a saved `git diff` file, and the output path. No R1 conversation or self-assessment.
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
