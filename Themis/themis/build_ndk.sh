#!/usr/bin/env bash
set -euo pipefail

# Build script for compiling embedded themis cdylib for Android targets using cargo-ndk
# Output libraries are placed directly in themis_app/android/app/src/main/jniLibs/<abi>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/../themis_app/android/app/src/main/jniLibs"

echo "=== Building Themis Native Library for Android NDK ==="

if ! command -v cargo-ndk &> /dev/null; then
    echo "[!] cargo-ndk is not installed."
    echo "    To install: cargo install cargo-ndk"
    echo "    Also ensure Android NDK is exported: export ANDROID_NDK_HOME=/path/to/ndk"
fi

mkdir -p "${TARGET_DIR}/arm64-v8a"
mkdir -p "${TARGET_DIR}/x86_64"

# If compiling on host without full NDK toolchain, copy local release build to x86_64 emulator folder
if [ -f "${SCRIPT_DIR}/target/release/libthemis.so" ]; then
    echo "[*] Copying local x86_64 build to jniLibs/x86_64/libthemis.so..."
    cp -v "${SCRIPT_DIR}/target/release/libthemis.so" "${TARGET_DIR}/x86_64/libthemis.so"
fi

echo "[*] To cross-compile for physical ARM64 Android devices:"
echo "    cargo ndk -t arm64-v8a -P 30 -o "${TARGET_DIR}" build --release --lib"
echo "=== Setup complete ==="
