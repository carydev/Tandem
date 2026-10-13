# TANDEM Adaptation Instructions

Adapt the installed files to this project. Speak with the user in {{LANG_NAME}} and write reports in {{LANG_NAME}}.
First read mode, lang, docs_root, and models in tandem/config.json, then check existing changes with git status. Preserve existing changes. Do not commit.

## 1. Understand the project
Check README, CLAUDE.md, AGENTS.md, .claude/, .codex/, project documents, existing task IDs, and handoff practices.
Fill in document paths, roles, write scopes, reference documents, and decisions that are hard to reverse according to the existing system.
Review differences in .new and report a merge proposal. Mark unverified facts as 'Unable to verify'.

## 2. Environment and models
@@if claude-main claude-solo
Check claude --version, Agent role recognition, and model assignments.
@@endif
@@if claude-main codex-main codex-solo
Check codex --version, codex exec --help, actual model IDs, reasoning effort, sandbox, and whether AGENTS.md is recognized.
@@endif
@@if codex-main
Check claude --version, supported claude -p flags, and invocation of claude-run.ps1.
@@endif
Record the model IDs actually available under models in tandem/config.json, and directly replace unresolved markers in installed files with the same values. Do not enter guessed values.
Run tandem/tools/manifest.ps1 -Rehash to refresh fingerprints of installed files. On update, the installer renders from config, preserving the values in the next version.
Check whether Fast/service_tier in the global Codex settings is fast or priority, and report the result. Do not change global settings.

## 3. Check mode-specific connections
@@if claude-main
Check recognition of tandem-manager, tandem-dispatch, and tandem-critic, and delegation through codex-run.ps1. Run R2 separately with another model in read-only mode.
@@endif
@@if codex-main
Check that the Codex lead reads lead-charter.md and AGENTS.md. Check the model, flags, artifacts, and logs of claude-run.ps1.
@@endif
@@if claude-solo
Check that tandem-worker-top/mid/light appear in the Agent tool and run with their assigned models.
@@endif
@@if codex-solo
Check recognition of .codex/agents roles, subagent model assignments, and file artifacts. If roles cannot be called by name, inject the TOML instructions.
@@endif
@@if codex-main codex-solo
Check the trust status of the project's .codex/ and approve the SessionStart command in Codex /hooks.
@@endif
Check configuration JSON, Codex TOML, file paths, log appending, and write scopes.
Do not cross G1/G2 before the user approves.

## 4. Jev and tokens
Check only whether the TANDEM_JEV_API_KEY or OPENROUTER_API_KEY environment variable exists. Do not print or record key values.
Only when a key exists, smoke-test tandem/tools/jev.ps1 -Route -Card <safe test card>.
If there is no key, check that routing falls back to the assignment table. Jev does not replace final judgment or G1/G2.
Run tandem/tools/token-report.ps1 -Days 7 and check the paths of the summary and detailed reports.

## 5. Safe smoke test
Use a small card that does not decide project content to check subagent invocation, result files, five-line summaries, and session/tokens/decided_by in execution logs.
For modes requiring R2, check a separate session with another model. If failures repeat, stop and report the original output.

## 6. Finish
Fill in verification results, active roles, confirmed models, and unverified items in {{DOCS}}/harness-status.md.
In {{DOCS}}/reports/setup/tandem-adapt.md, write a five-line summary, project findings, environment, model assignments, verification, smoke test, .new merge proposal, and decisions needed.
Keep the final message to five lines or fewer with a summary and report path. Do not commit.
