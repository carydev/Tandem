# 변경 기록

[English](CHANGELOG.md) | **한국어**

## v1.8 (2026-10-29)

- 칸반 보드: `docs/tandem/board/index.html` 이 같은 폴더의 `board-data.js` 를 3초마다 다시 읽어 할 일·진행중·작업완료·리뷰·테스트·완료·막힘 칸을 보여 준다. 파일을 더블클릭해서 열면 되고 서버가 필요 없다. 카드에 에이전트·모델·실행 횟수·시간·토큰(runs.jsonl 집계)이 붙는다.
- 새 도구 `board.ps1 add|move|note|remove|list|sync|open`. `board.json` 과 `board-data.js` 를 잠금 아래 원자적으로 쓴다.
- 이동 권한: 작업한 에이전트는 작업완료까지만, 리뷰 판정·테스트·완료·막힘은 총괄(claude-main 은 팀장). codex-run·claude-run 은 시작 때 진행중(R2 는 리뷰), 성공하면 작업완료, STOPPED 면 막힘으로 옮기고 R2 판정 줄을 메모에 남긴다. solo 모드 하위 일꾼(tandem-worker-*, implementer, researcher)은 끝날 때 작업완료로 옮긴다.
- 업그레이드: 설치기를 다시 실행한다. `tandem/tools/board.ps1` 과 `docs/tandem/board/index.html` 이 추가되고 래퍼 2종, 일꾼·팀장 에이전트, delegation·lead-charter·tasks 문서가 바뀐다.

## v1.7 (2026-10-28)

- 실행 표: 새 도구 `run-table.ps1 -Task <ID>` 가 `runs.jsonl` 로 종류·에이전트·모델·맡긴 작업·상태·시간·토큰 표와 합계(캐시 포함)를 만든다. 위임이 없으면 "없음" 한 줄 표. 총괄은 중간·완료 보고 끝에 이 표를 항상 붙인다(간결 보고 규칙 3의 예외로 명시).
- `runs.jsonl` 에 `kind`·`agent`·`title`·`duration_s` 필드. codex-run·claude-run·batch-run 이 자동 기록하고(`-Agent` 로 이름 지정 가능), 네이티브 하위 호출은 총괄이 적는다. 카드 첫 줄은 `# <ID> <한 줄 제목>`. 예전 기록과 `tokens: {"total": N}` 형식도 읽는다. Codex 하위 에이전트 토큰을 모르면 session 으로 Codex 세션 파일에서 채운다.
- 업그레이드: 설치기를 다시 실행한다. `tandem/tools/run-table.ps1` 이 추가되고 CLAUDE.md·AGENTS.md 블록, lead-charter·delegation·log·tasks 문서와 래퍼 3종이 바뀐다.

## v1.6 (2026-10-27)

- R2 검토 판정 스키마: 지적마다 `F1 [confirmed|needs_validation|rejected]` 한 줄. confirmed 는 근거와 심각도 필수, needs_validation 은 심각도 없이 미확인 사실, rejected 는 기각 이유. 새 도구 `review-check.ps1` 이 형식과 R3 응답(`fixed|disputed|deferred`) 누락을 검사하고, 래퍼는 R2 뒤 자동 실행해 요약에 `review=` 줄, `runs.jsonl` 에 `findings` 를 남긴다. 발견자는 검증하지 않는다 (cloudflare/security-audit-skill 의 발견자≠검증자 구조를 가져옴).
- 설치기 `-Plan` (아무것도 쓰지 않는 미리보기)과 `-Clean` (현재 모드에 없는 TANDEM 파일을 `tandem/.backup/<시각>/` 로 옮긴 뒤 제거). 모드 전환으로 남은 옛 모드 파일과 사용자 수정 파일은 이제 경고로 잡힌다. 이전에는 manifest 지문이 맞는 파일만 지우고 나머지는 말없이 남았다.
- 실패 교훈에 `(xN)` 횟수. 새 도구 `lessons.ps1 -Tags` 가 횟수 많은 순으로 최대 3줄만 돌려준다. `(x3)` 이상은 기준 문서로 승격. 세션 시작에는 여전히 읽지 않는다.
- 세션 시작 훅 알림을 800자에서 자른다 (`hook.max_chars`, 환경변수 `TANDEM_HOOK_MAX_CHARS`). `TANDEM_HOOK_OFF=1` 또는 `hook.enabled=false` 면 훅이 아무 것도 하지 않는다.
- 업그레이드: 설치기를 다시 실행한다. `tandem/tools/review-check.ps1`·`lessons.ps1` 이 추가되고 reviewer·critic·delegation·lessons·tasks·reports·log 문서가 바뀐다. 직접 고친 파일은 `.new` 로 나온다.

## v1.5 (2026-10-19)

- 래퍼가 같은 과제의 세션을 이어 쓴다. `-NewSession`으로 새 세션을 시작하며 `runs.jsonl`에는 `resumed`와 누계 `thread_total`을 기록한다. `claude-run`에서 `--no-session-persistence`를 제거했다.
- 반복 항목용 `batch-run.ps1`과 `docs/batch.md`를 추가했다. 묶음당 세션 하나를 쓰고 고정 지시는 첫 턴에만 보낸다.
- 토큰 보고서에 캐시율, 1턴 Codex 세션, 메인 상태 확인 호출 수를 추가했다. 비캐시 20k 이상 1턴 세션 수로 고정 블록 재전송을 의심할 수 있고, 진단 2줄은 1턴 세션 과다와 상태 확인 과다를 알린다.
- 20k 토큰 프롬프트 실측에서 다른 폴더의 새 세션은 캐시 0, 같은 폴더의 새 세션은 7k, 이어 쓴 2·3번째 턴은 입력의 99%가 캐시됐다. `--ephemeral`은 resume할 수 없다.

## v1.4 (2026-10-19)

- 단계표와 총괄 바로 아래 팀장 기본값을 추가했다. `claude-main` config.toml의 기본값은 mid이며 fable 별칭을 추가했다.
- `-EscalatedFrom`·`-Reason`으로 래퍼의 최상위 실행을 제한하고 Jev의 최상위 선택을 제외했다. 보고서에 최상위 사용 건수를 추가했다.
- R2는 mid 단계의 별도 읽기 전용 세션에서 실행한다. reviewer/critic 프로필 기본값은 mid다.

## v1.3 - 2026-10-14

### 추가

- 실패 교훈: 하위 일꾼이 같은 실패 3회로 멈추면 요약 첫 줄을 `STOPPED:`로 쓴다. 래퍼는 `stopped`로 기록하고 그 줄을 요약에 남긴다. 카드 작성자가 `<docs>/lessons/lessons.md`에 한 줄로 남기고, 다음 카드를 쓸 때 태그로 grep해 쓴다. 세션 시작 시 자동으로 읽지 않는다.
- `/tandem-tokens`에 Claude·Codex 세션 시작 비용(첫 요청 맥락)과 세션 길이(평균·최대)를 표시한다. 수치만 보여 주고 경고는 늘리지 않았다.
- README에 OpenAI 공식 `codex-plugin-cc` 안내: TANDEM에는 필요 없고, 2026-10-14 기준 Windows 미해결 이슈(#57, #295)가 있다.

### 변경

- 과정 모르는 검토: R2 검토자는 카드, 변경분 파일, 산출물 경로만 받는다. R1 대화·자기 평가는 넘기지 않는다. 새 도구 `tandem/tools/diff.ps1`이 변경분(추적 안 된 새 파일 포함, git 인덱스는 건드리지 않음)을 만들고, 래퍼는 `-Round R2`일 때 자동으로 붙인다.
- `codex-run.ps1`·`claude-run.ps1`이 위험한 `-Model`/`-Effort` 값과 `"`가 든 경로를 `status=fail`로 거부한다. cmd.exe 명령 주입 경로를 막았다.

### 업그레이드 안내

- 설치기를 다시 실행한다. `<docs>/lessons/README.md`가 추가되고, 안 고친 파일은 교체, 직접 고친 파일은 `.new`로 나온다.

## v1.2.1 - 2026-10-14

### 수정

- `check.ps1`, `codex-run.ps1`, `claude-run.ps1`, `jev.ps1`, `manifest.ps1`의 콘솔 출력을 UTF-8로 고정했다. Windows PowerShell 5.1에서는 한글 같은 비ASCII 출력(예: `codex-run.ps1`의 한국어 요약)이 OEM 코드페이지(한국어 Windows는 cp949)로 나가 Bash나 Claude Code에서 읽으면 깨졌다. `token-report.ps1`은 이미 그렇게 하고 있었다.

## v1.2 - 2026-10-13

### 추가

- `-NoJev`로 Jev를 끄면 질문·알림·호출이 중단되고 설정에 저장된다. `-UseJev`로 다시 켤 수 있다.
- OpenRouter 크레딧 부족·잘못된 키에 대한 언어별 Jev 안내와, 성공 호출 전까지 이어지는 세션 시작 알림.
- 로컬 Jev 응답 시험을 위한 선택적 `-Endpoint` 인자.

### 변경

- 설치기, 한 줄 설치, 도구 출력, 리포트, 알림 등 TANDEM이 보여 주는 모든 문구가 고른 언어(`-Lang` 또는 설정)로만 나온다. 언어를 고르기 전에는 Windows 표시 언어를 따른다.
- HTTP 402·401에서는 구체적인 이유와 함께 배치표로 대체한다. 메인은 세션당 한 번 안내하고 하위 에이전트는 안내문을 그대로 전달한다.
- README에 Jev 설정, 전송 데이터, 비용 감, 대체 동작을 정리했다.

### 업그레이드 안내

- 설치기를 다시 실행해 v1.2 파일을 받는다. 설치 후 사용자가 수정한 파일은 `.new`로 나올 수 있으니 `/tandem`에서 병합한다.

## v1.1 - 2026-10-13

### 추가

- `claude-main`, `codex-main`, `claude-solo`, `codex-solo` 네 모드와 설치 언어 선택 옵션 `-Lang ko|en`.
- `tandem/manifest.json` 지문 기반 업데이트와 새 버전·Jev 키 누락을 알리는 세션 시작 알림.
- Jev 선택 기능, `/tandem-tokens` 사용량 리포트·낭비 진단, 반복 폴링 없이 기다리고 실행 로그·토큰을 자동 기록하는 `codex-run`/`claude-run` 래퍼.
- 카파시 관찰에서 의역한 작업 규칙. 4번 목표 중심 실행은 실무자에게만 적용한다. 총괄에는 선택 언어 응답, 분기점 설명, 간결한 보고, 세션 연속성과 위임 규칙을 추가했다.

### 변경

- 모델을 지정하지 않은 Claude 하위 에이전트의 `CLAUDE_CODE_SUBAGENT_MODEL` 기본값을 `inherit`에서 `sonnet`으로 변경.
- 템플릿을 `tandem/templates/<lang>/`으로 옮기고 모델 ID의 기준을 `tandem/config.json`으로 통일.
- v1.1은 Windows만 지원. macOS/Linux 스크립트는 v1.0 상태로 남아 있으며 지원하지 않는다.

### 수정

- Windows PowerShell 5.1에서 `iwr | iex`를 실패하게 하던 `boot.ps1`의 BOM 제거.
- Codex 로그인 확인 중 stderr 메시지 때문에 PowerShell 5.1 설치가 중단되던 문제 수정.
- 태그 지정 설치의 404와 설치 결과 파일의 BOM 문제 수정.

### 보안 및 개인정보

- Jev 키는 사용자 환경변수에만 저장한다. Jev를 쓰면 과제 카드의 목표·제약·완료조건만 최대 6000자까지 OpenRouter/TypeSafe로 전송한다.
- `-JevKey`로 입력한 키는 명령 기록에 남을 수 있다. 대화형 입력을 권장한다.

### 업그레이드 안내

- v1.0 설치본에는 업데이트 알림 장치가 없으므로 같은 한 줄 설치를 다시 실행한다. v1.0 설정은 자동 승격된다.
- v1.0 때 설치한 파일에는 지문이 없어 업데이트가 `.new` 파일로 나올 수 있다. `/tandem`에서 병합한다.

### 알려진 제한

- 키가 없어 Jev 실제 호출은 검증하지 못했다. Codex·Claude 세션 시작 화면에서 알림이 표시되는지도 실제 세션에서는 확인하지 못했다.
- `codex login` 브라우저 흐름과 winget 설치는 미검증이다. 실제 프로젝트에서 네 모드 모두 `/tandem` 적응 전 과정을 실행해 보지 않았다.

## v1.0 - 2026-09-28

- 첫 공개: 한 줄 설치, Claude 지휘·Codex 실무, G1/G2 사용자 게이트, 과제 카드, 3라운드 토론, 실행 로그.
