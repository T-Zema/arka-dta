# Mod: creep Zergów (żyły TS)

Creep Zergów zrobiony z żył TS: neutralny Veinhole Monster („organizm”) rozrasta wokół siebie żyły. Źródła to Creep Tumor stawiany przez drona oraz Hatchery, Lair, Hive, Creep, Sunken i Spore Colony. Wszystkie jednostki są odporne, więc creep nikomu nie szkodzi. Stan: **zainstalowany 2026-10-27; dziury powstają, a żyły rosną w grze (piąty test użytkownika), odporność budynków i dziury na terenie innym niż Clear niezweryfikowane w grze**.

Źródła: [[plans/zerg-creep]] (studium i decyzje użytkownika), [[engine/veins]] (mechanika i kod `game.exe`), `INI/Art.ini` (`[TIBSPRDR4]`, `[TBSPRD_R4]`, `[TBSHARDR4]`, `[SBAG]`), deasemblacja `game.exe` (`BuildingClass::Unlimbo`, `AnimClass::AI`, `OverlayClass::Mark`, `CellClass::Can_Tiberium_Germinate`).

## Jak działa

| Źródło | Mechanizm |
|---|---|
| **Creep Tumor** | Hatchery/Lair/Hive budują „Drone: Creep Tumor” (`SCZDTUM`, 200, obrazek drona Creep Colony). Deploy → budynek `SCZTUM` z `Wall=yes`; jego art ma `ToOverlay=VEINHOLE`. `BuildingClass::Unlimbo` zamienia mur w nakładkę i usuwa budynek, a nakładka 167 tworzy Veinhole Monstera. |
| **Hatchery, Lair, Hive** (`SCZHAT`, `SCZHTS`, `SCZLAI`, `SCZHIV`, 4×3) | Niewidzialna `ActiveAnim=SCZCRSPL` (wzorzec DTA `TBSPRD_R4`) z `ActiveAnimX=0`, `ActiveAnimY=36` (komórka (1,1) fundamentu) co `TrailerSeperation=60` zrzuca w miejscu odłamek `SCZCRSHL` (`Bouncer`, `MaxXYVel=1`, `TiberiumSpawnType=VEINHOLE`). Potwór powstaje **pod budynkiem**, całe 3×3 mieści się w fundamencie. |
| **Creep, Sunken, Spore Colony** (`SCZCRP`, `SCZSUN`, `SCZSPO`, 2×2) | To samo z `SCZCRSPS` → `SCZCRSHS`, `ActiveAnimY=12` (komórka (0,0)); dziura wystaje na górne boki, za obrazkiem budynku. |

- Wersja pierwsza (rano 2026-10-27) rzucała odłamki losowo (`MaxXYVel` 70/50), a `Can_Tiberium_Germinate` nie pozwala siać pod budynkiem. Efekt w grze: dziury w losowych miejscach obok budynków. Teraz łatka (miejsce 5, [[engine/veins]]) dla `VEINHOLE` bierze własną komórkę animacji i wymaga tylko braku nakładki.
- Potwory są rysowane przed budynkami (`VeinholeMonsterClass::Draw_All` przed `Render_Objects_On_Layers`), więc budynek zasłania dziurę, a żyły wychodzą spod niego. **(niezweryfikowane w grze)**
- Pozycja animacji: `Render_Coord` budynku (górny róg fundamentu) + `ActiveAnimX/Y` w pikselach; środek komórki (x,y) = X `24·(x−y)`, Y `12·(x+y+1)`. Zgadza się z DTA: `TIBSPRDR4` ma `-24, 24`, czyli komórkę (0,1), a błąd „północnego sąsiada” cofa ją na (0,0).
- `ActiveAnim` rusza dopiero po skończonym morfie (Buildup). `ActiveAnimPowered=no`.
- Gdy potwór już stoi w pobliżu, kolejne próby odpadają (odstęp ≥ 3 komórki). Po zniszczeniu dziury budynek po chwili stawia nową.
- Gdy pod budynkiem są już żyły (`Land=Weeds`, np. od Creep Tumora), test 3×3 nie przejdzie i budynek nie zrobi własnej dziury.
- Potwór jest **neutralny**, ma `Strength=10000` z `[VEINTREE]` i zostaje po zniszczeniu budynku. Jego zniszczenie kurczy i usuwa żyły.
- **Budowanie na creepie:** `[Weeds]` ma w DTA `Buildable=yes`, ale łatka DTA w `CellClass::Is_Clear_To_Build` (jaskinia `0x86C0F0`) odrzuca każdą komórkę z nakładką, chyba że nakładka ma `Insignificant=yes` (ObjectType `+0xCB`; tak DTA robi z `PAVLAT1`, `CORPSE`…). Blok creepu daje `Insignificant=yes` nakładkom `VEINS` i `VEINHOLEDUMMY` (pierwsza wersja tego nie miała, w grze nie dało się budować na żyłach). Środek dziury (`VEINHOLE`) dalej blokuje. **(niezweryfikowane w grze)**
- Harvestery nie zbierają żył.
- **Wzrost żył:** `VeinholeMonsterClass::Grow` nic nie robi, gdy scenariusz ma `[Basic] VeinGrowthEnabled=no`, a tak ma 357 map DTA (21 ma `yes`), w tym mapy SC (`sc_fighting_spirit`). Drugi test 2026-10-27: dziury stały, żyły nie rosły (przy Hatchery nic nie było widać, przy koloniach tylko wystające obrzeże dziury). Blok creepu ustawia `[Basic] VeinGrowthEnabled=yes` (klient dokleja plik do mapy, późniejszy klucz wygrywa) i `[General] VeinholeGrowthRate=60` (Rules.ini: 300 klatek; jeden krok dodaje 1–5 komórek żył). Trzeci test: dalej tylko obrzeże dziury, bo potwór utworzony w trakcie gry ma pustą kolejkę wzrostu; łatka `game.exe` (miejsce 6, [[engine/veins]]) przebudowuje kolejki po każdym nowym potworze. Czwarty test: dalej nic, bo kolejka startuje tylko od istniejących żył w polu 5×5. Miejsce 6 v2 najpierw kładzie żyły na pierścieniu 5×5 wokół dziury, tak jak generator map losowych. **(niezweryfikowane w grze)**
- **Budowanie a creep (prośba użytkownika 2026-10-27, łatka `tools/patch-zergbuild.ps1`, niezweryfikowane w grze):**
  - na creepie (nakładki `VEINS`/`VEINHOLEDUMMY`) można stawiać tylko budynki Zergów; pasek budowy i MCV innych frakcji dostają tam czerwone pola;
  - budynki Zergów wymagają creepu pod każdym polem fundamentu, poza Hatchery/Lair/Hive/Infested CC (`Factory=UnitType`, jak Hatchery w SC), Extractorem (`Refinery=yes`) i zakopanym Lurkerem (1×1, nie mur);
  - Creep Tumor też wymaga creepu (jak w SC2), więc pierwszy creep daje Hatchery;
  - „Zerg” to typ budynku `SCZ*` (wszystkie 26), a nie dom: `UnitClass::Try_To_Deploy` sprawdza `Legal_Placement(komórka, NULL)` bez domu (pierwsza wersja łatki patrzyła na dom `Nod1` i przy deployu drona nie działała);
  - jedna owijka `CellClass::Is_Clear_To_Build` obejmuje pasek budowy, deploy, `BuildingClass::Mark` i kolory kratek.
- **Kratki przy deployu:** gdy kursor pokazuje deploy (albo zakaz deployu), gra rysuje fundament budynku każdego zaznaczonego drona tam, gdzie postawi go deploy: zielone pola wolne, czerwone zajęte albo bez creepu. Działa też dla MCV i Lurkera. Ta sama łatka, druga jaskinia ([[engine/game-exe-patching]]). Test 2026-10-27: zakaz budowy obcych na creepie działa, kratek nie było. Wersja 1 rysowała tylko drona, którego komórka była pod myszą, a kursor stoi na obrazku jednostki, który jest wyżej niż jej komórka. Wersja 2 bez tego warunku. **(niezweryfikowane w grze)**
- **Zasięg 8 pól (prośba użytkownika 2026-10-27):** dziura rozrasta żyły tylko w kole o promieniu ok. 8 pól (dx² + dy² ≤ 72). Wcześniej rosły aż do `MaxVeinholeGrowth=2000` pól. Miejsce 9 `patch-veins.ps1` ([[engine/veins]]). **(niezweryfikowane w grze)**
- **Dziura ginie z budynkiem (prośba użytkownika 2026-10-27):** dziura pod budynkiem `SCZ*` dostaje znacznik. Gdy budynku już nie ma, umiera jak po zniszczeniu: animacja śmierci, potem żyły się kurczą. Dziury Creep Tumora zostają. Miejsce 10 `patch-veins.ps1`. **(niezweryfikowane w grze)**
- **Creep Colony to silos:** `[SCZCRP] Storage=100`, tak jak Supply Depot i Pylon (prośba użytkownika 2026-10-27).
- Wszystkie typy piechoty, pojazdów, samolotów **i budynków** dostają `ImmuneToVeins=yes` (1038 z 1129 typów go nie miało). Atak żył trafia każdy obiekt techno w komórce, także budynki. Piąty test 2026-10-27: creep rósł, ale niszczył budynki, bo odporność miały tylko jednostki.
- **Siódmy test 2026-10-27 (sonda pamięci `tools/veinprobe.ps1`):** odłamki Hatchery i kolonii lądowały co 60 klatek dokładnie w swojej komórce, ale dziury prawie nie powstawały, a przy jednej kolonii leżała nakładka `CORPSE` („zwłoki”). Przyczyna: Vinifera ma własne `AnimClass::AI` (`AnimClassExt::_AI`), więc łatki animacji w `game.exe` nie działały, a dziury z budynków wychodziły tylko z losowego trafienia 1 na 4, komórkę obok. Poprawka: `tools/patch-vinifera-veins.ps1` w `Vinifera.dll` ([[engine/veins]]). **(niezweryfikowane w grze)**
- Szósty test 2026-10-27: creep dalej niszczył pojazdy. To nie żyły, tylko gaz potwora (`GasCloudM1`/`GasCloud1`, ignoruje `ImmuneToVeins`), wyłączony miejscem 8 łatki. **(niezweryfikowane w grze)**
- Dziura w polu żył innej dziury nie ma czego rozrastać: komórki dookoła należą już do pierwszego potwora (mapa właścicieli `0x80FBF0`), więc creep jest wspólny.
- Piąty test 2026-10-27: **creep rośnie** (guzy na równinie, wielkie pola żył). Hatchery i kolonie na zielonej wyżynie nie robiły dziury: test potwora wymaga `Land=Clear` na 3×3. Miejsce 7 łatki przepuszcza też Road, Rough i Weeds. **(niezweryfikowane w grze)**

## Warunki postawienia dziury (test `0x661C10`)

- Pole 3×3 płaskie (`Ramp=0`), `Land=Clear` (nie droga, nie Tiberium, nie Rough), jedna wysokość.
- W odległości < 3 komórek (w obu osiach) nie ma innego potwora.
- Środek: komórka bez nakładki (dla spreaderów; łatka zastępuje `Can_Tiberium_Germinate`, więc budynek nie przeszkadza).
- Gdy test nie przejdzie, Creep Tumor znika bez efektu (dron przepada), a odłamek spreadera nic nie robi.

## Pliki

| Plik | Zmiana | Kopia |
|---|---|---|
| `game.exe` | łatka `tools/patch-veins.ps1` (w `patch-game.ps1`): bez warunku wysokości ≥ 1, bez wykopu terenu w konstruktorze potwora (`0x660D0B`, crash renderu 2026-10-27), bez losowego +0–3 dla nakładki 167, `OverlayData=0` dla środka dziury, `VEINHOLE` z animacji we własnej komórce i pod budynkiem (`0x41548D`), pierścień żył 5×5 i kolejka wzrostu dla nowego potwora (`0x58B71A` → `Place_Veins` + `Place_Monsters(false)`, źródło `tools/patch-veins-cave4.asm`), test potwora przepuszcza Clear/Road/Rough/Weeds (`0x661CD3`); jaskinie `0x86C380`, `0x86C3A0`, `0x86CE00`, `0x86CE60`–`0x86CEDB`, `0x86CEE0`–`0x86CEFB` | `game.exe.bak` |
| `game.exe` | łatka `tools/patch-zergbuild.ps1` (w `patch-game.ps1`): owijka `Is_Clear_To_Build` (hook `0x452250`, jaskinia `0x86CD00`, źródło `patch-zergbuild.asm`) i kratki deployu (wywołania `Draw_Placement` `0x611ADC`/`0x611B65`, jaskinia `0x86CA00`, źródło `patch-zergbuild-grid.asm`) | `game.exe.bak` |
| `Vinifera.dll` | łatka `tools/patch-vinifera-veins.ps1` (po `patch-vinifera-workers.ps1`, która tworzy sekcję `.scdock`): siew `VEINHOLE` z odłamka we własnej komórce, pod budynkiem, bez losowego +0–3, `OverlayData=0`; hooki `0x1003DDBA`, `0x1003DE13`, `0x1003DE5A`, jaskinie `.scdock+0x100`–`+0x198` (źródło `patch-vinifera-veins.asm`) | `Vinifera.dll.bak` |
| `INI/Map Code/Terran Faction.ini` | blok `; >>> Zerg creep` na końcu: `[Animations] ZCA01–04`, `[BuildingTypes] ZCB01=SCZTUM`, `[VehicleTypes] ZCV01=SCZDTUM`, typy, `ImmuneToVeins=yes` | `.bak` (starszy) |
| `INI/Art.ini` | blok `; >>> Zerg creep` (`[SCZTUM]`, 4 animacje) + linie `ActiveAnim=…`/`ActiveAnimPowered=no` z komentarzem „Zerg creep” w 7 sekcjach budynków bloku „Zerg faction” | `.bak` (starszy) |

Generator: `tools/build-sczergcreep.ps1` (idempotentny). **Uruchom go ponownie po `build-sczergbase.ps1 -Install`** (ten przepisuje sekcje art budynków i usuwa linie `ActiveAnim`) i po każdym generatorze, który dodaje typy jednostek (odporność). Po aktualizacji DTA: `tools/patch-game.ps1`.

## Do sprawdzenia w grze

1. Czy dron rozstawia się w Creep Tumor i czy powstaje dziura z żyłami (`Wall=yes` przez `DeploysInto`).
2. Czy po morfie Hatchery/kolonii dziura powstaje pod budynkiem (żyły wychodzą spod niego) i czy po zniszczeniu wraca. Test 2026-10-27 (wersja z losowymi odłamkami): dziury i żyły powstawały, ale w losowych miejscach obok budynków, a na żyłach nie dało się budować. Obie rzeczy poprawione tego samego dnia.
3. Wygląd dziury na płaskim terenie (bez wykopu) i nakładek `VEINHOLEDUMMY` przy krawędzi budynku. Pierwszy test 2026-10-27: crash `Cell_Render_Rect` zaraz po powstaniu potwora, naprawiony 6. miejscem łatki ([[engine/veins]]).
4. Czy drony stawiają budynki na żyłach i czy jednostki nie dostają obrażeń.
5. Tempo: `TrailerSeperation` (częstość prób) i `MaxXYVel` (zasięg) w Art.ini; `[General] VeinholeGrowthRate=300` (globalne).

## Ograniczenia

- Wygląd z TS (czerwonobrązowe żyły), nie fioletowy creep SC.
- Creep nie znika sam po śmierci budynku: dziurę trzeba zniszczyć (10000 HP, wspólne `[VEINTREE]`).
- Brak premii za creep (prędkość, budowanie tylko na creepie); zob. [[plans/zerg-creep]].

## Odinstalowanie

Usuń bloki `; >>> Zerg creep` z `Terran Faction.ini` i `Art.ini` oraz linie z komentarzem `Zerg creep` w sekcjach `SCZHAT`, `SCZHTS`, `SCZLAI`, `SCZHIV`, `SCZCRP`, `SCZSUN`, `SCZSPO` w Art.ini. Łatka: `tools/patch-veins.ps1 -Revert`.
