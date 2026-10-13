# Changelog

**English** | [한국어](CHANGELOG.ko.md)

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
