# 모델 배치

모델 ID를 tandem/config.json의 models에 기록하고, 배치된 파일 안의 미확정 표기를 같은 값으로 직접 바꾼 뒤 tandem/tools/manifest.ps1 -Rehash를 실행한다. 업데이트 때 설치 스크립트가 config 값으로 렌더하므로 다음 버전에도 유지된다. 모델이 없으면 임의 ID를 추측하지 않는다.
tandem/config.json에서 `jev.enabled`가 false면 jev.ps1을 호출하거나 사용자에게 Jev를 언급하지 않는다. 배치표로 결정하고 decided_by=table을 기록한다. 그 외에 Jev 키가 있으면 tandem/tools/jev.ps1 -Route -Card <카드경로>를 호출해 tier와 effort를 받는다. decided_by=jev를 로그에 남긴다.
승급 판단은 tandem/tools/jev.ps1 -Escalate -Card <카드경로> -FailNote <실패요약>, 교차 검수 판단은 -NeedCritic -Card <카드경로>를 쓴다. 키가 없거나 오류·낮은 신뢰도면 아래 배치표를 쓴다. decided_by=table을 기록한다. Jev는 모델·강도와 교차 검수 필요성을 제안하고 승급 판단을 참고만 하며 최종 판정과 G1/G2는 정하지 않는다.
Jev가 `insufficient_credits` 또는 `invalid_key` 이유를 돌려주면 배치표로 결정한다. 메인은 반환된 `notice`를 그 세션에서 사용자에게 한 번만 안내하고 이후 호출에서 반복하지 않는다. 하위 에이전트와 전달책은 `notice`를 바꾸지 않고 메인에게 올린다.

@@if claude-main
| 역할 | 모델 | 기본 강도 |
|---|---|---|
| Claude 총괄 | {{CLAUDE_LEAD}} | 계정 설정 |
| 팀장 | {{CLAUDE_MANAGER}} | 총괄 바로 아래 단계 기본 |
| 전달책 | {{CLAUDE_DISPATCH}} | 낮음 |
| 교차 검수 | {{CLAUDE_CRITIC}} | 작업별 |
| Codex 리드 | {{MODEL_MID}} | high |
| Codex 일꾼 | {{MODEL_LIGHT}} | medium |
| Codex 승급 | {{MODEL_TOP}} | xhigh (승급 전용) |
Codex 호출은 codex-run.ps1, R2는 mid 단계 별도 세션(읽기 전용)을 쓴다.
@@endif
@@if codex-main
| 역할 | 모델 | 기본 강도 |
|---|---|---|
| Codex 총괄 | {{MODEL_TOP}} | 계정 설정 |
| Claude 실무 | {{CLAUDE_MID}} | 작업별 |
| Claude 경량 | {{CLAUDE_LIGHT}} | 작업별 |
| Claude 승급 | {{CLAUDE_TOP}} | 승급 전용 |
Claude 호출은 claude-run.ps1을 쓴다.
@@endif
@@if claude-solo
| 역할 | 모델 |
|---|---|
| 총괄 | {{CLAUDE_LEAD}} |
| 승급 일꾼 (승급 전용) | {{CLAUDE_TOP}} |
| 중간 일꾼 | {{CLAUDE_MID}} |
| 경량 일꾼 | {{CLAUDE_LIGHT}} |
Agent 도구로 모델이 지정된 tandem-worker-top/mid/light를 호출한다.
@@endif
@@if codex-solo
| 역할 | 모델 | 강도 |
|---|---|---|
| 총괄 | {{MODEL_TOP}} | 계정 설정 |
| 실무 일꾼 | {{MODEL_MID}} | high |
| 경량 일꾼 | {{MODEL_LIGHT}} | medium |
| 검토 | {{MODEL_MID}} | high (read-only) |
| 승급 | {{MODEL_TOP}} | xhigh (승급 전용) |
.codex/agents의 역할 정의를 따른다.
@@endif

## 최상위 모델 사용 규칙

총괄 아래 모든 역할은 최상위 단계(Claude `claude_top`, Codex `codex_top`)를 기본으로 쓰지 않는다. 최상위는 사용자가 해당 카드에 직접 지정해 `decided_by=human`으로 기록했거나, 같은 카드가 mid 단계에서 한 번 실패(`STOPPED:` 또는 완료 조건 미달)하고 총괄이 원인을 **모델 능력 부족**으로 판정했을 때만 쓴다. 스펙 모호·환경 문제·범위 오류는 카드를 수정한다.
카드당 승급은 한 번, 승급 실행은 R1 재실행 한 번이다. 승급은 총괄만 결정한다. 총괄은 `runs.jsonl`의 `escalated_from`·`reason`, 카드 머리와 산출물 머리에 각각 한 줄로 기록한다. 래퍼 모드에서는 `-EscalatedFrom`·`-Reason` 없이 최상위를 실행하지 않는다. 네이티브 모드에서는 총괄이 같은 두 필드를 `runs.jsonl`에 직접 쓴다. Jev는 최상위를 고르지 않으며 `-Escalate` 결과는 참고일 뿐 승급 조건을 대신하지 않는다.
claude-main 팀장(tandem-manager)은 총괄 바로 아래 `claude_manager`가 기본이다. 사용자 지정 또는 총괄 판단으로 최상위가 필요하면 총괄이 Agent 호출의 model을 지정해 올리고 사용자에게 한 줄 알린다. 팀장은 이유를 적어 제안만 한다. R2 적대 검토는 mid 단계의 별도 세션에서 R1과 따로 읽기 전용으로 한다(가능하면 다른 모델). `operating-model.md`의 되돌리기 어려운 결정 검수에만 총괄 승인으로 최상위를 쓰고 이유를 기록한다.
