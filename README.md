# expo repack POC

Ověřuje, že **Expo repack** (`@expo/repack-app`) lze trigrovat z **GitHub Actions** a podmínit ho
**fingerprintem** — když se native strana nezměnila, přeskočí se celý native build a prohodí se jen JS bundle.

Android only, plně lokální build na `ubuntu-latest`. Žádný EAS účet, žádné credity, žádné signing secrets
(repack si nese vlastní debug keystore).

## Jak to funguje

`.github/workflows/repack-poc.yml`:

1. `npx @expo/fingerprint fingerprint:generate --platform android` → hash native identity projektu
2. `actions/cache` s klíčem `android-apk-<hash>` → cache hit = existuje kompatibilní APK
3. **miss** → `expo prebuild` + `gradlew assembleRelease` → APK se uloží do cache
4. **hit** → `npx @expo/repack-app --platform android --source-app artifacts/app.apk` → jen JS swap

## Jak POC ověřit

```sh
npm run fingerprint          # lokálně: hash se NESMÍ měnit při změně JS
```

1. **Run 1** — první push → cache miss → plný native build (~10–15 min), APK do cache.
2. **Run 2** — změň v `App.tsx` jen `JS_MARKER = 'v1'` → `'v2'`, push → **stejný fingerprint** →
   cache hit → jede pouze repack step. Stáhni `repacked.apk` a ověř, že app zobrazuje `v2`.
3. **Run 3** — `npx expo install expo-camera`, push → **fingerprint se změní** → cache miss → plný build.
   Potvrzuje, že se repack správně nepoužije, když se native strana změní.

Projdou-li 2 i 3, POC je hotový.

## Známá omezení

- Repacked APK je podepsané jiným debug keystorem než původní → nejde nainstalovat *přes* originál
  (`adb uninstall com.strv.repackpoc` a pak `adb install`).
- Repack není určený pro produkční store buildy.
