# 인수인계 — TANDEM 저장소

> 이 파일은 Claude Code 세션이 작업을 이어받기 위한 문서다. **작업 시작 전에 전부 읽는다.**
> 작업이 끝나면 "진행 상황" 절을 갱신한다.

## 이 저장소는 무엇인가

**TANDEM** — 메인(대화 상대)이 지휘하고 서브가 실무를 하는 AI 에이전트 하네스. Claude/Codex 조합 4가지 모드.
어느 프로젝트에나 설치할 수 있는 배포용 템플릿 저장소다.

- 저장소: `https://github.com/carydev/Tandem`
- 소유자: carydev
- 라이선스: MIT
- 버전: v1.5 (`VERSION` 파일이 기준. 업데이트 알림이 이 파일을 본다)

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
  tools/*.ps1                설치 대상에 그대로 복사되는 도구 (check, token-report, jev, manifest, diff, batch-run, codex-run, claude-run)
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
| 실패 교훈은 카드 작성자가 `lessons/lessons.md`에 한 줄, 상시 로드 안 함 (카드 쓸 때 태그 grep) | 사용자 결정(2026-10-14): 메인 쪽이 기록. 상시 로드하면 시작 비용이 늘어난다. 설치는 README만 (데이터 파일이 `.new`를 만들지 않게) |
| 규칙 4 멈춤은 요약 첫 줄 `STOPPED:`, 래퍼가 `stopped`로 기록 | 래퍼는 산출물만 있으면 ok, 요약은 마지막 5줄이라 멈춤이 위로 안 올라갔다 |
| R2 검토 입력은 카드 + 변경분 파일(`diff.ps1`, 새 파일 포함, 인덱스 무변경) + 산출물 경로만. 래퍼 모드는 R2에서 자동 첨부 | 과정 모르는 검토가 결함을 더 찾는다는 실사용 보고. 읽기 전용 검토자가 셸을 못 쓰는 환경 대비해 diff는 파일로 |
| 래퍼 `-Model`/`-Effort` 정규식 검증 (try 안, `status=fail`) | `codex.cmd`/`claude.cmd`는 cmd.exe를 거쳐 `&` 등으로 명령 주입 가능. ValidateSet은 try 밖 오류라 전달책이 못 읽음 |
| **서브는 최상위 모델을 기본으로 못 쓴다** (`claude_top`/`codex_top`). 허용은 사용자 직접 지정(`decided_by=human`) 또는 mid 1회 실패 + 총괄이 '모델 능력 부족'으로 판정. 카드당 승급 1회 | 사용자 결정(2026-10-19): 서브가 최상위를 써서 토큰이 필요 이상으로 든다. 스펙 모호·환경·범위 문제는 승급이 아니라 카드 수정 |
| 래퍼는 최상위 모델이면 `-Reason`(1-200자, 큰따옴표·줄바꿈 금지) + `-EscalatedFrom`(또는 `-DecidedBy human`) 없이 `status=fail`. runs.jsonl에 `escalated_from`·`reason` 기록 | 문서 규칙만으로는 안 지켜진다. 래퍼가 강제해야 수치로 확인 가능 |
| 팀장(tandem-manager)만 예외: 기본 = 총괄 바로 아래 단계(`claude_manager`, 단계표 fable→opus→sonnet→haiku). 사용자 지정·총괄 판단으로만 최상위 | 사용자 결정(2026-10-19): 팀장은 판단 역할. 총괄이 fable이면 opus, opus면 sonnet |
| R2 적대 검토는 mid 단계 별도 세션(읽기 전용, 가능하면 다른 모델). 되돌리기 어려운 결정 검수만 총괄 승인으로 최상위 | 사용자 결정(2026-10-19). reviewer.toml·profiles.critic은 MID. claude-main의 .codex/config.toml 기본 model도 MID |
| Jev `-Route`는 `top`을 고르지 않음 (기본 Tiers mid,light; top만 넘기면 `invalid_tiers`로 배치표) | 승급은 총괄만 결정. `-Escalate`는 참고용 |
| **같은 과제·같은 모델의 후속 호출은 래퍼가 이전 세션을 이어 씀** (`codex exec … resume <thread> -`, Claude `--resume`). R2·승급(`-EscalatedFrom`)·`-NewSession`은 새 세션. runs.jsonl `resumed`·`thread_total` | 실측(2026-10-19): 새 세션은 폴더가 다르면 캐시 0, 같아도 20k 중 7k. resume 후속 턴은 99% 캐시. 실사용 감사에서 세션당 1호출 310건·캐시율 2.5% |
| Codex `turn.completed.usage`는 스레드 누계라 래퍼·batch-run이 이전 누계를 빼서 기록 | 실측 20272 → 40562 → 60882. 안 빼면 이어쓴 호출의 토큰이 중복 집계된다 |
| `--ephemeral` 금지, `-C`는 프로젝트 루트 고정 | ephemeral 스레드는 resume 불가(`no rollout found`). 폴더가 바뀌면 캐시 0 |
| 반복 항목 작업은 `batch-run.ps1` (묶음당 세션 하나, 고정 블록은 첫 턴에만, 세션 교체 상한, `-OnlyChanged`, 연속 3건 실패 중단, 항목별 증분 usage.jsonl + runs.jsonl 1줄) + `docs/batch.md` 규칙 6개 | 사용자 결정(2026-10-19): 역식 프로젝트만 고치지 않고 모든 프로젝트에 같이 적용되게. 자체 루프(Python)가 있는 프로젝트는 같은 규칙을 어댑터에 구현 |
| 토큰 보고서가 낭비 패턴 3종을 수치로 (캐시율, 1턴 세션 비율, 상태 확인 호출 수, 비캐시 20k 이상 1턴 세션) + 진단 2줄만 | 문서 규칙은 안 지켜진다(역식 AGENTS.md에 '기다린다'가 있었지만 28초마다 264회 폴링). 수치가 있어야 잡힌다 |

## 검증된 것 (v1.1, 2026-10-13, Windows PowerShell 5.1.19041)

- 4개 모드 × 2개 언어를 빈 git 폴더에 설치: 모드별 파일 집합이 `files.json`과 일치, 자리표시자·`@@` 잔존 0, 결과 파일 BOM 0, JSON 유효, en에 한글 0
- 기존 `CLAUDE.md`/`settings.json`(사용자 훅)/`.gitignore` 보존, 재실행 시 `.new` 0개, SessionStart 훅 중복 없음
- 모드 전환(claude-main → codex-solo, → codex-main): 안 고친 전용 파일 삭제, 블록 제거(블록 밖 보존), 사용자가 고친 파일 보존, 비활성 모드 훅 정리
- 실제 실행: `codex-run.ps1`(gpt-6-luna), `claude-run.ps1`(haiku) 한글 카드로 산출물 생성, runs.jsonl에 토큰·세션 자동 기록, 실패는 fail로 기록
- `token-report.ps1` farm-sim 60일: 9초, 메인 평균 맥락 46만·서브 호출당 35요청 등 진단 6개 (수동 분석과 일치)
- `check.ps1`: 알림 JSON(ASCII 이스케이프), 네트워크 실패 시 조용함, exit 0
- R2 적대 검토(gpt-6-astra) 15개 지적 전부 반영 후 재검증 (설치기 C6a, 도구 C6b, 템플릿 C6c 각 보고서 `.work/`는 배포 안 함)

## 검증된 것 (v1.3, 2026-10-14)

- 4개 모드 × 2개 언어 설치 + 언어 섞임 검사(`.work/v1.2/lang-check.ps1`) 통과. v1.2 설치본 위 업그레이드: lessons README 추가, `.new` 0개 (C13)
- 가짜 `codex.cmd`로 래퍼 끝까지 실행: `STOPPED:` 긴/짧은 요약 → `stopped` + 첫 줄 유지, 일반 → `ok`. `-Effort 'low&echo x> ...'` 차단, 파일 미생성
- `token-report.ps1` 시작 비용·세션 길이: 원본 jsonl 수동 계산과 일치 (C14)
- `diff.ps1`: 한글 내용·한글 파일명, 새 파일 포함, .gitignore 제외, 커밋 없는 저장소 확인 (C17 + 수동)
- **Jev 실제 호출 성공** (2026-10-14, 사용자 승인): C14 카드로 `-Route` → effort low(0.85), tier mid(0.37 < 0.6) → `low_confidence`로 배치표 대체. 1회 약 $0.00002
- 주의: 사용자 환경변수에 키가 생긴 뒤로 **lang-check를 돌릴 때마다 실제 Jev 호출이 1회 나간다**(빈 요청 `{}` → `reason=error`, 검사 전제가 키 없음이라 그 항목은 실패). 제품 결함 아님

## 검증된 것 (v1.4, 2026-10-19)

- Claude Code 2.1.303에서 `--model fable` 별칭 동작 확인 (실호출 1회, 약 $0.33 - 기본 시스템 프롬프트 맥락 비용)
- 4모드×2언어 설치: 자리표시자·`@@` 잔존 0, en 한글 0. 기본 설치 `claude_top=opus`, `claude_manager=sonnet`; config에 `claude_lead=fable`을 미리 넣으면 `claude_top=fable`, `claude_manager=opus`, tandem-manager.md model=opus (C18 + 수동)
- v1.3 설치본 재설치: `claude_manager=sonnet` 추가, `.new` 0개. v1.0식 키(claude_manager만) 이관 확인 (C18)
- claude-main 설치본 `.codex/config.toml` 최상위 `model = MID`, codex-main/solo는 TOP (수동)
- 래퍼 게이트 (가짜 `codex.cmd`/`claude.cmd`, C19 + 수동): 최상위 사유 없음·201자·큰따옴표 → `status=fail`, 상태 파일·runs.jsonl 미생성. `-EscalatedFrom`+`-Reason` 또는 `-DecidedBy human -Reason` → 실행, runs.jsonl에 두 필드, 프롬프트에 승급 줄. `fable` 허용, `gpt-5` 거부. C15 주입 차단·C16 STOPPED·C17 R2 diff 보존
- `jev.ps1 -Route -DryRun`: criteria mid·light만, `-Tiers top` → `invalid_tiers` (C20). `token-report.ps1`: 가짜 runs.jsonl 5건 → '사유 없는 실행 2' (C20)
- lang-check 2회 통과(Jev no_key 항목만 알려진 전제 문제로 실패, C21). 이번에도 실제 Jev 호출이 2회 나갔다

## 검증된 것 (v1.5, 2026-10-19)

- Codex 캐시 실측 (gpt-5.6-luna, 20k 프롬프트, 8회): 새 세션·다른 `-C` → cached 0; 같은 `-C`·같은 프롬프트 → 7168; 이미지가 바뀌면 3584; `exec resume` 2·3턴 → 턴 입력의 99%; `--ephemeral` resume 불가; usage 누계
- 실제 Codex로 래퍼 이어쓰기 (임시 git 설치본, claude-main en): 2번째 호출 `resumed=true`, cached 35200/38248 (92%), `thread_total` 누계 171k. 첫 호출은 임시 폴더에서 Codex 샌드박스 쓰기가 'environment setup error'로 실패해 `STOPPED:` → `result=stopped`로 올라옴 (v1.3 경로 확인)
- 실제 Codex로 batch-run (고정 블록 약 14k, 항목 3개): a2·a3 `resumed=true`, cached 14464/14732 (98%), 세션 1개, 캐시율 65.8%, runs.jsonl 1줄
- 가짜 CLI: resume 옵션 위치, R2·승급·`-NewSession`은 새 세션, `no rollout found` → 새 세션 재시도, 증분 계산, 세션 교체(7항목/3) → 3세션, `-OnlyChanged` 전부 skipped, 연속 3건 실패 → `STOPPED:`, 최상위 게이트, DryRun (C22·C24)
- 토큰 보고서: 가짜 Claude 30건·Codex 12세션 → 캐시율, 1턴 10/12, 상태 확인 25, 비캐시 20k 이상 10(중앙값 45k), 진단 2줄, `timestamp` 없으면 `n/a` (C23). 이 저장소 실제 실행 OK

## 검증 안 된 것 (남은 일)

- **Codex 훅**: `.codex/hooks.json`은 프로젝트 신뢰 + `/hooks` 승인 후에만 돈다. 실제 Codex 세션에서 알림 표시 미확인
- **Claude 훅 알림 표시**: settings 병합까지만 확인. 실제 세션 시작 화면 표시 미확인
- `codex login` 브라우저 흐름, winget 설치 (v1.0부터 미검증)
- `/tandem` 적응 전 과정을 실제 프로젝트에서 4개 모드로 돌려보기
- 총괄이 Agent 호출 때 `model`을 지정해 팀장을 최상위로 올리는 동작 (문서로만 정의, 실제 세션 미확인)
- 실제 운영에서 승급 조건(mid 1회 실패 + 능력 부족 판정)이 너무 엄격한지 - runs.jsonl의 `escalated_from`·`reason`으로 추적
- **Codex가 프로젝트 `.codex/config.toml`의 `profiles`·`multi_agent_v2` 키를 무시한다** (2026-10-19, Codex가 `Ignored unsupported project-local config keys: profiles` 경고). 래퍼는 `-m`/`-c`를 직접 넘기므로 영향 없지만 codex-solo의 프로필 기반 설명은 실제로 적용되지 않는다. 템플릿에서 profiles를 빼거나 문서를 고쳐야 함
- `%TEMP%` 아래 임시 폴더에서 Codex `--sandbox workspace-write` 쓰기가 'environment setup error'로 실패 (실제 프로젝트 폴더에서는 미재현). 임시 설치본 실호출 시험은 read-only 또는 batch-run으로
- claude-run `--resume` 실호출 (가짜 CLI만 확인). Claude 세션 디렉터리가 바뀌면 resume 실패 → 새 세션 재시도 경로만 가짜로 확인
- 긴 이어쓰기 스레드의 캐시 읽기 누적 비용 vs 고정 블록 재전송의 손익분기 (추정: 이미지 10k/호출이면 약 10호출, 텍스트만이면 약 25호출). batch-run 기본 30/150k는 텍스트 기준

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
- [x] **v1.3** (2026-10-14): 커뮤니티 조사 반영 - 실패 교훈 기록(`STOPPED:` 표식), 토큰 보고서 시작 비용·세션 길이, 과정 모르는 R2 검토, 래퍼 명령 주입 차단, README 공식 Codex 플러그인 안내
      - Codex 카드 C13-C17. 원격에 있던 v1.2.1(PowerShell 도구 UTF-8 콘솔 출력) 위로 rebase. 태그 `v1.3` + GitHub Releases 생성
      - 배포 검증: 원격 VERSION 1.3, 실제 URL 한 줄 설치(codex-main, en) 성공, v1.2 설치본에서 업데이트 알림 "1.2 -> 1.3"
- [x] **v1.4** (2026-10-19): 서브 최상위 모델 제한 - 단계표(fable→opus→sonnet→haiku)와 팀장 기본값 `claude_manager`(총괄 바로 아래), 래퍼 게이트 `-EscalatedFrom`/`-Reason`, runs.jsonl `reason` 필드, Jev top 제외, 토큰 보고서 최상위 사용 수치, R2·reviewer·critic mid, claude-main config.toml 기본 mid, `fable` 별칭, 규칙 문서화(model-routing.md '최상위 모델 사용 규칙')
      - Codex 카드 C18-C21 (`.work/v1.4/`). C19가 claude-worker.md(일꾼 시스템 프롬프트)에 래퍼 호출 문장을 넣어서 빼고 delegation.md codex-main 절로 옮김. Codex 실행 중 Claude Code가 메모리 부족으로 배경 셸을 3번 죽였지만 Codex 프로세스는 살아서 완료 (파일 감시로 대기)
      - 배포 검증: 원격 VERSION 1.4, 실제 URL 설치(claude-main, en) 성공 - config에 claude_manager=sonnet, model-routing.md에 Top-model policy, .codex/config.toml 기본 model=MID. 태그 `v1.4` + GitHub Releases 생성
- [x] **v1.5** (2026-10-19): 토큰 효율 - 래퍼 세션 이어쓰기(`-NewSession`, `resumed`·`thread_total`), claude-run `--no-session-persistence` 제거, `batch-run.ps1` + `docs/batch.md`, 토큰 보고서 캐시율·1턴 세션·상태 확인 호출·고정 블록 재전송 수치와 진단 2줄, README 토큰 효율 절
      - 계기: 역식 프로젝트(manga-trans) 사용량 감사 689건 - 하네스 310호출이 전부 새 세션(`--ephemeral` + 호출별 임시 `-C`)이라 46k 고정 블록을 매번 재전송(캐시 2.5%), 메인은 28초마다 264회 상태 확인. 사용자 결정: 역식만 고치지 않고 TANDEM에 일반화
      - Codex 카드 C22-C25 (`.work/v1.5/`). C22·C24의 실호출 시험은 임시 폴더 신뢰 문제로 Codex가 못 해서 내가 git 저장소 임시 설치본에서 직접 실행. 역식 쪽은 별도 카드 `D:/dev/manga-trans/docs/tandem/tasks/MT-902.md` (Python 어댑터에 같은 규칙 구현 + `wait_run.py` 블로킹 대기)
      - 배포 검증: 원격 VERSION 1.5, 실제 URL 설치(codex-main, ko) 성공 - batch-run.ps1·docs/batch.md 배치, claude-run에 resume. 태그 `v1.5` + GitHub Releases. 내가 고친 것: batch-run의 `--image` 뒤에 `resume`이 오면 이미지 경로로 먹히는 버그(MT-902 보고서에서 발견) → 이미지 인자를 앞으로 이동, 메시지 ko/en 분리 + BOM
      - 역식(manga-trans) MT-902 완료: 하네스 테스트 97개 통과, 실제 2쪽 호출 이어쓰기 캐시 93.6%, `wait_run.py`. **커밋은 안 했다** (그 저장소는 커밋 위임 없음, `harness/` 폴더 자체가 미추적 상태). TANDEM 설치본은 v1.2.1 그대로 - 업그레이드 여부는 사용자 결정
- [ ] **보류** 플러그인 방식 배포 (Claude `/plugin`, Codex `codex plugin`) - 한 줄 설치는 공식 마켓플레이스 심사가 필요해 보류. 계획: `docs/plan-plugin-distribution.md`

## 지키면 좋을 것

- **커밋은 사람이 지시할 때만.** (2026-09-28부터 사용자가 커밋·푸시를 맡김)
- 스크립트를 고쳤으면 빈 폴더와 기존 파일이 있는 폴더 양쪽에서 다시 돌려 본다.
- 문서 문체: 결론 먼저, 짧고 직접적으로, 미사여구 없이. 범위는 하이픈(-)으로 표기.
- 작업 문서는 한국어가 기본이다. README만 예외: `README.md`(영어, 기본)와 `README.ko.md`(한국어)를 함께 고친다.
