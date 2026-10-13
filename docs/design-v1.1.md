# TANDEM v1.1 설계서 (모든 과제 카드의 공통 기준)

저장소: `D:/dev/Tandem-repo`. 대상 OS: **Windows 전용**, **Windows PowerShell 5.1** 기준(pwsh 7 기능 금지).
`install.sh`/`boot.sh`는 손대지 않는다 (유지만, 검증 대상 아님).

## 0. 절대 규칙

- **인코딩**: 한글이 들어간 `.ps1`은 **UTF-8 BOM**. 프로젝트에 배치되는 결과 파일(md, json, toml)은 **BOM 없는 UTF-8**.
  `boot.ps1`은 **ASCII 전용 + BOM 없음** (BOM이 있으면 `iwr | iex`가 깨진다. 실측 확인됨).
- PowerShell 5.1에서 네이티브 명령(codex, claude, git, npm, winget)을 `$ErrorActionPreference="Stop"` 상태로 부르지 않는다.
  stderr 출력이 오류로 처리돼 스크립트가 멈춘다(실측). `install.ps1`의 `Native { }` 래퍼 패턴을 쓴다.
- 기존 파일 보존 원칙 유지: TANDEM이 깔지 않은 파일, 또는 깐 뒤 사용자가 고친 파일은 **절대 덮어쓰지 않는다** (`.new`).
- 커밋 금지. 지정된 파일 외 수정 금지.

## 1. 모드 4가지 (`config.json`의 `mode`)

| mode | 사용자가 대화하는 쪽 | 서브 | 서브 호출 방식 |
|---|---|---|---|
| `claude-main` | Claude (총괄) | Codex 팀 | Claude 팀장 → 전달책(haiku) → `tandem/tools/codex-run.ps1` → `codex exec` (v1.0 구조) |
| `codex-main` | Codex (총괄) | Claude | Codex 총괄이 셸에서 `tandem/tools/claude-run.ps1` → `claude -p` |
| `claude-solo` | Claude 상위 모델 (예: Fable) | 같은 Claude의 하위 모델 서브에이전트 | Agent 도구로 `tandem-worker-top/mid/light` (opus/sonnet/haiku) |
| `codex-solo` | Codex 상위 모델 (예: astra) | 같은 Codex의 하위 모델 일꾼 | Codex 네이티브 하위 에이전트 (`.codex/agents/*.toml`, sol/luna) |

모든 모드 공통: G1(과제 정의 확인) / G2(브리핑) 게이트, 과제 카드, 실행 로그, 3라운드 토론(R2는 다른 모델),
"메인은 실무를 하지 않는다. 지시·검수·보고만 한다", 산출물 본문을 메인 컨텍스트로 끌어오지 않는다(경로 + 5줄 요약).

## 2. 언어 (`config.json`의 `lang`: `ko` | `en`)

- 템플릿은 `tandem/templates/ko/`와 `tandem/templates/en/` 두 벌. **상대 경로 구조가 완전히 같다.**
- 언어가 정하는 것: 사용자와의 대화 언어, 운영 문서·보고서 작성 언어, 스크립트 안내 문구.
- 각 블록(`blocks/CLAUDE.md`, `blocks/AGENTS.md`)과 총괄 규칙에 "사용자와는 {{LANG_NAME}}로 대화하고, 문서·보고서도 {{LANG_NAME}}로 쓴다" 한 줄.
- 스크립트(`tandem/tools/*.ps1`, `install.ps1`)는 메시지를 ko/en 두 벌 테이블로 들고 `config.json`의 `lang`(설치 시엔 `-Lang`)으로 고른다.

## 3. 파일 계약: `tandem/files.json`

**이미 작성돼 있다. 바꾸지 마라.** (바꿔야 하면 보고서에 사유를 적고 멈춘다.)
- `kind: file` — `templates/<lang>/<src>`를 렌더링(자리표시자 치환 + 모드 조건 처리)해 `dst`에 둔다.
- `kind: block` — 렌더링 결과를 `<!-- TANDEM:BEGIN -->`…`<!-- TANDEM:END -->` 블록으로 삽입/교체.
- `kind: settings` — `.claude/settings.json`에 병합 (env, permissions.allow 합집합, hooks).
- `kind: codex-hooks` — `.codex/hooks.json`에 병합 (아래 7절).
- `kind: copy` — 저장소 루트 기준 `src`를 **바이트 그대로** 복사 (BOM 유지, 렌더링 안 함).
- `dst`의 `{{DOCS}}`는 문서 폴더로 치환.

## 4. 렌더링 규칙

### 자리표시자

| 자리표시자 | 값 |
|---|---|
| `{{PROJECT}}` `{{DOCS}}` `{{VERSION}}` `{{INSTALLED}}` | v1.0과 같음 |
| `{{MODE}}` | 모드 문자열 |
| `{{LANG}}` / `{{LANG_NAME}}` | `ko`/`en` / `한국어`/`English` |
| `{{MODEL_TOP}}` `{{MODEL_MID}}` `{{MODEL_LIGHT}}` | Codex 모델. `config.models.codex_*`, 비어 있으면 `MODEL_TOP_미확정`(ko) / `MODEL_TOP_UNSET`(en) |
| `{{CLAUDE_LEAD}}` | `config.models.claude_lead`, 비면 `총괄모델_미확정` / `LEAD_MODEL_UNSET` |
| `{{CLAUDE_TOP}}` `{{CLAUDE_MID}}` `{{CLAUDE_LIGHT}}` | `config.models.claude_top/mid/light`, 기본 `opus`/`sonnet`/`haiku` |
| `{{CLAUDE_MANAGER}}` `{{CLAUDE_DISPATCH}}` `{{CLAUDE_CRITIC}}` | 하위 호환 별칭 = `{{CLAUDE_TOP}}` / `{{CLAUDE_LIGHT}}` / `{{CLAUDE_MID}}` |

**자리표시자 이름을 바꾸거나 깨뜨리지 마라.**

### 모드 조건 (줄 단위, 중첩 없음)

```
@@if claude-main codex-solo
이 줄들은 mode가 claude-main 또는 codex-solo일 때만 남는다
@@endif
```
`@@if`/`@@endif` 줄 자체는 결과에서 지운다. 템플릿 작성자는 중첩하지 않는다. JSON/TOML 안에서는 쓰지 않는다.

## 5. 설정 `tandem/config.json` (v1.1 스키마)

```json
{
  "set": "TANDEM", "version": "1.1", "project": "...", "docs_root": "docs/tandem",
  "mode": "claude-main", "lang": "ko",
  "installed": "2026-10-13", "updated": "2026-10-13", "adapted": false,
  "models": { "codex_top": "", "codex_mid": "", "codex_light": "",
              "claude_lead": "", "claude_top": "opus", "claude_mid": "sonnet", "claude_light": "haiku" },
  "jev": { "model": "typesafe/jev-1.13", "key_env": "TANDEM_JEV_API_KEY", "min_confidence": 0.6, "notify_missing_key": true },
  "update": { "repo": "carydev/Tandem", "ref": "main", "notify": true },
  "task_id_format": "", "source_of_truth": []
}
```
- v1.0 config를 만나면 이 스키마로 승격한다 (`claude_manager`→`claude_top`, `claude_dispatch`→`claude_light`, `claude_critic`→`claude_mid`, 없는 키 추가, 기존 값 보존).
- **모델 ID는 이 파일에만 둔다.** `/tandem` 적응은 모델 ID를 여기 적고 `tandem/tools/manifest.ps1 -Render`로 재배치한다(8절).
- **API 키는 어떤 파일에도 쓰지 않는다.**

## 6. 업데이트와 지문 `tandem/manifest.json`

```json
{ "version": "1.1", "files": { ".claude/agents/tandem-manager.md": "<sha256 hex>", ... } }
```
- `kind: file`/`copy`만 기록한다 (block/settings/hooks는 각자 방식으로 갱신되므로 제외).
- 배치 규칙 (dst마다):
  1. 없음 → 배치, 지문 기록.
  2. 있음 & 내용이 새 렌더 결과와 같음 → 지문만 기록.
  3. 있음 & 현재 지문 == manifest 지문 (= 아무도 안 고침) → **새 버전으로 교체**, 지문 갱신.
  4. 그 외 (manifest에 없거나 사용자가 고침) → `<dst>.new`, 지문은 기존 값 유지. `-Force`여도 덮어쓰지 않는다(`.new`).
- 새 파일 목록에 없는데 manifest에 있는 파일(모드 변경, 파일 폐기):
  지문이 같으면 삭제하고 manifest에서 뺀다. 다르면 남겨두고 경고만 한다.
- 블록: 마커 사이만 교체. 모드상 블록이 필요 없어졌으면 마커 블록을 제거한다(블록 밖은 보존).

## 7. 훅 (세션 시작 알림)

`tandem/tools/check.ps1 -Agent claude|codex` 가 세션 시작 시 돈다.
- Claude: `.claude/settings.json`의 `hooks.SessionStart`에 병합. **mode가 `claude-main`/`claude-solo`일 때만** 넣는다
  (`codex-main`에서 Claude는 `claude -p` 서브라 알림이 잡음이 된다).
  ```json
  {"matcher":"startup","hooks":[{"type":"command","command":"powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/check.ps1 -Agent claude","timeout":15}]}
  ```
- Codex: `.codex/hooks.json` (`codex-main`/`codex-solo`). 템플릿 `codex/hooks.json`:
  ```json
  {"hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/check.ps1 -Agent codex","timeout":15}]}]}}
  ```
  기존 hooks.json이 있으면 `SessionStart` 배열에 우리 항목을 추가(명령에 `tandem/tools/check.ps1`이 이미 있으면 생략). 파싱 실패 시 `.new`.
  Codex는 프로젝트 `.codex/`가 신뢰돼야 하고 훅은 `/hooks`에서 승인해야 돈다 → adapt.md와 설치 안내에 명시.
- 병합 판정: 명령 문자열에 `tandem/tools/check.ps1`이 들어간 항목이 이미 있으면 추가하지 않는다.

## 8. 도구 스크립트 `tandem/tools/` (모두 PS 5.1, 한글 메시지 있으면 BOM)

공통: 프로젝트 루트 = 스크립트 위치의 두 단계 위. `tandem/config.json`에서 lang/docs_root/mode/models 읽음. 실패해도 상위를 막지 않는다.

- `check.ps1 -Agent claude|codex` — 세션 시작 알림.
  - 업데이트: `https://raw.githubusercontent.com/<update.repo>/<update.ref>/VERSION` 을 **하루 1회만** 확인(캐시 `tandem/.cache/update.json`), 타임아웃 3초. 원격 > 로컬이면 알림.
  - Jev 키: `TANDEM_JEV_API_KEY` 또는 `OPENROUTER_API_KEY`가 프로세스·User 환경변수 어디에도 없고 `jev.notify_missing_key`가 true면 알림(설정 방법 한 줄 포함).
  - 알릴 게 있으면 stdout에 `{"systemMessage":"..."}` **한 줄만** 출력. 비ASCII 문자는 `\uXXXX`로 이스케이프해 콘솔 인코딩과 무관하게 만든다. 없으면 아무것도 출력하지 않는다. 항상 exit 0. 전체 1초 내외.
- `manifest.ps1` — `-Rehash`: 현재 파일들의 지문을 manifest에 다시 기록(`/tandem` 적응이 파일을 직접 고친 뒤 호출). `-Status`: 고친 파일/누락 파일 목록 출력.
- `jev.ps1` — Jev 결정 클라이언트 (9절).
- `token-report.ps1` — 토큰 리포트 (10절).
- `codex-run.ps1` / `claude-run.ps1` — 서브 실행 래퍼 (11절).

## 9. Jev

- 엔드포인트 `POST https://openrouter.ai/api/alpha/decisions`, 헤더 `Authorization: Bearer <key>`, 모델 `config.jev.model`.
- 요청: `{ "model": "...", "state": {...}, "questions": { "<id>": { "type": "choice|noul|score", "instructions": "...", "criteria": ... } } }`
  - choice criteria: `{ "옵션명": "설명", ... }` / noul: `{ "true": "...", "false": "..." }` / score: `["단계0 설명", "단계1", ...]`
- 응답: `answers.<id>` = choice: `{choice, confidence, probabilities}` / noul: `{noul}` (예일 확률) / score: `{score, confidence, probabilities}`; `usage.cost`(USD).
- 입력 한도 32k 토큰 → state는 과제 카드의 목표·제약·완료조건 절만, 최대 6000자.
- `jev.ps1` 인터페이스:
  - `-Route -Card <카드경로> [-Tiers top,mid,light]` → 질문 2개: `tier`(choice: top/mid/light), `effort`(choice: low/medium/high).
  - `-Escalate -Card <경로> -FailNote <text>` → `escalate`(noul).
  - `-NeedCritic -Card <경로>` → `irreversible`(noul): 되돌리기 어려운 결정인가.
  - `-Request <json파일>` → 원시 요청.
  - 출력: stdout에 JSON 한 줄 `{"ok":true,"decided_by":"jev","answers":{...},"cost":0.00001}`.
    키 없음/오류/확신도 < `min_confidence` → `{"ok":false,"decided_by":"table","reason":"no_key|error|low_confidence", ...}` exit 0.
    (확신도 낮을 때도 answers는 같이 준다. 호출자는 배치표로 결정한다.)
- 규칙(문서에 반영): Jev는 **모델·강도 고르기, 승급 여부, 교차 검수 필요 여부**만. **산출물 합격 판정·G1/G2는 절대 맡기지 않는다.**
  결과는 실행 로그 `decided_by`에 남긴다. 키가 없으면 v1.0과 똑같이 동작.
- 설치 시 키 입력 → `[Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY', $key, 'User')` + 현재 프로세스. 파일에 쓰지 않는다.
  README에: 과제 카드 일부(목표·제약)가 OpenRouter/TypeSafe로 전송됨을 명시.

## 10. 토큰 리포트 `token-report.ps1` + `/tandem-tokens`

- 인자: `-Days 7`(기본), `-Out <경로>`(기본 `<docs>/reports/usage/usage-yyyyMMdd.md`).
- Claude 기록: `%USERPROFILE%/.claude/projects/<인코딩된 프로젝트 경로>/` (경로의 영숫자 외 문자를 `-`로 바꾼 이름. 예 `D:\dev\farm-sim` → `D--dev-farm-sim`).
  `*.jsonl` 메인 + `*/subagents/agent-*.jsonl`(+ 같은 이름 `.meta.json`의 `agentType`). 기간 내 수정된 파일만.
  `type=="assistant"` 줄의 `message.usage` (input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens), `message.model`.
  **`message.id`로 중복 제거** (스트리밍으로 같은 메시지가 여러 줄).
- Codex 기록: `%USERPROFILE%/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` 기간 내 날짜 폴더. `session_meta.payload.cwd`가 프로젝트 경로(대소문자·구분자 무시)인 것만.
  첫 `turn_context.payload`의 `model`, `effort`. 마지막 `event_msg`/`token_count`의 `payload.info.total_token_usage`
  (input_tokens, cached_input_tokens, output_tokens, reasoning_output_tokens). token_count 개수 = 턴 수.
  `function_call_output`/`custom_tool_call_output` 출력 길이 합 = 도구 출력 바이트.
- 성능: 300MB를 PS 5.1에서 60초 안. **전체 줄을 ConvertFrom-Json 하지 마라.** `[IO.File]::ReadLines` + `Contains` 필터 후 필요한 줄만 파싱(또는 정규식).
- 환산: "입력 환산 토큰" = input + 1.25×cache_write + 0.1×cache_read + 5×output (Claude). Codex는 uncached input + 0.1×cached + 4×output. 상대 비교용이라고 리포트에 명시.
- 리포트 내용: 역할(메인/서브에이전트 종류)×모델 표, 메인 요청당 평균 맥락, 서브 호출당 요청 수, Codex 모델·강도 분포, 세션당 턴·도구 출력, `runs.jsonl` 줄 수 vs Codex 세션 수.
- **다이어트 진단** (기준선 넘으면 항목별 처방 문장, ko/en):
  - 메인 요청당 평균 맥락 > 150k → 무관한 작업은 새 세션/`/clear`, 같은 작업은 이어서. 인계 문서 작성 후 끊기.
  - Claude 서브에이전트 중 TANDEM 역할이 아닌 것(general-purpose, Explore 외 커스텀)이 Claude 환산의 30% 초과 (claude-main/codex-main) → 실무를 Codex로 넘겨라.
  - 서브에이전트 1회당 요청 > 15 (전달책) → 폴링 의심. `codex-run.ps1 -Wait` 사용 확인.
  - Codex 최상위 모델 비중 > 50% 또는 high 이상 강도 비중 > 70% → 배치표 "한 단계 낮게" 위반, `model-routing.md` 수정안.
  - Codex 세션당 평균 턴 > 60 또는 도구 출력 > 300KB/세션 → 과제 카드 범위 좁히기, 검색 먼저, 긴 로그 요약.
  - Codex 세션 수 > runs.jsonl 기록 수 → 기록 없는 실행(재시도·중복 기동) 존재.
  - `~/.codex/config.toml`에 `service_tier`가 `fast` 또는 `priority` → Fast 계열 의심(한도 2.5배). 확인 권고. **전역 설정을 고치지는 않는다.**
  - `CLAUDE_CODE_SUBAGENT_MODEL=inherit` (프로젝트 settings) → 모델 미지정 서브에이전트가 메인 모델로 돈다.
- stdout에는 40줄 이내 요약(상위 항목 + 진단). 상세는 파일. `/tandem-tokens` 커맨드는 스크립트를 돌리고 **요약만 읽고** 처방을 정리한다. 배치표 수정은 제안까지(총괄만 고침).

## 11. 서브 실행 래퍼 (폴링 누수 차단)

배경 실측: 전달책이 Codex 완료를 `tail`/`ls`로 반복 확인 → 위임 1회에 26-417회 요청. Claude Bash 도구 타임아웃은 최대 10분이라 긴 실행을 한 번에 못 기다린다.

- `codex-run.ps1 -Task <id> -Round R1|R2|R3|single -Card <카드> -Out <산출물> -Model <id> -Effort <lvl> [-Sandbox workspace-write|read-only] [-DecidedBy jev|table|human] [-Prompt <추가지시>]`
  - `codex exec`를 **분리된 프로세스**로 시작: `--json` 출력은 `.codex-last/<task>-<round>.jsonl`, `-o .codex-last/<task>-<round>.txt`.
    프롬프트에 반드시 포함: 카드 경로, 산출물 경로, 쓰기 범위, "마지막 메시지는 5줄 이내 요약만".
  - 시작 직후 **최대 540초까지 블로킹 대기**. 끝나면 결과 출력, 안 끝나면 `RUNNING <run-id>` 출력 후 종료.
  - `codex-run.ps1 -Wait <run-id>` → 다시 최대 540초 블로킹. (호출 1번 = 최대 9분. 폴링 간격을 강제로 넓힌다.)
  - 완료 시 출력(8줄 이내): 상태, 종료코드, 산출물 존재 여부, 마지막 메시지 5줄, 세션 ID(`thread.started`의 thread_id), 토큰(마지막 `turn.completed`/token_count usage).
  - **완료 시 `runs.jsonl`에 스스로 한 줄 append** (ts, task, round, model, effort, result, escalated_from, workers:null, out, session, tokens{input,cached,output}, decided_by, note). 로그 누락을 원천 차단.
    `runs.jsonl`은 BOM 없는 UTF-8, `[IO.File]::AppendAllText`.
- `claude-run.ps1` — 같은 인터페이스(`-Model` = sonnet/opus/haiku). `claude -p` 를
  `--model <m> --permission-mode acceptEdits --append-system-prompt-file <docs>/claude-worker.md --output-format json --no-session-persistence`
  로 실행. 허용 도구는 `--allowedTools "Read,Edit,Write,Glob,Grep,Bash(git status:*),Bash(git diff:*)"` 기본.
  결과 JSON에서 `result`(마지막 메시지, 5줄로 자름), `usage`, `total_cost_usd`, `session_id`를 뽑아 로그에 쓴다.

## 12. 카파시 규칙 (출처: github.com/forrestchang/andrej-karpathy-skills, Karpathy의 관찰을 정리한 커뮤니티 문서)

의역해서 넣는다(원문 복사 금지). 출처 한 줄 표기.
1. **코딩 전에 생각한다** — 가정을 밝히고, 해석이 여럿이면 제시하고, 불분명하면 멈추고 묻는다.
2. **단순하게** — 요청한 것만. 추측성 기능·한 번 쓸 추상화·요청 안 한 설정 금지.
3. **필요한 곳만 고친다** — 주변 코드 개선·리팩터링 금지, 기존 스타일 따름, 무관한 죽은 코드는 지적만. 자기 변경이 만든 찌꺼기만 정리.
4. **목표 중심 실행** — 검증 가능한 완료 조건(테스트 등)을 정하고 통과할 때까지 반복. 여러 단계면 단계별 검증을 적는다.

적용 범위:
- 1-3: **모든 역할** (블록 `blocks/CLAUDE.md`, `blocks/AGENTS.md` 의 공통 절).
- 4: **서브(실무)에게만.** claude-main → Codex 일꾼(AGENTS 블록의 일꾼 절 + researcher/implementer/reviewer/work-lead TOML).
  codex-main → `docs/claude-worker.md`. claude-solo → `tandem-worker-top/mid/light.md`. codex-solo → researcher/implementer/reviewer TOML.
  **메인(총괄)·팀장·전달책에는 4를 넣지 않는다.** 메인은 "직접 반복 수정"이 아니라 반려·재위임한다.
  4의 반복은 무한이 아니다: 같은 실패 3회면 멈추고 막힌 지점을 산출물에 적는다.

## 13. 효율 규칙 (실무 역할 공통, 모든 서브에게)

- 관련 경로·심볼을 먼저 검색하고 필요한 파일 본문을 읽는다. 호출부·의존성 확인이 필요하면 범위를 넓힌다.
- 생성물(`bin/ obj/ build/ .gradle/ node_modules/ .godot/ dist/` 등)·대용량 로그·무관한 문서는 필요할 때만 읽는다.
- 바뀌지 않은 파일을 이유 없이 다시 읽지 않는다.
- 빌드·테스트는 생략하지 않는다. 출력은 종료 코드·실패 항목·오류 주변만 본다. 원문은 파일로 남기고 필요할 때 연다.
- 관련 테스트부터 돌리고 영향에 따라 범위를 넓힌다.
- 작은 수정에 긴 계획이나 여러 일꾼을 붙이지 않는다.
- 진전 없이 같은 시도가 반복되면 멈추고 원인과 막힌 지점을 정리한다.
- 마지막 메시지는 변경 내용·검증 결과·남은 위험 위주 5줄. 고친 코드를 다시 출력하지 않는다.

## 14. 메인(총괄) 규칙에 추가할 것 (모든 모드의 lead-charter)

- **세션 길이**: 같은 과제는 이어서(캐시 재사용), 무관한 과제는 새 세션/`/clear`. 과제가 끝나면 인계(결정·수정 파일·남은 문제·검증 결과)를 남기고 끊는다.
  `/compact`도 비용이 들고 모델 전환은 캐시를 다시 만든다 → 매 요청 모델·모드 왕복 금지.
- **서브 호출 대기**: 래퍼(`codex-run.ps1`/`claude-run.ps1`)의 블로킹 대기만 쓴다. `tail`·`ls`·상태 파일 반복 확인 금지. 산출물 본문 열람 금지(요약 절만).
- **Jev**: 9절 범위에서만.
- `/tandem-tokens`(Claude 메인) 또는 `token-report.ps1`(Codex 메인)로 주 1회 또는 과제 5건마다 점검.

## 15. 설정 조각 `settings.json` (Claude 측)

- `env`: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0`, **`CLAUDE_CODE_SUBAGENT_MODEL=sonnet`** (v1.0의 `inherit` 폐기: 모델 미지정 서브에이전트가 메인의 비싼 모델로 돌던 누수. farm-sim 실측 11%).
- `permissions.allow`: v1.0 목록 + `Bash(powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/*)` 류.
- hooks는 템플릿에 넣지 않는다 — 설치 스크립트가 모드 보고 병합(7절).

## 16. 설치 스크립트 인자

`install.ps1 [-DocsRoot <p>] [-Mode claude-main|codex-main|claude-solo|codex-solo] [-Lang ko|en] [-JevKey <k>] [-NoJev] [-SkipDeps] [-Yes] [-Force]`
- 모드/언어: 인자 > 기존 config > 대화형 질문(번호 메뉴) > 기본값(`claude-main`, UI 문화권이 ko면 `ko` 아니면 `en`). `-Yes`면 묻지 않고 기본값.
- 의존성: 모드에 Claude가 있으면 `claude` 확인, Codex가 있으면 codex 설치·로그인 처리(v1.0 로직).
- Jev: 키가 환경에 없고 `-NoJev`가 아니고 대화형이면 "Jev(OpenRouter) API 키, 엔터=건너뜀" 질문(`Read-Host -AsSecureString`). `-JevKey`로도 받음.
- `.gitignore`에 `.codex-last/`, `tandem/.cache/` 추가(없을 때만).
- 끝에 모드별 "다음 단계" 안내 (claude-main/solo: `claude` → `/tandem`; codex-main/solo: `codex` → "tandem/adapt.md 를 읽고 적응을 진행해", Codex 훅은 `/hooks`에서 승인).
- 저장소 루트에 `VERSION` 파일(`1.1`). `install.ps1`의 `$VERSION`은 이 파일을 읽는다.
- `boot.ps1`: `-Mode -Lang -JevKey -NoJev` 인자 추가 전달. ASCII·BOM 없음 유지.
