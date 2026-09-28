# TANDEM

[English](README.md) | **한국어**

**Claude가 지휘하고 Codex가 실무를 한다.**
TANDEM은 어느 프로젝트에나 설치하는 에이전트 하네스다. Claude는 계획, 검수, 보고만 하고
무거운 조사와 작성은 Codex 팀이 Codex 요금제로 한다.

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

그리고 `claude`를 띄워 `/tandem`을 입력한다. 끝이다.

> 이름은 2인용 자전거(tandem)에서 왔다. 앞사람이 핸들을 잡고 뒷사람이 페달을 더 밟는다.
> Claude가 방향을 잡고 Codex가 동력을 댄다.

---

## 왜 쓰나

- **Claude 호출 1회로 Codex 팀 전체가 돈다.** Codex는 하위 일꾼을 스스로 띄운다.
  안에서 몇 명이 돌든 Claude 쪽 소모는 늘지 않는다.
- **실무 부하가 Codex 요금제로 간다.** Claude는 지시, 검수, 보고만 한다.
- **산출물 본문이 Claude 컨텍스트에 안 들어온다.** Codex가 파일에 직접 쓰고,
  Claude는 경로와 5줄 요약만 받는다.
- **반박은 다른 모델이 한다.** 제안 → 적대 검토(다른 모델, 별도 세션) → 대응.
  같은 모델끼리 토론하면 금방 합의해 버린다.

## 준비물

- [Claude Code](https://claude.com/claude-code) CLI
- [Codex CLI](https://github.com/openai/codex)와 로그인된 계정. **Codex 없이는 동작하지 않는다.**
  없으면 설치 스크립트가 설치와 `codex login`을 제안한다.
- git 저장소 (권장. 되돌리기 수단이 된다)

## 빠른 시작

**설치할 프로젝트의 루트에서** 실행한다.

**Windows (PowerShell)**

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash
```

프로젝트에 맞춘다.

```
claude
/tandem
```

`/tandem`은 환경(실제 Codex 모델 ID, CLI 플래그)을 확인하고, 기존 문서 구조와 ID 체계에 맞춘 뒤
스모크 테스트까지 하고 보고한 다음 멈춘다. **커밋은 사람이 한다.**

총괄 세션을 띄워 일을 시킨다.

```powershell
claude --append-system-prompt-file ./docs/tandem/lead-charter.md
```

```
<과제 설명>
먼저 의도 파악 질문부터 해. G1 승인 후 진행해.
```

상태는 아무 세션에서나 `/tandem-status`.

## 구조

```
사람                  결정, 방향
 │
Claude 총괄           의도 파악, 최종 판정, 보고        [Claude 요금제]
 │
Claude 팀장           과제 분해, 카드 작성, 검수, 종합   [Claude 요금제]
 │
Claude 전달책         codex exec 호출, 로그 기록        [Claude 요금제, 극소]
 │
Codex 실무 리드       팀 편성, 설계 판단, 종합          [Codex 요금제]
 ├ 조사 일꾼 (경량 모델)
 ├ 설계 일꾼 (중상위 모델)
 ├ 구현 일꾼 (경량 모델)
 └ 적대 검토 (별도 세션, 다른 모델)

Claude 교차 검수      되돌리기 어려운 결정에만          [Claude 요금제, 드물게]
```

흐름: 지시 → 의도 파악 질문 → **G1**(과제 정의 확인) → Codex 팀 실행 → 검수 →
**G2**(브리핑) → 승인된 것만 반영. 사람 답 없이는 게이트를 못 넘는다.

## 무엇이 따라오나

| 기능 | 내용 |
|---|---|
| **모델 배치표** | 작업별 모델과 추론 강도. 한 단계 낮게 시작하고 실패했을 때만 승급 |
| **결재 게이트** | G1 과제 정의 확인, G2 브리핑. 사람 승인 없이는 다음으로 안 넘어감 |
| **과제 카드** | Codex는 대화 기록을 못 본다. 맥락을 담은 지시서를 파일로 전달 |
| **3라운드 토론** | 제안 → 적대 검토 → 대응. 합의 안 되면 쟁점으로 남김 |
| **실행 로그** | `runs.jsonl`에 호출마다 한 줄. 모델, 강도, 성공/실패, 승급 여부 |
| **자기 개선** | 팀장이 로그를 집계해 배치표 수정안을 냄. 감이 아니라 데이터로 고침 |
| **하네스 현황** | 한 파일만 읽으면 버전, 활성 역할, 확정 모델, 환경 상태를 앎 |
| **파일 소유권** | 누가 어떤 문서를 고칠 수 있는지 고정. 에이전트끼리 덮어쓰는 사고 방지 |

### 잘 맞는 경우

- 조사와 작성이 많아 Claude 쿼터가 금방 닳는 프로젝트
- 결정의 근거와 반론을 기록으로 남겨야 하는 일
- 혼자 하면서 검토자가 필요한 1인 개발
- 여러 세션에 걸쳐 오래 가는 작업

### 안 맞는 경우

- 한 번에 끝나는 짧은 작업. 계층이 오히려 느리다
- Codex CLI를 쓸 수 없는 환경
- 즉답이 필요한 대화형 작업

---

## 설치 상세

### 내려받아 실행

클론이나 압축으로 받았으면 **프로젝트 루트에서** 스크립트를 부른다.

```powershell
경로\Tandem\install.ps1
```

```bash
경로/Tandem/install.sh
```

### 옵션

| 옵션 (PowerShell / bash) | 뜻 |
|---|---|
| `-DocsRoot <경로>` / `[경로]` | 운영 문서 폴더. 기본 `docs/tandem` |
| `-SkipDeps` / `--skip-deps` | Codex 설치와 로그인 확인을 건너뛴다 |
| `-Yes` / `-y` | 묻지 않고 진행. 무인 실행용 |
| `-Force` (PowerShell만) | 이미 설치돼 있어도 템플릿을 다시 배치 |

한 줄 설치에 옵션을 주려면:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -DocsRoot docs/ops
```

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash -s -- docs/ops
```

### 설치 스크립트가 하는 일

1. git, `claude` 확인. 동의하면 **`codex` 설치와 로그인**까지 처리
   (Windows `winget install OpenAI.Codex`, macOS `brew install --cask codex`, 둘 다 없으면 `npm install -g @openai/codex`)
2. 프로젝트 이름 감지 (git remote 또는 폴더명)
3. 역할 파일, 슬래시 커맨드, Codex 설정, 운영 문서 배치
4. `CLAUDE.md` / `AGENTS.md`에 TANDEM 블록 삽입 (기존 내용 보존)
5. `.claude/settings.json` 병합 (기존 설정 보존)
6. `.gitignore`에 `.codex-last/` 추가
7. `tandem/config.json` 생성

**기존 파일을 덮어쓰지 않는다.** 겹치면 `.new`로 저장하고 알려준다. 여러 번 실행해도 안전하다.

### 설치되는 것

```
.claude/
  agents/tandem-manager.md      팀장
  agents/tandem-dispatch.md     전달책
  agents/tandem-critic.md       교차 검수
  commands/tandem.md            /tandem
  commands/tandem-status.md     /tandem-status
  settings.json                 병합됨
.codex/
  config.toml                   프로파일 4종
  agents/*.toml                 실무 리드, 조사, 구현, 검토
docs/tandem/                    (변경 가능)
  harness-status.md             현재 상태. 세션 시작 시 먼저 읽는다
  lead-charter.md               총괄 전용 규칙
  model-routing.md              모델 배치와 승급 조건
  delegation.md                 위임 방식, 비용 규칙, 함정
  operating-model.md            조직, 흐름, 파일 소유권
  log/runs.jsonl                실행 로그
  tasks/ briefings/ reports/    작업 산출물
CLAUDE.md                       TANDEM 블록 삽입
AGENTS.md                       TANDEM 블록 삽입
tandem/
  adapt.md                      /tandem 이 읽는 지시서
  config.json                   프로젝트 설정
```

## 되돌리기

설치 커밋을 되돌리면 된다. 기존 파일은 덮어쓰지 않고 `.new`로 저장되므로 원본이 그대로 있다.

## 알아둘 것

- **Agent Teams는 꺼진다.** 팀원이 전부 Claude라 비용이 크다. 실무는 Codex가 한다.
- **Codex 버전에 따라 하위 일꾼 모델 지정이 막혀 있다.** 그래서 적대 검토는 별도 세션으로 돌린다.
- **Codex 쿼터가 새 병목이 된다.** 실행 로그로 소모를 추적한다.
- **최상위 모델은 계정에 따라 기본 비활성일 수 있다.** `/tandem`이 확인해 배치를 조정한다.

## 포크해서 배포하기

포크한 뒤 `boot.ps1`과 `boot.sh`의 `carydev/Tandem`을 본인 것으로 바꾼다. 절차는 [PUBLISH.md](PUBLISH.md).

## 라이선스

[MIT](LICENSE)
