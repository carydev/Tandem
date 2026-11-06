# 디자인 품질

사람이 보는 화면과 문서는 Interfaces 스킬의 규칙으로 만들고 검수한다. 스킬 사본은 `tandem/design/skills/` 에 있다(출처와 라이선스: `tandem/design/SOURCE.md`).
스킬은 경로로 읽는다. 따로 설치하거나 사용자가 불러 줄 필요가 없다. 카드에 `디자인:` 줄이 있으면 만들 때와 검수할 때 자동으로 적용된다.
결과물 품질이 토큰 절약보다 우선이다. 디자인 과제에서 스킬 읽기와 디자인 검수를 비용 때문에 생략하지 않는다.

## 언제 적용하나
- 화면, 컴포넌트, 스타일, 아이콘, 애니메이션, 화면 문구, 사람이 여는 HTML 문서를 만들거나 바꾸는 과제는 디자인 과제다. 웹, Android, iOS, Flutter, 데스크톱을 가리지 않는다.
- 디자인 과제의 카드에는 `디자인: <web|android|ios|flutter|desktop|doc>` 줄을 적는다. 여러 개면 쉼표로 나눈다. `디자인: 예` 는 tandem/config.json 의 `design.platform` 을 쓴다.
- 화면과 무관한 과제는 줄을 빼거나 `디자인: 없음` 으로 적는다. 판단은 카드 작성자가 G1 전에 한다. 애매하면 디자인 과제로 본다.
- 줄이 없는 카드에서 화면 파일이 바뀌면 `design=unmarked` 알림이 나온다. 총괄이 카드에 줄을 적고 `board.ps1 add -Task <ID> -Card <카드>` 로 보드에 다시 올린 뒤 디자인 검수를 받는다.

## 흐름
1. 카드에 `디자인:` 줄을 적는다.
2. 일꾼이 스킬을 읽고 그 규칙대로 만든다(「만들 때」).
3. 판단이 갈리는 과제는 평소대로 R2 를 받는다. R2 는 정확성·테스트·보안·범위를 보고, 화면은 보지 않는다.
4. 디자인 검수(RD)를 받는다(「검수」). 디자인 과제에서는 필수다.
5. 판정이 block 이면 R3 로 고치고 RD 를 다시 받는다.
6. 판정이 approve 여야 보드에서 완료로 옮겨진다. G2 브리핑에 디자인 판정과 남은 지적을 넣는다.

## 만들 때
@@if claude-main codex-main
래퍼가 카드의 `디자인:` 줄을 보고 아래 지시를 일꾼 프롬프트에 자동으로 붙인다. 총괄과 전달책이 따로 전할 것은 없다.
@@endif
@@if claude-solo codex-solo
하위 일꾼은 카드에 `디자인:` 줄이 있으면 구현 전에 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/design.ps1 brief -Task <ID> -Card <카드>` 를 실행하고 나온 지시를 따른다. 총괄이 위임할 때 같은 출력을 프롬프트에 붙여도 된다.
@@endif
- 영역 스킬 6개를 이 순서로 읽는다: `better-accessibility`, `better-layout`, `better-writing`, `better-typography`, `better-colors`, `better-ui` (각 폴더의 `SKILL.md`, 참고 파일은 그 주제를 다룰 때).
- 웹이 아닌 플랫폼은 {{DOCS}}/design-platforms.md 로 규칙을 옮겨 적용한다. 원칙과 수치는 그대로 두고 구현 수단만 바꾼다.
- 프로젝트에 이미 있는 토큰, 컴포넌트, 디자인 문서가 먼저다. 새 값을 만들기 전에 있는 것을 쓴다. 취향으로 기존 결정을 뒤집지 않는다.
- `better-interface/SKILL.md` 의 최고 심각도 조건(Escalation triggers)이 하나라도 남으면 완료가 아니다.
- 렌더 증거를 남긴다. 스크린샷을 {{DOCS}}/reports/work/<ID>-shots/ 에 저장하고 산출물에 경로를 적는다. 만들 수 없으면 이유를 적는다. 수단은 design-platforms.md 의 「렌더 증거」.
- 산출물에 「디자인」 절을 둔다: 읽고 적용한 스킬, 최고 심각도 조건 자체 점검, 렌더 증거.

### 절차 스킬
카드에 `절차: <이름>` 을 적으면 일꾼이 `tandem/design/skills/<이름>/SKILL.md` 의 절차를 따른다. 원래는 사용자가 직접 부르는 스킬이지만 TANDEM 에서는 카드가 호출을 대신한다.

| 이름 | 쓰는 때 |
|---|---|
| build-design | Figma 파일이나 디자인 이미지를 그대로 구현할 때 |
| variant | 방향이 정해지지 않아 서로 다른 시안 3개를 놓고 고를 때 |
| state-machine | 컴포넌트의 모든 상태(로딩, 빈 값, 오류, 권한)를 한 화면에서 다듬을 때 |
| break | 컴포넌트 하나를 최악의 입력으로 한 번에 시험할 때 |
| explain-interface | 참고 사이트나 스크린샷이 어떻게 만들어졌는지 알아낼 때 |

이 절차들은 웹앱의 임시 페이지를 전제로 쓰여 있다. 다른 플랫폼은 design-platforms.md 의 「절차 스킬 옮기기」를 따른다.

## 검수
디자인 검수는 라운드 `RD` 다. 만든 쪽이 아닌 별도 세션이 읽기 전용으로 한다. mid 단계 이상, 가능하면 만든 모델과 다른 모델을 쓴다.
@@if claude-main
팀장이 전달책을 통해 `codex-run.ps1 -Task <ID> -Round RD -Card <카드> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{MODEL_MID}} -Effort high` 를 호출한다.
@@endif
@@if codex-main
총괄이 `claude-run.ps1 -Task <ID> -Round RD -Card <카드> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{CLAUDE_MID}} -Effort high` 를 호출한다.
@@endif
@@if codex-solo
총괄이 `codex-run.ps1 -Task <ID> -Round RD -Card <카드> -Out {{DOCS}}/reports/review/<ID>-design.md -Model {{MODEL_MID}} -Effort high` 를 호출한다.
@@endif
@@if claude-main codex-main codex-solo
래퍼가 읽기 전용 새 세션, 변경분 파일 첨부, 검수 지시 첨부, 판정 기록까지 한다. 요약의 `design=` 줄이 판정이다.
@@endif
@@if claude-solo
총괄이 `design.ps1 brief -Task <ID> -Card <카드> -For review` 출력과 `diff.ps1 -Task <ID>` 가 낸 변경분 경로를 tandem-critic 에게 주고, 결과를 {{DOCS}}/reports/review/<ID>-design.md 에 쓰게 한다. 그다음 `design.ps1 check -Task <ID> -Review <그 경로>` 를 실행한다. 출력 첫 줄의 `design=` 이 판정이다. runs.jsonl 에는 round 를 RD 로 적는다.
@@endif
- 검수자는 `better-interface` 의 절차와 `interface-review` 의 분류(introduced, regression, pre-existing)를 따른다. 지적은 delegation.md 의 판정 줄 형식에 `영역=` 과 `상태=` 를 더해 쓰고, 마지막 줄에 `VERDICT: approve` 또는 `VERDICT: block` 을 쓴다.
- 일반 R2 의 "지적 최소 3개" 는 디자인 검수에 적용하지 않는다. 지적이 없으면 없는 것이 맞는 결과다. 취향 차이는 지적이 아니다.
- 최고 심각도 조건은 화면이 사소해도 [높음] 이다. confirmed [높음] 중 이번 변경이 만들었거나 악화시킨 것이 하나라도 있으면 block 이다.
- 렌더를 봐야 판단되는데 증거가 없으면 needs_validation 이다. 총괄이 렌더를 확인해 confirmed 또는 rejected 로 판정한다.
- block 이면 R3 로 고친 뒤 RD 를 다시 받는 것이 기본이다. 지적이 한두 건이고 총괄이 고친 결과를 직접 확인했으면 `design.ps1 pass -Task <ID> -Reason "<확인한 내용>"` 으로 통과를 기록할 수 있다. 사용자가 G2 에서 지적을 감수하기로 하면 `-By human` 을 붙인다. 만든 일꾼의 "고쳤다" 는 말만으로 통과시키지 않는다.
- 디자인 과제 카드는 판정이 approve 가 아니면 `board.ps1 move -To done` 이 거부된다. `design.ps1 status -Task <ID>` 로 현재 상태를 본다.

## 명령
`powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/design.ps1 <명령> ...`

| 명령 | 하는 일 |
|---|---|
| `status -Task <ID> [-Card <카드>]` | 디자인 과제인지, 검수 판정이 무엇인지. 줄 없는 카드는 바뀐 화면 파일을 찾아 `design=unmarked` 로 알린다 |
| `brief -Task <ID> -Card <카드> [-For build\|review]` | 일꾼 또는 검수자에게 줄 지시문 |
| `check -Task <ID> -Review <검수 파일>` | 검수 파일의 형식과 판정을 확인하고 {{DOCS}}/log/design.jsonl 에 기록 |
| `pass -Task <ID> -Reason "<한 줄>" [-By <이름>]` | 총괄이 직접 확인했거나 사용자가 결정한 통과를 기록 |

## 설정
tandem/config.json 의 `design`: `enabled`(false 면 지시·알림·관문을 모두 끈다), `platform`(이 프로젝트의 기본 플랫폼, 적응 단계에서 채운다), `gate`(false 면 보드의 완료 관문만 끈다).
