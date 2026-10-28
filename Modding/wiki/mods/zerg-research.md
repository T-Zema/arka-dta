# Mod: badania Zergów (ulepszenia jako ulepszenia budynków)

Ulepszenia Zergów z SC dla frakcji Zerg ([[mods/zerg-faction]], dom `Nod1`) według wzorca badań Terran z [[mods/starcraft-research]]: badanie kupuje się w zakładce budynków i montuje na budynku, który prowadzi je w SC. Odblokowuje ono złotą „Upgraded” wersję jednostki. Stan: zainstalowany 2026-10-25, **(niezweryfikowane w grze)**.

Źródła: dane SC `arr/upgrades.dat`, `arr/techdata.dat`, `rez/stat_txt.tbl` (koszty, ikony, nazwy), `SD/unit/cmdicons/cmdicons.dds.grp`;
kod Vinifery (`houseext.cpp` `Has_Prerequisite`, `houseext_hooks.cpp` BuildConst, `buildingext_hooks.cpp` pasek budowy);
biblioteka klienta `Resources/Binaries/Rampastring.Tools.dll` (scalanie powtórzonych sekcji, zob. [[engine/ini-layering]]).

## Problem: Zergi nie mają Construction Yardu

Badania Terran to budynki-ulepszenia z paska budynków, a ten pasek wymaga fabryki budynków z `[AI] BuildConst`
([[engine/adding-new-types]]). Zergi budują wszystko dronami (`DeploysInto`), więc nie mają paska budynków.
**Rozwiązanie:** budynki technologiczne Zergów są „laboratoriami”: `Factory=BuildingType` i wpis w `[AI] BuildConst`. Dotyczy to
Evolution Chamber, Hydralisk Den, Spire, Greater Spire, Queen's Nest, Ultralisk Cavern i Defiler Mound. Gdy gracz ma którekolwiek z nich, pojawia się zakładka budynków.
Pokazuje tylko badania, bo każdy budynek Zergów ma `TechLevel=-1`, a jedyny klasyczny budynek z `Owner=Nod1` (`TDPROC`) wymaga grupy `POWER`, której Zergi nie mają.
- Spawning Pool i Lair są już fabrykami (jeden `Factory=` na budynek), więc ich badania (Metabolic Boost, Adrenal Glands,
  Pneumatized Carapace, Antennae) **rosną w dowolnym laboratorium**, zwykle w Evolution Chamber, a montuje się je na Poolu/Lairze.
- Bez `ConstructionYard=yes` (to włączałoby zwijanie conyardu przy opcji „Redeploy MCV”).
  **Jeśli zakładka budynków się nie pojawi**, pierwsza rzecz do sprawdzenia: dopisać `ConstructionYard=yes` laboratoriom.

## Badania

| ID | Badanie (SC) | Montowane na | Wymaga | Ikona SC | Koszt | Ulepsza |
|---|---|---|---|---|---|---|
| SCYMEL | Melee Attacks & Carapace | Evolution Chamber | — | 299 | 1200 | Zergling, Ultralisk, Broodling |
| SCYMIS | Missile Attacks & Carapace | Evolution Chamber | — | 300 | 1200 | Hydralisk, Lurker, Defiler (tylko HP) |
| SCYFLY | Flyer Attacks & Carapace | Spire | — | 301 | 1200 | wszystkie latające (Scourge, Queen, Overlord tylko HP) |
| SCYMET | Metabolic Boost | Spawning Pool | — | 263 | 1200 | Zergling: prędkość |
| SCYADR | Adrenal Glands | Spawning Pool | Hive | 264 | 2400 | Zergling: szybszy atak |
| SCYMUS | Muscular Augments | Hydralisk Den | Lair | 266 | 1800 | Hydralisk: prędkość |
| SCYGRV | Grooved Spines | Hydralisk Den | Lair | 268 | 1800 | Hydralisk: zasięg |
| SCYPNE | Pneumatized Carapace | Lair | — | 296 | 1800 | Overlord: prędkość |
| SCYANT | Antennae | Lair | — | 262 | 1800 | Overlord: wzrok i wykrywanie |
| SCYGAM | Gamete Meiosis | Queen's Nest | — | 294 | 1800 | Queen: szybszy atak |
| SCYMSN | Metasynaptic Node | Defiler Mound | — | 295 | 1800 | Defiler: częstsza Plaga |
| SCYANA | Anabolic Synthesis | Ultralisk Cavern | — | 378 | 2400 | Ultralisk: prędkość |
| SCYCHI | Chitinous Plating | Ultralisk Cavern | — | 379 | 1800 | Ultralisk: HP |

Koszt jak u Terran: (minerały + 2 × gaz) × 4. Poziomy 1–3 ataku i pancerza połączone w jedno badanie na klasę (jak „Weapons & Armor” Terran).
`Upgrades=` rodziców: Evolution Chamber 2, Spawning Pool 2, Hydralisk Den 2, Lair 2, Ultralisk Cavern 2, Spire 1, Queen's Nest 1, Defiler Mound 1.

## Ulepszone jednostki (max 2 ikonki na jednostkę)

Złota ramka i szewrony na cameo, nazwa „<jednostka> (Upgraded)”, ten sam koszt i miejsce produkcji co baza.

| Wersja | Wymaga (oprócz wymagań bazy) | Zmiany |
|---|---|---|
| SCZLNG2 Zergling | SCYMEL + SCYMET + SCYADR | HP ×1,25, obrażenia ×1,3, prędkość 12 → 18, ROF ×0,75 (11 → 8) |
| SCZHYL2 Hydralisk | SCYMIS + SCYMUS + SCYGRV | HP ×1,25, obrażenia ×1,3, prędkość 8 → 12, zasięg ×1,25 (7,8 → 9,75) |
| ~~SCZLRK2 Lurker~~ | — | **usunięty 2026-10-25 (sesja Zergów):** Lurker to teraz pojazd `SCZLRV`, który strzela tylko jako zakopany budynek `SCZLRB`, więc ulepszona kopia pojazdu nie miałaby czego ulepszać (wariant zakomentowany w generatorze) |
| SCZULT2 Ultralisk | SCYMEL + SCYANA + SCYCHI | HP ×1,5, obrażenia ×1,3, prędkość ×1,5 |
| SCZDFL2 Defiler | SCYMIS + SCYMSN | HP ×1,25, Plaga co 0,6 czasu |
| SCZBRD2 Broodling | SCYMEL | HP ×1,25, obrażenia ×1,3 |
| SCZOVL2 Overlord | SCYFLY + SCYPNE + SCYANT | HP ×1,25, prędkość 4 → 12, wzrok 11 → 14, `SensorsSight` 9 → 12 |
| SCZMUT2 Mutalisk | SCYFLY | HP ×1,25, obrażenia ×1,3 |
| SCZSCG2 Scourge | SCYFLY | HP ×1,25 (w SC obrażenia Scourge się nie ulepszają) |
| SCZGRD2 Guardian | SCYFLY | HP ×1,25, obrażenia ×1,3 |
| SCZDEV2 Devourer | SCYFLY | HP ×1,25, obrażenia ×1,3 |
| SCZQUN2 Queen | SCYFLY + SCYGAM | HP ×1,25, atak co 0,6 czasu |

Bronie ulepszonych wersji to kopie z sufiksem `U` (`SCZFClawU`…), tworzone tylko wtedy, gdy wariant zmienia broń.

## Pliki

- `Modding/tools/build-sczergresearch.ps1`: **generator**. Za każdym uruchomieniem odtwarza:
  - blok `; >>> Zerg research` … `; <<< Zerg research` w warstwie `INI/Map Code/SC Factions/040 Zerg research.ini` ([[engine/map-code-layers]]): `[AI] BuildConst` (lista z pliku + laboratoria),
    `[BuildingTypes] ZUB01–13`, `[InfantryTypes] ZUI01–06`, `[VehicleTypes] ZUV01–06`, **powtórzone sekcje budynków Zergów** z dopisanym
    `Factory=BuildingType`/`Upgrades=N`/opisem (klient scala je z blokiem „Zerg faction”, [[engine/ini-layering]]), badania, jednostki, bronie;
  - ten sam blok w `INI/Art.ini` (ikony badań, sekcje art jednostek skopiowane z bazy ze złotym cameo);
  - laboratoria w `[AI] BuildConst` w `INI/Game Options/StarCraft.ini` (plik checkboxa jest doklejany po pliku frakcji i powtarza listę),
    wstawione przed `SCPNEX`, żeby regex `build-scprotoss.ps1` dalej pasował;
  - `MIX/ECACHE84.MIX` (50 plików, ok. 6,3 MB): ikony badań, puste SHP badań, kopie SHP jednostek, złote cameo.
- Bloku „Zerg faction” (`build-sczergbase.ps1`) generator nie zmienia. **Po `build-sczergbase.ps1 -Install` trzeba uruchomić go ponownie**,
  bo kopie jednostek się zestarzeją (blok badań sam przetrwa, bo `Set-Block` sesji Zergów podmienia tylko swój blok).
- Wpisy innych skryptów, które trafiłyby do list w tym bloku (pierwsze wystąpienie `[InfantryTypes]` itp.), są przy regeneracji zachowywane.
- Kopie zapasowe: `.bak` warstwy (`040 Zerg research.ini.bak`), `Art.ini`, `StarCraft.ini`.

## Odstępstwa od SC (ograniczenia silnika)

- Jak u Terran: badanie nie ulepsza istniejących jednostek, tylko odblokowuje ulepszoną wersję. Starej nie da się ukryć.
- Badania „rosną” w laboratorium (kolejka paska budynków), a nie w samym budynku, i trzeba je ręcznie położyć na rodzicu.
- Pominięte: Burrow (brak zakopywania), Ventral Sacs (Overlord nie przewozi), Lurker Aspect (Lurker jest od razu jednostką),
  czary Queen/Defiler (Spawn Broodling, Ensnare, Dark Swarm, Plague, Consume, Parasite, Infestation: zastąpione bronią albo osobnymi typami).
- Bez ulepszonych wersji: Drone, Infested Terran (pojazd-samobójca).
- Badanie liczy się tylko, gdy rodzic stoi i jest włączony (`IsOn`); po zniszczeniu rodzica ulepszenie przepada.

## Do sprawdzenia w grze

1. Po zbudowaniu Evolution Chamber pojawia się zakładka budynków z dwoma badaniami; badanie da się położyć na Evo.
2. Badania Poola rosną w Evo i montują się na Poolu; Adrenal Glands dopiero z Hive.
3. Po trzech badaniach w Poolu pojawia się „Zergling (Upgraded)” ze złotym cameo.
4. Drony laboratoriów dalej normalnie się rozkładają (teraz celem jest typ z `BuildConst`).

## Odinstalowanie

Usunąć warstwę `INI/Map Code/SC Factions/040 Zerg research.ini` i w warstwie nad nią (`050 SC building select sounds.ini`) ustawić
`BasedOn=030 Zerg heroes.ini`. Usunąć blok `; >>> Zerg research` … `; <<< Zerg research` z `INI/Art.ini`, wykreślić
`SCZEVO,SCZHDN,SCZSPI,SCZGSP,SCZNES,SCZULC,SCZDFM` z `BuildConst=` w `INI/Game Options/StarCraft.ini`, usunąć `MIX/ECACHE84.MIX`.
