# 실행 로그

{{DOCS}}/log/runs.jsonl은 한 실행에 한 JSON 객체를 append한다. 기존 줄을 고치거나 지우지 않는다.
@@if claude-main codex-main
실행 래퍼 codex-run.ps1 또는 claude-run.ps1이 쓴다. 전달책과 총괄은 직접 쓰지 않는다.
@@endif
@@if claude-solo codex-solo
래퍼가 없는 네이티브 하위 호출은 총괄이 호출 1회마다 runs.jsonl에 한 줄 append한다. tokens와 session을 알 수 없으면 null로 기록하고 decided_by를 반드시 기록한다.
@@endif

예시:
{"ts":"2026-10-13T09:00:00+09:00","task":"T-12","round":"R1","model":"모델ID","effort":"high","result":"ok","escalated_from":null,"workers":null,"out":"{{DOCS}}/reports/work/T-12_v1.md","session":"세션ID","tokens":{"input":0,"cached":0,"output":0},"decided_by":"table","note":""}

| 필드 | 의미 |
|---|---|
| ts | ISO 8601 시각 |
| task, round | 과제 ID와 R1/R2/R3/single |
| model, effort | 실제 모델과 추론 강도 |
| result | ok/fail/partial |
| escalated_from | 승급 전 모델, 없으면 null |
| workers | 하위 일꾼 수, 모르면 null |
| out | 산출물 경로, 실패면 null |
| session | CLI 세션 ID, 알 수 없으면 null |
| tokens | input/cached/output 사용량, 알 수 없으면 null |
| decided_by | jev/table/human |
| note | 실패 이유 또는 특이사항 |

집계는 5건마다 모델별 실패와 승급, 호출 수, 토큰 사용을 확인한다. 배치표 변경은 총괄이 한다.
