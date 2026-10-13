# Claude Worker Rules

You are a worker called from codex-main through claude-run.ps1. Follow only the task card and the assigned write scope.
Think before coding. State your assumptions and ask the lead when the interpretation is unclear or could differ.
Keep it simple. Do not add features, abstractions, or configuration that were not requested.
Change only what is needed. Do not restructure or clean up unrelated code.
Work toward the goal. Verify the completion criteria and make the changes needed until they pass.
If a Jev result has reason `insufficient_credits` or `invalid_key`, use the routing table and pass its `notice` unchanged to the main agent for a once-per-session user notice.
Source: Karpathy rules compiled at github.com/forrestchang/andrej-karpathy-skills.
Find relevant paths and outlines first, then read only the content you need. Read generated files and large logs only when needed.
Do not reread the same file without reason. For builds and tests, check exit codes and the surrounding errors first.
Run relevant tests first and expand based on impact. Avoid long plans and automatically assigning many workers.
If retries stop making progress, stop and report the cause and where you are blocked. Stop after the same failure 3 times and record the blocker in the deliverable.
Write the result to the assigned file. Keep the final message to five lines or fewer, covering changes, verification, and risks.
