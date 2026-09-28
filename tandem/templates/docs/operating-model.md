# 운영 모델 — {{PROJECT}}

## 조직도

```
사람 (총괄 상위)                   결정, 방향
  │
Claude 총괄                        의도 파악, 최종 판정, 보고        [총괄 풀]
  │
Claude 팀장                        과제 분해, 카드, 검수, 종합       [Claude 풀]
  │
Claude 전달책                      codex exec 호출, 경로 반환, 로그   [Claude 풀, 극소]
  │
Codex 실무 리드                    팀 편성, 설계 판단, 종합           [Codex 풀]
  ├ 조사 일꾼
  ├ 설계 일꾼
  ├ 구현 일꾼
  └ 적대 검토 (별도 세션, 다른 모델)

Claude 교차 검수                   되돌리기 어려운 결정에만           [Claude 풀, 드물게]
```

요금제 의도: **실무 부하는 Codex 풀, 판단은 총괄 풀, 일반 Claude 풀은 팀장과 얇은 전달책만.**
Codex가 안에서 몇 명을 돌리든 Claude 호출 수는 늘지 않는다.

## 흐름

지시 → 의도 파악 → **G1** → 팀장 위임 → 과제 카드 → Codex 팀 실행 →
(R2 반박, R3 대응) → 팀장 검수와 종합 → 총괄 판정 → **G2** → 승인 → 기준 문서 반영

## 프로젝트 기준 문서

이 프로젝트에서 **총괄만 수정하는** 문서 목록이다. 적응 단계에서 채운다.

| 문서 | 역할 |
|---|---|
| (적응 단계에서 기입) | |

기준 문서가 없는 프로젝트면 적응 단계에서 최소한으로 만들거나, 없는 채로 운영한다고 명시한다.

## 되돌리기 어려운 결정

`tandem-critic` 교차 검수를 붙이는 기준이다. 적응 단계에서 프로젝트에 맞게 채운다.

- (적응 단계에서 기입. 예: 기술 스택 선택, 데이터 구조 변경, 외부 공개, 되돌리기 비용이 큰 것)

## 문서

| 문서 | 내용 |
|---|---|
| `{{DOCS}}/harness-status.md` | **현재 하네스 상태. 세션 시작 시 먼저 읽는다** |
| `{{DOCS}}/lead-charter.md` | 총괄 전용 규칙 |
| `{{DOCS}}/model-routing.md` | **모델 배치와 승급 조건** |
| `{{DOCS}}/delegation.md` | 위임 방식, 비용 규칙, 함정 |
| `{{DOCS}}/log/README.md` | 실행 로그 형식과 집계 방법 |
| `CLAUDE.md` | Claude 측 공통 |
| `AGENTS.md` | Codex 측 공통 |

## 폴더

| 경로 | 용도 | 작성자 |
|---|---|---|
| `{{DOCS}}/tasks/` | 과제 카드 | 팀장 |
| `{{DOCS}}/briefings/` | 브리핑 | 총괄 |
| `{{DOCS}}/reports/work/` | 실무 산출물 | Codex 리드 |
| `{{DOCS}}/reports/work/parts/` | 일꾼 부분 산출물 | Codex 일꾼 |
| `{{DOCS}}/reports/critique/` | 적대 검토 | Codex (별도 세션) |
| `{{DOCS}}/reports/review/` | 교차 검수 | tandem-critic |
| `{{DOCS}}/log/runs.jsonl` | 실행 로그 (append-only) | 전달책 |
| `.codex-last/` | Codex 최종 메시지 임시 (gitignore) | 전달책 |

## 실행 (PowerShell)

```powershell
claude --append-system-prompt-file .\{{DOCS}}\lead-charter.md
```

세션이 뜨면 `/model`에서 총괄 모델을 선택한다.

## 한계

- Agent Teams 팀원은 전부 Claude다. Codex 팀원은 만들 수 없다. 그래서 꺼 둔다.
- `codex exec`로 띄운 하위 일꾼은 Codex 데스크톱 트리에 부모-자식으로 표시되지 않는다.
- Codex 버전에 따라 하위 일꾼 모델 지정이 막혀 있다. 적대 검토를 별도 세션으로 돌리는 이유다.
- Codex 쿼터가 새 병목이 된다.
- 최상위 모델은 계정에 따라 기본 비활성일 수 있다.
