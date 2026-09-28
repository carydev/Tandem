# 하네스 현황

> **이 파일 하나만 읽으면 현재 상태를 안다.** 하네스를 바꿀 때마다 갱신한다.
> 설치/적응 세션이 갱신한다. 일반 작업 세션은 읽기만 한다.

## 버전

| 항목 | 값 |
|---|---|
| 세트 | TANDEM |
| 버전 | {{VERSION}} |
| 설치일 | {{INSTALLED}} |
| 프로젝트 | {{PROJECT}} |
| 적응 완료 | 아니오 ← `/tandem` 실행 후 "예"로 바꾼다 |
| 적응 보고서 | `{{DOCS}}/reports/setup/tandem-adapt.md` |

## 구조

```
사람 → Claude 총괄 → Claude 팀장 → Claude 전달책 → Codex 실무팀
                                                  → Codex 적대 검토(별도 세션)
                     Claude 교차 검수 (조건부)
```

## 활성 역할

| 이름 | 모델 | 위치 | 역할 |
|---|---|---|---|
| (총괄) | {{CLAUDE_LEAD}} | `{{DOCS}}/lead-charter.md` | 판정, 보고 |
| `tandem-manager` | {{CLAUDE_MANAGER}} | `.claude/agents/` | 과제 분해, 검수, 종합 |
| `tandem-dispatch` | {{CLAUDE_DISPATCH}} | `.claude/agents/` | codex exec 호출, 로그 |
| `tandem-critic` | {{CLAUDE_CRITIC}} | `.claude/agents/` | 교차 검수 (조건부) |
| `work-lead` | (적응 시 확정) | `.codex/agents/` | Codex 실무 리드 |
| `researcher` | (적응 시 확정) | `.codex/agents/` | 조사 |
| `implementer` | (적응 시 확정) | `.codex/agents/` | 구현 |
| `reviewer` | (적응 시 확정) | `.codex/agents/` | 적대 검토 |

## 확정된 모델 배치

적응 세션이 실제 계정에서 확인한 값으로 채운다. 상세는 `{{DOCS}}/model-routing.md`.

| 층 | 모델 ID | 기본 추론 강도 |
|---|---|---|
| 최상위 (승급 전용) | | |
| 중상위 (리드 기본) | | |
| 경량 (일꾼 기본) | | |

최상위 모델 사용 가능 여부: (기입)

## 환경 확인 결과

| 항목 | 결과 |
|---|---|
| `claude --version` | |
| `codex --version` | |
| Codex 하위 일꾼 편성 | 가능 / 불가 |
| 하위 일꾼 모델 지정 | 가능 / 불가 |
| 역할 이름 호출 | 가능 / 불가 (불가면 TOML 주입) |
| Codex 웹 검색 | 가능 / 불가 |
| `AGENTS.md` 인식 | |
| 지원 추론 강도 | |
| Agent Teams | 꺼짐 |

## 변경 이력

| 날짜 | 버전 | 내용 | 커밋 |
|---|---|---|---|
| {{INSTALLED}} | {{VERSION}} | 설치 | |

## 되돌리기

git으로 관리된다. 설치 커밋을 되돌리면 이전 상태로 돌아간다.
기존 파일은 덮어쓰지 않고 `.new`로 저장되므로, 병합 전이면 원본이 그대로 있다.
