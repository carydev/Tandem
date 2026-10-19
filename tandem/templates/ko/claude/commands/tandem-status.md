---
description: TANDEM 상태와 실행 요약
---
tandem/config.json, {{DOCS}}/harness-status.md, {{DOCS}}/log/runs.jsonl을 읽고 8줄 이내로 보고해라. 파일을 고치지 마라.
버전, 설치일, 모드, 활성 역할과 모델, 실행 성공·실패·승급 수와 최상위 사용 건수(`runs.jsonl`의 `escalated_from` 기준)를 적는다. 기록이 없으면 '아직 실행 기록 없음'이라고 적는다.
@@if claude-main
Codex 실무팀과 래퍼 상태를 포함한다.
@@endif
@@if claude-solo
Claude worker 세 단계와 Agent 호출 상태를 포함한다.
@@endif
