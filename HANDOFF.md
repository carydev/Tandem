# 인수인계 — TANDEM 저장소

> 이 파일은 Claude Code 세션이 작업을 이어받기 위한 문서다. **작업 시작 전에 전부 읽는다.**
> 작업이 끝나면 "진행 상황" 절을 갱신한다.

## 이 저장소는 무엇인가

**TANDEM** — Claude가 지휘하고 Codex가 실무를 하는 AI 에이전트 하네스.
어느 프로젝트에나 설치할 수 있는 배포용 템플릿 저장소다.

- 저장소: `https://github.com/carydev/Tandem`
- 소유자: carydev
- 라이선스: MIT
- 버전: v1.0

**이 저장소 자체에는 TANDEM이 설치돼 있지 않다.** 여기는 남에게 나눠 줄 템플릿을 담는 곳이다.
`.gitignore`가 설치 결과물(`docs/tandem/`, `tandem/config.json`)을 막고 있다. 이건 의도된 것이다.

## 구조

```
install.ps1 / install.sh     설치 스크립트 (사람이 직접 받았을 때)
boot.ps1 / boot.sh           원격 한 줄 설치 부트스트랩
tandem/
  adapt.md                   설치 후 /tandem 이 읽는 적응 지시서
  templates/                 설치 시 배치되는 원본 파일들
    claude/agents/*.md       팀장, 전달책, 교차 검수
    claude/commands/*.md     /tandem, /tandem-status
    codex/config.toml        Codex 프로파일 4종
    codex/agents/*.toml      실무 리드, 조사, 구현, 검토
    docs/*.md                운영 문서 6종
    CLAUDE.tandem.md         CLAUDE.md 에 삽입될 블록
    AGENTS.tandem.md         AGENTS.md 에 삽입될 블록
    settings.tandem.json     .claude/settings.json 에 병합될 조각
README.md                    사용자용 문서 (영어, 기본)
README.ko.md                 사용자용 문서 (한국어)
PUBLISH.md                   배포 절차 (포크하는 사람용)
QUICKSTART.txt               3줄 요약
LICENSE                      MIT
HANDOFF.md                   이 파일
```

`templates/` 안의 파일에는 `{{PROJECT}}`, `{{DOCS}}`, `{{MODEL_MID}}` 같은 자리표시자가 있다.
설치 스크립트가 치환한다. **템플릿을 고칠 때 자리표시자를 깨뜨리지 마라.**

## 설계 결정과 이유 (되돌리지 마라)

| 결정 | 이유 |
|---|---|
| Claude 호출 1회로 Codex 팀 전체 가동 | Codex는 자기 하위 일꾼을 스스로 띄운다. Claude가 하나씩 부르면 요금이 배로 든다 |
| 전달책이 산출물 본문을 안 읽음 | 본문이 Claude 컨텍스트에 들어오면 절감 효과가 사라진다. 경로와 5줄 요약만 반환 |
| 적대 검토는 별도 세션 + `-m` | Codex 일부 버전에서 하위 일꾼 모델 지정이 막혀 있다. 별도 세션이면 버전과 무관하게 분리 보장 |
| Agent Teams 기본 꺼짐 | 팀원이 전부 Claude라 비용이 크다. 실무는 Codex가 한다 |
| 하위 일꾼이 파일에 씀 | 반환 payload를 못 받고 끝나는 사례가 보고돼 있다 |
| 기존 파일 덮어쓰지 않음 | `.new`로 저장. 설치가 남의 프로젝트를 깨면 안 된다 |
| `CLAUDE.md`/`AGENTS.md`는 블록 삽입 | 기존 내용 보존. 재실행 시 블록만 갱신 |
| 설치와 적응을 분리 | 스크립트는 파일만 놓고, 프로젝트 맞춤은 `/tandem`이 한다. 환경마다 모델 ID가 다르다 |
| 실행 로그 JSONL | 여러 주체가 append 해도 안 깨진다. 배치표를 데이터로 고치는 근거 |

## 검증된 것

다음은 실제로 돌려서 확인했다.

- 빈 git 저장소에 설치
- 기존 `CLAUDE.md`, `.claude/settings.json`, 같은 이름 역할 파일이 있는 프로젝트에 설치
- 재실행 멱등성 (블록 중복 안 생김, 로그 보존, config 보존)
- `settings.json` 병합 시 기존 키(hooks 등) 보존
- 비대화형 실행 (질문이 자동 거절로 처리되고 멈추지 않음)
- `--skip-deps` 경로
- 자리표시자 잔존 없음
- `.gitignore`가 설치 결과물을 제외

## 검증 안 된 것 (남은 일)

- **실제 URL에서 한 줄 설치.** `boot.ps1`/`boot.sh`는 `carydev/Tandem`을 가리키게 돼 있지만
  실제로 raw.githubusercontent 에서 받아 도는지는 푸시 후에 확인해야 한다.
  **저장소 이름 대소문자가 중요하다. `Tandem`이지 `tandem`이 아니다.**
- **Codex CLI 설치와 로그인 흐름.** `winget install OpenAI.Codex`, `codex login status` 기반인데
  실제 환경에서 안 돌려봤다.
- Windows PowerShell 5.1 에서의 동작. 스크립트는 UTF-8 BOM으로 저장돼 있어 한글이 깨지지 않아야 하지만
  실제 확인은 안 했다.

## 진행 상황

- [x] 템플릿, 설치 스크립트, 부트스트랩, 문서 작성
- [x] `carydev/Tandem` 주소 반영
- [x] README 영어(`README.md`, 기본) + 한국어(`README.ko.md`) 분리 (2026-09-28)
- [x] **`boot.ps1` BOM 제거, ASCII 전용화** (2026-09-28). BOM이 있으면 PS 5.1에서 `iwr | iex`와
      `[scriptblock]::Create` 둘 다 `Unexpected attribute 'CmdletBinding'`로 실패했다. 로컬 HTTP 서버로 재현 후 수정.
      **`boot.ps1`에 한글이나 BOM을 다시 넣지 마라.** `install.ps1`은 파일로 실행되므로 BOM 유지
- [x] **`install.ps1` codex 로그인 확인 시 중단 버그 수정** (2026-09-28). `codex login status`가 stderr로 출력하는데
      `$ErrorActionPreference = "Stop"`인 PS 5.1이 이를 오류로 보고 설치를 멈췄다. `Native { }` 래퍼로 감쌈
- [x] `install.ps1`이 `settings.json`/`config.json`/`.gitignore`/`CLAUDE.md` 추가분을 BOM 없이 쓰도록 통일
- [x] 태그 설치 버그 수정. `boot.*`가 `refs/heads/$Ref`를 써서 태그가 404였다. `codeload .../zip/$Ref`로 변경.
      PUBLISH.md의 `TANDEM_REF=` 위치 오류 수정
- [x] Windows PowerShell 5.1 검증 (2026-09-28, 5.1.19041): 빈 git 저장소 / 기존 `CLAUDE.md`·`settings.json`(hooks)·`.gitignore`
      있는 폴더 / 재실행 멱등성. 한글 출력 정상, 결과 파일 BOM 없음, JSON 유효, 자리표시자 잔존 0, 블록 중복 없음, hooks 보존
- [x] codex 로그인됨 경로(실제 계정)와 미로그인 경로(빈 `CODEX_HOME`) 확인. **`codex login` 브라우저 흐름과 winget 설치는 미검증**
- [x] 첫 푸시 `3334b14` (2026-09-28). GitHub 자동 생성 README 커밋 `22e0e22` 위에 얹음
- [x] 실제 URL로 한 줄 설치 검증 (2026-09-28). PS 5.1, 빈 git 폴더에서 `iwr ... | iex` 성공, 20개 배치
- [ ] 저장소 description, topics 설정 - `gh`가 로그인 안 돼 있어 사람이 GitHub 웹에서 직접 넣는다
- [ ] 릴리스 태그 `v1.0`

방침: **Windows 전용으로 최적화한다.** `install.sh`/`boot.sh`는 남겨 두지만 검증과 개선 대상이 아니다.

## 지키면 좋을 것

- **커밋은 사람이 한다.** 에이전트가 임의로 커밋하거나 푸시하지 않는다.
- 스크립트를 고쳤으면 빈 폴더와 기존 파일이 있는 폴더 양쪽에서 다시 돌려 본다.
- 문서 문체: 결론 먼저, 짧고 직접적으로, 미사여구 없이. 범위는 하이픈(-)으로 표기.
- 작업 문서는 한국어가 기본이다. README만 예외: `README.md`(영어, 기본)와 `README.ko.md`(한국어)를 함께 고친다.
