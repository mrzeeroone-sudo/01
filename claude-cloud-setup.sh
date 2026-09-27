#!/usr/bin/env bash
# =====================================================================
#  سكربت تهيئة بيئة Claude Code السحابية لهذا المشروع
#  الاستخدام:
#   1) الصقه كاملاً في حقل "Setup script" عند إنشاء البيئة السحابية
#      (Network access: Full — لأن Android SDK يُحمَّل من dl.google.com).
#   2) أو نفّذه يدوياً داخل الجلسة:  bash claude-cloud-setup.sh
#  يثبّت Flutter (stable) في ~/flutter وAndroid SDK في ~/android-sdk.
#  آمن لإعادة التشغيل: يتخطى ما هو مثبّت مسبقاً.
# =====================================================================
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
ANDROID_DIR="$HOME/android-sdk"
# إن تغيّر رابط أدوات سطر الأوامر مستقبلاً، حدّثه من:
# https://developer.android.com/studio#command-line-tools-only
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
ANDROID_PACKAGES=("platform-tools" "platforms;android-35" "build-tools;35.0.0")

echo "== Flutter =="
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version
flutter config --enable-web >/dev/null
flutter precache --android --web

echo "== Android SDK =="
if [ ! -d "$ANDROID_DIR/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_DIR/cmdline-tools"
  tmp="$(mktemp -d)"
  if curl -fsSL "$CMDLINE_TOOLS_URL" -o "$tmp/tools.zip"; then
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "$tmp/tools.zip" -d "$tmp"
    else
      python3 -m zipfile -e "$tmp/tools.zip" "$tmp"
      chmod +x "$tmp"/cmdline-tools/bin/* || true
    fi
    mv "$tmp/cmdline-tools" "$ANDROID_DIR/cmdline-tools/latest"
  else
    echo "!! تعذّر تحميل Android SDK (تحقق أن الشبكة Full). سيُبنى APK في GitHub Actions بدلاً من هنا."
  fi
  rm -rf "$tmp"
fi

if [ -d "$ANDROID_DIR/cmdline-tools/latest" ]; then
  export ANDROID_HOME="$ANDROID_DIR"
  SDKM="$ANDROID_DIR/cmdline-tools/latest/bin/sdkmanager"
  yes | "$SDKM" --licenses >/dev/null 2>&1 || true
  "$SDKM" --install "${ANDROID_PACKAGES[@]}" >/dev/null
  flutter config --android-sdk "$ANDROID_DIR" >/dev/null
  yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
fi

# تثبيت المسارات للجلسات اللاحقة
if ! grep -q 'home-needs flutter env' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo '# home-needs flutter env'
    echo 'export PATH="$HOME/flutter/bin:$PATH"'
    echo 'export ANDROID_HOME="$HOME/android-sdk"'
    echo 'export PATH="$ANDROID_HOME/platform-tools:$PATH"'
  } >> "$HOME/.bashrc"
fi

flutter doctor || true
echo "== setup done =="
