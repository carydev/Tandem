# Operating Model — {{PROJECT}}

The user's language is {{LANG_NAME}}. Write documents and reports in {{LANG_NAME}} as well.
The sequence is: instruction → G1 confirmation of task definition → card creation → worker execution → review → G2 briefing → update source-of-truth documents after approval.
Fill in the source-of-truth document table during adaptation. If there are none, state that explicitly. Also fill in the list of decisions that are hard to reverse for this project.

@@if claude-main
Human → Claude lead → Claude manager → Claude dispatcher → Codex implementation team. Cross-review uses a Claude critic when needed.
@@endif
@@if codex-main
Human → Codex lead → Claude implementation worker. Delegation goes through the claude-run.ps1 wrapper.
@@endif
@@if claude-solo
Human → Claude top-level lead → tandem-worker-top/mid/light Agent.
@@endif
@@if codex-solo
Human → Codex top-level lead → workers in .codex/agents.
@@endif

| Document | Authority |
|---|---|
| Project source-of-truth documents | Lead edits after G2 approval |
| {{DOCS}}/tasks/ | Role responsible for writing task cards |
| {{DOCS}}/reports/ | Workers and reviewers |
| {{DOCS}}/model-routing.md | Lead |
| {{DOCS}}/log/runs.jsonl | Main: execution wrapper; solo: lead appends per subagent call |
| {{DOCS}}/harness-status.md | Installation and adaptation session |

## Project source-of-truth documents
| Path | Role |
|---|---|
| Fill in during adaptation | Do not finalize before verification |

## Decisions that are hard to reverse
- Fill in the project-specific list during adaptation.
