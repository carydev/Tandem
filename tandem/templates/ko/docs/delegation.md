# 위임 방식

과제 카드에 목표, 배경, 산출물, 쓰기 범위, 완료 조건을 담는다. 하위 일꾼에게 경로를 주고 결과는 파일과 5줄 요약으로 받는다.
작은 과제는 한 라운드로 끝낸다. 판단이 갈리면 R1 제안 → 다른 모델의 별도 R2 반론 → R3 대응을 쓴다. R2는 읽기 전용이다. 세 라운드 뒤 합의가 없으면 쟁점으로 남긴다.
하위 일꾼은 관련 경로부터 검색하고 필요한 본문만 읽는다. 작업 후 관련 검증을 수행하고 변경, 검증, 위험을 짧게 보고한다.

@@if claude-main
팀장 → tandem-dispatch → tandem/tools/codex-run.ps1 → Codex 리드. 전달책은 래퍼 호출과 블로킹 대기만 한다.
래퍼가 runs.jsonl을 append한다. 전달책은 codex exec 직접 실행, 폴링, 산출물 본문 읽기, 로그 직접 쓰기를 하지 않는다.
@@endif
@@if codex-main
Codex 총괄 → tandem/tools/claude-run.ps1 → Claude 실무. 래퍼가 runs.jsonl을 append한다.
@@endif
@@if claude-solo
Claude 총괄 → Agent 도구의 tandem-worker-top/mid/light. 명시된 모델을 확인하고 산출물을 파일로 받는다.
@@endif
@@if codex-solo
Codex 총괄 → .codex/agents/researcher, implementer, reviewer. 역할 이름 호출이 안 되면 TOML의 developer_instructions를 전달한다.
codex-run.ps1은 배치되지만 R2의 별도 세션·다른 모델 호출에만 쓴다.
@@endif
@@if claude-solo codex-solo
네이티브 하위 호출에는 래퍼가 없다. 총괄이 호출 1회마다 {{DOCS}}/log/runs.jsonl에 한 줄 append하고, 알 수 없는 tokens·session은 null, decided_by는 실제 판단 주체로 기록한다. 형식은 log/README.md를 따른다.
@@endif
