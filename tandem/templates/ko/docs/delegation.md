# 위임 방식

과제 카드에 목표, 배경, 산출물, 쓰기 범위, 완료 조건을 담는다. 하위 일꾼에게 경로를 주고 결과는 파일과 5줄 요약으로 받는다.
작은 과제는 한 라운드로 끝낸다. 판단이 갈리면 R1 제안 → mid 단계의 별도 세션에서 읽기 전용 R2 적대 검토(가능하면 다른 모델) → R3 대응을 쓴다. 세 라운드 뒤 합의가 없으면 쟁점으로 남긴다.
R3·재시도·반려 후 재실행은 R1 세션을 이어 쓴다(캐시). R2와 승급은 새 세션이다.
R2에는 카드 경로(목표·완료 조건), 변경분 파일 경로, 산출물 경로만 준다. R1 대화·추론 과정·자기 평가는 전달하지 않는다.
@@if claude-main codex-main
R2 호출 시 래퍼가 `tandem/tools/diff.ps1`로 변경분(새 파일 포함)을 저장해 경로를 넘긴다.
@@endif
@@if claude-solo codex-solo
총괄이 `tandem/tools/diff.ps1 -Task <ID>`를 실행해 나온 경로를 검토자에게 준다.
@@endif
래퍼가 `status=stopped`를 반환하면 `STOPPED:` 줄을 그대로 전달한다. 카드 작성자가 lessons/README.md에 따라 기록한다. 승급은 총괄만 model-routing.md의 사용 규칙에 따라 결정한다.
하위 일꾼은 관련 경로부터 검색하고 필요한 본문만 읽는다. 작업 후 관련 검증을 수행하고 변경, 검증, 위험을 짧게 보고한다.

@@if claude-main
팀장 → tandem-dispatch → tandem/tools/codex-run.ps1 → Codex 리드. 전달책은 래퍼 호출과 블로킹 대기만 한다.
래퍼가 runs.jsonl을 append한다. 전달책은 codex exec 직접 실행, 폴링, 산출물 본문 읽기, 로그 직접 쓰기를 하지 않는다.
@@endif
@@if codex-main
Codex 총괄 → tandem/tools/claude-run.ps1 → Claude 실무. 래퍼가 runs.jsonl을 append한다. 최상위 모델(`claude_top`)은 총괄이 `-EscalatedFrom <ID> -Reason <한 줄>`(사용자 지정은 `-DecidedBy human -Reason`)을 붙였을 때만 실행된다.
@@endif
@@if claude-solo
Claude 총괄 → Agent 도구의 tandem-worker-top/mid/light. 명시된 모델을 확인하고 산출물을 파일로 받는다.
@@endif
@@if codex-solo
Codex 총괄 → .codex/agents/researcher, implementer, reviewer. 역할 이름 호출이 안 되면 TOML의 developer_instructions를 전달한다.
codex-run.ps1은 배치되지만 R2의 mid 단계 별도 읽기 전용 세션에만 쓴다.
@@endif
@@if claude-solo codex-solo
네이티브 하위 호출에는 래퍼가 없다. 총괄이 호출 1회마다 {{DOCS}}/log/runs.jsonl에 한 줄 append하고, 알 수 없는 tokens·session은 null, decided_by는 실제 판단 주체로 기록한다. 에이전트 이름·카드 제목·걸린 시간(agent, title, duration_s)도 남긴다. 형식은 log/README.md를 따른다.
@@endif

## R2 판정과 R3 응답

R2 는 지적마다 번호(F1, F2…)와 판정 하나를 쓴다. `confirmed` 는 근거(경로:줄 또는 산출물 위치)와 심각도(높음/중간/낮음)가 있는 결함, `needs_validation` 은 근거를 확인하지 못한 지적(심각도 없음, `미확인=` 에 어떤 사실인지), `rejected` 는 검토 중 기각한 후보(`이유=`)다. confirmed + needs_validation 은 최소 3개다.
총괄은 `tandem/tools/review-check.ps1 -Review <R2 경로>` 로 형식을 확인한다. `status=fail` 은 판정 줄이 없는 것이니 R2 를 다시 받는다. `warn` 줄은 총괄이 읽고 판단한다.
@@if claude-main codex-main
래퍼는 R2 호출 뒤 같은 검사를 자동으로 돌려 요약에 `review=` 줄을 붙이고 runs.jsonl 에 `findings` 를 기록한다.
@@endif
needs_validation 은 발견자가 아닌 쪽이 사실을 확인한다. 총괄이 직접 확인하거나 확인 과제를 따로 준다. 확인되면 confirmed, 아니면 rejected 로 총괄이 판정한다.
R3 는 confirmed 와 needs_validation 마다 한 줄로 답한다: `- F1 fixed|disputed|deferred <한 줄>`. `review-check.ps1 -Review <R2> -Response <R3>` 가 빠진 ID 를 알린다.
confirmed 높음 이 fixed 가 아니면 반려한다. disputed 는 총괄이 판정하고, 3라운드 뒤에도 남은 것은 쟁점으로 기록한다.

## 디자인 과제

카드에 `디자인:` 줄이 있으면 {{DOCS}}/design.md 를 따른다. 만들 때 Interfaces 스킬(`tandem/design/skills/`)을 읽고, 디자인 검수(라운드 RD)가 approve 여야 완료다.
@@if claude-main codex-main
래퍼가 R1·R3·single 프롬프트에 디자인 지시를 자동으로 붙인다. 끝난 뒤 요약에 `design=` 줄이 붙으면 할 일이 남은 것이다. `review=missing`, `review=block`, `review=invalid` 는 RD 가 남았다는 뜻이고, `design=unmarked` 는 줄 없는 카드로 화면 파일이 바뀌었다는 뜻이다.
RD 는 래퍼를 `-Round RD` 로 호출한다(mid 단계, 강도 high, 출력 {{DOCS}}/reports/review/<ID>-design.md). 래퍼가 읽기 전용 새 세션에서 변경분과 검수 지시를 붙이고 `design.ps1 check` 로 판정을 기록해 요약에 `design=approve`, `design=block`, `design=invalid` 중 하나를 붙인다.
@@endif
@@if codex-solo
하위 일꾼은 구현 전에 `design.ps1 brief -Task <ID> -Card <카드>` 가 내는 지시를 따른다. RD 는 총괄이 `codex-run.ps1 -Round RD` 로 호출한다(mid 단계, 강도 high, 출력 {{DOCS}}/reports/review/<ID>-design.md). 래퍼가 읽기 전용 새 세션에서 변경분과 검수 지시를 붙이고 판정을 기록해 요약에 `design=approve`, `design=block`, `design=invalid` 중 하나를 붙인다.
@@endif
@@if claude-solo
하위 일꾼은 구현 전에 `design.ps1 brief -Task <ID> -Card <카드>` 가 내는 지시를 따른다. RD 는 총괄이 `design.ps1 brief -Task <ID> -Card <카드> -For review` 출력과 `diff.ps1 -Task <ID>` 경로를 tandem-critic 에게 주어 {{DOCS}}/reports/review/<ID>-design.md 에 쓰게 하고, `design.ps1 check -Task <ID> -Review <경로>` 로 판정을 기록한다.
@@endif
RD 의 지적도 R2 와 같은 판정 줄을 쓰고 confirmed·needs_validation 마다 R3 응답을 받는다. 다만 지적 최소 3개 규칙은 RD 에 적용하지 않는다. block 이면 R3 로 고친 뒤 RD 를 다시 받는다.
디자인 카드는 판정이 approve 가 되기 전에는 `board.ps1 move -To done` 이 거부된다. RD 가 도는 동안 카드는 review 칸에 있다.

## 칸반 보드

{{DOCS}}/board/index.html 을 브라우저로 열면 3초마다 갱신되는 보드가 보인다(`board.ps1 open`). 데이터는 같은 폴더의 board.json 이며 board.ps1 만 고친다.
칸: todo 할 일 → doing 진행중 → built 작업완료 → review 리뷰 → test 테스트 → done 완료, 그리고 blocked 막힘.
- 총괄: G1 뒤 `add`, 테스트 시작 `test`, 합격 `done`, STOPPED 나 진전 없음 `blocked`.
- 작업한 에이전트는 built 까지만 옮긴다. 리뷰·테스트·완료는 스스로 옮기지 않는다(발견자≠검증자).
@@if claude-main codex-main
- 래퍼가 호출 시작에 doing(R2 는 review), 성공하면 built, STOPPED 면 blocked 로 옮기고 R2 판정 줄을 카드 메모에 남긴다.
@@endif
@@if claude-solo codex-solo
- 총괄이 위임할 때 doing, R2 를 시작할 때 review 로 옮긴다. 하위 일꾼은 끝날 때 built 로 옮긴다. 못 옮겼으면 총괄이 옮긴다.
@@endif
- 완료 보고 전 `board.ps1 list -Task <ID>` 로 카드 칸이 실제 상태와 맞는지 확인한다.
명령: `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/board.ps1 add|move|note|remove|list|sync|open -Task <ID[,ID]> [-To <칸>] [-By <이름>] [-Note <한 줄>]`
