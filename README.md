# TANDEM

**English** | [한국어](README.ko.md)

**Choose the lead; agents do the work.** TANDEM installs task cards, review rules, and run logs in your project. Claude or Codex can lead; the lead directs, reviews, and reports while workers implement.

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

Without options, the installer asks you to choose a mode and language. To pass `-Mode` or `-Lang ko|en` directly, use the `scriptblock` form in Quick start.

## Why

- The lead gets file paths and summaries of at most five lines, not entire worker outputs.
- G1 confirms the task definition; G2 briefs you on the result. Agents do not decide these gates.
- Task cards, a three-round discussion with another model in R2, and `runs.jsonl` keep work traceable.
- Model routing starts at a suitable lower tier and escalates when needed.

## Requirements

- Windows with Windows PowerShell 5.1 or later and git.
- [Claude Code](https://claude.com/claude-code) CLI for modes involving Claude; [Codex CLI](https://github.com/openai/codex) and a logged-in account for modes involving Codex. The installer checks dependencies for your mode.
- macOS/Linux scripts remain from v1.0 but are unsupported in v1.1.

## Quick start

Run in the root of the project you want to set up:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -Mode claude-main -Lang en
```

In `claude-main` or `claude-solo`, run `claude`, then `/tandem`. In `codex-main` or `codex-solo`, run `codex` and ask it to read `tandem/adapt.md` and adapt TANDEM. Adaptation checks models, CLI flags, project docs, and a smoke test. Review its report; you make the commit. In Codex modes, trust the project and approve the session hook through `/hooks`.

Describe the task to the lead. It asks for G1 confirmation, delegates implementation, and gives you the G2 briefing. Run the same install command again to update or switch modes; pass another `-Mode` or `-Lang` to change them.

## How it works

| Mode | You talk to | Who does the work |
|---|---|---|
| `claude-main` | Claude lead | Codex team through a Claude manager and dispatcher |
| `codex-main` | Codex lead | Claude worker called with `claude -p` |
| `claude-solo` | Claude lead | Lower-tier Claude agents through the Agent tool |
| `codex-solo` | Codex lead | Native Codex subagents |

The lead defines and checks work. Workers write files. G1 confirms scope before delegation; R1 proposes, R2 reviews with another model, R3 responds; G2 briefs you.

### What you get

| Feature | Purpose |
|---|---|
| Routing table | Choose model and reasoning effort, then record escalation |
| Task cards and G1/G2 | Define scope and keep confirmation and briefing with you |
| Three-round discussion | Record objections and unresolved issues |
| Run log and token report | Track calls and detect costly patterns |
| Operating docs | Keep roles, ownership, routing, and status in one place |

### Working rules

All roles clarify assumptions, keep solutions simple, and edit only what the task needs. Workers set verifiable completion checks and repeat until they pass; after the same failure three times, they stop and record the block. These rules paraphrase [a community collection of Andrej Karpathy's observations](https://github.com/forrestchang/andrej-karpathy-skills), not a repository maintained by Karpathy.

Execution wrappers wait without repeated polling and log calls automatically. Unspecified Claude subagents default to `sonnet` through `CLAUDE_CODE_SUBAGENT_MODEL`. Session rules keep related work together and start a new session for unrelated work; efficiency rules limit reading and test output to what the task needs.

### Official Codex plugin

OpenAI offers [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) for Codex reviews and task delegation inside Claude Code.
TANDEM does not require this plugin; its own `codex-run.ps1` wrapper handles task cards, token logs, and model routing.
As of 2026-10-14, Windows review mode and shell calls have unresolved issues: [#57](https://github.com/openai/codex-plugin-cc/issues/57), [#295](https://github.com/openai/codex-plugin-cc/issues/295).

### Jev (optional)

Jev is TypeSafe's decision-only model through OpenRouter. It chooses a model and reasoning effort, whether to escalate, and whether cross-review is needed. It does **not** judge artifact acceptance or decide G1/G2. Without a key, TANDEM works as in v1.0 using its routing table.

Enter an OpenRouter key interactively during installation, or set the **user** environment variable with `[Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY','<key>','User')`. When Jev is used, **the objective, constraints, and completion-conditions sections of a task card, up to 6,000 characters, are sent to OpenRouter/TypeSafe**. For an escalation decision, a failure summary of up to 1,000 characters is also sent. The key is not written to project files. `-JevKey` is available, but command history may retain its argument; interactive entry is recommended.

OpenRouter charges for input tokens only. A decision uses roughly 1,000–2,000 tokens, so the cost is very low; see the [OpenRouter model page](https://openrouter.ai/typesafe/jev-1.13) for the current exact rate. If credits run out or the key is invalid, TANDEM automatically uses the routing table, tells the user once in the current session, and shows a reminder at the start of the next session. A successful Jev call clears the reminder.

Use `-NoJev` when installing to turn Jev off and save `jev.enabled=false` in `tandem/config.json`. While it is off, TANDEM uses the routing table without Jev prompts, notices, or requests. Re-run the installer with `-UseJev` to turn it back on. With neither option, the saved setting is kept.

### Token report

Run `/tandem-tokens` in a Claude lead session, or run `tandem/tools/token-report.ps1` in PowerShell. It groups Claude and Codex use by role and model and suggests ways to reduce waste. For example, it can reveal 460,000 average context tokens per lead request or 35 requests per dispatcher call.

## Install details

### Run from a download

From your project root, call the downloaded script:

```powershell
path\to\Tandem\install.ps1 -Mode codex-main -Lang en
```

### Options

| Option | Meaning |
|---|---|
| `-DocsRoot <path>` | Operating docs directory; default `docs/tandem` |
| `-Mode <mode>` | One of the four modes above; re-run to switch |
| `-Lang ko\|en` | Language for conversation, docs, and guidance |
| `-JevKey <key>` | OpenRouter key; prefer interactive entry because command history may retain it |
| `-NoJev` | Turn Jev off and save the setting |
| `-UseJev` | Turn Jev back on and save the setting |
| `-SkipDeps` | Skip dependency and login checks |
| `-Yes` | Use defaults without prompts |
| `-Force` | Re-run placement; user-edited files still go to `.new` |

Use the `scriptblock` form in Quick start to pass options to the one-line installer.

### What the installer does

1. Selects mode and language, checks required CLIs, and offers Codex setup when needed.
2. Places mode-specific roles and commands, shared operating docs, and tools.
3. Inserts applicable TANDEM blocks into `CLAUDE.md` and `AGENTS.md` and merges settings and hooks.
4. Writes `tandem/config.json` and `tandem/manifest.json`; adds cache and run-output paths to `.gitignore`.

On update, unchanged TANDEM-owned files are replaced automatically. User-edited files stay in place and the new version goes to `<file>.new`. Session-start hooks can announce a newer version and a missing Jev key. Codex hooks require project trust and `/hooks` approval.

### What gets installed

| Scope | Files |
|---|---|
| All modes | `docs/tandem/` (or `-DocsRoot`), `tandem/adapt.md`, `tandem/config.json`, `tandem/manifest.json`, shared scripts in `tandem/tools/` |
| `claude-main` | Claude manager, dispatcher, critic, and commands; Codex work lead and agents; Claude settings and project instruction blocks |
| `codex-main` | Codex configuration and hook; Claude worker doc and settings; `tandem/tools/claude-run.ps1` |
| `claude-solo` | Claude lead, critic, top/mid/light agents and commands; Claude settings |
| `codex-solo` | Codex configuration, researcher/implementer/reviewer agents and hook; `tandem/tools/codex-run.ps1` |

The file set follows the mode. Shared tools cover checks, Jev, manifests, and token reporting; execution wrappers are installed where used.

## Undo

Revert your install commit. Review any `.new` files and user edits separately.

## Good to know

- A global Codex `service_tier` of `fast` or `priority` can consume limits 2.5 times faster. TANDEM does not change global settings; `/tandem` and the token report flag this.
- Codex session hooks require project trust and `/hooks` approval.
- In an untrusted folder, `claude -p` ignores settings permissions. The Claude wrapper passes needed permissions with `--allowedTools`.

## Fork and publish your own

Replace `carydev/Tandem` in `boot.ps1` and install examples with your repository. See [PUBLISH.md](PUBLISH.md).

See the [Changelog](CHANGELOG.md) for release notes.

## License

[MIT](LICENSE)
