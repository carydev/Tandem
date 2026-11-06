# Platform mapping

The rules in `tandem/design/skills/` are written for the web (CSS, ARIA). On any other platform, carry them over with this document.
The principles and values (contrast, spacing ratios, touch targets, writing rules) stay as they are. Only the means of implementation and the units change.
The API names below are starting points. Check in the code and the official documentation that the version the project uses has the API before you use it. If it does not, find the means that serves the same purpose.

## How to carry a rule over
1. Read the principle in the skill's rule. Example: "an icon-only button needs an accessible name".
2. Use the platform's own means first. "Use the platform" from `better-interface` comes first here too. Do not rebuild a platform component or its default feedback because of a web rule.
3. Use a value from the project's design system (theme, tokens, shared components).
4. Only when neither exists, convert the skill's value to the platform's unit (px to dp/pt/logical pixels, rem to sp/Dynamic Type).

Web-only and not carried over: `text-wrap`, `@media (hover: hover)`, `overscroll-behavior`, `:focus-visible`, the viewport meta tag and OKLCH notation itself (compute a color in OKLCH if you like, but store it in the platform's color format).

## Escalation triggers
The conditions of `better-interface` in platform terms. Any one of them is [high].

| Condition | Android | iOS | Flutter |
|---|---|---|---|
| An interactive control has no accessible name | No `contentDescription` on an icon or image button (decoration: null or `importantForAccessibility="no"`) | No `accessibilityLabel` | No `Semantics(label:)` or `tooltip` |
| No visible focus indicator | Focus is not visible with a keyboard, D-pad or switch control | Focus is not visible with Full Keyboard Access or VoiceOver | No focus indication on a `FocusNode` |
| Reachable by touch but not by another input | A gesture-only action TalkBack or a keyboard cannot run (no alternative action) | A gesture VoiceOver cannot run (no custom action) | A `GestureDetector`-only action without semantics |
| Ignores the reduce-motion setting | Essential information lives only in motion with system animations removed | Ignores Reduce Motion (`accessibilityReduceMotion`) | Ignores `MediaQuery.disableAnimations` |
| Clipped or overlapping on a narrow screen or with large text | Clipped or overlapping at 320dp width or 200% font scale | Clipped on the smallest device or at the largest Dynamic Type size | Overflow at a narrow width or text scale 2.0 |
| Text or control contrast fails | Below 4.5:1 (3:1 for large text and boundaries), computed from the real color pair, in light and dark | Same | Same |
| State carried by color alone | Same | Same (including Differentiate Without Color) | Same |
| A destructive action with no confirmation, undo or distinct treatment | Same | Same | Same |
| Truncated content with no way to the full value | `maxLines` ellipsis with no expand or detail screen | `lineLimit` with no way to the rest | `TextOverflow.ellipsis` with no way to the rest |
| Content hidden past a scroll edge with no cue | Same | Same | Same |
| An error that names no way to recover | Same | Same | Same |
| A semantic color used against its meaning | The theme `error` color on a non-destructive action | The system destructive color on an ordinary action | `colorScheme.error` misused |
| A state change carried by motion alone | No color, icon or label left when animation is off | Same | Same |

## Android (Compose, View)
| Domain | Web rule | Carried over as |
|---|---|---|
| Accessibility | Name, role, state | Compose: `contentDescription`, `Modifier.semantics { role; stateDescription; heading() }`, `mergeDescendants`, `clearAndSetSemantics`. View: `android:contentDescription`, `android:labelFor`, `importantForAccessibility` |
| Accessibility | Live announcements (`role="status"`) | Compose `liveRegion`, View `accessibilityLiveRegion` |
| Accessibility | 44px touch target | 48dp. Compose `minimumInteractiveComponentSize()`, View `minWidth`/`minHeight` of 48dp |
| Accessibility | Reading order equals source order | Check that TalkBack order equals screen order. Where needed, `isTraversalGroup` and `traversalIndex` |
| Layout | Gap between groups at least twice the gap within one | Unchanged, in dp, with `Arrangement.spacedBy`. Use the project's spacing steps |
| Layout | Logical properties (`margin-inline-start`) | Use `start`/`end` only. Never `left`/`right` (RTL) |
| Layout | Responsive, 320px | Window size classes (compact, medium, expanded), 320dp width, rotation, the keyboard open (`imePadding`) and system bar areas (`WindowInsets`) |
| Layout | No fixed height on a text container | Give no fixed height to anything that holds text. `heightIn(min = …)` |
| Typography | Units and scaling | Text is in `sp`. Check at 200% font scale. Line height through `TextStyle.lineHeight` in `sp` or `em` |
| Typography | Scale and tracking | Use the steps of `MaterialTheme.typography`. Letter spacing in `em` |
| Typography | `tabular-nums` | `fontFeatureSettings = "tnum"` (changing numbers: timers, prices, numeric columns) |
| Typography | Wrapping | `LineBreak.Heading` for headings, `LineBreak.Paragraph` for body. Ellipsis with `maxLines` + `TextOverflow.Ellipsis` and a way to the full value |
| Color | Primitive and semantic tokens | Use the roles of `MaterialTheme.colorScheme` (`primary`/`onPrimary`, `surface`/`onSurface`, `error`). No `Color(0xFF…)` inside a component |
| Color | Measured contrast | Compute from the real pair (the on-color and its background), in light, dark and dynamic color |
| UI | Outer radius = inner radius + padding | Unchanged. `RoundedCornerShape`, from `MaterialTheme.shapes` where possible |
| UI | Press feedback | The platform default, the ripple, comes first. Where the design system uses a press scale, apply the `0.96` rule |
| UI | Named transition properties, easing | `animate*AsState`, `AnimatedVisibility`. Easing `CubicBezierEasing(0.2f, 0f, 0f, 1f)`; springs without bounce |
| UI | Shadows and borders | Tonal elevation and `Modifier.shadow`. Check that edges still read in dark mode |
| Writing | All of it | Unchanged. Strings in `strings.xml`, plurals for counts, format arguments in place of concatenated fragments |

## iOS (SwiftUI, UIKit)
| Domain | Carried over as |
|---|---|
| Accessibility | `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, `accessibilityAddTraits(.isButton / .isHeader)`; decoration gets `accessibilityHidden(true)`. Touch targets of 44×44pt |
| Accessibility | Announcements through accessibility notifications. Check that VoiceOver order equals screen order |
| Layout | `leading`/`trailing` only. Safe areas, the keyboard, the smallest device width, landscape |
| Typography | Text styles (`.body`, `.headline`) and Dynamic Type. `@ScaledMetric` in place of fixed sizes. Check at the largest accessibility size. Changing numbers get `.monospacedDigit()` |
| Color | Semantic colors (asset catalog light and dark pairs, system colors). Compute contrast from the real pair. Check Increase Contrast and Differentiate Without Color |
| UI | Reduce Motion through the `accessibilityReduceMotion` environment value. Springs without bounce. The platform's default transitions and haptics come first |
| Writing | Unchanged. String catalogs, plural rules, no concatenated fragments |

## Flutter
| Domain | Carried over as |
|---|---|
| Accessibility | `Semantics`, `MergeSemantics`, `ExcludeSemantics`, `IconButton.tooltip`. Touch targets of 48 logical pixels |
| Layout | `EdgeInsetsDirectional`, `AlignmentDirectional`. Check narrow widths and text scale 2.0 with `LayoutBuilder`/`MediaQuery`. `SafeArea` |
| Typography | `Theme.of(context).textTheme`. Changing numbers get `FontFeature.tabularFigures()`. Ellipsis only with a way to the full value |
| Color | The roles of `Theme.of(context).colorScheme`. No color constants inside a widget |
| UI | Respect `MediaQuery.disableAnimations`. Easing `Cubic(0.2, 0, 0, 1)`. The platform default (ink effects) comes first |
| Writing | Unchanged. `intl` messages and plurals |

## Desktop and everything else
- The keyboard is the primary input. Every action works from the keyboard, the focus indicator is visible and tab order equals screen order.
- Expose name, role and state to the platform accessibility API (Windows UI Automation, macOS Accessibility).
- Check at the smallest window size and with the system text scale and high-contrast settings.
- For a terminal interface (TUI), apply only these: no state by color alone, the writing rules, and clipping at a narrow terminal width.

## Rendered evidence
The builder leaves screenshots under {{DOCS}}/reports/work/<ID>-shots/. Use the means the project already has first. Do not install a new tool because there is none. If nothing can be made, say why in the artifact.

| Platform | Means |
|---|---|
| Web | Screenshots from the project's browser tests (Playwright and the like), or the dev server URL with the widths to check |
| Android | Screenshot tests (Paparazzi, Roborazzi or whatever the project has), Compose previews (light and dark, font scale and screen size variants), `adb exec-out screencap -p` from a connected device or emulator. Accessibility warnings from `./gradlew lint` count as evidence too |
| iOS | Xcode previews, snapshot tests, `xcrun simctl io booted screenshot` |
| Flutter | Golden tests, `flutter screenshot` |

States to capture: default, empty, loading, error, the narrowest width, the largest text and dark mode. Capture only what the task touched.

## Carrying over the procedure skills
`break`, `state-machine` and `variant` assume a scratch route in a web app. On other platforms use a throwaway preview.

| Web | Android | iOS | Flutter |
|---|---|---|---|
| A scratch route page | A `@Preview` function in the debug source set, or a throwaway screen | A `#Preview` block | A throwaway widget and golden tests |
| The state switcher (`__state`) | One preview per state, or a `PreviewParameterProvider` | One preview per state | One golden per state |
| One pass over everything | A preview group or the screenshot test output | The preview canvas | The golden images |

Delete the throwaway preview when the task ends. The principle is the same: feed data in and leave the real component untouched.
