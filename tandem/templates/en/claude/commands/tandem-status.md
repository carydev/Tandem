---
description: TANDEM status and run summary
---
Read tandem/config.json, {{DOCS}}/harness-status.md, and {{DOCS}}/log/runs.jsonl, then report in no more than eight lines. Do not edit files.
Include the version, installation date, mode, active roles and models, and counts of successful, failed, and escalated runs, plus top-tier uses (from `escalated_from` in `runs.jsonl`). If there are no records, write 'No runs recorded yet'.
@@if claude-main
Include the status of the Codex implementation team and wrapper.
@@endif
@@if claude-solo
Include the three Claude worker tiers and Agent invocation status.
@@endif
