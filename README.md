# NGR Neo — Liquid Garage OS

Rebuild awal NGR pakai Flutter + Dart. Fokus versi ini: UI liquid glass, daily KM, streak, fuel, money, service priority, assist, dan route planner manual tanpa GPS live.

## Cara build APK di GitHub
1. Upload semua isi folder ini ke repo GitHub baru/lama.
2. Buka **Actions** → **Build NGR Neo APK** → **Run workflow**.
3. Download artifact `ngr-neo-debug-apk`.

Workflow akan menjalankan `flutter create . --platforms=android` otomatis kalau folder Android belum ada.

## Catatan
- Ini v0.1 core UI Flutter dulu supaya feel premium rapi.
- Map asli MapLibre/MapTiler bisa masuk phase berikutnya setelah core stabil.
- Data disimpan lokal pakai `shared_preferences` sebagai JSON. SQLite bisa masuk setelah struktur fitur fix.
