# 배치 작업

같은 규칙으로 항목 수십~수백 건을 모델에 넘길 때 `tandem/tools/batch-run.ps1`을 사용한다.

1. 묶음당 세션 하나를 쓰고 고정 블록은 첫 턴에만 보낸 뒤 resume 한다.
2. 고정 블록을 먼저, 항목 내용을 뒤에 둔다.
3. 회차 전체 대신 해당 항목에 필요한 문맥만 넣는다.
4. `-OnlyChanged`로 바뀐 항목만 재처리한다.
5. 항목 실패가 연속 3건이면 중단한다.
6. 모델, 강도, 캐시 토큰을 기록한다.

| 실측 | 캐시 결과 |
| --- | --- |
| 46k 토큰 고정 블록을 새 세션마다 반복 | 캐시율 2.5% |
| 같은 세션을 resume | 후속 입력의 99% 캐시 |
| 다른 폴더에서 새 세션 | 해당 실측에서 캐시 0 |
| `--ephemeral` | resume 불가 |

Codex `turn.completed.usage`는 **스레드 누계**다. 항목별 사용량은 이전 누계를 빼서 구한다.

```powershell
./tandem/tools/batch-run.ps1 -Name pages -Fixed rules.txt -Items pages.jsonl -Out batch-results -ItemsPerSession 30 -OnlyChanged
```

JSONL 항목에는 `id`, `text`, 선택적인 `images`(최대 12)를 넣는다. `usage.jsonl` 필드:

| 필드 | 의미 |
| --- | --- |
| `ts`, `id`, `thread` | 시각, 항목, 세션 |
| `resumed` | resume 사용 여부 |
| `tokens.input`, `tokens.cached`, `tokens.output` | 항목별 증분 |
| `thread_total` | 마지막 스레드 누계 |
| `images`, `result`, `note` | 이미지 수, 결과, 상세 |

자체 루프(Python 등)가 있는 프로젝트는 어댑터에 같은 규칙을 적용한다: resume 사용, `--ephemeral` 금지, `-C` 고정, 호출별 지시문은 고정 블록 뒤에 둔다.
