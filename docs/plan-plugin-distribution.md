# 보류: 플러그인 방식 배포 (Claude Code / Codex)

> 상태: **보류** (2026-10-13, 사용자 결정). 구현하지 않음. 다시 꺼낼 때 이 문서부터 본다.

## 목표

어느 PC에서든 Claude Code나 Codex 안에서 명령어로 TANDEM을 추가한다. `npm add` 같은 사용감.
지금은 프로젝트마다 PowerShell 한 줄 설치(`iwr ... | iex`)를 따로 실행해야 한다.

## 확인된 사실 (2026-10-13, Claude Code 2.1.296 / Codex CLI 0.156.0)

두 도구 모두 **GitHub 저장소를 플러그인 마켓플레이스로 추가**하는 기능이 있다.

| | 처음 한 번 (PC마다) | 이후 (프로젝트마다) |
|---|---|---|
| Claude Code | `/plugin marketplace add carydev/Tandem` → `/plugin install tandem@tandem` | `/tandem:install` |
| Codex | `codex plugin marketplace add carydev/Tandem` → `codex plugin add tandem@tandem` | `$tandem-install` (스킬) |

- `claude plugin marketplace add <source>`: URL, 경로, GitHub `owner/repo` 지원. `--scope user` 기본.
- `codex plugin marketplace add <SOURCE>`: 로컬 경로, `owner/repo[@ref]`, HTTPS/SSH Git URL 지원. `codex plugin add PLUGIN@MARKETPLACE`.
- Codex 사용자 스킬 위치: `$HOME/.agents/skills/<이름>/SKILL.md` (frontmatter `name`, `description` 필수). 호출은 `$이름` 또는 `/skills`.
- 등록 정보는 PC 로컬(`~/.claude`, `~/.codex`, `~/.agents`)에 저장된다. 계정 따라 동기화되지 않는다.

## 보류 이유

- **명령 한 줄(`/plugin install tandem`)로 끝내려면 Anthropic·OpenAI 공식 마켓플레이스 등록(심사)이 필요하다.**
  심사 없이 가능한 건 위 표처럼 "마켓플레이스 추가 + 설치" 두 줄이다. 사용자 판단: 심사가 필요하면 의미가 작다.
- 현재 한 줄 설치(`iwr ... | iex`)와 비교해 얻는 이득이 "PowerShell 대신 대화창에서 입력" 정도다.

## 다시 할 때의 설계 메모

- 저장소 루트에 Claude 마켓플레이스 파일(`.claude-plugin/marketplace.json`)과 플러그인(커맨드 `install`)을 둔다.
  커맨드는 플러그인 폴더의 `install.ps1`을 현재 프로젝트에 실행하고, 이어서 같은 세션에서 `tandem/adapt.md` 적응을 진행한다. 설치 파일은 플러그인에 들어 있어 매번 내려받지 않는다.
- Codex 마켓플레이스·플러그인 형식은 구현 전에 공식 문서로 확인한다(이 문서 작성 시점엔 CLI 도움말만 확인).
- 플러그인 버전은 `VERSION`과 맞춘다. 업데이트는 각 도구의 마켓플레이스 업데이트(`codex plugin marketplace upgrade` 등)로.
- 공식 마켓플레이스 등록을 하게 되면 그때 한 줄 설치가 된다. 등록 절차·요건은 그 시점에 확인.
- 대안(비추천): MCP 서버로 설치 도구 제공 — 한 번 쓰는 설치에 상시 서버가 필요해 과하다.
