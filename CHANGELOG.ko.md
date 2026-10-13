# 변경 기록

[English](CHANGELOG.md) | **한국어**

## v1.1 - 2026-10-13

### 추가

- `claude-main`, `codex-main`, `claude-solo`, `codex-solo` 네 모드와 설치 언어 선택 옵션 `-Lang ko|en`.
- `tandem/manifest.json` 지문 기반 업데이트와 새 버전·Jev 키 누락을 알리는 세션 시작 알림.
- Jev 선택 기능, `/tandem-tokens` 사용량 리포트·낭비 진단, 반복 폴링 없이 기다리고 실행 로그·토큰을 자동 기록하는 `codex-run`/`claude-run` 래퍼.
- 카파시 관찰에서 의역한 작업 규칙. 4번 목표 중심 실행은 실무자에게만 적용한다. 총괄에는 선택 언어 응답, 분기점 설명, 간결한 보고, 세션 연속성과 위임 규칙을 추가했다.

### 변경

- 모델을 지정하지 않은 Claude 하위 에이전트의 `CLAUDE_CODE_SUBAGENT_MODEL` 기본값을 `inherit`에서 `sonnet`으로 변경.
- 템플릿을 `tandem/templates/<lang>/`으로 옮기고 모델 ID의 기준을 `tandem/config.json`으로 통일.
- v1.1은 Windows만 지원. macOS/Linux 스크립트는 v1.0 상태로 남아 있으며 지원하지 않는다.

### 수정

- Windows PowerShell 5.1에서 `iwr | iex`를 실패하게 하던 `boot.ps1`의 BOM 제거.
- Codex 로그인 확인 중 stderr 메시지 때문에 PowerShell 5.1 설치가 중단되던 문제 수정.
- 태그 지정 설치의 404와 설치 결과 파일의 BOM 문제 수정.

### 보안 및 개인정보

- Jev 키는 사용자 환경변수에만 저장한다. Jev를 쓰면 과제 카드의 목표·제약·완료조건만 최대 6000자까지 OpenRouter/TypeSafe로 전송한다.
- `-JevKey`로 입력한 키는 명령 기록에 남을 수 있다. 대화형 입력을 권장한다.

### 업그레이드 안내

- v1.0 설치본에는 업데이트 알림 장치가 없으므로 같은 한 줄 설치를 다시 실행한다. v1.0 설정은 자동 승격된다.
- v1.0 때 설치한 파일에는 지문이 없어 업데이트가 `.new` 파일로 나올 수 있다. `/tandem`에서 병합한다.

### 알려진 제한

- 키가 없어 Jev 실제 호출은 검증하지 못했다. Codex·Claude 세션 시작 화면에서 알림이 표시되는지도 실제 세션에서는 확인하지 못했다.
- `codex login` 브라우저 흐름과 winget 설치는 미검증이다. 실제 프로젝트에서 네 모드 모두 `/tandem` 적응 전 과정을 실행해 보지 않았다.

## v1.0 - 2026-09-28

- 첫 공개: 한 줄 설치, Claude 지휘·Codex 실무, G1/G2 사용자 게이트, 과제 카드, 3라운드 토론, 실행 로그.
