# Interfaces skills (vendored)

TANDEM ships a copy of the Interfaces agent skills so that workers and reviewers can read them by path in every mode.

| Item | Value |
|---|---|
| Source | https://github.com/jakubkrehel/skills |
| Author | Jakub Krehel (https://jakub.kr/skills, https://interfaces.dev) |
| License | MIT, see `LICENSE` in this folder |
| Upstream version | 1.17.0 |
| Commit | 60bf140e43c98b248e6594487384ec967e89d98a (2026-11-01) |
| Copied | `skills/` except `teardown` (technical illustration, not interface quality) |

The files under `skills/` are unmodified copies. Do not edit them here; TANDEM-specific rules live in the project's `design.md` and `design-platforms.md`.
TANDEM reads these files by path. They are not registered as Claude or Codex skills, so they do not collide with a copy you installed yourself (`npx skills add jakubkrehel/skills`).
