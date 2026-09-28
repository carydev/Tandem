# TANDEM

**English** | [한국어](README.ko.md)

**Claude directs. Codex does the work.**
TANDEM is an agent harness you drop into any project. Claude plans, reviews and reports.
A Codex team does the heavy research and writing on your Codex plan.

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

Then run `claude` and type `/tandem`. That's it.

> The name comes from a tandem bicycle: the front rider steers, the back rider pedals harder.
> Claude steers, Codex supplies the power.

---

## Why

- **One Claude call runs a whole Codex team.** Codex spawns its own sub-workers.
  However many workers run inside Codex, Claude usage does not grow.
- **Heavy work moves to your Codex plan.** Claude only instructs, reviews and reports.
- **Output never floods Claude's context.** Codex writes results to files.
  Claude gets back a path and a 5-line summary.
- **The reviewer is a different model.** Proposal → adversarial review (other model, separate session) → response.
  Same-model debates agree too fast.

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI
- [Codex CLI](https://github.com/openai/codex) with a logged-in account. **TANDEM does not work without Codex.**
  The installer offers to install it and run `codex login` if missing.
- A git repository (recommended - it is your undo button)

## Quick start

Run in the **root of the project** you want to install into.

**Windows (PowerShell)**

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash
```

Then adapt it to your project:

```
claude
/tandem
```

`/tandem` checks your environment (real Codex model IDs, CLI flags), fits TANDEM to your existing docs and ID scheme,
runs a smoke test, reports, and stops. **You commit.**

Start working with the lead session:

```powershell
claude --append-system-prompt-file ./docs/tandem/lead-charter.md
```

```
<describe the task>
Ask clarifying questions first. Proceed after G1 approval.
```

Check status from any session with `/tandem-status`.

> **Note:** the installed role files and operating docs are currently written in Korean.
> Claude and Codex read them fine. An English template set is not included yet.

## How it works

```
You                     decisions, direction
 │
Claude lead             intent, final verdict, report       [Claude plan]
 │
Claude manager          task breakdown, task cards, review  [Claude plan]
 │
Claude dispatcher       calls codex exec, writes the log    [Claude plan, tiny]
 │
Codex work lead         forms the team, design calls        [Codex plan]
 ├ research worker  (light model)
 ├ design worker    (mid-upper model)
 ├ build worker     (light model)
 └ adversarial review (separate session, different model)

Claude critic           only for hard-to-reverse decisions  [Claude plan, rare]
```

Flow: task → clarifying questions → **G1** (you confirm the task) → Codex team runs → review →
**G2** (briefing to you) → approved changes applied. Nothing passes a gate without your answer.

## What you get

| Feature | What it does |
|---|---|
| **Model routing table** | Which model and reasoning effort per job. Start one level lower, escalate only on failure |
| **Approval gates** | G1 task definition, G2 briefing. No human approval, no next step |
| **Task cards** | Codex can't see the chat. Context goes to it as a file |
| **3-round debate** | Proposal → adversarial review → response. Unresolved points stay recorded as open issues |
| **Run log** | One line per call in `runs.jsonl`: model, effort, pass/fail, escalation |
| **Self-tuning** | The manager aggregates the log and proposes routing changes. Data, not guesses |
| **Harness status** | One file tells you version, active roles, confirmed models, environment |
| **File ownership** | Who may edit which doc is fixed. Agents don't overwrite each other |

### Good fit

- Research- and writing-heavy projects that burn through Claude quota
- Work where decisions, evidence and objections must be on record
- Solo developers who need a reviewer
- Long work spanning many sessions

### Not a fit

- Short one-shot tasks - the hierarchy makes them slower
- Environments without Codex CLI
- Interactive work that needs instant answers

---

## Install details

### Run from a download

Cloned or unzipped? Call the script from **your project root**:

```powershell
path\to\Tandem\install.ps1
```

```bash
path/to/Tandem/install.sh
```

### Options

| Option (PowerShell / bash) | Meaning |
|---|---|
| `-DocsRoot <path>` / `[path]` | Operating docs folder. Default `docs/tandem` |
| `-SkipDeps` / `--skip-deps` | Skip Codex install and login checks |
| `-Yes` / `-y` | Don't ask. For unattended runs |
| `-Force` (PowerShell only) | Re-place templates even if already installed |

With the one-liner:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -DocsRoot docs/ops
```

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash -s -- docs/ops
```

### What the installer does

1. Checks git, `claude`, and **installs / logs in `codex`** if you agree
   (`winget install OpenAI.Codex` on Windows, `brew install --cask codex` on macOS, else `npm install -g @openai/codex`)
2. Detects the project name (git remote or folder name)
3. Places role files, slash commands, Codex config, operating docs
4. Inserts a TANDEM block into `CLAUDE.md` / `AGENTS.md` (existing content kept)
5. Merges `.claude/settings.json` (existing settings kept)
6. Adds `.codex-last/` to `.gitignore`
7. Writes `tandem/config.json`

**It never overwrites your files.** On conflict it saves `<file>.new` and tells you. Safe to re-run.

### What gets installed

```
.claude/
  agents/tandem-manager.md      manager
  agents/tandem-dispatch.md     dispatcher
  agents/tandem-critic.md       critic
  commands/tandem.md            /tandem
  commands/tandem-status.md     /tandem-status
  settings.json                 merged
.codex/
  config.toml                   4 profiles
  agents/*.toml                 work lead, researcher, implementer, reviewer
docs/tandem/                    (configurable)
  harness-status.md             current state - read first each session
  lead-charter.md               lead-only rules
  model-routing.md              model routing and escalation
  delegation.md                 delegation, cost rules, pitfalls
  operating-model.md            org, flow, file ownership
  log/runs.jsonl                run log
  tasks/ briefings/ reports/    work output
CLAUDE.md                       TANDEM block inserted
AGENTS.md                       TANDEM block inserted
tandem/
  adapt.md                      instructions read by /tandem
  config.json                   project settings
```

## Undo

Revert the install commit. Your original files were never overwritten - conflicts went to `.new`.

## Good to know

- **Agent Teams is turned off.** Its members are all Claude, which is expensive. Codex does the work here.
- **Some Codex versions block choosing a sub-worker's model.** That is why adversarial review runs as a separate session.
- **Codex quota becomes the new bottleneck.** The run log tracks usage.
- **Top-tier models may be disabled by default on some accounts.** `/tandem` checks and adjusts routing.

## Fork and publish your own

Fork, then replace `carydev/Tandem` in `boot.ps1` and `boot.sh` with your repo. See [PUBLISH.md](PUBLISH.md) (Korean).

## License

[MIT](LICENSE)
