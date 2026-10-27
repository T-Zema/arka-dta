# Mapa: Fighting Spirit (StarCraft) w DTA

Mapa StarCrafta **(4)Fighting Spirit** (wersja iCCup 1.3) jako mapa skirmisha dla 2–4 graczy, zrobiona pipeline'em
[[workflow/scmap-pipeline]]. Stan: zainstalowana, zarchiwizowana, **niezweryfikowana w grze**. Kontrole pipeline'u: PASS.

Źródła: `C:\Program Files (x86)\StarCraft\Maps\ladder\Season 6\(4)Fighting Spirit.scx` (identyczna w 10 folderach sezonów;
`Season 11\(4)Fighting_Spirit_1.3.scx` to wariant o tej samej budowie z koreańską nazwą), tileset jungle, `review.png` w archiwum.

## Pliki

- `Maps/Custom/sc_fighting_spirit.map` (300 KB) + `sc_fighting_spirit.png`. Klient: Skirmish → **Custom Map** → „Fighting Spirit (StarCraft)”.
- Odinstalowanie: usunąć oba pliki. Archiwum: `archive/sc-fighting-spirit_2026-10-24/` (+ `.zip`, z `review.png` i `summary.json`).
- Regeneracja: `Modding\tools\port-scmap.ps1 -Map "Fighting Spirit"`.

## Co wyszło

- 4 bazy w rogach na płaskowyżach z rampami, naturale, 4 ukośne kanały wodne z klifami wodnymi po obu brzegach.
  W miejscach mostów SC są przejścia lądem (bruk).
- Środek: dwie kolumny murów `BRIK` (z murów w kształcie X) obok dwóch centralnych ekspansji (klejnoty + drzewa tyberium).
- Klejnoty: 108 pól minerałów → 396 komórek, wszystkie osiągalne. 14 gejzerów → `TIBTREE`.
- Kontrole: 4 starty połączone, 13 komórek „odciętych” (małe kieszenie przy wodzie), 65 „przecieków” (wąskie paski brzegu,
  w SC odcięte od reszty), 0 nieudanych łańcuchów.

## Czego Fighting Spirit nauczył konwerter

Woda w wąskich kanałach (udział niebieskich minikafli), mosty, mury X (szkielet), pętla naprawcza dekoracji, łańcuch bez
nakładania na siebie, poziomy płaskowyżów. Szczegóły: [[workflow/scmap-pipeline]], [[engine/connected-tiles]].
