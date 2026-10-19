# Harness Status

| Item | Value |
|---|---|
| Set | TANDEM |
| Version | {{VERSION}} |
| Installed | {{INSTALLED}} |
| Project | {{PROJECT}} |
| Mode | {{MODE}} |
| Language | {{LANG_NAME}} |
| Adaptation complete | No |
| Adaptation report | {{DOCS}}/reports/setup/tandem-adapt.md |

@@if claude-main
Structure: Claude lead {{CLAUDE_LEAD}} → manager {{CLAUDE_MANAGER}} → dispatcher {{CLAUDE_DISPATCH}} → Codex lead {{MODEL_MID}} / worker {{MODEL_LIGHT}}. Cross-review: {{CLAUDE_CRITIC}}.
@@endif
@@if codex-main
Structure: Codex lead {{MODEL_TOP}} → Claude worker {{CLAUDE_MID}} / light worker {{CLAUDE_LIGHT}} / escalation {{CLAUDE_TOP}}.
@@endif
@@if claude-solo
Structure: Claude lead {{CLAUDE_LEAD}} → top worker {{CLAUDE_TOP}}, mid worker {{CLAUDE_MID}}, light worker {{CLAUDE_LIGHT}}.
@@endif
@@if codex-solo
Structure: Codex lead {{MODEL_TOP}} → .codex/agents mid worker {{MODEL_MID}}, light worker {{MODEL_LIGHT}}.
@@endif

Fill in environment checks with actual execution results during adaptation. Leave unverified items as Unable to verify.
| Item | Result |
|---|---|
| Claude CLI | Unable to verify |
| Codex CLI | Unable to verify |
| Model IDs and reasoning effort | Unable to verify |
| Worker calls and output files | Unable to verify |
| Hooks approval | Unable to verify |
| Jev key and smoke test | Unable to verify |
| Fast/service_tier | Unable to verify |
| Cache rate / single-turn session ratio | Unable to verify |
