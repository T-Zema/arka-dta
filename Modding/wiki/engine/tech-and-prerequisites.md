# TechLevel, wymagania i właściciel: czy jednostkę da się zbudować

Jednostka pojawia się w pasku budowy tylko wtedy, gdy przejdzie wszystkie warunki opisane niżej. Ta strona pomaga zdiagnozować, czemu czegoś „nie ma”.

Źródła: `INI/Rules.ini` (`[General]` Prerequisite*, `[TNKD]`, `[AMCV]`, `[2TNK]`, `[BEHEMOTH]`), `Maps/Missions/FRSTBITE.MAP`.

## Warunki

1. **`TechLevel=`** jednostki ≤ `TechLevel=` domu gracza (w misji: sekcja domu w mapie, np. `[Allies] TechLevel=10`;
   w skirmishu: dropdown *Tech Level* 1–7). **`TechLevel=-1` = wyłączona całkowicie.** To najczęstszy powód „ukrytych” jednostek.
2. **`Owner=`** zawiera dom gracza (`GDI`, `Nod`, `Allies`, `Soviet`…). Żeby dać jednostkę innej frakcji,
   dopisz dom: `Owner=Soviet,Allies`. Nie usuwaj oryginalnego właściciela, bo AI z misji może go potrzebować.
3. **`Prerequisite=`** to lista z warunkiem **AND**: trzeba mieć wszystkie wymienione budynki.
   Grupy ogólne z `[General]`:
   - `POWER` = NUKE, RAPOWR, NUK2, RAAPWR (+ wersje `_AI`)
   - `BARRACKS` = PYLE, HAND, RATENT, RABARR
   - `FACTORY` = WEAP, AFLD, AWEAP, SWEAP
   - `RADAR` = HQ, NHQ, COMM, RADOME, SDOME, EYE
   - `TECH` = EYE, TMPL, RAATEK, RASTEK
   Vinifera ma też `[PrerequisiteGroups]` (np. `RATECH`, `CABHUT`, `SERVICE`, `NODFACTORY`).
4. **`BuildLimit=`**: limit sztuk.
5. **`Buildability=AIOnly`** (tylko AI) / `HumanOnly`. Wersje `AI*` jednostek (np. `AI3TNK`) to osobne typy AI,
   więc zmiana `[3TNK]` nie wpływa na produkcję AI w misjach.
6. **Ikonka (cameo).** Jednostka bez `Cameo=` w swojej sekcji Art.ini (lub w sekcji z `Image=`)
   nie powinna trafiać do paska budowy. Takie jednostki dajemy graczowi jako postawione na mapie
   (zob. [[engine/adding-new-types]]).

## Pułapki z praktyki

- **Wymaganie nie do spełnienia.** Np. `[AMCV] Prerequisite=AWEAP,RAATEK`, a w misji bez Construction Yardu
  Tech Centera nie da się postawić. Rozwiązanie: w mapie `Prerequisite=AWEAP`.
- **Autor misji celowo blokuje jednostkę** wymogiem budynku, którego nikt nie ma. Frostbite: `[2TNK] Prerequisite=AWEAP,RAFCOM`
  (RAFCOM to sowieckie Forward Command Center z `TechLevel=-1`).
- **Budynki innych frakcji** buduje się z własnego Construction Yardu, jeśli `Owner=` zawiera dom gracza.
  Trzeba sprawdzić, czy mapa ma teren (`[Map] Theater=`), dla którego budynek ma grafikę. Temperate jest bezpieczny.

## Zasięg budowania (`Adjacent`, `BaseNormal`)

Komentarz w nagłówku `Rules.ini`: `Adjacent` = odległość, w jakiej wolno postawić budynek od innych budynków (domyślnie 1),
`BaseNormal` = czy budynek liczy się przy sprawdzaniu sąsiedztwa (domyślnie `yes`). W DTA `Adjacent` ma wartości 1–4.
`BaseNormal=no` ma 200 sekcji Rules: mury i płoty (`SBAG`, `BRIK`, `CYCL`, `GGATE_*`), budynki z deployu (`DBFRT`, `DEP*`),
miny (`VMINE`), a także budynki cywilne (`V01…`, `CITY*`, `CA*`).
- `Adjacent=` należy do **stawianego** budynku: mówi, jak daleko od istniejącej „bazy” wolno go położyć (tak opisuje to ModEnc
  dla RA2, który dziedziczy kod TS).
- `BaseNormal=no` sprawia, że od budynku **nie** można budować dalej.
- **Kształt i liczenie (deasemblacja `Vinifera.dll`, 2026-10-26).** Vinifera zastępuje sprawdzanie `game.exe` (`0x4762E4`) własną
  funkcją `Passes_Proximity_Check(BuildingTypeClass*, HousesType, Cell&)`. Przeszukuje ona **kwadrat**: obrys stawianego budynku
  powiększony o `Adjacent+1` pól z każdej strony (z pominięciem samego obrysu). Wystarczy, że w kwadracie leży komórka budynku
  własnego domu z `BaseNormal=yes`; pod kluczem `BuildOffAlly` także sojusznika. Między budynkiem a kotwicą może więc
  być do `Adjacent` pustych pól, także po przekątnej. Zasięg zależy **wyłącznie od stawianego budynku**. Różny zasięg dla
  różnych kotwic (np. Pylon 6, Nexus 7) wymagałby łatki `Vinifera.dll`.
- Wzorzec „pylony” ([[mods/protoss-faction]]): bazą są tylko Nexus i Pylon (`BaseNormal=yes`, `Adjacent=8`), reszta ma
  `BaseNormal=no` i `Adjacent=6` (historia: 10/8 → 9/7 → 8/6, użytkownik dopasował zasięg do widocznej poświaty). Każdy
  nowy budynek musi więc stanąć do 6 pustych pól od Nexusa albo Pylona, a Pylony mogą „skakać” co 8. Zasięg od Pylonów działa w grze (test użytkownika).
- Deploy pojazdu w budynek (`DeploysInto`) nie sprawdza `Adjacent` ([[plans/zerg-faction]]).

## Ulepszenia budynków jako wymagania (badania)

Źródło: kod Vinifery `src/extensions/house/houseext.cpp` (`Has_Prerequisite`), `objecttypeext.cpp` (`Who_Can_Build_Me`), Rules `[COMM1]`/`[COMM]`.
- Ulepszenie (`PowersUpBuilding=<rodzic>`, `PowersUpToLevel=-1`, rodzic ma `Upgrades=N`) kupuje się w pasku i montuje na rodzicu,
  tak jak Ion Cannon Uplink na Comm Center GDI. **Liczy się jako spełnione wymaganie** dla jednostek
  (`Has_Prerequisite` skanuje `Upgrades[]` budynków). Rodzic musi być **zasilany** (`IsOn`).
- Grafika ulepszenia na rodzicu jest opcjonalna (`PowerUp1Anim=` w Art.ini rodzica). `RAASTRP` ma ulepszenie bez grafiki.
- **Wymagań negatywnych nie ma** („dostępne, dopóki NIE masz X”). Starej wersji jednostki nie da się więc ukryć po badaniu.
  Pasek ukrywa jednostkę tylko wtedy, gdy `Who_Can_Build_Me` nie znajdzie fabryki: `BuiltAt=` jednostki i `ExclusiveFactory=yes` budynku.
- Wzorzec: badanie `SCU238` (U-238 Shells na Academy) → `SCMARINE2 Prerequisite=FACTORY,SCU238`, zob. [[mods/starcraft-marine]].
- Ulepszenia buduje się z paska budynków, więc dom potrzebuje fabryki budynków z `[AI] BuildConst`. Frakcja bez conyardu (Zergi):
  budynki tech jako „laboratoria” `Factory=BuildingType` + wpis w `BuildConst`, zob. [[mods/zerg-research]]. Budynek ma tylko jedno `Factory=`,
  więc badania montowane na fabrykach (Pool, Lair) rosną w innym laboratorium. Budynek ma maksymalnie 3 sloty ulepszeń (`Upgrades[3]`).

## Szablon odblokowania (w mapie)

```ini
[TNKD]
TechLevel=3
Prerequisite=AWEAP
```
Dla jednostki obcej frakcji dodatkowo `Owner=<oryginał>,Allies`.
