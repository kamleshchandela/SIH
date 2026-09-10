# 05 — APK packaged a stale native lib (verify bytes before every verdict)

## Symptom

EXIF fix verified in source (`cargo check` clean, NDK rebuilt, fresh
`jniLibs/arm64-v8a/libthemis.so` `13c9b054…`), fresh APK built, installed —
phone behavior byte-identical (28.6% again). The fix provably never shipped.

## Investigation (all dead ends kept, they cost an hour)

Hash the `.so` at every pipeline stage — source of truth is `sha256sum`,
never timestamps or "Build succeeded":

```bash
sha256sum themis_app/android/app/src/main/jniLibs/arm64-v8a/libthemis.so
for f in $(find themis_app/build -name "libthemis.so"); do
  echo "$(sha256sum $f | cut -c1-12) $f"
done
rm -rf /tmp/opencode/apkcheck && mkdir -p /tmp/opencode/apkcheck
unzip -o -q themis_app/build/app/outputs/flutter-apk/app-release.apk \
  lib/arm64-v8a/libthemis.so -d /tmp/opencode/apkcheck
sha256sum /tmp/opencode/apkcheck/lib/arm64-v8a/libthemis.so
```

Findings, in order: `merged_jni_libs` = new `13c9b054…`, `merged_native_libs` =
new, but `stripped_native_libs` and the APK = old `ae08cb26…` — through
`flutter clean`, through deleting `build/` **and** `android/.gradle`, with no
Gradle build-cache directory on disk. A manual NDK `llvm-strip` of the new
`.so` produced a *third* hash (`40a6364b…`), proving AGP's strip output could
not have come from the current input by any real stripping.

Resolution: copied the manually-stripped `.so` (`40a6364b…`) into `jniLibs`
(pre-stripped input makes the rogue strip step a byte-preserving no-op) —
APK then contained `40a6364b…` exactly, verified installed:

```bash
adb install -r themis_app/build/app/outputs/flutter-apk/app-release.apk
adb shell dumpsys package gov.doca.themis.themis_app | grep lastUpdateTime
```

Root mechanism of the phantom strip output was never fully identified
(leading theory: a stuck Gradle daemon reusing in-memory task outputs across
`flutter clean`, which only wipes `build/`). Standing rule, stated bluntly:
**no on-device verdict counts unless the APK's `.so` hash matches the intended
build.** The earlier "29% retest" that seemingly disproved the EXIF fix was
measured on the stale library and means nothing.

Note: `jniLibs/arm64-v8a/libthemis.so` currently holds the pre-stripped
variant by design (see above); the next NDK rebuild will overwrite it with an
unstripped one and this dance may repeat — re-verify hashes after every NDK
build, or stop the Gradle daemon (`./gradlew --stop`) before release builds.
