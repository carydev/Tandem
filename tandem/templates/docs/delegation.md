# 위임 방식

실무는 Codex 팀이 한다. Claude는 지시, 검수, 보고만 한다.
모델 선택은 `{{DOCS}}/model-routing.md`를 따른다.

## 한 번의 위임이 어떻게 도는가

```
팀장
  │  과제 카드 작성: {{DOCS}}/tasks/<과제ID>.md
  │
  └→ tandem-dispatch             ← Claude 호출은 여기까지. 과제당 1회
       │  codex exec 1회
       │
       └→ Codex 실무 리드
            │  .codex/agents/ 의 역할을 읽어 팀을 편성
            ├─ 조사 일꾼 (경량)
            ├─ 설계 일꾼 (중상위)
            └─ 구현 일꾼 (경량)
            │  서로 메시지로 조율
            └→ {{DOCS}}/reports/work/<과제ID>_v1.md
  │
  └→ 팀장이 요약 읽고 검수 → 총괄이 보고
```

**Codex가 안에서 몇 명을 돌리든 Claude 호출 수는 그대로다.** 이것이 이 구조의 전부다.

## 비용 규칙 (반드시 지킨다)

1. **Codex 산출물 본문을 Claude 컨텍스트로 끌어오지 않는다.**
   Codex가 결과 파일을 직접 쓴다. 전달책은 짧은 완료 메시지만 확인하고
   **경로 + 성공 여부 + 5줄 요약**만 반환한다.
2. **긴 지시는 과제 카드 파일로 전달한다.** Codex에게는 경로만 알려 준다.
3. **팀장은 요약 섹션부터 읽는다.** 전문은 판단이 갈리는 절만.
4. **총괄은 팀장의 종합만 읽는다.** 원본 산출물을 직접 읽지 않는다.
5. 한 단계 낮은 모델로 시작한다. 승급은 실패 후에만.

## 3라운드 토론

과제 ID가 `T-12`일 때. ID 형식은 프로젝트 규칙을 따른다.

| 라운드 | 실행 | 모델 | 출력 |
|---|---|---|---|
| R1 제안 | `codex exec` 1회 (리드가 팀 편성) | 중상위 + high | `{{DOCS}}/reports/work/T-12_v1.md` |
| R2 반박 | `codex exec` **별도 세션** | R1과 다른 모델 + high | `{{DOCS}}/reports/critique/T-12_critique.md` |
| R3 대응 | `codex exec` (R1 이어받기 가능) | 중상위 + high | `{{DOCS}}/reports/work/T-12_v2.md` |

- R2는 **반드시 별도 세션**이다. R1을 이어받으면 자기 안을 변호한다. 모델도 `-m`으로 다르게 박는다.
- 3라운드 후에도 합의가 안 되면 강요하지 않는다. 쟁점으로 남겨 올린다.
- 작은 과제는 R1만 하고 끝낸다. 3라운드는 판단이 갈리는 과제에만.

## 호출 형태 (PowerShell)

정확한 플래그는 적응 단계에서 `codex exec --help`로 확인해 이 절을 갱신한다.
일반적으로 있는 것: `-m/--model`, `--sandbox read-only|workspace-write|danger-full-access`,
`--output-last-message <경로>`, `--full-auto`, `--profile <이름>`, `--search`, `--json`.

R1 제안:

```powershell
codex exec -m {{MODEL_MID}} --sandbox workspace-write `
  --output-last-message .\.codex-last\T-12_v1.txt `
  "{{DOCS}}/tasks/T-12.md 를 읽고 지시대로 수행해라. 필요하면 .codex/agents/ 의 역할 정의를 읽어 팀을 편성해라. 결과는 {{DOCS}}/reports/work/T-12_v1.md 에 써라. 그 파일 외에는 아무것도 수정하지 마라. 마지막 메시지는 5줄 이내 요약만."
```

R2 반박 (별도 세션, 다른 모델, 읽기 전용):

```powershell
codex exec -m {{MODEL_TOP}} --sandbox read-only `
  --output-last-message .\.codex-last\T-12_critique.txt `
  "{{DOCS}}/reports/work/T-12_v1.md 를 비판해라. 약점을 최소 3개, 각각 근거와 심각도(높음/중간/낮음)를 붙여라. 동의만 하는 답은 금지. 결과 전문을 최종 메시지로 내라."
```

읽기 전용이라 파일을 못 쓰므로, 전달책이 최종 메시지 파일을 `{{DOCS}}/reports/critique/` 아래로 옮긴다.

`.codex-last/`는 임시 폴더다. `.gitignore`에 들어간다.

## 알려진 함정

적응 단계에서 현재 버전에 해당하는지 확인하고 대응을 이 절에 기록한다.

| 함정 | 대응 |
|---|---|
| `.codex/agents/*.toml` 역할을 이름으로 직접 호출하지 못하는 버전이 있다 | 리드가 TOML을 읽어 `developer_instructions`를 프롬프트로 주입해 일반 일꾼을 띄운다 |
| 하위 일꾼에 모델/추론강도 지정이 막힌 버전이 있다 | 적대 검토를 **별도 세션 + `-m`**으로 분리한다 |
| 하위 일꾼이 결과를 반환하지 못하고 끝나는 사례가 있다 | 일꾼이 **파일에 쓰게** 한다. 반환 payload에 의존하지 않는다 |
| 동시 스레드가 한도를 넘으면 멈춘다 | `max_threads = 4`, `max_depth = 1` |
| 비대화형에서 승인 요청이 비활성 스레드에서 올라온다 | 상속된 샌드박스 안에서만 돌게 설계. `--yolo` 금지 |
| 자식 스레드 UI 모델 표시가 실제와 다를 수 있다 | 표시를 믿지 말고 실제 사용량으로 확인 |
| `codex exec`로 띄운 하위 일꾼이 Codex 데스크톱 트리에 부모-자식으로 안 보인다 | 동작에는 문제 없다. 보기 문제일 뿐 |

## 규칙 파일 두 벌

| 파일 | 읽는 쪽 |
|---|---|
| `CLAUDE.md` | 총괄, 팀장, 전달책, 교차 검수 |
| `AGENTS.md` | Codex 전원 |

Codex는 `CLAUDE.md`를 읽지 않는다. 공통 규칙은 한쪽에 쓰고 다른 쪽에서 참조한다.
같은 규칙을 두 벌로 관리하면 반드시 어긋난다.
