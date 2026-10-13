# 운영 모델 — {{PROJECT}}

사용자 언어는 {{LANG_NAME}}이다. 문서와 보고도 {{LANG_NAME}}로 쓴다.
지시 → G1 과제 정의 확인 → 카드 작성 → 하위 실행 → 검수 → G2 브리핑 → 승인 뒤 기준 문서 반영 순서다.
기준 문서는 적응 단계에서 표를 채운다. 없으면 없다고 명시한다. 되돌리기 어려운 결정 목록도 프로젝트에 맞춰 채운다.

@@if claude-main
사람 → Claude 총괄 → Claude 팀장 → Claude 전달책 → Codex 실무팀. 교차 검수는 조건부 Claude critic.
@@endif
@@if codex-main
사람 → Codex 총괄 → Claude 실무 일꾼. 위임은 claude-run.ps1 래퍼를 거친다.
@@endif
@@if claude-solo
사람 → Claude 상위 총괄 → tandem-worker-top/mid/light Agent.
@@endif
@@if codex-solo
사람 → Codex 상위 총괄 → .codex/agents 하위 일꾼.
@@endif

| 문서 | 권한 |
|---|---|
| 프로젝트 기준 문서 | 총괄이 G2 승인 뒤 수정 |
| {{DOCS}}/tasks/ | 과제 카드 작성 역할 |
| {{DOCS}}/reports/ | 하위 일꾼과 검수자 |
| {{DOCS}}/model-routing.md | 총괄 |
| {{DOCS}}/log/runs.jsonl | main: 실행 래퍼, solo: 총괄이 하위 호출마다 append |
| {{DOCS}}/harness-status.md | 설치·적응 세션 |

## 프로젝트 기준 문서
| 경로 | 역할 |
|---|---|
| 적응 단계에서 채움 | 확인 전에는 확정하지 않음 |

## 되돌리기 어려운 결정
- 적응 단계에서 프로젝트별 목록을 채운다.
