#!/bin/bash
cd /Users/kosherbaev/Desktop/project/lumos
flutter build macos 2>&1 || true
cd build/macos/Build/Products/Release/
ditto --noextattr --norsrc reportdeepen.app /tmp/reportdeepen.app
codesign --force --deep --sign - /tmp/reportdeepen.app
rm -rf reportdeepen_clean.app
cp -R /tmp/reportdeepen.app reportdeepen_clean.app
echo "✅ Готово! Запуск: open /tmp/reportdeepen.app"
open /tmp/reportdeepen.app
