# Advanced AI DTA (skirmish): jak komputer buduje bazę, dobiera jednostki i atakuje

Jak działa „Advanced AI” DTA: osobna logika w `Vinifera.dll` (prywatny fork DTA, katalog źródeł `src/new/advai`, w publicznej Vinifera-Developers go **nie ma**), która w skirmishu zastępuje klasyczne AI z `AI.ini`. Odczytane z disasemblacji z nazwami z `Vinifera.pdb` (2026-10-30). Wszystko poniżej **(niezweryfikowane w grze)**, poza tym, co mówi sama treść INI.

Źródła: `Vinifera.dll` + `Vinifera.pdb` (disasemblacja, adresy VA niżej), `game.exe` (`HouseClass::AI` 0x4BCFC3), `INI/Game Options/Advanced AI.ini` (taktyki, ustawienia), `INI/Rules.ini` `[AI]`, `[Houses]`, `[IQ]`, `INI/Enhance.ini` `[AI]`, `INI/Game Options/Extreme AI.ini`, [[engine/sides-and-houses]], [[engine/triggers-and-dialogue]]. Narzędzia: `tools/vdis.py` (disasembler capstone, [[workflow/tooling]]), zrzut `llvm-pdbutil dump -publics|-types Vinifera.pdb`.

## Najważniejsze w skrócie

- **Armię tworzą tylko „taktyki”** (`[AdvancedAIGroundTactics]` itd.). Taktyka ma `House=` = **indeks domu w `[Houses]`** (`HouseTypeClass::HeapID`, nie `ActsLike` ani strona). DTA definiuje tylko `House=0..3` (GDI, Nod, Allies, Soviet). Dom bez pasującej taktyki (Terran `GDI1` = 6, Zerg `Nod1` = 7, Protoss `GDI2` = 8) **buduje bazę, ale nigdy nie tworzy ani nie wysyła armii**. Naprawa samym INI: własne taktyki z `House=6/7/8` ([[mods/terran-ai]]).
- Przy `AdvancedAIUnitProduction=yes` **AITriggery (`[AITriggerTypes]`) nie działają** dla żadnego domu komputera.
- Budowa bazy to sztywna kolejka priorytetów z limitami, oparta na listach `[AI] Build*`. Bierze tylko typy z `AIBuildThis=yes`.
- Dobór jednostek to wzór wartości (broń kontra pancerz wroga, zasięg, szybkość, maskowanie, koszt). Drużyny i skrypty tworzy kod (`TT_H<dom>_...`), nie INI.
- **Literówka w nazwie enuma taktyki kończy grę** (`Emergency_Exit`). Poprawne nazwy można wyciągnąć z DLL (generator [[mods/terran-ai]] to robi).

## Włączanie i główna pętla

- Checkbox lobby `chkExtremeAI` (domyślnie zaznaczony) dokleja `INI/Game Options/Advanced AI.ini`: `[AI] UseAdvancedAI=yes`, `AdvancedAIBaseBuilding=yes`, `AdvancedAIUnitProduction=yes` i inne. Domyślne wartości w kodzie: wszystkie `no`.
- `HouseClass::AI` (`game.exe`) woła `Expert_AI`, które Vinifera podmienia (`HouseClassExt::_Expert_AI` 0x100C6583). Na początku woła `AdvAI_HouseClass_Expert_AI` (0x100C2DC9), co ok. 106–112 klatek. Bramki: dom komputera, `HouseType` bez `MultiplayPassive`, `UseAdvancedAI=yes`. **Brak sprawdzenia trybu gry**.
- Kolejność w pętli: zagrożenie wczesnym rushem → samoobrona → (tylko GDI) zwijanie Enforcerów → sprawdzenie „tylko morze” co 5000 klatek → (przy `AdvancedAIUnitProduction`) rekrutacja, utrzymanie drużyn, wybór taktyki → inżynierowie co 500 klatek → ekonomia co 500 → budzenie śpiących zbieraczy co 1000.
- **Szarża po 5000 klatkach:** jeśli dom nie ma ani placu budowy, ani fabryki pojazdów, wszystkie jego pojazdy (poza MCV i zbieraczami) dostają `Hunt`. Jednorazowo.
- `AdvancedAIBaseBuilding` i `AdvancedAIUnitProduction` działają niezależnie od `UseAdvancedAI` i dotyczą wszystkich domów komputera.

### W misji kampanii

Da się: Vinifera czyta `[AI]` i sekcje taktyk z mapy (`Rule->Process(scenario)` 0x100EA4B7), tak jak w skirmishu. Ale:
- działa na **wszystkie** domy komputera (nie da się wybrać jednego; wyjątek: `MultiplayPassive` domu);
- AITriggery są martwe; drużyny z akcji triggerów działają, ale AI nie produkuje dla nich jednostek (ich proporcje są zerowe), co może zatkać kolejkę produkcji (wniosek);
- w kampanii `HouseClass::Enemy` nie jest wybierany sam (tylko w multiplayer). Trzeba go ustawić akcją triggera (Make Enemy), inaczej warunki `ENEMY_IS_*` zawsze zawodzą, a siła wroga liczy się ze wszystkich domów, także cywilów;
- samoobrona ściąga z posterunków jednostki bez drużyny.

Dlatego w misjach ARKA AI jest pisane triggerami ([[engine/triggers-and-dialogue]], [[engine/zerg-ai]]); Advanced AI jest dla skirmisha.

## Budowa bazy (`AdvAI_Evaluate_Get_Best_Building`, 0x100C1E85)

Warunki ogólne: dom ma co najmniej jeden plac budowy (`ConstructionYard=yes`), nic nie stoi w kolejce, sprawdzenie co 75 klatek.

**Czy typ wolno zbudować** (`AdvAI_Can_Build_Building`, 0x100C1324): `TechLevel` ≤ poziom domu, `AIBuildThis=yes`, bit **`ActsLike`** domu w `Owner=`, wymagania (chyba że Vinifera `AdvancedAIIgnoresPrerequisites=yes` na budynku; grupa = dowolny członek), ulepszenie (`PowersUpBuilding`) potrzebuje budynku z wolnym slotem. `BuildLimit` i strona nie są sprawdzane.

**Kolejka (pierwsza pasująca reguła wygrywa):**

1. Brak elektrowni podstawowej → elektrownia. Z `BuildPower` liczą się tylko **pierwszy i ostatni dostępny** wpis: niższa `Power=` = podstawowa, wyższa = zaawansowana.
2. Łatwy poziom i kasa ≥ `AIAlternateProductionCreditCutoff` → brakujące koszary.
3. Brak rafinerii → rafineria (**ostatni** dostępny wpis `BuildRefinery`).
4. Koszary: każdego dostępnego typu z `BuildBarracks` po (rafinerie − 1)/4 + 1.
5. Limit obrony D = (elektrownie)/4 + rafinerie/3, z poprawkami czasowymi i po +1 za: radar, tech, zagrożenie ekspansji, przewagę wroga, niedawny atak, **GDI-Allies (`HeapID` 2) po 20000 klatkach**.
6. Typy obrony: przeciw piechocie i przeciw pancerzom = najlepszy z `BuildDefense` (wartości liczy `IsBaseDefense=yes` + broń: pocisk `AG=yes` → anty-pancerz i anty-piechota, `AA=yes` → anty-lotnictwo), przeciwlotnicza = ostatni dostępny z `BuildAA`.
7. Gdy braki w obronie są małe (< `AdvancedAICriticalBaseDefenseDeficiencyThreshold`, DTA 3): fabryki pojazdów (`BuildWeapons`, po (rafinerie − 1)/4 + 1, ale dopiero przy kasie startowej > 8000 albo > 2 rafineriach), rafinerie do `AdvancedAIMinimumRefineryCount` (DTA 3).
8. Ekspansja (pole bezpieczne) → rafineria.
9. Stocznie (`BuildNavalYard`, klucz Vinifery) po (rafinerie − 1)/6 + 1.
10. Obrona z największym brakiem.
11. Radar (`BuildRadar`), jeśli żadnego. **Ten krok pomija wymagania** (wpis z wymaganiami może być wybrany za wcześnie).
12. Bez niedawnego ataku: lądowiska (`BuildHelipad`, po (rafinerie − 1)/2 + 1) i po klatce `AdvancedAINoTechCenterBeforeFrame` (10000) po jednym z `BuildTech`.
13. `BuildPDefense`: ostatni dostępny, D/2 sztuk.
14. Bez przewagi wroga: **po jednym z każdego typu `AIBuildThis=yes`**, którego dom nie ma (kolejność `[BuildingTypes]`). Budynki z `SensorArray` tylko, gdy wrogiem jest Nod (`HeapID` 1).
15. Ekspansja → elektrownia w jej stronę; nadwyżka prądu < 100 → zaawansowana elektrownia.

Na koniec budynek, który spowodowałby brak prądu, jest zamieniany na elektrownię. Puste listy (radar, lądowisko, tech, PDefense) są bezpiecznie pomijane. Elektrownie i rafineria muszą mieć wpis dla domu, inaczej odczyt poza tablicą.

**Ekonomia:** przy ≤ 1000 kredytów bez rafinerii sprzedaje najdroższy budynek; poza łatwym poziomem **sprzedaje rafinerie, których jest więcej niż zbieraczy** typów z `[General] HarvesterUnit`.

**Ekspansja** szuka tylko obiektów terenu z `SpawnsTiberium=yes` (drzewa Tyberium) na polu bez nakładki. Na mapach SC (minerały jako nakładki, bez drzew) AI nie ekspanduje, a rafinerie stawia przy środku bazy.

**Rozmieszczenie:** rafineria przy punkcie ekspansji albo środku bazy; koszary i fabryki w stronę ekspansji; obrona przy uszkodzonym budynku, przy placu lub rafinerii (rush), w punkcie obrony albo w stronę wroga; tech daleko od wroga po ataku. Zawsze 1 pole odstępu i zasięg `Adjacent` od budynku `BaseNormal`.

## Produkcja jednostek

- **Filtry** (`AdvancedAI_AI_Unit` 0x100BBF0F, `_Infantry` 0x100C3EAE): nie `Naval`, nie `Buildability=HumanOnly`, `TechLevel` ≤ domu (więc `-1` odpada), bit `ActsLike` w `Owner=`, wymagania, `BuildLimit` (z rozstawioną formą). `Insignificant`, `AIBuildThis` i lokomotor **nie** są sprawdzane.
- Jednostki z `Naval=yes` buduje **tylko** `AdvancedAI_AI_Naval_Unit`, dla drużyn taktyk morskich. Taktyka morska wymaga posiadania budynku z `[AI] BuildNavalYard`. Samoloty (`AircraftTypes`) wymagają lądowiska z `BuildHelipad`.
- **Wartość jednostki** (`TeamClassExtension::AdvAI_Get_Object_Value_For_Team` 0x100FF125): broń główna musi mieć pocisk `AG=yes`, inaczej wartość = minimum i jednostka **nigdy** nie powstaje (medycy z leczeniem, transportowce bez broni, czyste AA). Wartość broni = obrażenia × `Verses` × zasięg / ROF, +20% za każde pole zasięgu ponad 8, ×`AdvancedAIOffensiveWeaponValueMultiplier`. Do tego `Strength`, kara za nadmiar jednego pancerza i tego samego typu, mnożnik szybkości, ×2 za `Cloakable`, podział przez koszt (`Cost=0` = dominuje), losowo ×⅔–×1,5.
- Zdolność przeciwlotnicza nie dodaje nic do wartości.
- Piechota: progi `AdvancedAISkipInfantryProductionValueThreshold` (60) i `...Conditional...` (120) przy posiadanej fabryce, limit taniej piechoty w drużynie.
- **Zbieracz** = pierwszy wpis `[General] HarvesterUnit` z bitem `ActsLike` domu. Rafinerie liczone = pierwszy taki wpis `BuildRefinery`. Brak takiego wpisu = brak sprawdzenia NULL (awaria). Liczba zbieraczy na rafinerię 2 / 1,5 / 1 (trudny/normalny/łatwy).
- **MCV:** po stracie placu AI buduje pierwszy `UnitType` z `DeploysInto` = plac budowy, który dom posiada (bit `ActsLike`).

## Taktyki

Lista `[AdvancedAIGroundTactics]` (oraz `[AdvancedAIAirTactics]`, `[AdvancedAINavalTactics]`): wartości to nazwy sekcji. Listy z kilku plików się sumują (klient scala sekcje), sekcja taktyki czytana dwa razy podwaja warunki.

**Wybór** (`AdvAI_Tactic_Selection_AI` 0x100C39A4): po `AdvancedAITacticSelectionDelay` (trudny/normalny/łatwy) od ostatniej taktyki i gdy żadna nie trwa, **pierwsza w kolejności listy** taktyka, której wszystkie warunki są spełnione. Bez wag; losowość tylko z `PERCENT_CHANCE`.

**Klucze sekcji** (`Read_INI` 0x10135692):

| Klucz | Znaczenie |
|---|---|
| `PrimaryTacticType` | `TACTIC_*` / `AIRTACTIC_*` / `NAVALTACTIC_*`: skład drużyn i klucz odstępu `NOT_REPEATED` |
| `House` | indeks w `[Houses]` (domyślnie −1 = nic) |
| `Conditions.N` | `TACTICCOND_*,p1[,p2]`, N od 0 bez dziur, wszystkie muszą być spełnione |
| `AdvAITeamTypes.N` | `ADVAITT_*,IsSuicide,IsTransportTeam,AvoidThreats,MaxCost,LimitToRTTI,TacticTypeOverride` (`LimitToRTTI` = `Infantry`/`Unit`/`<none>`; `AvoidThreats` nieużywane) |
| `AdvAIAircraftTeamType` | `IsSuicide,MaxCost` (taktyki lotnicze) |
| `MinimumExpectedDuration`, `MaximumExpectedDuration` | czas zbierania drużyn w klatkach (losowo między) |
| `FrameBasedDurationIncrease`, `...TimeStep`, `...IncreaseMax` | +Increase co TimeStep klatek gry (do Max): późniejsze ataki są większe |
| `ScaleDurationByBuildTime` | × szybkość budowy domu |
| `SetTacticalValueIndex`, `...Min`, `...Max`, `...Chance` | ustawia „wartość taktyczną” domu (10 slotów) |
| `MaxInstances` | najwyżej tyle żywych drużyn tej taktyki (−1 = bez limitu; DTA nie używa) |

Po czasie zbierania drużyny ruszają (dzielone na `AdvancedAIMaxTeamSize`). Ataki bezpośrednie czekają +1000 klatek, gdy armia jest za słaba.

**Warunki** (`AdvancedAITacticTypeClass::Process`, tablica skoków 0x10135593):

| Warunek | Znaczenie |
|---|---|
| `FRAME_LESS_THAN` / `FRAME_MORE_THAN` | klatka gry < p1 / ≥ p1 |
| `ENEMY_IS_HOUSETYPE` / `ENEMY_IS_NOT_HOUSETYPE` | `HeapID` domu wroga == / != p1 (oba fałszywe bez wroga) |
| `PERCENT_CHANCE` | losowo p1% |
| `HAS_WAR_FACTORY` / `HAS_NO_WAR_FACTORY` | ma budynek z `[AI] BuildWeapons` |
| `IS_OUTNUMBERED` / `IS_NOT_OUTNUMBERED` | siła wroga > 2 × koszt własnych drużyn naziemnych |
| `IS_DISADVANTAGED` / `IS_NOT_DISADVANTAGED` | siła wroga > koszt wszystkich własnych drużyn |
| `ENEMY_VULNERABLE_REFINERIES`, `ENEMY_LIGHTLY_DEFENDED_REFINERIES` | rafinerie wroga (`BuildRefinery`) poniżej progu zagrożenia |
| `ENEMY_VULNERABLE_CONYARDS`, `ENEMY_LIGHTLY_DEFENDED_CONYARDS` | to samo dla `BuildConst` |
| `ENEMY_HAS_SENSORS` / `ENEMY_HAS_NO_SENSORS` | wróg ma budynek z `SensorArray` |
| `ENEMY_HARVESTER_COUNT_EXCEEDS` | wg kodu liczy rafinerie wroga > p1 (wniosek) |
| `NOT_REPEATED_FOR_FRAMES` | od ostatniej taktyki **tego samego typu** minęło p1 klatek |
| `HOUSE_TACTICAL_VALUE_ABOVE` / `_BELOW` | slot p1 > / < p2 |
| `ENEMY_ARTILLERY_STRENGTH_ABOVE`, `ENEMY_ANTI_AIR_STRENGTH_BELOW` | siła artylerii / OPL wroga |

Stara gra DTA na slocie 0: start z losowym 1–10, rush przy < 4 (Nod < 6), zwiad przy < 11 (może ustawić 11), obrona przy > 10.

**Typy taktyk → skład drużyny:** `SCOUT` (szybkość ×2,5), `RUSH_ATTACK` (przeciw lekkim, szybkość), `DIRECT_ATTACK_REGULAR` (zrównoważony + artyleria 0,5), `DIRECT_ATTACK_FAST` (szybkość ×2), `ATTACK_HARVESTERS` (przeciw ciężkim, szybkość, maskowanie), `ATTACK_REFINERIES`, `APC_ATTACK` (transporter z piechotą), `DEFEND`/`SIEGE`/`CHINOOK_ATTACK` (po równo). Proporcje są przesuwane w stronę składu armii wroga.

**Typy drużyn `ADVAITT_*`** (skrypt tworzony w kodzie): `SCOUT` (Hunt albo atak placu), `DIRECT_ATTACK` i `ATTACK_FACTORIES` (Hunt), `RUSH` (50% plac budowy, 50% rafinerie, potem Hunt), `ATTACK_REFINERIES`, `APC_VS_FACTORIES`/`APC_VS_REFINERIES` (załaduj, jedź, wyładuj, atakuj), `ATTACK_HARVESTERS` (zawsze samobójcza: zbieracze, potem pojazdy), `DEFEND` (zostaje w bazie). Taktyki morskie przyjmują tylko `ADVAITT_DIRECT_ATTACK`.

**Lotnictwo:** szansa = 100 − OPL wroga / 100 (min. 5), zależnie od kasy; potrzebne lądowisko z `BuildHelipad`.

## Samoobrona

Do 900 klatek od ostatniego ataku: wszystkie wolne jednostki z bronią (bez rozpoczętej drużyny) jadą do pierwszego uszkodzonego budynku, który nie jest obroną.

Szczegóły (`AdvAI_Self_Defense_AI` 0x100C3724, odczytane 2026-10-30):
- Okno działania: `HouseClass::LATime` (+0x310) + 900 ≥ bieżąca klatka.
- Cel: **pierwszy** w wektorze budynków własny, uszkodzony budynek bez `IsBaseDefense`, czyli niekoniecznie ten, który jest teraz atakowany. Uszkodzona sama obrona nikogo nie wzywa.
- Jednostki: muszą mieć broń, nie mogą być w ruchu (`NavCom` = 0) i nie mogą należeć do drużyny już wysłanej (`TeamClass::IsForcedActive`, +0x67). Flagę tę ustawia start drużyny (0x100C1C24), więc **jednostki drużyny, która się jeszcze zbiera, też bronią bazy**. Pomijane są zbieracze i samoloty w powietrzu.
- Działanie: misja `Guard` (5) zmienia się na `Guard Area` (10), a jednostka jedzie na wolne pole obok budynku.
- `TechnoClass::Threat_Range` (`game.exe` 0x6365B0): w `Guard` jednostka komputera szuka celu w promieniu `GuardRange`, a gracz zawsze w zasięgu broni. W `Guard Area` liczy się `GuardRange` dla wszystkich. Bez `GuardRange` jednostka walczy tylko w zasięgu broni. Dlatego DTA ma klony `AI*` z `GuardRange=12`. Jednostki SC go nie miały, więc AI-Terran stało i patrzyło na atak (test użytkownika 2026-10-30). Naprawa: [[mods/terran-ai]].

Zagrożenie wczesnym rushem (do klatki 10000): piechota wroga ×5 (człowiek) lub ×2 (AI) większa niż własna ×3 → przerwa w budowie nieobronnych budynków i produkcja kontrująca.

## Rozkładanie jednostek (Enforcer, Siege Tank)

Odczytane 2026-10-30 (prośba użytkownika: „AI DTA rozkłada Enforcera, więc się da”). Nie robi tego AdvAI, tylko misja Hunt:

- `UnitClassExt::_Do_MISSION_HUNT` (Vinifera 0x101157E3, zastępuje `UnitClass::Mission_Hunt` `game.exe` 0x655270, slot vtable +0x1D0) rozkłada jednostkę z `DeploysInto=`, gdy dom jest ludzki **albo** `DeploysInto` jest na `[AI] BuildConst` (MCV) **albo jednostka ma cel** (`TarCom`). Hunt wybiera cel z całej mapy, więc komputer rozkłada maszynę w chwili, gdy drużyna zaczyna polować, tam, gdzie stoi. Drużyny AdvAI z atakiem bezpośrednim mają skrypt Hunt.
- Plac budowy z MCV rozkłada `UnitClass::Mission_Guard` (hak Vinifery 0x101173CB: `DeploysInto` na `BuildConst`).
- **Zwijanie:** `AdvAI_Undeploy_Enforcers` (0x100C3B89), tylko dom 2 (Allies), co 2250 klatek: każdy budynek z `UndeploysInto=`, bez celu, którego jednostka ma broń główną (place budowy jej nie mają), dostaje misję Unload.
- `Artillary=yes` (tylko `DBFRT` w DTA) **nie** steruje rozkładaniem. Sprawia tylko, że komputerowa jednostka, która się w taki budynek rozkłada, nie odpowiada ogniem (`TechnoClassExt::_Is_Allowed_To_Retaliate`); do tego dochodzi obsługa w `Try_To_Deploy` i rysowaniu.
- **Łatka `patch-vinifera-siegeai.ps1`** ([[mods/terran-ai]]): komputer rozkłada się dopiero, gdy cel jest w zasięgu jego broni głównej (`ObjectClass::In_Range`, vtable +0x138, współrzędna celu z `AbstractClass::Center_Coord` +0x4C) i jednostka może się rozłożyć w miejscu, w którym stoi. Inaczej podjeżdża i walczy jako jednostka. Zwijanie działa też dla domu 6 (Terran). Zmienia to zachowanie każdej komputerowej maszyny rozkładanej: Enforcera, Vulture'a ze Spider Mines, okrętów. **(niezweryfikowane w grze)**

## Poziomy trudności

Lobby ma 7 poziomów AI, a `spawn.ini` zapisuje je w `[HouseHandicaps] MultiN=` (wartość 0–6). `Spawner_Config_AI_Difficulty_To_Game_AI_Difficulty` (0x1016F2A0) mapuje wartości 0, 1, 2, 3, 4, 5, 6 na 0, 1, 2, 6, 5, 4, 3. `HouseClassExt::_Assign_Handicap` (0x100C5F18) wybiera sekcję handicapu z tablicy reguł (7 sekcji) i ustawia `Difficulty` domu (+0x58) na tę wartość, ale dla 3–6 na 0. Wynik (nazwy sekcji według komentarzy DTA, kolejność w tablicy wywnioskowana):

| Lobby | Sekcja handicapu | `BuildTime` | `Cost` | inne | AdvAI `Difficulty` |
|---|---|---|---|---|---|
| Easy AI (test 2026-10-30: `Multi2=2`) | `[Difficult]` | 2,8 | 1 | | 2: taktyki od klatki 1500, odstęp 1200, 1 zbieracz/rafinerię, nie sprzedaje rafinerii |
| Medium AI | `[Normal]` | 1,33 | 1 | opóźnienia napraw i budowy | 1: odstęp 600, 1,5 zbieracza |
| Hard AI | `[Easy]` | 1,0 | 1 | | 0: odstęp 200, 2 zbieracze |
| Very Hard … Ultimate | `[VeryEasy]`, `[BrutallyEasy]`, `[ExtremelyEasy]`, `[UltimatelyEasy]` | 0,95 / 0,9 / 0,8 / 0,66 | 0,8 / 0,675 / 0,55 / 0,3 | | 0 |

Wartości z `Advanced AI.ini` (nadpisuje Rules). Wszystkie: `ROF=0.91`, `Groundspeed=0.9`. Handicapy i `Difficulty` dotyczą każdego domu komputera tak samo, a taktyki DTA nie zależą od poziomu. Frakcje SC dostają więc te same poziomy co DTA bez żadnych dopisków. Różnica „AI DTA” to klony jednostek `AI*` (`Buildability=AIOnly`, `GuardRange=12`, wersje gracza `HumanOnly`), niezależne od poziomu; pliki `INI/Map Code/AI Discounts *.ini` nie są podpięte w `MPMaps.ini`.

## Twarde odwołania do domów (`HeapID`)

GDI (0): inna szybkość składu ataku bezpośredniego. Nod (1): szybkość rushu, wróg-Nod odblokowuje budowę sensorów. Allies (2): +1 obrony po 20000 klatkach, zwijanie Enforcerów (z łatką siegeai także Terran, 6). Nic poza tym dla 6–8, więc nowe frakcje są „neutralne”.

## Ryzyka dla frakcji SC

- Terran `GDI1`: zrobione w [[mods/terran-ai]].
- **Protoss `GDI2`:** zrobione w [[mods/protoss-ai]] (2026-10-30): `SCPASM` na `BuildRefinery`, `TDHARV` bez `GDI2`, taktyki `House=8`, budynki i badania `AIBuildThis=yes`. Do tego łatka `patch-vinifera-navalai.ps1`. `AdvancedAI_AI_Unit` wpisuje zastępczego zbieracza i MCV do `House->BuildUnit` (0x100BC0F9), a Probe i `SCPDNEX` mają `Naval=yes`. Lądowa kolejka zostawała wtedy pełna na zawsze, co blokowało piechotę i budowę. Łatka kieruje takie jednostki do `BuildNavalUnit` (+0x34).
- **Zerg `Nod1`:** AI nie rozstawia dronów, więc nie zbuduje bazy ([[engine/zerg-ai]]).

## Klasyczne AI (Advanced AI wyłączone)

Bez checkboxa: klasyczne `AI_*` i AITriggery z `AI.ini` (pole Side = `ActsLike + 1`, [[engine/triggers-and-dialogue]]). `Extreme AI.ini` to wariant klasycznego AI (inne koszary, opóźnienia drużyn). Frakcje SC nie mają AITriggerów, więc bez Advanced AI nie atakują.
