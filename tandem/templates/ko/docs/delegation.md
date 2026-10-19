# 위임 방식

과제 카드에 목표, 배경, 산출물, 쓰기 범위, 완료 조건을 담는다. 하위 일꾼에게 경로를 주고 결과는 파일과 5줄 요약으로 받는다.
작은 과제는 한 라운드로 끝낸다. 판단이 갈리면 R1 제안 → mid 단계의 별도 세션에서 읽기 전용 R2 적대 검토(가능하면 다른 모델) → R3 대응을 쓴다. 세 라운드 뒤 합의가 없으면 쟁점으로 남긴다.
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
네이티브 하위 호출에는 래퍼가 없다. 총괄이 호출 1회마다 {{DOCS}}/log/runs.jsonl에 한 줄 append하고, 알 수 없는 tokens·session은 null, decided_by는 실제 판단 주체로 기록한다. 형식은 log/README.md를 따른다.
@@endif
