# 작업 히스토리

주제(예: 로그인, 결제)마다 `<주제>.md` 하나에 작업 과정을 번호 붙여 쌓는다. `/clear` 뒤에도 그 주제의 최근 지점에서 이어 가기 위한 문서다.

| 파일 | 내용 |
|---|---|
| INDEX.md | 주제마다 한 줄 (최근 번호, 마지막 기록, 다음 할 일). 세션 시작·`/clear`·압축 직후 훅이 자동으로 넣는다 |
| <주제>.md | 맨 위 요약 카드(목표, 현재, 다음, 결정, 파일, 과제, 최근 실행) + 최근 기록 #n |
| archive/ | 오래된 기록. 주제 파일 기록이 20개를 넘으면 오래된 것부터 옮긴다(원본 그대로) |
| .state.json | 도구용 상태. 손으로 고치지 않는다 |

## 쓰는 법
- 기록: 중간·완료 보고 때마다 `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <주제> -Did <한 일> -Next <다음 할 일> -Decision <결정 또는 없음> [-Files a,b] [-Task T-12] [-Blocked <막힌 것>] [-Goal <목표>] [-By <이름>]`
  - `-Next`와 `-Decision`은 필수다. 요약 카드가 이 두 칸으로 만들어진다.
  - `-Task`로 과제를 묶으면 래퍼 실행 결과가 그 주제 카드의 "최근 실행"에 자동으로 붙는다.
  - 비슷한 이름의 주제가 있으면 기록하지 않고 알린다. 같은 주제면 그 이름을 쓰고, 새 주제면 `-New`를 붙인다.
- 이어가기: `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 show -Topic <주제>` 로 요약 카드와 최신 기록 2개만 읽는다. 기록 이후 바뀐 파일, 커밋 안 된 변경, 같은 파일을 만진 다른 주제를 `주의:` 줄로 알려 준다. 주의가 있으면 해당 파일을 확인한 뒤 이어 간다.
- 지난 내용: `history.ps1 search <단어>` (최대 10줄, 보관 포함) → `history.ps1 show -Topic <주제> -Entry <번호>`.
- 히스토리 파일 전체나 archive를 통째로 읽지 않는다.

## 비용 상한
이어가기 1회 = 목차(1500자 이하) + 요약 카드와 최신 기록 1~2개. 기록이 쌓여도 늘지 않는다. 30일 동안 기록이 없는 주제는 목차에서 "보관 주제"로 접히고, 다시 기록하면 펼쳐진다.
설정: `tandem/config.json` 의 `history` (inject, max_chars, max_entries, keep, active_days, active_max). `TANDEM_HOOK_OFF=1` 또는 `history.inject=false` 면 자동 주입을 끈다.
