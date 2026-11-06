# Task Cards

Follow the project's existing task ID format. If there is no existing format, choose one during adaptation.
The first line of a card is `# <ID> <one-line title>`. The wrapper logs that title as `title` in runs.jsonl (the "Task" column of the run table).
After G1, put the card on the board in To do with `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/board.ps1 add -Task <ID> -Card <card path>`.
Each card states the goal, confirmed background, write scope, output path, model and effort, reference paths, and verifiable completion criteria.
A task that makes or changes a screen or a document people look at carries a `Design: <web|android|ios|flutter|desktop|doc>` line on its card (design.md). With that line the worker gets the skill brief, and a design review (RD) is required before done. For a task that touches no interface, leave the line out or write `Design: none`.
Before writing a card, run `tandem/tools/lessons.ps1 -Tags <tag,tag>` and add its lines (at most three) to the background (lessons/README.md).
@@if claude-main
tandem-manager writes the card and the Codex lead reads it.
@@endif
@@if codex-main codex-solo
The Codex lead writes the card and workers read it.
@@endif
@@if claude-solo
The Claude lead writes the card and workers read it.
@@endif
