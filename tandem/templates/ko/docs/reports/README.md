# 산출물 폴더

| 폴더 | 내용 |
|---|---|
| work/ | 실무 산출물 |
| work/parts/ | 하위 일꾼 부분 산출물 |
| critique/ | 별도 R2 반론 |
| review/ | 조건부 교차 검수 |
| setup/ | 설치·적응 보고서 |

@@if claude-main
Codex 리드가 work/를 작성한다. Claude 팀장은 요약부터 검수하고 총괄에 종합만 올린다.
@@endif
@@if codex-main
Claude 하위 일꾼이 work/를 작성한다. Codex 총괄은 요약부터 검수한다.
@@endif
@@if claude-solo
Claude worker가 work/를 작성한다. Claude 총괄은 요약부터 검수한다.
@@endif
@@if codex-solo
Codex 하위 일꾼이 work/를 작성한다. Codex 총괄은 요약부터 검수한다.
@@endif

산출물에는 과제 ID, 작성 역할과 모델, 라운드, 결론, 근거와 출처, 미해결 쟁점, 검증 결과를 적는다.
맨 앞 요약은 5줄 이내다. R2 는 지적을 `- F1 [confirmed|needs_validation|rejected]` 판정 줄로 쓴다. confirmed 는 근거와 심각도가 필수, needs_validation 은 심각도 없이 미확인 사실, rejected 는 기각 이유. confirmed + needs_validation 최소 3개. 형식은 delegation.md 「R2 판정과 R3 응답」.
