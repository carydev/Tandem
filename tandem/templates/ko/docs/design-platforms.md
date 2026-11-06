# 플랫폼 대응표

`tandem/design/skills/` 의 규칙은 웹(CSS, ARIA) 기준으로 쓰여 있다. 웹이 아닌 플랫폼에서는 이 문서로 옮겨 적용한다.
원칙과 수치(대비, 간격 비율, 터치 영역, 문구 규칙)는 그대로다. 바뀌는 것은 구현 수단과 단위뿐이다.
아래 API 이름은 출발점이다. 프로젝트가 쓰는 버전에 그 API 가 있는지 코드와 공식 문서로 확인하고 쓴다. 없으면 같은 목적의 수단을 찾는다.

## 옮기는 순서
1. 스킬의 규칙에서 원칙을 읽는다. 예: "아이콘만 있는 버튼에는 접근 가능한 이름이 있어야 한다".
2. 그 플랫폼의 기본 수단을 먼저 쓴다. `better-interface` 의 "Use the platform" 이 여기서도 첫 번째다. 플랫폼 기본 컴포넌트와 기본 피드백을 웹 규칙 때문에 다시 만들지 않는다.
3. 프로젝트의 디자인 시스템(테마, 토큰, 공용 컴포넌트)에 있는 값을 쓴다.
4. 그래도 없을 때만 스킬의 수치를 그 플랫폼 단위로 옮긴다(px → dp/pt/논리 픽셀, rem → sp/Dynamic Type).

웹 전용이라 옮기지 않는 것: `text-wrap`, `@media (hover: hover)`, `overscroll-behavior`, `:focus-visible`, viewport meta, OKLCH 표기 자체(색은 OKLCH 로 계산해도 저장은 플랫폼 색 형식으로).

## 최고 심각도 조건
`better-interface` 의 조건을 플랫폼 말로 바꾼 것이다. 하나라도 해당하면 [높음] 이다.

| 조건 | Android | iOS | Flutter |
|---|---|---|---|
| 조작 요소에 접근 가능한 이름이 없다 | 아이콘·이미지 버튼에 `contentDescription` 없음(장식은 null 또는 `importantForAccessibility="no"`) | `accessibilityLabel` 없음 | `Semantics(label:)` 또는 `tooltip` 없음 |
| 포커스 표시가 없다 | 키보드·D-pad·스위치 제어에서 포커스 표시가 안 보임 | 전체 키보드 접근·VoiceOver 포커스가 안 보임 | `FocusNode` 포커스 표시 없음 |
| 터치로는 되는데 다른 입력으로 안 된다 | TalkBack·키보드로 실행 못 하는 제스처 전용 동작(대체 동작 없음) | VoiceOver 로 실행 못 하는 제스처(사용자 정의 동작 없음) | 의미 없는 `GestureDetector` 전용 동작 |
| 동작 줄이기 설정을 무시한다 | 시스템 "애니메이션 삭제"에서도 필수 정보가 움직임에만 있음 | "동작 줄이기"(`accessibilityReduceMotion`) 무시 | `MediaQuery.disableAnimations` 무시 |
| 좁은 화면·큰 글자에서 잘리거나 겹친다 | 너비 320dp, 글꼴 배율 200% 에서 잘림·겹침 | 가장 작은 기기, 가장 큰 Dynamic Type 에서 잘림 | 좁은 너비, 텍스트 배율 2.0 에서 overflow |
| 글자·조작 요소 대비 미달 | 실제 색 쌍으로 계산해 4.5:1(큰 글자·경계 3:1) 미달. 라이트·다크 모두 | 같음 | 같음 |
| 색만으로 상태를 전달한다 | 같음 | 같음("색상 없이 구별" 설정 포함) | 같음 |
| 파괴적 동작에 확인·실행 취소·구분된 표현이 없다 | 같음 | 같음 | 같음 |
| 잘린 내용의 전체 값을 볼 방법이 없다 | `maxLines` 말줄임 뒤 펼침·상세 화면 없음 | `lineLimit` 뒤 방법 없음 | `TextOverflow.ellipsis` 뒤 방법 없음 |
| 스크롤 가장자리 뒤에 단서 없이 숨은 내용 | 같음 | 같음 | 같음 |
| 복구 방법이 없는 오류 문구 | 같음 | 같음 | 같음 |
| 의미에 어긋나게 쓴 의미색 | 테마의 `error` 색을 파괴적이지 않은 동작에 사용 | 시스템 파괴색을 일반 동작에 사용 | `colorScheme.error` 오용 |
| 움직임만으로 전달되는 상태 변화 | 애니메이션이 꺼지면 남는 색·아이콘·라벨이 없음 | 같음 | 같음 |

## Android (Compose, View)
| 영역 | 웹 규칙 | 옮긴 수단 |
|---|---|---|
| 접근성 | 이름, 역할, 상태 | Compose: `contentDescription`, `Modifier.semantics { role; stateDescription; heading() }`, `mergeDescendants`, `clearAndSetSemantics`. View: `android:contentDescription`, `android:labelFor`, `importantForAccessibility` |
| 접근성 | 실시간 알림(`role="status"`) | Compose `liveRegion`, View `accessibilityLiveRegion` |
| 접근성 | 터치 영역 44px | 48dp. Compose `minimumInteractiveComponentSize()`, View `minWidth`/`minHeight` 48dp |
| 접근성 | 읽기 순서 = 소스 순서 | TalkBack 순서가 화면 순서와 같은지 확인. 필요하면 `isTraversalGroup`, `traversalIndex` |
| 레이아웃 | 묶음 사이 간격은 묶음 안의 2배 이상 | 그대로. dp 단위, `Arrangement.spacedBy`. 프로젝트 간격 단계를 쓴다 |
| 레이아웃 | 논리 속성(`margin-inline-start`) | `start`/`end` 만 쓴다. `left`/`right` 금지(RTL) |
| 레이아웃 | 반응형, 320px | 창 크기 등급(compact, medium, expanded), 320dp 너비, 화면 회전, 키보드가 올라온 상태(`imePadding`), 시스템 바 영역(`WindowInsets`) |
| 레이아웃 | 글자 상자는 고정 높이 금지 | 글자가 든 요소에 고정 높이를 주지 않는다. `heightIn(min = …)` |
| 타이포 | 단위, 배율 | 글자는 `sp`. 글꼴 배율 200% 에서 확인. 줄 높이는 `TextStyle.lineHeight` 를 `sp` 또는 `em` 으로 |
| 타이포 | 위계, 자간 | `MaterialTheme.typography` 의 단계를 쓴다. 자간은 `em` |
| 타이포 | `tabular-nums` | `fontFeatureSettings = "tnum"` (바뀌는 숫자: 타이머, 가격, 표 숫자 열) |
| 타이포 | 줄바꿈 | 제목 `LineBreak.Heading`, 본문 `LineBreak.Paragraph`. 말줄임은 `maxLines` + `TextOverflow.Ellipsis` 와 전체 값 보는 길 |
| 색 | 원시 토큰과 의미 토큰 | `MaterialTheme.colorScheme` 역할(`primary`/`onPrimary`, `surface`/`onSurface`, `error`)을 쓴다. 컴포넌트 안에 `Color(0xFF…)` 를 직접 쓰지 않는다 |
| 색 | 대비 실측 | 실제 색 쌍(on 색과 바탕색)으로 계산한다. 라이트, 다크, 동적 색상 모두 |
| UI | 바깥 반경 = 안쪽 반경 + 여백 | 그대로. `RoundedCornerShape`, 가능하면 `MaterialTheme.shapes` |
| UI | 누름 피드백 | 플랫폼 기본인 리플이 먼저다. 디자인 시스템이 눌림 축소를 쓰면 `0.96` 규칙을 적용한다 |
| UI | 전환 속성 지정, 이징 | `animate*AsState`, `AnimatedVisibility`. 이징 `CubicBezierEasing(0.2f, 0f, 0f, 1f)`, 스프링은 튀지 않게 |
| UI | 그림자, 테두리 | 고도(tonal elevation)와 `Modifier.shadow`. 다크 모드에서 경계가 보이는지 확인 |
| 문구 | 전부 | 그대로. 문자열은 `strings.xml`, 복수형은 plurals, 조각을 이어 붙이지 않고 형식 인자를 쓴다 |

## iOS (SwiftUI, UIKit)
| 영역 | 옮긴 수단 |
|---|---|
| 접근성 | `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, `accessibilityAddTraits(.isButton / .isHeader)`, 장식은 `accessibilityHidden(true)`. 터치 영역 44×44pt |
| 접근성 | 알림은 접근성 알림(announcement)으로. VoiceOver 순서가 화면 순서와 같은지 확인 |
| 레이아웃 | `leading`/`trailing` 만 사용. 안전 영역, 키보드, 가장 작은 기기 너비, 가로 방향 |
| 타이포 | 텍스트 스타일(`.body`, `.headline`)과 Dynamic Type. 고정 크기 대신 `@ScaledMetric`. 가장 큰 접근성 글자 크기에서 확인. 바뀌는 숫자는 `.monospacedDigit()` |
| 색 | 의미색(에셋 카탈로그의 라이트·다크 쌍, 시스템 색). 대비는 실제 색 쌍으로 계산. "대비 증가", "색상 없이 구별" 설정 확인 |
| UI | 동작 줄이기는 `accessibilityReduceMotion` 환경값. 스프링은 튀지 않게. 플랫폼 기본 전환과 햅틱이 먼저다 |
| 문구 | 그대로. 문자열 카탈로그, 복수형 규칙, 조각 연결 금지 |

## Flutter
| 영역 | 옮긴 수단 |
|---|---|
| 접근성 | `Semantics`, `MergeSemantics`, `ExcludeSemantics`, `IconButton.tooltip`. 터치 영역 48 논리 픽셀 |
| 레이아웃 | `EdgeInsetsDirectional`, `AlignmentDirectional`. `LayoutBuilder`/`MediaQuery` 로 좁은 너비와 텍스트 배율 2.0 확인. `SafeArea` |
| 타이포 | `Theme.of(context).textTheme`. 바뀌는 숫자는 `FontFeature.tabularFigures()`. 말줄임은 전체 값 보는 길과 함께 |
| 색 | `Theme.of(context).colorScheme` 역할. 위젯 안에 색 상수를 직접 쓰지 않는다 |
| UI | `MediaQuery.disableAnimations` 를 지킨다. 이징 `Cubic(0.2, 0, 0, 1)`. 플랫폼 기본(잉크 효과)이 먼저다 |
| 문구 | 그대로. `intl` 메시지와 복수형 |

## 데스크톱과 그 밖
- 키보드가 주 입력이다. 모든 조작이 키보드로 되고, 포커스 표시가 보이고, 탭 순서가 화면 순서와 같아야 한다.
- 플랫폼의 접근성 API(Windows UI Automation, macOS Accessibility)에 이름·역할·상태를 노출한다.
- 창 크기를 가장 작게 줄였을 때와 시스템 글자 배율·고대비 설정에서 확인한다.
- 터미널 화면(TUI)은 색만으로 상태를 전달하지 않기, 문구 규칙, 좁은 터미널 너비에서의 잘림만 적용한다.

## 렌더 증거
만든 쪽이 스크린샷을 {{DOCS}}/reports/work/<ID>-shots/ 에 남긴다. 프로젝트에 이미 있는 수단을 먼저 쓴다. 없다고 새 도구를 설치하지 않는다. 못 만들면 이유를 산출물에 적는다.

| 플랫폼 | 수단 |
|---|---|
| 웹 | 프로젝트의 브라우저 테스트(Playwright 등) 스크린샷, 또는 개발 서버 주소와 확인할 너비 목록 |
| Android | 스크린샷 테스트(Paparazzi, Roborazzi 등 프로젝트에 있는 것), Compose 미리보기(라이트·다크, 글꼴 배율, 화면 크기 변형), 연결된 기기·에뮬레이터의 `adb exec-out screencap -p`. `./gradlew lint` 의 접근성 경고도 증거다 |
| iOS | Xcode 미리보기, 스냅샷 테스트, `xcrun simctl io booted screenshot` |
| Flutter | 골든 테스트, `flutter screenshot` |

찍을 상태: 기본, 비어 있음, 로딩, 오류, 가장 좁은 너비, 가장 큰 글자, 다크 모드. 과제가 건드린 것만 찍는다.

## 절차 스킬 옮기기
`break`, `state-machine`, `variant` 는 웹앱의 임시 라우트를 전제로 한다. 다른 플랫폼에서는 임시 미리보기로 바꾼다.

| 웹 | Android | iOS | Flutter |
|---|---|---|---|
| 임시 라우트 페이지 | 디버그 소스의 `@Preview` 함수 또는 임시 화면 | `#Preview` 블록 | 임시 위젯과 골든 테스트 |
| 상태 전환기(`__state`) | 상태마다 미리보기 하나, 또는 `PreviewParameterProvider` | 상태마다 미리보기 하나 | 상태마다 골든 하나 |
| 한 번에 훑어보기 | 미리보기 묶음 또는 스크린샷 테스트 결과 | 미리보기 캔버스 | 골든 이미지 |

임시 미리보기는 과제가 끝나면 지운다. 실제 컴포넌트는 고치지 않고 데이터만 넣는다는 원칙은 같다.
