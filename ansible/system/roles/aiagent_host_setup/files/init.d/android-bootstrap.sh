#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/temurin-21-jdk}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

cmdline_tools_version="${ANDROID_CMDLINE_TOOLS_VERSION:-15641748}"
cmdline_tools_sha1="${ANDROID_CMDLINE_TOOLS_SHA1:-63523a02a975a81102238566f2a16c057d52301e}"
cmdline_tools_url="${ANDROID_CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-${cmdline_tools_version}_latest.zip}"

mkdir -p "$ANDROID_HOME/cmdline-tools" "$GRADLE_USER_HOME"

if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
    echo "[init] Bootstrapping Android SDK command-line tools..."

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    curl -fsSLo "$tmp/commandlinetools.zip" "$cmdline_tools_url"
    printf '%s  %s\n' "$cmdline_tools_sha1" "$tmp/commandlinetools.zip" | sha1sum -c -

    unzip -q "$tmp/commandlinetools.zip" -d "$tmp"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    cp -a "$tmp/cmdline-tools/." "$ANDROID_HOME/cmdline-tools/latest/"

    echo "[init] Android SDK command-line tools ready."
else
    echo "[init] Android SDK command-line tools already present, skipping."
fi

yes | sdkmanager --licenses >/dev/null || true

sdk_packages=(
    "platform-tools"
    "platforms;android-36.1"
    "build-tools;36.1.0"
)

echo "[init] Ensuring Android SDK packages are installed..."
sdkmanager --install "${sdk_packages[@]}"
echo "[init] Android SDK packages ready."
