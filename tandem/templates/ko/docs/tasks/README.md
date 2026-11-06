# 과제 카드

과제 ID 형식은 프로젝트의 기존 체계를 따른다. 기존 체계가 없으면 적응 단계에서 정한다.
카드 첫 줄은 `# <ID> <한 줄 제목>` 이다. 래퍼가 이 제목을 runs.jsonl의 title(실행 표의 "맡긴 작업")로 기록한다.
G1 확인이 끝난 카드는 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/board.ps1 add -Task <ID> -Card <카드 경로>` 로 보드의 할 일 칸에 올린다.
카드에는 목표, 확정 배경, 쓰기 범위, 산출물 경로, 모델과 강도, 참고 경로, 검증 가능한 완료 조건을 적는다.
화면이나 사람이 보는 문서를 만들거나 바꾸는 과제는 카드에 `디자인: <web|android|ios|flutter|desktop|doc>` 줄을 적는다(design.md). 이 줄이 있으면 일꾼에게 스킬 적용 지시가 붙고, 완료 전에 디자인 검수(RD)를 받아야 한다. 화면과 무관하면 줄을 빼거나 `디자인: 없음` 으로 적는다.
카드 쓰기 전 `tandem/tools/lessons.ps1 -Tags <태그,태그>` 로 교훈을 최대 3줄 뽑아 배경에 붙인다 (lessons/README.md).
@@if claude-main
tandem-manager가 쓰고 Codex 리드가 읽는다.
@@endif
@@if codex-main codex-solo
Codex 총괄이 쓰고 하위 일꾼이 읽는다.
@@endif
@@if claude-solo
Claude 총괄이 쓰고 worker가 읽는다.
@@endif
