# Failure Lessons

Record lessons in {{DOCS}}/lessons/lessons.md. Create it on the first entry; it is not installed.
One-line format: `- YYYY-MM-DD [tag,tag] symptom -> cause -> next time do this`
The card author records a lesson when a worker result summary starts with `STOPPED:` or a failure is resolved after escalation or retries. If the lesson already exists, update only its date.
Before writing a card, grep for relevant tags and copy only matching lines into the card's "Background". Do not read the whole file.
When it exceeds 40 lines, promote lessons repeated at least three times to a governing document (such as operating-model) and delete those lines.
