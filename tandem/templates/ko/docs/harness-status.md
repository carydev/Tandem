# 하네스 현황

| 항목 | 값 |
|---|---|
| 세트 | TANDEM |
| 버전 | {{VERSION}} |
| 설치일 | {{INSTALLED}} |
| 프로젝트 | {{PROJECT}} |
| 모드 | {{MODE}} |
| 언어 | {{LANG_NAME}} |
| 적응 완료 | 아니오 |
| 적응 보고서 | {{DOCS}}/reports/setup/tandem-adapt.md |

@@if claude-main
구조: Claude 총괄 {{CLAUDE_LEAD}} → 팀장 {{CLAUDE_MANAGER}} → 전달책 {{CLAUDE_DISPATCH}} → Codex 리드 {{MODEL_MID}} / 일꾼 {{MODEL_LIGHT}}. 교차 검수 {{CLAUDE_CRITIC}}.
@@endif
@@if codex-main
구조: Codex 총괄 {{MODEL_TOP}} → Claude 실무 {{CLAUDE_MID}} / 경량 {{CLAUDE_LIGHT}} / 승급 {{CLAUDE_TOP}}.
@@endif
@@if claude-solo
구조: Claude 총괄 {{CLAUDE_LEAD}} → worker 상위 {{CLAUDE_TOP}}, 중간 {{CLAUDE_MID}}, 경량 {{CLAUDE_LIGHT}}.
@@endif
@@if codex-solo
구조: Codex 총괄 {{MODEL_TOP}} → .codex/agents 중간 {{MODEL_MID}}, 경량 {{MODEL_LIGHT}}.
@@endif

환경 확인은 적응 단계에서 실제 실행 결과로 채운다. 미확인 항목은 확인 불가로 남긴다.
| 항목 | 결과 |
|---|---|
| Claude CLI | 확인 불가 |
| Codex CLI | 확인 불가 |
| 모델 ID와 추론 강도 | 확인 불가 |
| 하위 호출과 결과 파일 | 확인 불가 |
| hooks 승인 | 확인 불가 |
| Jev 키 및 스모크 테스트 | 확인 불가 |
| Fast/service_tier | 확인 불가 |
