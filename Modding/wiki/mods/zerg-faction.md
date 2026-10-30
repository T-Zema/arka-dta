# Mod: frakcja Zerg (pełna, budowa przez drony)

Szósta grywalna frakcja w skirmishu: „Zerg” (przejęty dom `Nod1`, strona 7) ze wszystkimi budynkami i jednostkami Zergów z Brood War. Nie ma Construction Yardu: każdy budynek to dron-pojazd z `DeploysInto=`, który po deployu znika, a budynek rośnie z kokonu SC tyle, ile trwa jego budowa w SC. Stan: **pełna wersja zainstalowana 2026-10-25, (niezweryfikowane w grze)**. Wcześniej w grze potwierdzone: morf przez deploy (test 1).

Źródła: [[plans/zerg-faction]], kod Vinifery (`Vinifera-develop/src`: `houseext_hooks.cpp`, `unitext_hooks.cpp`, `buildingext_hooks.cpp`
`Unlimbo_Naval_Helper`, `objecttypeext.cpp` `Who_Can_Build_Me`, `scenarioext.cpp` `Create_Units`, `rulesext.cpp` `PrerequisiteGroups`,
`prerequisitegroup_hooks.cpp`, `technotypeext.h` `Description[200]`), deasemblacja `game.exe` ([[engine/buildup-timing]]),
dane SC z CASC (`arr/units.dat`, `flingy.dat`, `sprites.dat`, `images.dat`/`images.tbl`, `scripts/iscript.bin`, `rez/stat_txt.tbl`,
`unit/zerg/*.grp`, `SD/sound/...`), `Resources/SkirmishLobby.ini` (`cmbGameSpeedCap`), logi `Debug/DEBUG_25-10-2026_05-09-04.LOG`.

## Jak się gra

1. Lobby skirmisha: strona **Zerg** (Deathmatch albo Custom Map). Checkbox STARCRAFT **nie jest potrzebny**, bo frakcja ma własne typy.
2. Start: „Drone: Hatchery” (`SCZDHTS`) → deploy → startowa Hatchery (`SCZHTS`, morf 1 s). Jednostki startowe Zergów to drony-robotnicy.
3. Hatchery, Lair i Hive produkują (zakładka pojazdów): robotnika, 16 typów „Drone: <budynek>”, Infested Terrana i latające Zergi.
   Gotowa jednostka pojawia się obok budynku (larwa), dron budowlany w ok. 1 s (54 ticki).
4. Dron jedzie na miejsce, **deploy** → kokon rośnie (Hatchery 75 s, Pool 50 s, Creep 13 s), potem budynek działa.
5. Piechotę szkolą Spawning Pool i Nydus Canal (wysunięte wyjście). Budynków Zergów nie da się sprzedać (jak w SC).

## Drzewko

```
Hatchery ─┬─ Extractor, Evolution Chamber ── (+Creep) Spore Colony
(ZHATCHERY)├─ Creep Colony
          └─ Spawning Pool ─┬─ Hydralisk Den ── (+Lair) Lurker
                            ├─ (+Creep) Sunken Colony
                            └─ Lair (ZLAIRUP) ─┬─ Spire (ZSPIREUP) ── (+Hive) Greater Spire
                                                └─ Queen's Nest ── Hive (ZHIVEUP) ─┬─ Ultralisk Cavern
                                                                                    ├─ Defiler Mound
                                                                                    └─ Nydus Canal
```
Grupy w `[PrerequisiteGroups]` bloku (Vinifera czyta je też z pliku doklejanego do mapy, przed typami): `ZHATCHERY` = Hatchery/start/Lair/Hive,
`ZLAIRUP` = Lair/Hive, `ZHIVEUP` = Hive, `ZSPIREUP` = Spire/Greater Spire. Lair i Hive to osobne budynki (Hatchery zostaje) i same są fabrykami larw.

## Typy

**Budynki** (`TechLevel=-1`, `Unsellable=yes`, `Owner=Nod1`; HP = SC × 8, koszt = (minerały + 2 × gaz) × 4; morf = czas SC × 37,8 ticka):

| ID | Budynek | GRP / cień | Fund. | Koszt | HP | Morf | Rola |
|---|---|---|---|---|---|---|---|
| SCZHAT / SCZHTS | Hatchery (/startowa) | hatchery / zhashad | 4x3 | 1200 | 10000 | 4536 / 60 | larwy (`Naval`, `ExclusiveFactory`), radar, `Power=50`, silos 40 |
| SCZLAI | Lair | lair / zlrshad | 4x3 | 1400 | 14400 | 3780 | jak Hatchery |
| SCZHIV | Hive | hive / zhishad | 4x3 | 2000 | 20000 | 4536 | jak Hatchery |
| SCZEXT | Extractor | extract / zreshad | 4x3 | 200 | 6000 | 1512 | rafineria, `Bib`, `FreeUnit=SCZWORK` |
| SCZPOL | Spawning Pool | chrysal / zchshad | 3x2 | 800 | 6000 | 3024 | `Factory=InfantryType` |
| SCZEVO | Evolution Chamber | cerebrat / zceshad | 3x2 | 300 | 6000 | 1512 | wymóg Spore |
| SCZHDN | Hydralisk Den | Snakey / zsbshad | 3x2 | 800 | 6800 | 1512 | Hydralisk, Lurker |
| SCZSPI | Spire | spire / zspshad | 2x2 | 2000 | 4800 | 4536 | Mutalisk, Scourge |
| SCZGSP | Greater Spire | MutaCham / zmcshad | 2x2 | 1600 | 8000 | 4536 | Guardian, Devourer |
| SCZNES | Queen's Nest | nest / zneshad | 3x2 | 1400 | 6800 | 2268 | Queen, Broodling, Infested Terran, Hive |
| SCZULC | Ultralisk Cavern | RCluster / zrcshad | 3x2 | 2200 | 4800 | 3024 | Ultralisk |
| SCZDFM | Defiler Mound | Mutapit / zmhshad | 4x2 | 1200 | 6800 | 2268 | Defiler |
| SCZNYD | Nydus Canal | NydusPit / znyshad | 2x2 | 600 | 2000 | 1512 | drugie wyjście piechoty (`Factory=InfantryType`) |
| SCZCRP | Creep Colony | fcolony / zfcshad | 2x2 | 300 | 3200 | 756 | `Sight=10`, wymóg kolonii |
| SCZSUN | Sunken Colony | Lurker / zlushad | 2x2 | 500 | 3000 heavy | 1512 | ziemia: 80 × ROF 42, zasięg 8 |
| SCZSPO | Spore Colony | SColony / zscshad | 2x2 | 500 | 3200 heavy | 1512 | powietrze: 38 × ROF 20, zasięg 8, `Sensors` |
| SCZICC | Infested Command Center | `terran/control` + nakładka `infest03` / `terran/tccshad` | 4x3 | 1600 | 12000 | 4536 | jedyna fabryka Infested Terrana (`BuiltAt=SCZICC`); dron wymaga Queen's Nest (w SC Queen infekuje CC) |

Jednostki Brood War bez odpowiednika: **Overseer to jednostka z SC2** (nie ma go w SC1 ani w CASC SC1). Larwa, jajo, kokon i jajo Lurkera
to stany przejściowe, które zastępuje kolejka fabryki.

**Drony** (pojazdy SHP z `drone.grp`, `Naval=yes`, `BuiltAt=SCZHAT,SCZHTS,SCZLAI,SCZHIV`): `SCZWORK` robotnik (zbieracz, `Dock=SCZEXT`, 400),
`SCZDHTS` start, `SCZD<xxx>` dla każdego budynku: koszt 200 + budynek, `BuildTimeMultiplier=0.03` (minimum 54 ticki).

**Piechota** (własne kopie z `Image=` piechoty z [[mods/starcraft-zerg]], grafika `ECACHE80`, bronie `SCZF*`):
Zergling `SCZLNG` (Pool, 100), Hydralisk `SCZHYL` (Den, 500, też powietrze), Lurker `SCZLRK` (Den + Lair, 1500), Ultralisk `SCZULT` (Cavern, 2400),
Defiler `SCZDFL` (Mound, 1400), Broodling `SCZBRD` (Nest, 75). **Infested Terran** `SCZINF` (pojazd z Hatchery, `Image=SCINFT`, Nest, `Suicide`).

**Latające** (pojazdy SHP z lokomotorem Fly jak okręty Terran, [[engine/fly-locomotor]], z Hatchery/Lair/Hive):

| ID | Jednostka | GRP, klatki lotu | Wymaga | HP | Broń | Koszt |
|---|---|---|---|---|---|---|
| SCZOVL | Overlord | overlord 0–3 | ZHATCHERY | 4000 heavy | brak, `Sensors`, `Sight=11` | 400 |
| SCZMUT | Mutalisk | mutalid 0–4 | ZSPIREUP | 2400 | Glave 23 × ROF 40, 4,5, ziemia + powietrze | 1200 |
| SCZSCG | Scourge | avenger 0–4 | ZSPIREUP | 500 | samobójczy 280, tylko powietrze | 350 |
| SCZGRD | Guardian | guardian 0–6 | SCZGSP | 3000 heavy | Acid Spore 50 × ROF 40, zasięg 9, ziemia | 2200 |
| SCZDEV | Devourer | devour 0–5 | SCZGSP | 5000 heavy | Corrosive 63 × ROF 133, 7, powietrze | 2200 |
| SCZQUN | Queen | queen 0–4 | SCZNES | 2400 | splunięcie 40 × ROF 60, 6, ziemia (w SC bez broni) | 1200 |

Dźwięki (głosy, śmierć, atak) z SC, ataki odczytane z iscript: `zmuFir00`, `ZGuFir00`, `ZQuFir00`, `firesuck`, `ZAvHit00`. `Sound.ini` 1300–1338.

## Pliki

| Plik | Co | Kopia |
|---|---|---|
| `MIX/ECACHE86.MIX` | 136 plików (17,9 MB): 17 budynków × (SHP, Buildup, cameo), 17 SHP drona + cameo „budynek + dron”, 6 latających + cameo, 43 AUD | — |
| `Modding/tools/build-sczergbase.ps1`, `ScZerg.cs` | budowa (`-Install` = INI, lobby, pliki strony; odmawia instalacji bez łatki `game.exe`); `BuildupCached`, `WriteShared`, cameo, przycięcie | — |
| `Modding/tools/patch-buildup.ps1` | łatka `game.exe`: długie Buildupy ([[engine/buildup-timing]]) | `game.exe.bak` |
| `INI/Map Code/SC Factions/010 Zerg faction.ini` ([[engine/map-code-layers]]) | blok „Zerg faction”: `[Sides] ZergSide=Nod1`, `ZRG01–46` w `[VehicleTypes]`, `ZRI01–05` w `[InfantryTypes]`, strona, dom, grupy, `[BuildingTypes] ZRB01–17`, wszystkie typy i bronie | `.bak` warstwy |
| `INI/Map Code/SC Factions/000 Terran faction.ini` | wspólne `BaseUnit=SCMCVT,SCZDHTS,…`, `HarvesterUnit=…,SCZWORK` (generator dopisuje do nich swoje typy) | `Terran Faction.ini.bak` (stan sprzed Zergów i Protossów) |
| `INI/Art.ini`, `INI/Sound.ini` | bloki „Zerg faction” | starsze `.bak` |
| `INI/Game Options/StarCraft.ini` | posprzątane: piechota z checkboxa znów tylko `GDI1`, budynki Zergów poza grupami `BARRACKS/RADAR/TECH` | starsza `.bak` |
| `Resources/GameOptions.ini`, `INI/MPMaps.ini`, `MIX/SideC08/sidenc08/Speech08.mix`, `Resources/zergicon.png`, `l600s7*/l480s7*.pcx` | lobby i pliki strony (kopie Nod) | `.bak` |

**Wspólny kod mapy z Terranami i Protossami** (`MapCodeININame` przyjmuje jedną nazwę pliku, ale ten plik łączy warstwy przez `BasedOn`): kolejność `[Sides]` `TerranSide` (warstwa 000), `ZergSide` (010), `ProtossSide` (020) = strony 6, 7, 8.
Od 2026-10-28 wpisy list Zergów (`[Sides]`, `[VehicleTypes]`, `[InfantryTypes]`) są we własnych sekcjach warstwy `010` (klient scala powtórzone sekcje, [[engine/ini-layering]]); wcześniejsza uwaga o „niepewnych duplikatach” jest nieaktualna. Po przegenerowaniu pliku przez inną sesję: `build-sczergbase.ps1 -Install`.

## Morf: czasy i dwa błędy pierwszej wersji (zgłoszenie „za szybko się morfowało”)

1. **Przelicznik:** czasy liczyłem w „minutach” z Rules (900 ticków = 1 min, czyli 15 ticków/s), a skirmish domyślnie chodzi w **60 FPS**
   (`SkirmishLobby.ini` `cmbGameSpeedCap`, `GameSpeed=1` = „60 FPS”), więc wszystko było 4× za szybko (Hatchery ok. 14 s).
   Teraz: czas budowy SC w sekundach gry × 0,63 (SC „Fastest”) × 60 = ticki. Przy innej prędkości gry czasy skalują się razem z nią.
2. **Brak Buildup w Art.ini:** pętla `foreach ($b in $B)` nadpisywała listę (PowerShell nie rozróżnia wielkości liter), więc tylko Sunken
   miał sekcję art. Pozostałe budynki nie miały animacji i pojawiały się od razu. Naprawiła to sesja Protossów ([[mods/protoss-faction]]).
   Zasada: w skryptach listy i zmienne pętli muszą mieć różne nazwy (`$Bldgs`/`$bd`).

Kokon pulsuje (klatka co 3 ticki, tam i z powrotem) i rośnie: mały kokon dla 2x2, średni dla 3x2/4x2, duży dla 4x3; na końcu pęknięcie i `zSpawn`.
Każda różna klatka jest zapisana raz (`ScZerg.BuildupCached` + `WriteShared`), więc 4536 klatek Hatchery to ok. 500 KB.

## Dlaczego to działa (kod Vinifery)

- **ConYard nie jest potrzebny do jednostek.** `[AI] BuildConst` bramkuje tylko stawianie z paska, AI i auto-deploy MCV. Deploy pojazdu
  w budynek spoza listy idzie zwykłą ścieżką (w DTA tak samo `BFRT` → `DBFRT`).
- **Hatchery jako „stocznia” (`Naval=yes`):** `Unlimbo_Naval_Helper` stawia produkt na wolnej komórce obok (wg `SpeedType`). Fabryki „naval”
  liczą się razem do premii `MultipleFactory` (`Factory_Count(RTTI, PRODFLAG_NAVAL)`), więc kolejne Hatchery przyspieszają produkcję.
- **Start:** `Create_Units` bierze pierwszy pasujący `BaseUnit`, a „ConYard na start” stawia jego `DeploysInto`.

## Test użytkownika 1 (2026-10-25)

Budynki się morfują (deploy działa). „Za szybko” wyjaśnione wyżej i poprawione w pełnej wersji.

**Pomiar 2026-10-25 (11:58, gra Terranem):** sonda zmierzyła **45,2 FPS**, a nie 60 z opisu lobby. Przelicznik zmieniony na
czas SC × 0,63 × **45** (`$GameFps` w skryptcie): Hatchery 3402 ticki = 75 s, Pool 2268 = 50 s, Creep 567 = 12,6 s. Tabela wyżej
(ticki przy 60 FPS) jest przez to nieaktualna o czynnik 0,75. Instalacja nowych czasów czeka w tle na zamknięcie gry.

**Test użytkownika 2 (2026-10-25, 12:19–12:28): morf POTWIERDZONY w grze** (sonda): Creep 576 klatek w 12,7 s, Extractor 1129 w 24,9 s,
Pool 2277 w 50,3 s, Lair 2842 w 62,8 s, Spire 3402 w 77,6 s; zawsze `Rate 1` i klatki = `Count` (±10 z próbkowania), 45,2 FPS.

## Poprawki po teście 2 (2026-10-25, prośby użytkownika; niezweryfikowane w grze)

- **Sunken Colony:** obrażenia 80 → 160, zasięg 8 → 16, `Sight` 12. **2026-10-27 cofnięte** (użytkownik: „za mocne”): znów `Damage=80`, `Range=8`, `GuardRange=8` (kod mapy frakcji, dziś warstwa `010 Zerg faction.ini`, + build-sczergbase.ps1; kopie w mapach arka01/arka02 też poprawione).
- **Zergling, 2026-10-27:** `GuardRange=2.75` (o 1 kratkę więcej niż domyślny zasięg pazurów 1.75; zasięg ataku bez zmian) dla `SCZLNG`, `SCZLNG2` i `SCZLING` (StarCraft.ini), a bohater Devouring One `SCZHDO` ma `GuardRange=3.28` (pazury 2.28 + 1), w blokach „SC balance (user)”, których generatory nie nadpisują **(niezweryfikowane w grze)**. **2026-10-30:** jeszcze +1 kratka (użytkownik: „zwiększ zasięg reagowania zerglingów o 1 pole”, nie wzrok i nie zasięg ataku): Zergling `GuardRange=3.75`, Devouring One `4.28`; przy okazji wszystkie jednostki wręcz dostały `GuardRange` = zasięg broni + 1: Ultralisk `SCZULT`/`SCZULT2`/`SCULTRA` i Torrasque `SCZHTQ` 3.5, Broodling `SCZBRD`/`SCZBRD2`/`SCBROOD` 2.93, Infested Kerrigan `SCZHKE` 3.1 (Drone, Infested Terran i Scourge pominięte: robotnik i jednostki samobójcze); gotowe mapy arka01–05 poprawione w miejscu **(niezweryfikowane w grze)**. Pod celem wyrasta macka SC: animacja `SCZTENT` (`bullet\Tentacle.grp`
  0–5–0, broń SC ma obraz Tentacle) z dźwiękiem uderzenia `ZLuHit00` (`SCZSUNHT`); przy strzale nadal `ZLuFir00`. Wcześniej był tylko
  dźwięk startu i niewidzialny pocisk.
- **Lurker** = pojazd `SCZLRV` z Lair/Hive (`BuiltAt=SCZLAI,SCZHIV`, wymaga Hydralisk Den + Lair), bez broni (jak w SC) ↔ zakopany budynek
  `SCZLRB` 1x1: deploy zakopuje (animacja zakopywania z iscript, zestawy 11–24, dźwięk `ZLuBurrw`), deploy budynku wykopuje
  (`UndeploysInto`, wymaga opcji „Re-Deployable MCV”). Zakopany: `Cloakable=yes` (niewidzialny bez wykrywacza z `Sensors`),
  broń `SCZFLurkSpine`: **fala `IsSonic`** (mechanika Disruptora `SonicZap`: rani wszystko na linii co klatkę `AmbientDamage=2`)
  + `Damage=100` w celu (2× poprzednie 50), zasięg **20,4** = oblężony Siege Tank (`SCShockCan`), dźwięki `ZLrkFir1`/`ZLrkHit1`,
  kolce `SCZSPIKE` (`bullet\Spike.grp`) w miejscu trafienia. Lurker-piechota usunięta z `[InfantryTypes]`.
- `SCZTENT` i `SCZSPIKE` dopisane do `Rules.ini [Animations]` (obrazy animacji ładują się z teatrem, przed plikami mapy).
- **Test 3 (13:06–13:16, sonda): Lurker się zakopuje** (4×, Buildup 14 klatek × tempo 5 = ok. 70 ticków). Odkopywanie nie wymaga opcji
  „Re-Deployable MCV” (użytkownik: Siege Tank ma ten sam mechanizm i działa bez niej).
  (niezweryfikowane) czy budynek z `Cloakable=yes` się maskuje (w TS strzał chwilowo odsłania), czy fala `IsSonic` działa z budynku.
- **Poprawki 2026-10-25 po teście 3 (prośby użytkownika):** Hydralisk o 30% wolniejszy (`Speed` 8 → 6, ulepszony 12 → 8: `SpeedX` 4/3
  w `build-sczergresearch.ps1`; także `SCHYDRA` z checkboxa). Stary Lurker-piechota usunięty całkiem (`SCLURK` z checkboxa, `SCZLRK2` z badań).
  **Ulepszony Lurker** `SCZLRV2` ↔ `SCZLRB2` (`Image=SCZLRB`): HP 3325 (+33%), broń `SCZFLurkSpineU` 133 + `AmbientDamage` 3 (+33%),
  wymaga badania `SCYMIS` (Missile Attacks), złote cameo `SCZLRV2I`. Lurker „nie strzela z daleka”: zakopany ma `Sight=10` przy zasięgu 20,4,
  a budynek sam celuje tylko w to, co gracz widzi. **Poprawione na prośbę użytkownika: zakopany Lurker (oba) ma `Sight=21`.**
  Oryginalny TS przycina widzenie do 10 w `MapClass::Sight_From`, ale Vinifera z DTA ma hak `_From_Sight_Dynamic_Sight_Range_Patch`
  (`0x00510C9A`, potwierdzony w `Vinifera.pdb` przez `llvm-pdbutil dump -publics`), który liczy tabelę odsłaniania dla dowolnego promienia.
  (niezweryfikowane w grze)
- `build-sczergbase.ps1 -Install` sam nakłada `patch-buildup.ps1`, gdy łatki brakuje: `patch-flyhover.ps1 -FromBackup` skasował ją 2× (13:16, 13:36).
- **Sonda 13:40–18:52 (13 gier):** w grach o 14:13 i 17:39 morfy miały `Rate 0` i kończyły się od razu: łatkę znowu skasował
  `-FromBackup` (`game.exe` zapisany o 18:15). Bez łatki tempo 0 oznacza budynek gotowy od razu, a nie budowę, która stoi wiecznie.
  **Poprawka:** `patch-flyhover.ps1` po `-FromBackup` sam uruchamia `patch-buildup.ps1` (test na kopii: 13/13 + 4/4, wywołanie → `0x6C9FC0`).
- **Kolce Lurkera zamiast `IsSonic` (2026-10-25, 19:10 i 19:40).** Test 19:01: z bliska fala działała, z daleka grał tylko dźwięk.
  Sonda pokazała cele na 17–19 polach, a fala sonic ma stałą, krótką długość. Nowa broń to pocisk `SCZSpineProj` (niewidzialny obraz
  `SCZSPINP`), który co 3 klatki zostawia raniący kolec `SCZSPIKT` (`Image=SCZSPIKE`, `Damage=6`, `DamageRate=180`,
  `Warhead=SCZFLurkTrailWH`, oszczędza swoich). Pełne trafienie i splash są w celu.
  **Test 19:31: przy Lurkerze był jeden kolec i nic dalej.** Pierwszy powód: `Trailer=` i `SpawnDelay=` pocisku TS czyta z sekcji
  obrazka w **Art.ini** (jak `[FLMPRJ]` → `FTNKINVBURNINIT` u Behemotha), a nie z Rules, więc smuga się nie tworzyła. Drugi powód był
  prawdopodobnie w locie: pocisk `Level=yes` z FLH na poziomie gruntu wybuchał od razu. Poprawki: `Trailer` przeniesiony do Art
  `[SCZSPINP]`, a klucze lotu skopiowane z `FlameProj1E2`, który w DTA leci cały zasięg (`Arm=2`, `High=yes`, `Ranged=yes`, `ROT=100`,
  `Acceleration=5`). (niezweryfikowane w grze)
- **Guardian (19:08):** strzela pociskiem kuli kwasu `SCZGAcidProj` (`Image=SCZGACID`, `thingy\ep3Shot` 2× w zieleni `ScZerg.AcidGreen`).
  Rozprysk `SCZGBURST` (`ep3Burst`) i dźwięk `SCZGUHIT` pochodzą z warheadu `SCZFAcidWH`. (niezweryfikowane w grze)
  Potwierdzone w grze: ulepszony Lurker się zakopuje (`SCZLRB2`), animacja ataku Hydraliska 19 klatek (było 5). Hydraliski w jednej grze:
  zwykły (6) ok. 0,095 komórki/klatkę, ulepszony (8) ok. 0,120, proporcja zgodna z 6:8.
  Sonda loguje teraz też nowe cele uzbrojonych budynków (`SCZLRB*`, `SCZSUN`, `SCZSPO`) z odległością, żeby sprawdzić strzały Lurkera z ok. 20 pól.
  Gry z 25.10. ok. 20:26 (po instalacji kolców): zakopany `SCZLRB2` bierze cele z 14–20,1 pola. Czy kolce dolatują, sonda nie widzi
  (niezweryfikowane w grze).
- **Gra Zergami 2026-10-27, 07:40–07:47 (sonda): czasy morfu POTWIERDZONE dla prawie całego drzewka.** Klatki zgadzają się z `Count × Rate`
  co do ±3: Spore i Sunken 25,0 s, Extractor 25,0 s, Nydus 38,6 s, Defiler Mound 37,5 s, Ultralisk Cavern 50,1 s, Lair 63,6 s,
  Spire 76,2 s, Hive 75,1 s, Greater Spire 75,1 s, przy 44–45 FPS. **Problem zgłoszony przez użytkownika:** w trakcie morfu budynek już
  działa (fabryka i wymagania). Powód: TS wpisuje budynek do listy gracza przy `Unlimbo`, a `Buildup` jest tylko kosmetyczny, co
  wnioskuję z kodu źródłowego RA i jeszcze nie sprawdziłem w deasemblacji. Naprawa wymaga łatki `game.exe`: czeka na decyzję użytkownika.
  `SCZSUN` bierze cele z 14,7–15,8 pola, czyli jego zasięg 16 działa.
- Skrypty z `Add-Type` uruchamiać w **osobnych procesach** (`powershell -File …`): drugi skrypt w tym samym procesie pada na „type 'Casc' already exists”.
- Po zmianach w jednostkach bazowych trzeba ponownie uruchomić `build-sczergresearch.ps1` ([[mods/zerg-research]]), bo kopiuje SHP i art.
  Zrobione 2026-10-25 po poprawce animacji ataku; jego wariant `SCZLRK2` wyłączony (Lurker jest teraz pojazdem).
- **Zacinanie Hydralisków przy ataku:** przyczyna nieznana; sonda `morphprobe.ps1 -TraceInfantry` loguje każdą zmianę stanu piechoty
  `SCZ*` (`Doing`, misja, cel, `IsFiring`, `IsProne`, timer przeładowania, komórka; offsety z `Vinifera.pdb` przez `llvm-pdbutil`).

## Weryfikacja morfu w grze: sonda `tools/morphprobe.ps1`

Sonda pamięci tylko do odczytu (wzór `nukeprobe.ps1`): czeka na `game.exe`, co 10 s loguje prawdziwe FPS (licznik `Frame` pod `0x7E4924`,
ten sam, który `Begin_Mode` zapisuje jako start etapu), a dla każdego budynku `SCZ*` w stanie budowy (`BState` 0) zapisuje `Count`/`Rate`
typu (`Anims[0]` +0x53C/+0x540) i na końcu liczbę klatek oraz sekundy od początku do końca morfu. Log: `Modding/tools/morphprobe.log`.
Oczekiwane: `Rate` 1, `Count` = ticki z tabeli, klatki ≈ `Count`, sekundy ≈ `Count / FPS`.

## Do sprawdzenia w grze

1. Start, startowa Hatchery w 1 s, robotnicy zbierają do Extractora.
2. Czasy morfów (Hatchery ok. 75 s, Creep ok. 13 s przy 60 FPS) i to, że budynek działa dopiero po pęknięciu kokonu.
3. Grupy wymagań: Lair odblokowuje Spire/Nest, Hive odblokowuje Cavern/Mound/Nydus/Greater Spire, kolejne Hatchery i Lair produkują.
4. Piechota z Poola i z Nydus Canal (ustawionego jako główny). Lurker dopiero z Lair.
5. Latające: lot, wiszenie (łatka Fly), Scourge i Devourer biją tylko w powietrze, Guardian tylko w ziemię, Spore Colony strzela w latające.
6. Overlord i Spore Colony wykrywają niewidzialnych (`Sensors`): **(niezweryfikowane, czy działa dla jednostek)**.

## Regeneracja do pełna, bez naprawy (2026-10-25, prośba użytkownika; niezweryfikowane w grze)

- **Wszystkie** typy Zergów (jednostki, drony, budynki, zakopany Lurker) mają `SelfHealing=yes` + `SelfHealingCap=1.0`.
  Bez tego Vinifera leczy tylko do `ConditionYellow` (50%) i o 1 HP na krok ([[mods/protoss-faction]], te same klucze co tarcze Protossów).
- `SelfHealingStep`: jednostki 0,4% `Strength`, budynki 0,2% na krok (krok co `RepairRate` ≈ 0,24 s przy 60 FPS),
  czyli od zera ok. 60 s dla jednostek i ok. 2 min dla budynków. Ulepszone wersje z [[mods/zerg-research]] mają krok przeskalowany razem z HP.
- Budynki Zergów: `Repairable=no` (klucz zwykłych budynków TS, jak `Repairable=false` u min). Nie da się ich naprawić kluczem.
- Kod: `$bldgKeys` i funkcja `Add-ZergRegen` w `build-sczergbase.ps1` (dopisuje klucze każdej sekcji z `SelfHealing=yes`, która nie ma własnego `SelfHealingCap`).
- Do sprawdzenia: czy samoleczenie Vinifery działa dla **budynków** (Protossi zakładają, że tak, ale też bez testu).

## Rebalans Zerglinga (2026-10-26, prośba użytkownika; niezweryfikowane w grze)

- Zergling o 20% wolniejszy, bo zacinał się przy chodzeniu po skosie. `Speed` jest liczbą całkowitą: `SCZLNG` 12 → 10,
  `SCZLNG2` (Upgraded) 18 → 14, a w checkboxie STARCRAFT `SCZLING` 12 → 10 ([[mods/starcraft-zerg]]).
- Wartości są w bloku `; >>> SC balance (user)` w warstwie `INI/Map Code/SC Factions/900 Hand edits.ini` (na górze łańcucha) i na końcu `StarCraft.ini`. Klient scala powtórzone sekcje
  i późniejszy klucz wygrywa, więc ponowne uruchomienie generatorów (`build-sczergbase.ps1`, `build-sczergresearch.ps1`,
  `build-sczerg.ps1`) tego nie cofnie. W tym bloku trzymaj kolejne ręczne zmiany balansu.

## Wolniejsze leczenie Zergów (2026-10-28, prośba użytkownika; niezweryfikowane w grze)

- „Ogólnie Zergi powinny się trochę wolniej leczyć”: wszystkie 85 typów Zergów z `SelfHealing=yes` z kodu mapy frakcji dostały `SelfHealingStep` × 0,6 (zaokrąglone, co najmniej 1), np. Zergling 3 → 2, Hydralisk 6 → 4, Overlord 16 → 10, Ultralisk 40 → 24, Hatchery 20 → 12, drony budynków 3 → 2. Wpisy (ze starą wartością w komentarzu) są w bloku `; >>> SC balance (user)` w `900 Hand edits.ini`. Zergi z checkboxa STARCRAFT (`StarCraft.ini`) się nie leczą, więc tam nic nie doszło.
- Wyjątek: `SCZDTUM` (dron Creep Tumora) ma `SelfHealingStep` ustawiony za blokiem balansu (blok creepu), więc jego zmiana nie działa; to dron, więc pominięty. (2026-10-28: po podziale na warstwy blok balansu jest na górze łańcucha i wygrywa, więc `SCZDTUM` ma teraz `SelfHealingStep=2` zamiast 3.)
- Misje z typami SC skopiowanymi do mapy (ARKA) dostają nowe wartości przy następnym uruchomieniu generatora misji; ARKA 5 już przebudowana.

## Dźwięki śmierci pojazdów (2026-10-27, zgłoszenie użytkownika; niezweryfikowane w grze)

- Objaw: Overlord ginął z dźwiękiem zniszczonego budynku. Przyczyna: pojazdy ignorują `DieSound=`, a generatory Zergów dawały
  `Explosion=FBALL1`, więc grał `Report=` kuli ognia. Dotyczyło wszystkich 43 pojazdów `SCZ*` z `DieSound=` (drony, robotnik,
  Lurker, Overlord, Mutalisk, Scourge, Guardian, Devourer, Queen, ich wersje Upgraded, bohaterowie Kukulza, Matriarch, Yggdrasill).
- Poprawka: `tools/build-sczergdeath.ps1` (wzór Protossów `SCPPDTHX`): animacja `ZDTH_<dźwięk>` (obraz `FBALL1`, `Report=` z
  `DieSound`) w bloku `; >>> Zerg death sounds` na końcu `Art.ini` i w warstwie `INI/Map Code/SC Factions/090 Zerg death sounds.ini` (`[Animations]` `ZDA01–08`,
  `Explosion=`/`ScrapExplosion=` per pojazd). **Uruchom ponownie po każdym generatorze Zergów**, który dodaje pojazdy.
- Budynki nie są ruszane: one same grają `DieSound=` (`SCZBDTH`).

## Bohaterowie i budynki specjalne

Osobny mod [[mods/zerg-heroes]] (`build-sczergheroes.ps1`, blok „Zerg heroes”): 10 bohaterów SC i budynki z kampanii (Overmind ×2, Cerebrate,
Daggoth, Mature Chrysalis) z supermocą Overminda. **Po `build-sczergbase.ps1 -Install` uruchom też `build-sczergheroes.ps1 -Install`.**

## Badania (ulepszenia SC)

Osobny mod [[mods/zerg-research]] (`build-sczergresearch.ps1`, własna warstwa kodu mapy `040 Zerg research.ini`): 13 badań na budynkach Zergów
i złote „Upgraded” wersje 12 jednostek. Budynki tech (Evo, Den, Spire, Greater Spire, Nest, Cavern, Mound) dostają tam
`Factory=BuildingType` i trafiają do `[AI] BuildConst`. **Po `build-sczergbase.ps1 -Install` uruchom też `build-sczergresearch.ps1`.**

## Skrzynki (2026-10-25, sesja Protossów)

Hydralisk wziął skrzynkę i gra się zawiesiła (ostatnia linia logu: `Crate at 89,136 contains a unit`). Dom `Nod1` nie miał żadnego
pojazdu z `CrateGoodie=yes`, więc losowanie nagrody nie miało końca. Naprawione blokiem „Crate goodies (SC factions)” w warstwie
`900 Hand edits.ini` (Mutalisk, Queen, Guardian), zob. [[engine/crates]].

## Znane ograniczenia

- **AI nie umie grać Zergiem** (nie rozstawia dronów). Nie dawaj Zerga komputerowi.
- Brak creepu, larw (kolejka fabryki), zakopywania, czarów Queen/Defiler (zastąpione bronią), Overlord nie przewozi i nie daje „supply”.
- Lair/Hive nie zastępują Hatchery: to osobne budynki z własnymi dronami.
- Sidebar i EVA: przekolorowana kopia Nod i 9 kwestii doradcy Zergów z SC ([[mods/zerg-side]]); logo na radarze to dalej skorpion Nod (w fiolecie).

## Odinstalowanie

Usunąć warstwę `INI/Map Code/SC Factions/010 Zerg faction.ini` (najpierw warstwy zależnych modów Zergów: heroes, research, creep, death sounds)
i w warstwie nad nią (`020 Protoss faction.ini`) ustawić `BasedOn=000 Terran faction.ini`; w `000 Terran faction.ini` wykreślić `,SCZDHTS`
z `BaseUnit=` i `,SCZWORK` z `HarvesterUnit=`. Uwaga: bez `ZergSide` strona Protossów spadnie z indeksu 8 na 7.
Stan sprzed Zergów i Protossów to `Terran Faction.ini.bak`. W `Art.ini`/`Sound.ini` usunąć bloki
„Zerg faction” i `[SoundList] 1300–1338`; `GameOptions.ini` bez `,Zerg`; `MPMaps.ini` `4,5,6,7` → `4,5,6`; usunąć `MIX\ECACHE86.MIX`,
`MIX\SideC08.mix`, `sidenc08.mix`, `Speech08.mix`, `Resources\zergicon.png`, `l600s7*.pcx`, `l480s7*.pcx`. Łatka `game.exe`: `patch-buildup.ps1 -Revert`.
