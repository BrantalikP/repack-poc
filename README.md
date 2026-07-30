# expo repack POC

Ověřuje, že **Expo repack** (`@expo/repack-app`) lze trigrovat z **GitHub Actions** a podmínit ho
**fingerprintem** — když se native strana nezměnila, přeskočí se celý native build a prohodí se jen JS bundle.

Android only, plně lokální build na `ubuntu-latest`. Žádný EAS účet, žádné credity, žádné signing secrets
(repack si nese vlastní debug keystore).

## Výsledky

| | plný build | repack |
|---|---|---|
| trvání | 18 min 51 s | **33 s** |
| fingerprint | změněný | stejný |

Repackované APK bylo ověřené Maestrem na reálném Pixelu 7 — tedy nejen že se přebalení dokončilo,
ale že binárka běží a obsahuje nový JS.

## Jak to funguje

`.github/workflows/repack-poc.yml` je jen orchestrace, logika je v `scripts/`:

1. **fingerprint** — `npm run fingerprint` → hash native identity projektu
2. **cache lookup** — klíč `android-apk-<hash>`; hit znamená „existuje kompatibilní binárka"
3. **miss** → `scripts/build-native.sh` (`expo prebuild` + `gradlew assembleRelease`), APK do cache
4. **hit** → `scripts/repack.sh` (`@expo/repack-app`) → jen JS swap
5. **e2e** → `scripts/browserstack-maestro.sh` → Maestro suite na reálném zařízení

Scripty jdou spustit i lokálně, což je jediný rozumný způsob, jak na nich něco ladit:

```sh
export BROWSERSTACK_USERNAME=... BROWSERSTACK_ACCESS_KEY=...
scripts/browserstack-maestro.sh artifacts/repacked.apk
```

## Jak POC ověřit

```sh
npm run fingerprint          # hash se NESMÍ měnit při změně JS ani testů
```

1. **Plný build** — první push pro daný fingerprint, ~19 min, APK se uloží do cache.
2. **Repack** — změň `JS_MARKER` v `App.tsx`, push → stejný fingerprint → cache hit → jen repack.
   Maestro ověří marker na zařízení (ručně: `adb uninstall com.strv.repackpoc && adb install repacked.apk`).
3. **Návrat k buildu** — `npx expo install <native-dep>` → fingerprint se změní → plný build.
   Potvrzuje, že se repack nepoužije, když se native strana změní.

## BrowserStack + Maestro

Flows jsou v `.maestro/`. `smoke.yaml` a `relaunch.yaml` asertují **přesný** JS marker — workflow ho
před uploadem doplní z `App.tsx`, takže zelený build je sám důkazem, že se bundle prohodil. Stará
binárka by ukázala předchozí verzi a flow by spadl. `marker-format.yaml` je záměrně na verzi nezávislý.

Secrets (bez nich se e2e step přeskočí):

```
BROWSERSTACK_USERNAME
BROWSERSTACK_ACCESS_KEY
```

Projekt na BrowserStacku se nezakládá ručně — vytvoří ho pole `project` v build requestu.
Android appky BrowserStack defaultně resignuje vlastním certifikátem, takže debug podpis z repacku
nevadí. Pro `browserstack.resignApp: false` (např. API klíče vázané na SHA-1) předej repacku vlastní
keystore přes `--ks` / `--ks-pass` / `--ks-key-alias`.

## Gotchas

Čtyři věci, které nás v tomhle POC reálně kously. Všechny selhaly tiše nebo zavádějícím způsobem,
takže než něco z toho „zjednodušíš" zpátky, přečti si proč:

**Test-suite zip potřebuje rodičovskou složku.** S flows v rootu archivu BrowserStack spustil
**jeden** flow ze tří a build nahlásil jako `passed`. Proto `scripts/browserstack-maestro.sh` zipuje
`flows/` a proto na konci kontroluje, že počet spuštěných test cases odpovídá počtu flows.

**Bez `execute` běží jen flows v rootu rodičovské složky.** Cokoli v podsložkách se ignoruje.
Script proto posílá explicitní výčet.

**`actions/cache` neuloží nic, když job selže.** Ukládá v post-stepu, který se při failu přeskočí —
takže failnutý test zahodil devatenáctiminutový build. Proto je cache rozdělená na
`cache/restore` a explicitní `cache/save` hned po buildu.

**`ls a b | head -1` pod `pipefail`.** `ls` skončí nenulově, když jeden soubor chybí, a to zabije
celý step. Projevilo se to jen na full-build cestě, kde `repacked.apk` neexistuje, a v zsh se to
nereprodukuje — jen v bashi, který používá GitHub.

**`cache: gradle` u `setup-java` neprojde.** `android/` generuje až `expo prebuild`, takže v době
běhu toho stepu žádné gradle soubory neexistují a action skončí chybou.

## Známá omezení

- Repacked APK je podepsané jiným debug keystorem než původní → nejde nainstalovat *přes* originál.
- Repack není určený pro produkční store buildy (jen ad-hoc a development signing).
- Repack nikdy nepoužívej při změně native strany — JS by volal API, které v binárce nejsou.
