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
   cache hit → jede pouze repack step. Maestro flow ověří marker na reálném zařízení
   (nebo ručně: `adb uninstall com.strv.repackpoc && adb install repacked.apk`).
3. **Run 3** — `npx expo install expo-camera`, push → **fingerprint se změní** → cache miss → plný build.
   Potvrzuje, že se repack správně nepoužije, když se native strana změní.

Projdou-li 2 i 3, POC je hotový.

## BrowserStack + Maestro

`.maestro/smoke.yaml` asertuje **přesný** JS marker. Workflow ho před uploadem doplní z `App.tsx`,
takže zelený build je sám důkazem, že repack prohodil bundle — stará binárka by ukázala předchozí
verzi a flow by spadl.

Step se přeskočí, dokud nejsou nastavené secrets:

```
BROWSERSTACK_USERNAME
BROWSERSTACK_ACCESS_KEY
```

BrowserStack Android appky defaultně resignuje vlastním certifikátem, takže debug podpis z repacku
nevadí. Pokud bys potřeboval `browserstack.resignApp: false` (např. API klíče vázané na SHA-1),
předej repacku vlastní keystore přes `--ks` / `--ks-pass` / `--ks-key-alias`.

## Známá omezení

- Repacked APK je podepsané jiným debug keystorem než původní → nejde nainstalovat *přes* originál
  (`adb uninstall com.strv.repackpoc` a pak `adb install`).
- Repack není určený pro produkční store buildy.
