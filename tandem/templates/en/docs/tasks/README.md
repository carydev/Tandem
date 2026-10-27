# Task Cards

Follow the project's existing task ID format. If there is no existing format, choose one during adaptation.
Each card states the goal, confirmed background, write scope, output path, model and effort, reference paths, and verifiable completion criteria.
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
