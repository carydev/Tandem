# Design quality

Screens and documents people look at are built and reviewed to the rules of the Interfaces skills. The copies live in `tandem/design/skills/` (source and license: `tandem/design/SOURCE.md`).
The skills are read by path. Nothing has to be installed separately and the user does not have to invoke them. When a card carries a `Design:` line, they apply automatically while building and while reviewing.
Output quality comes before token savings. On a design task, do not skip reading the skills or the design review to save cost.

## When it applies
- A task that makes or changes a screen, component, style, icon, animation, interface copy or an HTML document people open is a design task. That holds for web, Android, iOS, Flutter and desktop alike.
- The card of a design task carries a `Design: <web|android|ios|flutter|desktop|doc>` line. Separate several with commas. `Design: yes` uses `design.platform` from tandem/config.json.
- For a task that touches no interface, leave the line out or write `Design: none`. The card author decides before G1. When in doubt, treat it as a design task.
- When a card without the line changes interface files, a `design=unmarked` notice appears. The lead adds the line to the card, puts it back on the board with `board.ps1 add -Task <ID> -Card <card>` and gets a design review.

## Flow
1. Write the `Design:` line on the card.
2. The worker reads the skills and builds to their rules ("When building").
3. A task where judgement differs gets R2 as usual. R2 looks at correctness, tests, security and scope, not at the interface.
4. Get a design review (RD) ("Review"). It is required on a design task.
5. On a block verdict, fix in R3 and get RD again.
6. The card moves to done on the board only with an approve verdict. Put the design verdict and the remaining findings in the G2 briefing.

## When building
@@if claude-main codex-main
The wrapper reads the card's `Design:` line and appends the brief below to the worker prompt automatically. The lead and the dispatcher pass nothing extra.
@@endif
@@if claude-solo codex-solo
When the card carries a `Design:` line, the worker runs `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/design.ps1 brief -Task <ID> -Card <card>` before implementing and follows the brief it prints. The lead may also paste the same output into the delegation prompt.
@@endif
- Read the six domain skills in this order: `better-accessibility`, `better-layout`, `better-writing`, `better-typography`, `better-colors`, `better-ui` (the `SKILL.md` in each folder; reference files when you work on that topic).
- On a platform other than the web, carry the rules over with {{DOCS}}/design-platforms.md. Principles and values stay; only the means of implementation change.
- The tokens, components and design documents the project already has come first. Use what exists before adding a value. Do not overturn an existing decision on taste.
- The task is not complete while any Escalation trigger in `better-interface/SKILL.md` remains.
- Leave rendered evidence. Save screenshots under {{DOCS}}/reports/work/<ID>-shots/ and give the paths in the artifact. If none can be made, say why. The means are in "Rendered evidence" in design-platforms.md.
- Add a "Design" section to the artifact: the skills read and applied, the self-check against the escalation triggers and the rendered evidence.

### Procedure skills
When the card says `Procedure: <name>`, the worker follows the procedure in `tandem/design/skills/<name>/SKILL.md`. These are skills a user normally invokes by hand; in TANDEM the card stands in for the invocation.

| Name | When to use it |
|---|---|
| build-design | Implementing a Figma file or a design image as designed |
| variant | The direction is open and you want three different candidates to choose from |
| state-machine | Working through every state of a component (loading, empty, error, permissions) on one page |
| break | Stress testing one component with worst-case input in a single pass |
| explain-interface | Finding out how a reference site or a screenshot was built |

These procedures assume a scratch page in a web app. On other platforms follow "Carrying over the procedure skills" in design-platforms.md.

## Review
The design review is round `RD`. A separate session that did not build the work does it read-only. Use the mid tier or higher and, where possible, a different model from the one that built it.
@@if claude-main
The manager calls `codex-run.ps1 -Task <ID> -Round RD -Card <card> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{MODEL_MID}} -Effort high` through the dispatcher.
@@endif
@@if codex-main
The lead calls `claude-run.ps1 -Task <ID> -Round RD -Card <card> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{CLAUDE_MID}} -Effort high`.
@@endif
@@if codex-solo
The lead calls `codex-run.ps1 -Task <ID> -Round RD -Card <card> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{MODEL_MID}} -Effort high`.
@@endif
@@if claude-main codex-main codex-solo
The wrapper handles the read-only new session, attaches the changes file and the review brief, and records the verdict. The `design=` line of the summary is the verdict.
@@endif
@@if claude-solo
The lead gives tandem-critic the output of `design.ps1 brief -Task <ID> -Card <card> -For review` and the changes path printed by `diff.ps1 -Task <ID>`, and has it write the result to {{DOCS}}/reports/review/<ID>-design.md. The lead then runs `design.ps1 check -Task <ID> -Review <that path>`. The `design=` on the first output line is the verdict. Record the round as RD in runs.jsonl.
@@endif
- The reviewer follows the procedure of `better-interface` and the classification of `interface-review` (introduced, regression, pre-existing). Findings use the verdict line format of delegation.md with `domain=` and `status=` added, and the last line is `VERDICT: approve` or `VERDICT: block`.
- The "at least three findings" rule of the general R2 does not apply to a design review. No findings is a valid result. A difference of taste is not a finding.
- An escalation trigger is [high] however minor the surface. Any confirmed [high] finding that this change introduced or made worse means block.
- Where a judgement needs the rendered result and there is no evidence, it is needs_validation. The lead checks the render and rules it confirmed or rejected.
- On block, the default is to fix in R3 and get RD again. When there are one or two findings and the lead has checked the fixed result personally, `design.ps1 pass -Task <ID> -Reason "<what was checked>"` records an approve. When the user accepts a finding at G2, add `-By human`. The worker saying "fixed" is not enough to pass.
- For a design card, `board.ps1 move -To done` is refused unless the verdict is approve. `design.ps1 status -Task <ID>` shows the current state.

## Commands
`powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/design.ps1 <command> ...`

| Command | What it does |
|---|---|
| `status -Task <ID> [-Card <card>]` | Whether this is a design task and what the review verdict is. For a card without the line it looks for changed interface files and reports `design=unmarked` |
| `brief -Task <ID> -Card <card> [-For build\|review]` | The brief to give a worker or a reviewer |
| `check -Task <ID> -Review <review file>` | Checks the format and verdict of a review file and records it in {{DOCS}}/log/design.jsonl |
| `pass -Task <ID> -Reason "<one line>" [-By <name>]` | Records an approve that the lead verified personally or the user decided |

## Settings
`design` in tandem/config.json: `enabled` (false turns off the briefs, notices and the gate), `platform` (this project's default platform, filled in during adaptation), `gate` (false turns off only the done gate on the board).
