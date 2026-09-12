# iOS Liquid Glass

The shared glass widgets use `real_liquid_glass` 0.3.0 on actual iOS runtimes.
Its native platform view renders Apple's `UIGlassEffect` on iOS 26+, with the
system blur fallback on older iOS versions. This is distinct from the existing
Flutter `BackdropFilter` frosted-glass treatment.

## Coverage

- `GlassContainer` / `GlassCard`: native surface under Flutter content.
- `GlassButton` / `GlassIconButton`: native interactive material and tap callback.
- `BrandedScaffold`: native title badge and back control.
- `LiquidGlassNavBar`: native background and moving selection lens; existing
  labels, SVG icons, badges, tab state and drag handling are preserved.
- `GlassBackdrop`: native material for shared modal sheets and dialogs.
- Home, profile, wallet, chat headers/composer and other screens that reuse these
  components inherit the material without changing their business logic.

## App-wide surface migration (2026-09-09)

`GlassContainer.lite` / `GlassCard.lite` now also use native material on iOS.
The lite optimization is retained in the non-native fallback, not on iOS.

Legacy `Container`, `DecoratedBox`, rounded `Material` and `Ink` surfaces in
feature screens now go through `LiquidSurface`, `LiquidDecoratedBox`,
`LiquidMaterial` and `LiquidInk`. Rounded cards, header/title/logo pills,
message bubbles, selected options, form panels and local action containers
therefore no longer depend on whether the screen originally used GlassContainer.
Neutral light fills become untinted glass; colored actions retain a capped tint.
Full-screen backgrounds, undecorated layout boxes and photographs stay content,
not an extra glass layer. Selection/error outlines are preserved.

`LiquidActionButton` retains the actual Material filled/elevated/outlined/text
button (including icon variants) for focus, disabled state and callbacks.
`LiquidIconControl` adapts standalone icon buttons. `LiquidAppBar` covers the
remaining utility-screen headers with floating title pills. Standalone category,
FAQ and service searches and selection chips use native-backed form controls.
Shared text fields and custom field panels inherit the same glass surfaces.

Android delegates to the original widgets and decorations: no UIKit views or
new backdrop filters are created there. iOS list rows now contain more native
views, so real-device scrolling/frame-time checks remain a release requirement.

## Platform and accessibility

`usesNativeLiquidGlass` checks the runtime platform as well as the theme. Android
and web never instantiate UIKit views. High contrast uses opaque alternatives;
native iOS materials additionally follow the system's Reduce Transparency setting.
Bottom-navigation animations honor Flutter's disable-animations setting.
Decorative native surfaces ignore touches; interactive buttons use native tap
callbacks and retain Flutter accessibility semantics.

## Validation

Run `flutter test test/glass_platform_test.dart test/add_card_screen_test.dart
test/chat_design_test.dart test/request_answers_test.dart
test/master_service_pricing_test.dart` and an iOS simulator build with the existing
API defines. The UIKit widget test mocks platform channels: it verifies native
view selection, not native compositing or GPU performance.

Platform tests also cover legacy logo pills, lite surfaces, a Material action,
icon taps firing once, and Android icon-button size equivalence. Two existing
call-screen pixel goldens differ in this checkout even when that screen's
LiquidSurface migration is reverted; their reference images were not silently
regenerated. Functional call assertions continue to run.

Before release, validate real iPhones: tab taps/drags and badges, keyboard focus,
back navigation, button taps firing once, sheets, Reduce Transparency/Increase
Contrast, and scrolling/frame times. A simulator build is not real-device
performance evidence. No store release or Git push is implied by this change.

Reference: https://pub.dev/packages/real_liquid_glass
# iOS hit-testing tuzatishi

GlassButton va GlassIconButton’da app amali native view callbackiga berilmaydi.
GlassTapTarget butun yuzani Flutter `HitTestBehavior.opaque` bilan boshqaradi;
native glass va dekorativ ikonka/matn `IgnorePointer` ostida qoladi. Bir bosish
bitta callback beradi; disabled va scroll gesture holatlari saqlanadi.
Bosilgan holat yengil scale animatsiyasi bilan ko‘rsatiladi; material hanuz
native UIGlassEffect. Android tarmog‘i o‘zgarmagan.

GlassContainer va LiquidSurface native tarmog‘ida shaffof hit-test yuzasi bor:
oldingi decorated Container kabi padding/bo‘sh joy ham ancestor gesture’ga
yetadi. Test: `flutter test test/glass_hit_target_test.dart`.
