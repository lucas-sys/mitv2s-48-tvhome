# Android 5.1 (API 22) port notes

Upstream CleanYourTV's launcher targets `minSdk 26` (Android 8). This repository keeps the same
Java sources but makes them run on **Android 5.1 / API 22**. Everything below is the difference from
the upstream launcher directory; the rest is unchanged upstream code.

## Build changes

| Change | Why |
|---|---|
| `minSdk 22`, `targetSdk 34`, `compileSdk 34` | the TV is API 22; a recent target is still required by some firmware |
| `coreLibraryDesugaringEnabled true` + `com.android.tools:desugar_jdk_libs:2.1.4` | the code uses `java.time` and `java.util.function` (API 24+); without desugaring Android 5.1 throws `NoClassDefFoundError` |
| `minifyEnabled false`, `shrinkResources false` | on API 22 R8's lambda desugaring produced `NoClassDefFoundError: RemoteKeys$$ExternalSyntheticLambda2`; the APK is ~1.9 MB instead of ~550 KB |
| release signed with Gradle's debug key | sideload only; never published to a store |

## 48 `NewApi` lint errors fixed with real guards (not suppressions)

`./gradlew lintRelease` reports **0 `NewApi` errors** after the port (48 before). The categories:

- **API 23** — `Context#getSystemService(Class)` → the string service form; `Context#checkSelfPermission` →
  `PackageManager.checkPermission`; `Context#getColorStateList` → `Resources#getColorStateList`;
  `TextView#get/setCompoundDrawableTintList` → guarded, with `Drawable#setTintList` (API 21) as the fallback.
- **API 24** — `View#forceHasOverlappingRendering` → no-op below 24 (no public setter exists);
  `ConnectivityManager#registerDefaultNetworkCallback` → `registerNetworkCallback` with the same request;
  `Configuration#getLocales` → `Configuration.locale`; `TvInputInfo#isHidden/loadCustomLabel` →
  visible/false and the plain label;
  `UserManager#isUserUnlocked` → false (5.1 has no direct-boot user); `AccessibilityService#disableSelf` → guarded.
- **API 26** — `PackageManager#getChangedPackages` → package broadcasts still drive the refresh;
  `Bitmap.Config#HARDWARE` → the decoded bitmap; `Resources#getFont` → same-weight system family;
  `java.nio.file.Files.readAllLines` (API 26 and *not* covered by desugaring) → `BufferedReader`/`FileInputStream`.
- **Resources** — `android:drawableTint` moved to `values-v23/styles.xml`; the colour selector moved from
  `res/drawable` to `res/color` so the API 22 fallback can read it.

## Launcher behaviour added by this fork

- **Wallpaper chooser** (`WallpaperChooserActivity`): a 4-column thumbnail grid of
  `files/wallpapers/` plus "theme default (rotation)" and "none"; the choice is stored in the launcher
  settings and Home rebuilds with it. A `wallpaper_button` config switch puts it in the dock.
- **`settings_pill_native`**: the Settings pill opens the vendor settings app
  (`com.xiaomi.mitv.settings`) instead of AOSP Settings — China firmware keeps the network / ADB
  debugging switch only there.
- **HOME priority 999**: helps where firmware ranks its own launcher higher.
- **Focus fixes for slow API 22 firmware**: the glass highlight is repositioned after the dock row is
  parked, a startup safety net re-focuses the first tile only while nothing has focus (it must never
  pull focus off the top bar), and the wallpaper chooser's GridView holds the D-pad focus itself.

## Verification done on the device

- `lintRelease`: 0 errors, 0 `NewApi`; `testReleaseUnitTest` passes.
- APK `aapt2 dump badging`: `sdkVersion:'22'`, `targetSdkVersion:'34'`, v1+v2 signatures.
- Installed and used on a MiTV2S-48 (Android 5.1.1): cold boot into the launcher, Home key, app launch,
  Settings/Wi-Fi pills, wallpaper picker, rotation and restore all checked; `logcat -b crash` empty.
