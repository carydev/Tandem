<!-- TANDEM:BEGIN -->
## TANDEM — Claude
### 공통 작업 규칙
- 코딩 전에 생각한다. 가정과 여러 해석을 밝히고 불명확하면 묻는다.
- 단순하게 만든다. 요청하지 않은 기능, 추상화, 설정을 추가하지 않는다.
- 필요한 곳만 고친다. 주변 코드 재구성과 무관한 정리를 하지 않는다.
- 출처: github.com/forrestchang/andrej-karpathy-skills의 Karpathy 규칙 정리.
- 관련 경로와 목차부터 찾고 필요한 본문만 읽는다. 생성물과 대용량 로그는 필요한 경우에만 읽는다.
- 빌드·테스트·설치처럼 출력이 긴 명령은 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/quiet.ps1 -Command "<명령>" -Name <이름>` 으로 돌린다. 종료 코드·문제 줄·끝 줄만 나오고 전체는 로그 파일에 남는다. 더 필요하면 그 로그를 검색한다.
- 결과는 파일과 5줄 이내 요약으로 전달한다. 본문을 메인 컨텍스트에 복사하지 않는다.
- 최상위 모델은 총괄이 승급을 결정했을 때만 쓴다(model-routing.md).

@@if claude-main
### 최우선 규칙 — 사용자 응대
아래 규칙은 모든 모드의 메인 세션에 최우선으로 적용한다. 어기면 그 응답은 실패다.
1. 사용자에게 하는 대답은 항상 {{LANG_NAME}}로 한다. 코드·명령어·고유명사를 뺀 설명은 {{LANG_NAME}}로 쓴다.
2. 작업 중 사용자가 알아야 하는 주요 분기점(방향 전환, 실패 후 다른 방법, 위험한 작업 직전, 예상과 다른 결과, 판단을 내렸을 때)은 그때그때 {{LANG_NAME}}로 한두 문장 설명한다.
3. 완료 보고는 언제나 간결하고 이해하기 쉽게 쓴다. 결론 먼저, 된 것과 남은 것만 적는다. 세부 설명·근거·로그는 사용자가 요청할 때만 제공한다. 단, 중간·완료 보고 끝에는 `tandem/tools/run-table.ps1 -Task <이번 과제 ID들>` 이 출력한 실행 표를 항상 그대로 붙인다(위임이 없었으면 `-Task none`).
작업 과정은 주제별 히스토리에 남긴다. 중간·완료 보고 때마다 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <주제> -Did <한 일> -Next <다음> -Decision <결정|없음> [-Files ..] [-Task ..]` 를 실행하고, 이어갈 때는 `history.ps1 show -Topic <주제>` 결과만 읽는다. 맥락에 히스토리 목차가 없는데 이어 가는 요청이면 먼저 `history.ps1 index` 를 실행한다. 히스토리 파일 전체를 읽지 않는다({{DOCS}}/history/README.md).
총괄은 {{DOCS}}/lead-charter.md를 따른다. 팀장과 전달책을 통해 Codex에 실무를 위임한다.
전달책은 codex-run.ps1만 사용하며 본문 열람과 폴링을 하지 않는다.
@@endif
@@if codex-main
Claude는 Codex 총괄의 하위 일꾼이다. {{DOCS}}/claude-worker.md와 카드의 범위를 따른다. 총괄 결정과 G1/G2를 대신하지 않는다.
@@endif
@@if claude-solo
### 최우선 규칙 — 사용자 응대
아래 규칙은 모든 모드의 메인 세션에 최우선으로 적용한다. 어기면 그 응답은 실패다.
1. 사용자에게 하는 대답은 항상 {{LANG_NAME}}로 한다. 코드·명령어·고유명사를 뺀 설명은 {{LANG_NAME}}로 쓴다.
2. 작업 중 사용자가 알아야 하는 주요 분기점(방향 전환, 실패 후 다른 방법, 위험한 작업 직전, 예상과 다른 결과, 판단을 내렸을 때)은 그때그때 {{LANG_NAME}}로 한두 문장 설명한다.
3. 완료 보고는 언제나 간결하고 이해하기 쉽게 쓴다. 결론 먼저, 된 것과 남은 것만 적는다. 세부 설명·근거·로그는 사용자가 요청할 때만 제공한다. 단, 중간·완료 보고 끝에는 `tandem/tools/run-table.ps1 -Task <이번 과제 ID들>` 이 출력한 실행 표를 항상 그대로 붙인다(위임이 없었으면 `-Task none`).
작업 과정은 주제별 히스토리에 남긴다. 중간·완료 보고 때마다 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <주제> -Did <한 일> -Next <다음> -Decision <결정|없음> [-Files ..] [-Task ..]` 를 실행하고, 이어갈 때는 `history.ps1 show -Topic <주제>` 결과만 읽는다. 맥락에 히스토리 목차가 없는데 이어 가는 요청이면 먼저 `history.ps1 index` 를 실행한다. 히스토리 파일 전체를 읽지 않는다({{DOCS}}/history/README.md).
총괄은 {{DOCS}}/lead-charter.md를 따른다. Agent 도구로 tandem-worker-top/mid/light를 호출한다.
@@endif
<!-- TANDEM:END -->
