# 모델 배치

모델 ID를 tandem/config.json의 models에 기록하고, 배치된 파일 안의 미확정 표기를 같은 값으로 직접 바꾼 뒤 tandem/tools/manifest.ps1 -Rehash를 실행한다. 업데이트 때 설치 스크립트가 config 값으로 렌더하므로 다음 버전에도 유지된다. 모델이 없으면 임의 ID를 추측하지 않는다.
tandem/config.json에서 `jev.enabled`가 false면 jev.ps1을 호출하거나 사용자에게 Jev를 언급하지 않는다. 배치표로 결정하고 decided_by=table을 기록한다. 그 외에 Jev 키가 있으면 tandem/tools/jev.ps1 -Route -Card <카드경로>를 호출해 tier와 effort를 받는다. decided_by=jev를 로그에 남긴다.
승급 판단은 tandem/tools/jev.ps1 -Escalate -Card <카드경로> -FailNote <실패요약>, 교차 검수 판단은 -NeedCritic -Card <카드경로>를 쓴다. 키가 없거나 오류·낮은 신뢰도면 아래 배치표를 쓴다. decided_by=table을 기록한다. Jev는 모델·강도, 승급, 교차 검수 필요성만 정하고 최종 판정과 G1/G2는 정하지 않는다.
Jev가 `insufficient_credits` 또는 `invalid_key` 이유를 돌려주면 배치표로 결정한다. 메인은 반환된 `notice`를 그 세션에서 사용자에게 한 번만 안내하고 이후 호출에서 반복하지 않는다. 하위 에이전트와 전달책은 `notice`를 바꾸지 않고 메인에게 올린다.

@@if claude-main
| 역할 | 모델 | 기본 강도 |
|---|---|---|
| Claude 총괄 | {{CLAUDE_LEAD}} | 계정 설정 |
| 팀장 | {{CLAUDE_MANAGER}} | 작업별 |
| 전달책 | {{CLAUDE_DISPATCH}} | 낮음 |
| 교차 검수 | {{CLAUDE_CRITIC}} | 작업별 |
| Codex 리드 | {{MODEL_MID}} | high |
| Codex 일꾼 | {{MODEL_LIGHT}} | medium |
| Codex 승급 | {{MODEL_TOP}} | xhigh |
Codex 호출은 codex-run.ps1, R2는 별도 세션의 다른 모델과 read-only를 쓴다.
@@endif
@@if codex-main
| 역할 | 모델 | 기본 강도 |
|---|---|---|
| Codex 총괄 | {{MODEL_TOP}} | 계정 설정 |
| Claude 실무 | {{CLAUDE_MID}} | 작업별 |
| Claude 경량 | {{CLAUDE_LIGHT}} | 작업별 |
| Claude 승급 | {{CLAUDE_TOP}} | 작업별 |
Claude 호출은 claude-run.ps1을 쓴다.
@@endif
@@if claude-solo
| 역할 | 모델 |
|---|---|
| 총괄 | {{CLAUDE_LEAD}} |
| 상위 일꾼 | {{CLAUDE_TOP}} |
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
.codex/agents의 역할 정의를 따른다.
@@endif

경량 추출·요약부터 시작한다. 설계 판단은 중간 단계와 high, 실제 실패한 난제는 상위로 승급한다. 긴 자율 작업이나 명시적 지시도 승급 사유다.
실패 없이 막연히 상위 모델로 올리지 않는다. Jev가 없으면 배치표와 실패 기록으로 결정한다. 승급 이유와 이전 모델을 산출물과 로그에 적는다.
R2 반론은 R1과 다른 모델의 별도 세션에서 수행한다. 3라운드 뒤 미해결이면 쟁점으로 보고한다.
