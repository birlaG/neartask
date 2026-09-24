#!/usr/bin/env bash
set -e

echo "── Backend setup ──────────────────────────"
cd neartask-backend
cp -n .env.example .env || true
npm install
cd ..

echo "── Flutter SDK install ────────────────────"
# Same method Flutter's own docs recommend for Linux — no unofficial images.
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
if ! grep -q 'flutter/bin' ~/.bashrc; then
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
fi
export PATH="$PATH:$HOME/flutter/bin"

flutter config --enable-web
flutter precache --web

echo "── App setup ───────────────────────────────"
cd neartask_app
flutter pub get
cd ..

echo "── Done. Open a new terminal so PATH picks up Flutter, then see SETUP.md ──"
