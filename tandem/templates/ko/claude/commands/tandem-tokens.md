---
description: 최근 TANDEM 토큰 사용량 요약
---
powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/token-report.ps1 -Days 7 을 실행한다.
stdout의 40줄 이내 요약만 읽고 비용 신호와 권장 조치를 짧게 보고한다. 상세 보고서는 필요할 때만 읽는다.
요약에 캐시율, 1턴 Codex 세션, 메인 상태 확인 호출 수를 포함한다.
모델 배치 변경은 제안까지만 한다.
