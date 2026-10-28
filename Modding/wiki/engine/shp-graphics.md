# Grafika SHP, palety i ikonki (cameo)

Jak zbudowane są grafiki jednostek DTA i jak przygotować własne (np. ze StarCrafta).

Źródła: `MIX/*.mix` (UNITTEM.PAL, CAMEO.PAL, 2TNK.SHP, RANG.SHP, E1.SHP, *ICON.SHP), kod Vinifera `src/extensions/unit/unitext_hooks.cpp` (`_UnitClass_Draw_Shape_IdleRate_Patch`, `Facing_To_Frame_Number`), narzędzia w `Modding/tools/`.

## Gdzie leżą pliki

- Wszystko jest w nieszyfrowanych MIX-ach TS w `MIX/`. Każdy ma `local mix database.dat` z nazwami plików. Silnik szuka MIX-ów po wzorcu: `EXPAND99/98`, `ECACHE05…00` itd.
  Własne assety pakujemy do własnych `MIX/ECACHE<nn>.MIX` (rejestr numerów niżej). **Nie 99:** skrypt aktualizatora DTA
  `preupdateexec` kasuje `MIX/ECache99.mix` przy każdej aktualizacji ([[workflow/repo-and-updates]]).
- Ścieżki wyszukiwania (log): `;SOUNDS;SPEECH;MUSIC;INI;MIX;MOVIES;MAPS`.
- ID pliku w MIX = CRC32 nazwy wielkimi literami z dopełnieniem do wielokrotności 4 (`Mix.Id` w `tools/ModTools.cs`).

## Palety

- Jednostki: `UNITTEM.PAL` (Temperate), `UNITDES.PAL`, `UNITSNO.PAL`, w `Cache.mix`. 256 × RGB, składowe 6-bitowe.
  - indeks 0 = przezroczystość, 1 = cień;
  - **16–31 = kolor gracza** (remap): w palecie gradient magenty F600F6 → 040004, od jasnego do ciemnego;
  - do własnych grafik bezpiecznie używać indeksów 32–254.
- Ikonki: `CAMEO.PAL` (Cache.mix). Strony mają osobne `SIDEBAR.PAL` w `SIDEC0x.MIX`.
- Animacje: `ANIM.PAL`. Z `AltPalette=yes` w Art.ini animacja używa palety jednostek.

## Pojazd SHP: układ klatek (Vinifera)

- Art.ini: `Voxel=no`, `Facings=32`, `StartStandFrame`, `StandingFrames`, `StartWalkFrame`, `WalkFrames`,
  `StartFiringFrame`, `FiringFrames`, `FiringSyncFrame0`, `PrimaryFireFLH`.
- Numer klatki: **kierunek-major**, `start + kierunek × liczba_klatek + faza`.
  - postój: `StartStandFrame + kierunek × StandingFrames`;
  - chód: `StartWalkFrame + kierunek × WalkFrames + (TotalFramesWalked % WalkFrames)`;
  - strzał: `StartFiringFrame + kierunek × FiringFrames + FiringSyncDelay/2`. `FiringSyncDelay` startuje od
    `2×FiringFrames−1` i **maleje**, więc faza leci od ostatniej do 0. Broń odpala, gdy delay = `FiringSyncFrame0`.
  - bezczynność (Vinifera, `IdleRate` > 0): `StartIdleFrame + kierunek × IdleFrames + (TotalFramesWalked % IdleFrames)`, gdy pojazd
    stoi; licznik rośnie co `IdleRate` ticków (`_FootClass_AI_IdleRate_Patch`). Kolejność: strzał, śmierć, chód, bezczynność, postój.
    Z łatką [[mods/sc-workers]] harvester gra ją tylko podczas zbierania (`IsHarvesting`). Wzorzec DTA: `[CTNK2T]`.
- **Kierunki: 0 = północ ekranu, dalej zgodnie z ruchem wskazówek zegara** (8 = E, 16 = S, 24 = W). Ustalone na
  wieżyczce `2TNK.SHP` (klatki 32–63).
- **Cienie: druga połowa pliku**, klatka cienia = klatka + liczba_klatek/2 (2TNK: 128 = 64 + 64 cienie). Piksele cienia mają indeks 1.
- Nagłówek SHP TS: `0, szer, wys, liczba`; nagłówek klatki ma 24 B (x, y, w, h, kompresja, …, offset). Kompresja 3 = RLE zer.
## Piechota SHP: sekwencje (użyte dla Zergów, [[mods/starcraft-zerg]])

- Art.ini: `Sequence=<Nazwa>` → sekcja `[<Nazwa>]` z kluczami `Ready, Guard, Prone, Walk, FireUp, Down, Crawl, Up,
  FireProne, Idle1, Idle2, Struggle, Die1…Die5` (tylko te występują we wszystkich 37 sekwencjach DTA; latająca piechota
  ma też `Fly, Hover, FireFly`). Wartość `start,klatki,krok`: klatka = `start + kierunek × krok + faza`.
  Krok 0 = animacja bez kierunku (śmierci).
- **8 kierunków w kolejności N, NW, W, SW, S, SE, E, NE** (przeciwnie do wskazówek zegara od góry ekranu), ustalone na
  klatkach strzału `E1.SHP` 64–127 (błysk lufy). Zupełnie inaczej niż u pojazdów.
- Cienie w drugiej połowie pliku, jak u pojazdów. Środek kadru SHP = pozycja jednostki.
- Art: `FireUp=` = faza sekwencji `FireUp`, w której pada strzał; `Crawls=no` dla piechoty, która się nie kładzie.
- Rules: **obowiązkowo `Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}` i `MovementZone=Infantry`** (bez nich piechota
  z opcji gry kręci się w miejscu, nie atakuje i „teleportuje się”, zob. [[mods/starcraft-zerg]]); `Fearless=yes` (nie kładzie się pod ostrzałem), `NotHuman=yes` (bez ludzkich animacji śmierci typu płonący żołnierz),
  `VoiceDie=` (dźwięk śmierci, jak u psa `DOG`). Piechotę trenuje każdy budynek z `Factory=InfantryType`, a słowo
  `BARRACKS` w `Prerequisite=` to lista `[General] PrerequisiteBarracks` (opcja STARCRAFT dopisuje tam `SCBARR`).

## Rejestr numerów ECACHE (żeby sesje nie nadpisywały sobie MIX-ów)

Gra wczytuje `MIX/ECACHE%02d.MIX` w pętli od 99 do 0 i pomija brakujące numery (`game.exe` `0x4E3F77`), więc wolne są też 06–79 (79 zajmuje [[mods/sc-building-sounds]]). **91–95 zajmuje klient** (kopiuje tam opcje z `Resources/`), 00–05 to gra.
**99 nie używać** (kasuje go aktualizacja DTA; do 2026-10-27 był tam Marine). Kolejność ładowania (99 → 0) to pierwszeństwo:
przy tej samej nazwie pliku w dwóch MIX-ach wygrywa wyższy numer, więc przy zmianie numeru sprawdzić kolizje identyfikatorów.
Zajęte przez mody: **77 Marine** (`tools/build-scmarine.ps1`, przeniesiony z 99), 98 budynki Terran, 97 jednostki Terran, 96 Uber Supply Depot, 90 okręty TEST (Fly),
89 latające budynki Terran, 88 dodatkowe dźwięki broni SC (sesja frakcji, `tools/build-scsfx.ps1`),
**87 badania SC + ulepszone jednostki** (sesja marine'a, `tools/build-scresearch.ps1`), **86 frakcja Zerg** (budynki, drony,
`tools/build-sczergbase.ps1`, zob. [[mods/zerg-faction]]), **85 frakcja Protoss** (`tools/build-scprotoss.ps1`,
zob. [[mods/protoss-faction]]), **84 badania Zergów** (`tools/build-sczergresearch.ps1`, zob. [[mods/zerg-research]]),
**83 badania Protossów** (`tools/build-scprotossresearch.ps1`), **80 Zergi** (piechota), **78 robotnicy SC z animacją wydobycia** (`tools/build-scworkers.ps1`, [[mods/sc-workers]]), **82 bohaterowie i budynki specjalne Zergów** (`tools/build-sczergheroes.ps1`, zarezerwowane 2026-10-25). **81 piechota SC ze stimpackiem** (`tools/build-scinfstim.ps1`, [[mods/sc-infantry-stim]], 2026-10-27). **76 armata 100 Ton Gun ARKA 0** (`tools/build-gun100t.ps1`: `RAPARTY` przeskalowana 2× na fundament 2×2, [[missions/arka-00-triggers]], 2026-10-27). Wolne: 06–75.
(2026-10-25: `build-scresearch.ps1` przez pomyłkę raz nadpisał 89. Zanim wybierzesz numer, przeczytaj ten rejestr.) Nowy mod: wybierz wolny numer poniżej 90 i dopisz go tutaj.

## Budynek SHP: układ i pozycja

Ustalone na `WEAP`, `RAPOWR`, `NUKE`, `GFACT`, `TDPROC` i `BIB43` z `Cache.mix` (sesja budynków Terran).

- Klatki: `normal, damaged[, trzecia]`, potem tyle samo cieni (`NUKE`/`WEAP`: 6, `GUN`: 4). Własne budynki: 4 klatki.
- Buildup (`Buildup=` w Art.ini, nazwa `<ID>MK`): dowolna liczba klatek + tyle samo cieni (`NUKEMK` 20+20, `GFACTMK` 32+32).
- **Pozycja: środek kanwy SHP = górny wierzchołek rombu fundamentu.** Fundament `WxH` (W w prawo-dół, H w lewo-dół) zajmuje
  od środka kanwy x od −H·24 do +W·24 i y od 0 do (W+H)·12. Środek rombu: ((W−H)·12, (W+H)·6). Kafel 48×24 (`clear01.tem`).
  `BIB43` (144×144) przy tej regule pokrywa się z siatką 4×3 co do piksela.
- **Skala:** budynki DTA są w skali klasycznego C&C (np. `RAPOWR` 2×2 ma ok. 40 px szerokości na rombie 96 px, `WEAP` 4×3 ok. 69 px).
  Grafiki SC (32 px/kafel) są większe, ale wypełniają romb fundamentu sensowniej. Marine też nie jest skalowany, więc budynki SC zostają 1:1.
- Wieżyczka budynku (`Turret=yes`, `TurretAnim=` w Rules, sekcja anim w Art.ini z `LoopEnd=32`, `Rate=0`, wpis w `[Animations]`):
  osobny SHP o tym samym kanwasie co budynek, 32 kierunki + 32 cienie (`GUN_A`, `SAM_A`: 64 klatki).
  **Kierunki wieży budynku idą przeciwnie do wskazówek zegara od N** (`ART_A`: klatka 4 = NW, 8 = W), odwrotnie niż wieża
  pojazdu. Pomyłka daje lustrzane działo (Siege Mode, [[mods/starcraft-terran-units]] patch 5).
  **Wysoka wieżyczka potrzebuje mocno ujemnego `TurretAnimZAdjust`** (Rules), inaczej bufor głębi ją ucina („lufa zanika”).
  `-30` (jak `GUN`) to za mało dla działa wystającego ~34 px nad romb; `-120` działa (potwierdzone w grze 2026-10-25, `OBLI`: `-100`).
- Animacje wystrzału broni (`Anim=` w broni): lista 1, 8 (`MINIGUN-N,…-NE,…-E`… zgodnie z zegarem) albo 32 (`FTNKFLM00–31`,
  `IOWA5M00–31`) wybierana wg kierunku. Rysowana na środku w `Fire_Coord` (środek + FLH); przy `FireFLH=0,0,0` przesunięcie
  lufy można wpisać w samą klatkę SHP.
- Budynki używają palety jednostek (`UNITTEM.PAL`), remap 16–31 jak u pojazdów. W Art.ini `NewTheater=no`, żeby nazwa pliku się nie zmieniała z teatrem.

## Pułapki potwierdzone testem (2026-10-24)

- **Art.ini `Image=` jest ignorowane dla jednostek** (UnitType). Ulepszony marine z `[SCMARIN2] Image=SCMARINE` był niewidoczny.
  Każdy typ potrzebuje SHP pod nazwą swojej sekcji Art (albo `Image=` w **Rules**, ale wtedy cameo też pochodzi z tej sekcji).
  Rozwiązanie: kopie plików (`SCMARIN2.SHP` = `SCMARINE.SHP`).
- **Nowe animacje muszą być w `Rules.ini [Animations]`.** Animacja dodana tylko w mapie lub opcji gry powstaje w
  `Rule->Addition()`, a to dzieje się **po** `Initializing Theater`, kiedy silnik wczytuje obrazy animacji. Taka animacja
  nie ma SHP i się nie pojawia (nie gra nawet `Report=`). Dotyczy też `TurretAnim`, `ActiveAnim` itd.
- Art.ini i Rules.ini mają kodowanie **Windows-1252**. Edytuj bajtowo albo przez Latin-1 (`GetEncoding(28591)`),
  nigdy przez zapis UTF-8 (zob. [[workflow/tooling]]).

## Ikonka (cameo)

- `<Cameo>.SHP`, **64×48**, 1 klatka, paleta `CAMEO.PAL` (np. `2TNKICON.SHP`, `RANGICON.SHP` w ECache05.mix).
- Vinifera ma też ścieżkę `%s.PCX` dla cameo (`CameoImageSurface`), ale nie jest jeszcze sprawdzona.
- Art.ini: `Cameo=` w sekcji grafiki. Ten sam SHP z innym cameo wymaga **kopii SHP** pod nową nazwą, bo `Image=` w Art.ini
  nie działa dla jednostek (zob. pułapki wyżej).

## Konwersja ze StarCrafta

Zob. [[engine/starcraft-assets]] i [[mods/starcraft-marine]].
