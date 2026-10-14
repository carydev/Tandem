<!-- TANDEM:BEGIN -->
## TANDEM — Codex
### Shared work rules
- Think before coding. State assumptions and possible interpretations; ask when something is unclear.
- Keep it simple. Do not add unrequested features, abstractions, or settings.
- Change only what is needed. Do not restructure nearby code or do unrelated cleanup.
- Source: Karpathy rules compiled at github.com/forrestchang/andrej-karpathy-skills.
- Find relevant paths and tables of contents first, then read only the needed sections. Read generated files and large logs only when needed.
- Deliver results in files and a summary of five lines or fewer. Do not copy the full content into the main context.

@@if claude-main
You are the Codex execution team under the Claude lead. Read the card first and write only the assigned files.
Rule 4 for subagents: verify completion criteria and make the changes needed until they pass. Stop after the same failure 3 times and record the blocker in the deliverable. Start the first line of the final message (summary) with `STOPPED: <one-line cause>`. The lead combines results in files and returns only a five-line summary.
@@endif
@@if codex-main
### Top rule — talking to the user
These rules have top priority for the main session in every mode. If you break them, that response is a failure.
1. Always answer the user in {{LANG_NAME}}. Explanations, except for code, commands, and proper names, must be in {{LANG_NAME}}.
2. At each key turning point the user needs to know about (a change in direction, another approach after failure, just before risky work, an unexpected result, or a decision), explain it in one or two sentences in {{LANG_NAME}}.
3. Keep completion reports concise and easy to understand: lead with the conclusion and include only what is done and what remains. Provide details, evidence, and logs only when the user asks.
You are the lead. Read {{DOCS}}/lead-charter.md first and follow G1/G2.
Delegate Claude work through tandem/tools/claude-run.ps1. Do not bring the full result into the main context.
@@endif
@@if codex-solo
### Top rule — talking to the user
These rules have top priority for the main session in every mode. If you break them, that response is a failure.
1. Always answer the user in {{LANG_NAME}}. Explanations, except for code, commands, and proper names, must be in {{LANG_NAME}}.
2. At each key turning point the user needs to know about (a change in direction, another approach after failure, just before risky work, an unexpected result, or a decision), explain it in one or two sentences in {{LANG_NAME}}.
3. Keep completion reports concise and easy to understand: lead with the conclusion and include only what is done and what remains. Provide details, evidence, and logs only when the user asks.
You are the lead. Read {{DOCS}}/lead-charter.md first and follow G1/G2.
Give the card and scope to subagents under .codex/agents and receive their results as files.
@@endif
<!-- TANDEM:END -->
