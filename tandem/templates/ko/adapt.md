# TANDEM 적응 지시서

설치가 배치한 파일을 이 프로젝트에 맞춘다. 사용자와 {{LANG_NAME}}로 대화하고 보고서도 {{LANG_NAME}}로 쓴다.
먼저 tandem/config.json의 mode, lang, docs_root, models를 읽고 git status로 기존 변경을 확인한다. 기존 변경은 보존한다. 커밋하지 않는다.

## 1. 프로젝트 파악
README, CLAUDE.md, AGENTS.md, .claude/, .codex/, 프로젝트 문서, 기존 과제 ID와 인수인계 방식을 확인한다.
기존 체계에 맞춰 문서 경로, 역할, 쓰기 범위, 기준 문서, 되돌리기 어려운 결정 목록을 채운다.
.new는 차이를 검토해 병합안을 보고한다. 확인하지 않은 사실은 '확인 불가'로 남긴다.

## 2. 환경과 모델
@@if claude-main claude-solo
claude --version과 Agent 역할 인식 및 모델 지정을 확인한다.
@@endif
@@if claude-main codex-main codex-solo
codex --version, codex exec --help, 실제 모델 ID, 추론 강도, 샌드박스, AGENTS.md 인식 여부를 확인한다.
@@endif
@@if codex-main
claude --version과 claude -p 지원 플래그, claude-run.ps1 호출을 확인한다.
@@endif
실제 사용 가능한 모델 ID를 tandem/config.json의 models에 기록하고, 배치된 파일 안의 미확정 표기를 같은 값으로 직접 바꾼다. 추측값을 넣지 않는다.
tandem/tools/manifest.ps1 -Rehash를 실행해 적용된 파일의 지문을 갱신한다. 업데이트 때 설치 스크립트가 config 값으로 렌더하므로 다음 버전에도 유지된다.
`claude_lead`를 기록하면 `claude_top`은 그 값, `claude_manager`는 바로 아래 단계가 기본이다(fable→opus, opus→sonnet). 사용자가 달리 정하면 config에 적는다.
Codex 전역 설정의 Fast/service_tier가 fast 또는 priority인지 확인해 보고한다. 전역 설정은 고치지 않는다.

## 3. 모드별 연결 확인
@@if claude-main
tandem-manager, tandem-dispatch, tandem-critic 인식과 codex-run.ps1 위임을 확인한다. R2는 mid 단계의 별도 읽기 전용 세션에서 실행한다(가능하면 다른 모델).
@@endif
@@if codex-main
Codex 총괄이 lead-charter.md와 AGENTS.md를 읽는지 확인한다. claude-run.ps1의 모델·플래그·산출물·로그를 확인한다.
@@endif
@@if claude-solo
tandem-worker-top/mid/light가 Agent 도구에 보이고 각 모델로 실행되는지 확인한다. tandem-worker-top은 승급 전용이다.
@@endif
@@if codex-solo
.codex/agents 역할 인식, 하위 모델 지정과 파일 산출물을 확인한다. 역할 이름 호출이 안 되면 TOML 지시를 주입한다.
@@endif
@@if codex-main codex-solo
프로젝트 .codex/ 신뢰 상태를 확인하고 Codex의 /hooks에서 SessionStart 명령을 승인한다.
@@endif
설정 JSON, Codex TOML, 파일 경로, 로그 append, 쓰기 범위를 확인한다.
사용자가 승인하기 전 G1/G2를 넘어가지 않는다.

## 4. Jev와 토큰
환경 변수 TANDEM_JEV_API_KEY 또는 OPENROUTER_API_KEY의 유무만 확인하고 키 값은 출력하거나 파일에 적지 않는다.
tandem/config.json에서 `jev.enabled`가 false면 Jev 점검을 모두 건너뛰고 jev.ps1을 호출하지 않는다. 배치표를 쓰며 사용자에게 Jev를 언급하지 않는다.
그 외에 키가 있을 때만 tandem/tools/jev.ps1 -Route -Card <안전한 시험 카드>를 스모크 테스트한다.
키가 없으면 배치표로 돌아가는지 확인한다. Jev는 최종 판정과 G1/G2를 대신하지 않는다.
tandem/tools/token-report.ps1 -Days 7 실행과 요약·상세 보고서 경로를 확인한다.
보고서의 캐시율과 1턴 세션 비율을 {{DOCS}}/harness-status.md에 적는다. 프로젝트에 자체 반복 항목 루프가 있으면 {{DOCS}}/batch.md 규칙 적용 여부를 '결정할 것'에 올린다.

## 5. 안전한 스모크 테스트
프로젝트 내용을 결정하지 않는 작은 카드로 하위 호출, 결과 파일, 5줄 요약, 실행 로그의 session/tokens/decided_by를 확인한다.
R2가 필요한 모드는 mid 단계의 별도 읽기 전용 세션을 확인한다. 반복 실패하면 멈추고 원문을 보고한다.

## 6. 마무리
{{DOCS}}/harness-status.md에 확인 결과, 활성 역할, 확정 모델과 미확인 사항을 채운다.
{{DOCS}}/reports/setup/tandem-adapt.md에 요약 5줄, 프로젝트 파악, 환경, 모델 배치, 검증, 스모크 테스트, .new 병합안, 결정할 것을 쓴다.
마지막 메시지는 요약과 보고서 경로를 5줄 이내로 전한다. 커밋하지 않는다.
