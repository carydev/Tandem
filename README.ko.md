# TANDEM

[English](README.md) | **한국어**

**총괄을 고르면 에이전트가 실무를 한다.** TANDEM은 과제 카드, 검수 규칙, 실행 로그를 프로젝트에 설치한다. Claude나 Codex가 총괄하고, 총괄은 지시·검수·보고를, 일꾼은 구현을 맡는다.

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

옵션 없이 실행하면 설치기가 모드와 언어를 대화형으로 묻는다. `-Mode` 또는 `-Lang ko|en`을 직접 주려면 빠른 시작의 `scriptblock` 형식을 쓴다.

## 왜 쓰나

- 총괄은 산출물 본문 대신 파일 경로와 5줄 이내 요약을 받는다.
- G1에서 과제 정의를 확인하고 G2에서 결과를 브리핑한다. 에이전트가 게이트를 결정하지 않는다.
- 과제 카드, R2 검토를 포함한 3라운드 토론, `runs.jsonl`로 작업을 추적한다.
- 모델 배치는 적절한 낮은 단계에서 시작해 필요할 때 승급한다.

## 준비물

- Windows, Windows PowerShell 5.1 이상, git.
- Claude가 참여하는 모드에는 [Claude Code](https://claude.com/claude-code) CLI, Codex가 참여하는 모드에는 로그인된 [Codex CLI](https://github.com/openai/codex)가 필요하다. 설치기가 선택한 모드의 의존성을 확인한다.
- macOS/Linux 스크립트는 v1.0 상태로 남아 있지만 v1.1에서는 지원하지 않는다.

## 빠른 시작

설치할 프로젝트 루트에서 실행한다.

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -Mode claude-main -Lang ko
```

`claude-main` 또는 `claude-solo`에서는 `claude`를 실행하고 `/tandem`을 입력한다. `codex-main` 또는 `codex-solo`에서는 `codex`를 실행하고 `tandem/adapt.md`를 읽어 프로젝트에 맞게 적응하라고 지시한다. 적응 과정에서 모델, CLI 플래그, 프로젝트 문서, 스모크 테스트를 확인한다. 보고서를 검토하고 커밋은 직접 한다. Codex 모드에서는 프로젝트를 신뢰 대상으로 설정하고 `/hooks`에서 세션 훅을 승인한다.

총괄에게 과제를 설명한다. 총괄은 G1 확인을 받고 실무를 위임한 다음 G2 브리핑을 한다. 같은 설치 명령을 다시 실행하면 업데이트하거나 모드를 바꿀 수 있다. `-Mode` 또는 `-Lang`에 다른 값을 주면 해당 설정이 바뀐다.

## 구조

| 모드 | 대화 상대 | 실무 담당 |
|---|---|---|
| `claude-main` | Claude 총괄 | Claude 팀장·전달책을 거친 Codex 팀 |
| `codex-main` | Codex 총괄 | `claude -p`로 호출한 Claude 일꾼 |
| `claude-solo` | Claude 총괄 | Agent 도구로 호출하는 하위 Claude 에이전트 |
| `codex-solo` | Codex 총괄 | Codex 네이티브 하위 에이전트 |

총괄은 일을 정의하고 검수하며 일꾼이 파일을 쓴다. G1에서 범위를 확인한 뒤 R1이 제안하고 R2가 mid 단계의 별도 읽기 전용 세션에서 검토하며 R3가 답한다. G2에서 결과를 브리핑한다.

### 모델 정책

총괄 아래 역할은 최상위 단계를 기본으로 쓰지 않는다. 사용자가 카드에 직접 지정하거나 mid 단계에서 한 번 실패해 총괄이 모델 능력 부족으로 판정한 경우에만 쓴다.
승급은 총괄이 결정하며 래퍼 호출에는 `-EscalatedFrom`과 `-Reason`이 필요하다. claude-main 팀장은 총괄 바로 아래 단계를 기본으로 쓰고 최상위는 제안만 한다.
R2 검토는 mid 단계의 별도 읽기 전용 세션에서 한다(가능하면 다른 모델).

### 토큰 효율

같은 과제의 후속 호출은 래퍼가 세션을 이어 쓴다. R2 검토와 승급은 새 세션에서 한다.
반복 항목은 `batch-run.ps1`을 쓴다. 묶음당 세션 하나에서 고정 블록은 첫 턴에만 보내고 바뀐 항목만 보낸다. 자세한 규칙은 `docs/batch.md`.
`/tandem-tokens`는 캐시율, 1턴 세션, 상태 확인 호출 수를 보여 준다.
실측: 2026-10-19, Codex CLI, gpt-5.6-luna, 20k 토큰 프롬프트.
| 호출 | 캐시 결과 |
|---|---|
| 새 세션·다른 작업 폴더 | 0 |
| 새 세션·같은 폴더·같은 프롬프트 | 20k 중 7k |
| `exec resume` 2·3번째 턴 | 턴 입력의 99% |
| `--ephemeral` | resume 불가; Codex usage는 스레드 누계 |

### 검토 판정

R2 검토는 지적마다 `F1 [confirmed|needs_validation|rejected]` 판정 줄을 쓴다. confirmed 는 근거(경로:줄)와 심각도가 필수, needs_validation 은 심각도 없이 미확인 사실만, rejected 는 기각 이유다. confirmed + needs_validation 이 3개 미만이면 동의만 한 것으로 본다.
`tandem/tools/review-check.ps1` 이 형식과 R3 응답(`F1 fixed|disputed|deferred`) 누락을 검사한다. 래퍼는 R2 뒤 자동으로 돌려 요약에 `review=` 줄을 붙이고 `runs.jsonl` 에 판정 수를 남긴다.
발견자는 검증하지 않는다. needs_validation 은 총괄이 직접 확인하거나 별도 과제로 확인한 뒤 confirmed 또는 rejected 로 판정한다.

### 무엇이 따라오나

| 기능 | 용도 |
|---|---|
| 모델 배치표 | 과제별 모델과 추론 강도를 고르고 승급을 기록 |
| 과제 카드와 G1/G2 | 범위를 정의하고 확인·브리핑 결정권을 사용자에게 유지 |
| 3라운드 토론 | 반론과 미해결 쟁점 기록 |
| 실행 로그와 토큰 리포트 | 호출을 추적하고 비용이 큰 패턴 발견 |
| 검토 판정 검사 | R2 판정 형식과 R3 응답 누락을 기계적으로 확인 |
| 실패 교훈 | 한 줄 교훈에 `(xN)` 횟수, 카드 쓸 때 `lessons.ps1` 로 상위 3줄만 |
| 운영 문서 | 역할, 소유권, 모델 배치, 현황 관리 |

### 작업 규칙

모든 역할은 가정을 밝히고, 단순하게 풀고, 과제에 필요한 곳만 고친다. 일꾼은 검증 가능한 완료 조건을 정해 통과할 때까지 반복한다. 같은 실패가 세 번이면 멈추고 막힌 지점을 기록한다. 이 규칙은 [카파시의 관찰을 정리한 커뮤니티 문서](https://github.com/forrestchang/andrej-karpathy-skills)를 의역한 것이며 카파시 본인의 저장소는 아니다.

실패 교훈은 `lessons.md` 한 줄에 `(xN)` 횟수를 붙이고, 카드를 쓸 때 `tandem/tools/lessons.ps1 -Tags <태그>` 로 횟수 많은 순 3줄만 가져온다. 세션 시작에는 읽지 않는다. 세션 시작 알림은 기본 800자로 자르며(`hook.max_chars`, `TANDEM_HOOK_MAX_CHARS`), `TANDEM_HOOK_OFF=1` 또는 `hook.enabled=false` 로 끈다.

실행 래퍼는 반복 폴링 없이 일꾼을 기다리고 호출을 자동 기록한다. 모델을 지정하지 않은 Claude 하위 에이전트는 `CLAUDE_CODE_SUBAGENT_MODEL`로 `sonnet`을 쓴다. 세션 규칙은 같은 과제를 이어서 하고 무관한 과제는 새 세션에서 하도록 한다. 효율 규칙은 필요한 파일과 테스트 출력만 읽도록 한다.

### 공식 Codex 플러그인과의 관계

OpenAI의 [codex-plugin-cc](https://github.com/openai/codex-plugin-cc)는 Claude Code 안에서 Codex 검토와 작업 위임을 지원한다.
TANDEM에는 이 플러그인이 필요하지 않다. 자체 `codex-run.ps1` 래퍼로 과제 카드, 토큰 기록, 모델 배치를 처리한다.
2026-10-14 기준 Windows의 검토 모드와 셸 호출에 미해결 이슈가 있다: [#57](https://github.com/openai/codex-plugin-cc/issues/57), [#295](https://github.com/openai/codex-plugin-cc/issues/295).

### Jev (선택)

Jev는 OpenRouter를 통해 쓰는 TypeSafe의 결정 전용 모델이다. 모델과 추론 강도, 승급, 교차 검수 필요 여부를 참고하도록 제안하며 최상위 단계는 고르지 않는다. **산출물 합격 판정이나 G1/G2 결정은 하지 않는다.** 키가 없으면 v1.0처럼 배치표를 쓴다.

OpenRouter 키는 설치 중 대화형으로 입력하거나 `[Environment]::SetEnvironmentVariable('TANDEM_JEV_API_KEY','<key>','User')`로 **사용자** 환경변수에 설정한다. Jev를 쓰면 **과제 카드의 목표·제약·완료조건 절, 최대 6000자가 OpenRouter/TypeSafe로 전송된다.** 승급 판단에는 최대 1000자의 실패 요약도 전송한다. 키는 프로젝트 파일에 쓰지 않는다. `-JevKey`도 쓸 수 있지만 명령 기록에 인자가 남을 수 있으므로 대화형 입력을 권장한다.

OpenRouter는 입력 토큰에만 과금한다. 결정 1회는 약 1000~2000토큰이라 비용이 매우 낮다. 정확한 현재 단가는 [OpenRouter 모델 페이지](https://openrouter.ai/typesafe/jev-1.13)를 참고한다. 크레딧이 부족하거나 키가 잘못되면 배치표로 자동 대체하고 현재 세션에서 사용자에게 한 번 안내하며 다음 세션 시작 때 다시 알린다. Jev 호출이 성공하면 알림 상태를 지운다.

설치할 때 `-NoJev`를 쓰면 `tandem/config.json`에 `jev.enabled=false`가 저장된다. 꺼진 동안에는 Jev 질문·알림·호출 없이 배치표로 결정한다. 다시 켜려면 설치기를 `-UseJev`로 재실행한다. 어느 옵션도 없으면 저장된 설정을 유지한다.

### 토큰 리포트

Claude 총괄 세션에서는 `/tandem-tokens`, PowerShell에서는 `tandem/tools/token-report.ps1`을 실행한다. Claude·Codex 사용량을 역할과 모델별로 모으고 누수를 줄일 방법을 제안한다. 예를 들어 총괄 요청당 평균 맥락 46만 토큰이나 전달책 호출당 요청 35회를 찾아낼 수 있다.

## 설치 상세

### 내려받아 실행

프로젝트 루트에서 내려받은 스크립트를 호출한다.

```powershell
경로\Tandem\install.ps1 -Mode codex-main -Lang ko
```

### 옵션

| 옵션 | 뜻 |
|---|---|
| `-DocsRoot <경로>` | 운영 문서 폴더; 기본 `docs/tandem` |
| `-Mode <모드>` | 위의 네 모드 중 선택; 다시 실행하면 전환 |
| `-Lang ko\|en` | 대화·문서·안내 언어 |
| `-JevKey <키>` | OpenRouter 키; 명령 기록에 남을 수 있어 대화형 입력 권장 |
| `-NoJev` | Jev 끄기, 설정에 저장 |
| `-UseJev` | Jev 다시 켜기, 설정에 저장 |
| `-SkipDeps` | 의존성과 로그인 확인 건너뛰기 |
| `-Yes` | 질문 없이 기본값 사용 |
| `-Force` | 재배치 실행; 사용자가 고친 파일은 여전히 `.new`로 보존 |
| `-Plan` | 미리보기. 배치·교체·제거·잔존 파일 경고만 보여주고 아무것도 쓰지 않는다 (질문 없이 기본값) |
| `-Clean` | 현재 모드에 없는 TANDEM 파일(옛 모드 잔존·사용자 수정)을 `tandem/.backup/<시각>/`에 옮기고 제거 |

한 줄 설치에 옵션을 주려면 빠른 시작의 `scriptblock` 형식을 쓴다.

### 설치 스크립트가 하는 일

1. 모드와 언어를 고르고 필요한 CLI를 확인하며, 필요하면 Codex 설치를 제안한다.
2. 모드별 역할·명령, 공통 운영 문서와 도구를 배치한다.
3. 해당하는 `CLAUDE.md`·`AGENTS.md`에 TANDEM 블록을 넣고 설정과 훅을 병합한다.
4. `tandem/config.json`과 `tandem/manifest.json`을 쓰고 캐시·실행 결과 경로를 `.gitignore`에 추가한다.

업데이트 때 고치지 않은 TANDEM 파일은 자동 교체한다. 사용자가 고친 파일은 그대로 두고 새 버전을 `<파일>.new`에 쓴다. 현재 모드에 없는 TANDEM 파일(모드 전환으로 남은 옛 파일, 사용자가 고친 파일)은 경고만 하고 두며, `-Clean`을 주면 `tandem/.backup/`에 옮긴 뒤 제거한다. `-Plan`으로 먼저 미리볼 수 있다. 세션 시작 훅은 새 버전과 Jev 키 누락을 알릴 수 있다. Codex 훅에는 프로젝트 신뢰와 `/hooks` 승인이 필요하다.

### 설치되는 것

| 범위 | 파일 |
|---|---|
| 모든 모드 | `docs/tandem/` (`-DocsRoot`로 변경 가능), `tandem/adapt.md`, `tandem/config.json`, `tandem/manifest.json`, `tandem/tools/`의 공통 스크립트 (점검, 토큰 리포트, Jev, 지문, 변경분, 검토 판정 검사, 교훈 조회, 배치 실행) |
| `claude-main` | Claude 팀장·전달책·검수자와 명령, Codex 실무 리드와 에이전트, Claude 설정과 프로젝트 지시 블록 |
| `codex-main` | Codex 설정과 훅, Claude 일꾼 문서와 설정, `tandem/tools/claude-run.ps1` |
| `claude-solo` | Claude 총괄·검수자·상중하 일꾼과 명령, Claude 설정 |
| `codex-solo` | Codex 설정·조사/구현/검토 에이전트·훅, `tandem/tools/codex-run.ps1` |

파일 구성은 선택한 모드를 따른다. 공통 도구는 점검, Jev, 지문, 토큰 리포트를 맡고 실행 래퍼는 해당 모드에 배치된다.

## 되돌리기

설치 커밋을 되돌린다. `.new` 파일과 사용자 수정 사항은 별도로 확인한다. `-Clean`으로 옮긴 파일은 `tandem/.backup/<시각>/`에 있다.

## 알아둘 것

- Codex 전역 `service_tier`가 `fast` 또는 `priority`이면 한도가 2.5배 빨리 소모될 수 있다. TANDEM은 전역 설정을 바꾸지 않고 `/tandem`과 토큰 리포트에서 알린다.
- Codex 세션 훅에는 프로젝트 신뢰와 `/hooks` 승인이 필요하다. 훅 알림은 800자에서 잘리고(`tandem/config.json`의 `hook.max_chars`), 환경변수 `TANDEM_HOOK_OFF=1`이면 훅이 아무 것도 하지 않는다.
- 신뢰되지 않은 폴더에서 `claude -p`는 settings 권한을 무시한다. Claude 래퍼가 필요한 권한을 `--allowedTools`로 넘긴다.

## 포크해서 배포하기

`boot.ps1`과 설치 예시의 `carydev/Tandem`을 본인 저장소로 바꾼다. 절차는 [PUBLISH.md](PUBLISH.md)를 본다.

[변경 기록](CHANGELOG.ko.md)에서 릴리스별 변경 사항을 볼 수 있다.

## 라이선스

[MIT](LICENSE)
