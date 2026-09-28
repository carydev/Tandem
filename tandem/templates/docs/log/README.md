# 실행 로그

`runs.jsonl` — 한 줄에 한 번의 Codex 실행. **append만 한다. 기존 줄을 고치거나 지우지 않는다.**
JSONL을 쓰는 이유는 여러 주체가 동시에 덧붙여도 줄이 깨지지 않기 때문이다.

## 누가 쓰나

`tandem-dispatch`가 `codex exec` 호출을 마칠 때마다 한 줄을 덧붙인다. 성공이든 실패든 **반드시** 쓴다.

## 한 줄 형식

```json
{"ts":"2026-09-28T11:05:00+09:00","task":"T-12","round":"R1","model":"<모델ID>","effort":"high","result":"ok","escalated_from":null,"workers":3,"out":"{{DOCS}}/reports/work/T-12_v1.md","note":""}
```

| 필드 | 값 |
|---|---|
| `ts` | ISO 8601, 로컬 시간 |
| `task` | 과제 ID |
| `round` | `R1` / `R2` / `R3` / `single` |
| `model` | 실제 사용한 모델 ID |
| `effort` | 추론 강도 |
| `result` | `ok` / `fail` / `partial` |
| `escalated_from` | 승급했으면 이전 모델 ID, 아니면 `null` |
| `workers` | 리드가 띄운 하위 일꾼 수. 모르면 `null` |
| `out` | 산출물 경로. 실패면 `null` |
| `note` | 실패 사유나 특이사항. 없으면 빈 문자열 |

## 덧붙이기 (PowerShell)

```powershell
$line = '{"ts":"...","task":"T-12",...}'
Add-Content -Path .\{{DOCS}}\log\runs.jsonl -Value $line -Encoding UTF8
```

## 무엇에 쓰나

**모델 배치표를 감이 아니라 데이터로 고치기 위해서다.**

팀장이 과제 5건마다, 또는 지시가 있을 때 읽고 센다.

1. **승급률** — `escalated_from`이 `null`이 아닌 비율. 높으면 기본 모델이 너무 낮다.
2. **실패율** — 모델과 추론 강도 조합별 `fail` 비율. 특정 조합이 계속 실패하면 올린다.
3. **과잉 배치** — 상위 모델을 썼는데 한 번에 성공한 건. 한 단계 낮춰도 되는 신호다.
4. **호출 횟수** — 과제당 호출 수. 늘고 있으면 과제 카드가 부실한 것이다.

결과는 `{{DOCS}}/model-routing.md` 수정안으로 총괄에게 올린다.
**배치표는 총괄만 고친다.** 팀장은 제안까지다.

## 집계 예시

```powershell
# 승급 건만
Get-Content .\{{DOCS}}\log\runs.jsonl | ConvertFrom-Json | Where-Object { $_.escalated_from -ne $null }

# 모델별 실패 수
Get-Content .\{{DOCS}}\log\runs.jsonl | ConvertFrom-Json | Group-Object model | ForEach-Object {
  "{0}: {1}건 중 실패 {2}" -f $_.Name, $_.Count, ($_.Group | Where-Object result -eq 'fail').Count
}
```
