# 인수인계 — TANDEM 저장소

> 이 파일은 Claude Code 세션이 작업을 이어받기 위한 문서다. **작업 시작 전에 전부 읽는다.**
> 작업이 끝나면 "진행 상황" 절을 갱신한다.

## 이 저장소는 무엇인가

**TANDEM** — 메인(대화 상대)이 지휘하고 서브가 실무를 하는 AI 에이전트 하네스. Claude/Codex 조합 4가지 모드.
어느 프로젝트에나 설치할 수 있는 배포용 템플릿 저장소다.

- 저장소: `https://github.com/carydev/Tandem`
- 소유자: carydev
- 라이선스: MIT
- 버전: v1.2 (`VERSION` 파일이 기준. 업데이트 알림이 이 파일을 본다)

**이 저장소 자체에는 TANDEM이 설치돼 있지 않다.** 여기는 남에게 나눠 줄 템플릿을 담는 곳이다.
`.gitignore`가 설치 결과물(`docs/tandem/`, `tandem/config.json`, `tandem/manifest.json`)을 막고 있다. 이건 의도된 것이다.

## 구조

```
install.ps1                  설치·업데이트 스크립트 (UTF-8 BOM)
boot.ps1                     원격 한 줄 설치 (ASCII 전용, BOM 없음 - 절대 바꾸지 마라)
install.sh / boot.sh         v1.0 그대로. 지원 안 함
VERSION                      현재 버전 (업데이트 알림 기준)
tandem/
  files.json                 파일 계약: 무엇을 어느 모드에 어디로 놓는가
  templates/ko/, en/         언어별 템플릿 (상대 경로 구조 동일)
    claude/ codex/ docs/ blocks/ settings.json adapt.md
  tools/*.ps1                설치 대상에 그대로 복사되는 도구 (check, token-report, jev, manifest, codex-run, claude-run)
docs/plan-plugin-distribution.md  보류된 플러그인 배포 계획
docs/design-v1.1.md          v1.1 설계서 (모드, 렌더링, 지문 업데이트, 훅, Jev, 리포트, 래퍼)
README.md / README.ko.md     사용자 문서 (영어 기본 / 한국어). 함께 고친다
PUBLISH.md / QUICKSTART.txt / LICENSE / HANDOFF.md
```

템플릿에는 `{{PROJECT}}`, `{{DOCS}}`, `{{MODEL_MID}}` 등 자리표시자와 `@@if <모드...>` / `@@endif` 줄 조건이 있다.
설치 스크립트가 처리한다. **자리표시자·조건 줄을 깨뜨리지 마라.** ko 를 고치면 en 도 같은 의미로 고친다.

## 설계 결정과 이유 (되돌리지 마라)

| 결정 | 이유 |
|---|---|
| Claude 호출 1회로 Codex 팀 전체 가동 | Codex는 자기 하위 일꾼을 스스로 띄운다. Claude가 하나씩 부르면 요금이 배로 든다 |
| 전달책이 산출물 본문을 안 읽음 | 본문이 Claude 컨텍스트에 들어오면 절감 효과가 사라진다. 경로와 5줄 요약만 반환 |
| 적대 검토는 별도 세션 + `-m` | Codex 일부 버전에서 하위 일꾼 모델 지정이 막혀 있다. 별도 세션이면 버전과 무관하게 분리 보장 |
| Agent Teams 기본 꺼짐 | 팀원이 전부 Claude라 비용이 크다. 실무는 Codex가 한다 |
| 하위 일꾼이 파일에 씀 | 반환 payload를 못 받고 끝나는 사례가 보고돼 있다 |
| 기존 파일 덮어쓰지 않음 | `.new`로 저장. 설치가 남의 프로젝트를 깨면 안 된다. **v1.1 보완(사용자 승인 2026-10-13):** TANDEM이 깔았고 아무도 안 고친 파일(`tandem/manifest.json` 지문 일치)만 업데이트 때 교체. 이미 있는 `.new`도 덮어쓰지 않음 |
| `CLAUDE.md`/`AGENTS.md`는 블록 삽입 | 기존 내용 보존. 재실행 시 블록만 갱신 |
| 설치와 적응을 분리 | 스크립트는 파일만 놓고, 프로젝트 맞춤은 `/tandem`이 한다. 환경마다 모델 ID가 다르다 |
| 실행 로그 JSONL | 여러 주체가 append 해도 안 깨진다. 배치표를 데이터로 고치는 근거 |
| 모드 4가지 (claude-main, codex-main, claude-solo, codex-solo) | 프로젝트마다 대화 상대·실무 담당이 다르다. 메인은 지시·검수·보고만 |
| 서브 호출은 래퍼(`codex-run`/`claude-run`)로만, 러너가 로그 기록 | farm-sim 실측: 전달책 폴링으로 위임 1회당 26-417 요청, Codex 실행 40% 로그 누락 |
| `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` (inherit 폐기) | 모델 미지정 서브에이전트가 메인의 비싼 모델로 돌았다 (실측 11%) |
| 카파시 규칙 1-3 전원, 4는 서브에게만 (같은 실패 3회면 중단) | 메인이 직접 반복 수정하면 "메인은 실무 안 함" 원칙이 깨진다 |
| Jev는 모델·강도 선택, 승급, 교차 검수 필요 여부만 | 이유를 안 주는 모델이다. 합격 판정·G1/G2는 맡기지 않는다. 키는 사용자 환경변수에만 |
| 사용자가 고르지 않은 언어는 절대 보이지 않음 (선택 전엔 Windows 표시 언어, `boot.ps1`은 유니코드 이스케이프로 ASCII 유지) | 사용자 요구(2026-10-13). 검사: `.work/v1.2/lang-check.ps1` (배포 안 함) |
| Jev 끄기는 config에 저장 (`-NoJev`/`-UseJev`) | Jev를 원치 않는 사용자에게 질문·알림·호출이 전혀 없어야 한다 |
| 메인의 사용자 응대 최우선 규칙 3개 | 사용자 요구(2026-10-13): 선택 언어로 대답, 분기점 설명, 완료 보고는 간결 |

## 검증된 것 (v1.1, 2026-10-13, Windows PowerShell 5.1.19041)

- 4개 모드 × 2개 언어를 빈 git 폴더에 설치: 모드별 파일 집합이 `files.json`과 일치, 자리표시자·`@@` 잔존 0, 결과 파일 BOM 0, JSON 유효, en에 한글 0
- 기존 `CLAUDE.md`/`settings.json`(사용자 훅)/`.gitignore` 보존, 재실행 시 `.new` 0개, SessionStart 훅 중복 없음
- 모드 전환(claude-main → codex-solo, → codex-main): 안 고친 전용 파일 삭제, 블록 제거(블록 밖 보존), 사용자가 고친 파일 보존, 비활성 모드 훅 정리
- 실제 실행: `codex-run.ps1`(gpt-6-luna), `claude-run.ps1`(haiku) 한글 카드로 산출물 생성, runs.jsonl에 토큰·세션 자동 기록, 실패는 fail로 기록
- `token-report.ps1` farm-sim 60일: 9초, 메인 평균 맥락 46만·서브 호출당 35요청 등 진단 6개 (수동 분석과 일치)
- `check.ps1`: 알림 JSON(ASCII 이스케이프), 네트워크 실패 시 조용함, exit 0
- R2 적대 검토(gpt-6-astra) 15개 지적 전부 반영 후 재검증 (설치기 C6a, 도구 C6b, 템플릿 C6c 각 보고서 `.work/`는 배포 안 함)

## 검증 안 된 것 (남은 일)

- **Jev 실제 호출**: 키가 없어 `-DryRun`·키 없음·응답 검증 함수만 확인
- **Codex 훅**: `.codex/hooks.json`은 프로젝트 신뢰 + `/hooks` 승인 후에만 돈다. 실제 Codex 세션에서 알림 표시 미확인
- **Claude 훅 알림 표시**: settings 병합까지만 확인. 실제 세션 시작 화면 표시 미확인
- `codex login` 브라우저 흐름, winget 설치 (v1.0부터 미검증)
- `/tandem` 적응 전 과정을 실제 프로젝트에서 4개 모드로 돌려보기

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
- [x] **v1.1** (2026-10-13): 모드 4가지, 언어 선택(ko/en), 지문 기반 업데이트, 세션 시작 알림(새 버전·Jev 키),
      Jev 선택 기능, `/tandem-tokens` 리포트와 다이어트 진단, 실행 래퍼(폴링 차단·자동 로그), 카파시 규칙, 사용자 응대 규칙
      - TANDEM 방식으로 작업: Claude가 설계서·카드·검수, Codex가 구현 12회(C1-C8). Codex 입력 2,253만 중 97% 캐시, 출력 20만
      - 승급 1회: C4 번역 gpt-6-luna 실패(구조만 복사) → gpt-6-sol 재시도 성공
- [x] v1.1 푸시 `c41a28e` + 원격 검증 (2026-10-13): 실제 URL 옵션 설치(codex-main, en) 성공, 원격 VERSION 기준 업데이트 알림 "1.0 -> 1.1" 확인
- [x] 릴리스 노트 `CHANGELOG.md`/`CHANGELOG.ko.md`, 태그 `v1.0`(3d4571b)·`v1.1`(4cdd196) 푸시 (2026-10-13)
- [x] GitHub Releases `v1.1` 생성 (2026-10-13) https://github.com/carydev/Tandem/releases/tag/v1.1

방침: **Windows 전용으로 최적화한다.** `install.sh`/`boot.sh`는 남겨 두지만 검증과 개선 대상이 아니다.

- [x] **v1.2** (2026-10-13): Jev 잔액 부족(402)·키 오류(401) 안내 + 배치표 대체 + 다음 세션 알림, Jev 끄기/켜기(`-NoJev`/`-UseJev`, 저장됨), 사용자 언어 일관성(전 출력), README Jev 절
      - Codex 카드 C10-C12. 검증: 4모드×2언어 통합 시험, 언어 검사(가짜 서버 시작 타이밍 때문에 402 항목이 가끔 실패 - 기능 결함 아님, 재실행 2회 통과)
- [ ] **보류** 플러그인 방식 배포 (Claude `/plugin`, Codex `codex plugin`) - 한 줄 설치는 공식 마켓플레이스 심사가 필요해 보류. 계획: `docs/plan-plugin-distribution.md`

## 지키면 좋을 것

- **커밋은 사람이 지시할 때만.** (2026-09-28부터 사용자가 커밋·푸시를 맡김)
- 스크립트를 고쳤으면 빈 폴더와 기존 파일이 있는 폴더 양쪽에서 다시 돌려 본다.
- 문서 문체: 결론 먼저, 짧고 직접적으로, 미사여구 없이. 범위는 하이픈(-)으로 표기.
- 작업 문서는 한국어가 기본이다. README만 예외: `README.md`(영어, 기본)와 `README.ko.md`(한국어)를 함께 고친다.
