# Failure Lessons

Record lessons in {{DOCS}}/lessons/lessons.md. Create it on the first entry; it is not installed and is never loaded at session start.
One-line format: `- YYYY-MM-DD [tag,tag] symptom -> cause -> next time do this (xN)`. `(xN)` is how many times the lesson has applied. Omit it on the first entry (= x1).
The card author records a lesson when a worker result summary starts with `STOPPED:` or a failure is resolved after escalation or retries. If the lesson already exists, update its date and raise `(xN)` by one instead of adding a line. Also raise it when a lesson attached to a card actually prevented a failure.
Before writing a card, run `tandem/tools/lessons.ps1 -Tags <tag,tag>`. It prints at most three lines (`-Top`), highest count first, then newest. Copy only those lines into the card's "Background". Do not read the whole file.
Promote lessons at `(x3)` or more to a governing document (such as operating-model) and delete the line. When the file exceeds 40 lines, delete x1 lines older than 90 days first.
