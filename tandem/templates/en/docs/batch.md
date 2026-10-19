# Batch work

Use `tandem/tools/batch-run.ps1` when tens or hundreds of items need the same model rules.

1. Use one session per batch; send the fixed block only on the first turn, then resume.
2. Put the fixed block first and the item text after it.
3. Include only the context needed for each item, not the whole round.
4. Reprocess changed items with `-OnlyChanged`.
5. Stop after three consecutive item failures.
6. Record model, effort, and cached tokens.

| Observation | Cache behavior |
| --- | --- |
| Repeating a 46k-token fixed block in new sessions | 2.5% cache in a measured run |
| Resuming the same session | 99% of subsequent input cached in a measured run |
| New session in another folder | No cache in that measurement |
| `--ephemeral` | Cannot resume |

Codex `turn.completed.usage` is a **thread total**. Subtract the preceding total for each item's usage.

```powershell
./tandem/tools/batch-run.ps1 -Name pages -Fixed rules.txt -Items pages.jsonl -Out batch-results -ItemsPerSession 30 -OnlyChanged
```

Each JSONL item has `id`, `text`, and optional `images` (at most 12). `usage.jsonl` contains:

| Field | Meaning |
| --- | --- |
| `ts`, `id`, `thread` | Time, item, session |
| `resumed` | Whether the item used resume |
| `tokens.input`, `tokens.cached`, `tokens.output` | Per-item increments |
| `thread_total` | Last cumulative thread usage |
| `images`, `result`, `note` | Image count, outcome, detail |

Projects with their own loop (Python, for example) should apply the same rules in the adapter: resume, never use `--ephemeral`, keep `-C` fixed, and put per-call instructions after the fixed block.
