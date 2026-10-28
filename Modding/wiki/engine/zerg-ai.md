# AI Zergów: jak komputer buduje bazę dronami

Jak komputer w misji stawia budynki Zergów po zergowemu: Wylegarnia wykluwa drona, dron idzie na miejsce na creepie i się przepoczwarza. Silnikowe AI tego nie umie, więc robi to wielokrotnego użytku funkcja `Add-ZergBuilder` z `Modding/tools/MissionKit.ps1`. Pierwsze użycie: [[missions/arka-04-zielony-krysztal]]. **Test użytkownika 2026-10-28: AI rozstawia drony (deploy działa w grze).** Nie wiadomo jeszcze, czy drony wyprodukowała Wylegarnia, czy wylęgły się ze strażnika (`80`).

Źródła: `Maps/Missions/cr07.map` (dekompilacja `tools/dump-triggers.ps1`: drużyny „Deploy Power Plant #1”… z deployerem `DEPPP` i skryptem `4 Move to cell` → `9 Deploy`), `se03.map`, skan `Maps/Missions` (akcja `4 Create Team` w 47 mapach, skrypt `9 Deploy` w 27), `Map Editor/FinalSun/FSData.ini` (`[Scripts]`, `[Actions]`), `Modding/tools/patch-zergbuild-grid.asm` (`UnitClass::Try_To_Deploy`: początek budynku = komórka jednostki + `AdjacentCoord[7]`), `INI/Rules.ini` `[IQ]`, [[mods/zerg-creep]], [[mods/zerg-faction]], [[mods/zerg-research]].

## Dlaczego zwykłe AI nie wystarcza

- Komputer w misji buduje tylko **węzły bazy** (`NodeCount`, `000=TYP,x,y` w sekcji domu), i to po „konstruktorowemu”: budynek wyrasta na miejscu z fabryki `Factory=BuildingType`, której typ jest w `[AI] BuildConst` (Vinifera bez tego nie zbuduje nic). Tak samo buduje w skirmishu.
- Zergi nie mają ConYardu: każdy budynek to dron `SCZD<x>` z `DeploysInto=SCZ<x>`. Laboratoria z [[mods/zerg-research]] (Hydralisk Den, Evolution Chamber, Spire) mają co prawda `Factory=BuildingType` i są w `BuildConst`, więc węzły by „wyrosły”. Pierwsza wersja ARKA 4 tak robiła. To jednak nie jest mechanika Zergów (użytkownik 2026-10-27: „tu jest odrębna mechanika… zrób to porządnie”).
- **Skirmish:** AI frakcji Zerg nie zbuduje sama żadnego budynku. Do tego potrzebna byłaby łatka `game.exe`/Vinifery w planowaniu bazy AI („zamiast budynku wyprodukuj drona i rozstaw go”). To osobny projekt, nie zrobiony.

## Mechanizm (wzorzec DTA `cr07`)

1. Drużyna z jednym dronem i skryptem `4,<y*1000+x>` (Move to cell) → `9,0` (Deploy). Dokładnie tak `cr07` rozstawia bazę Sowietów deployerami.
2. Trigger z `4 Create Team` tworzy drużynę. Członków, których brakuje, **produkuje dom w swoich fabrykach** (silnik RA/TS liczy jednostki potrzebne niepełnym drużynom w `AI_Unit`), o ile dom ma `IQ` ≥ `[IQ] Production` (5) i włączoną produkcję (`3 Production Begins`). Dron kosztuje tyle co budynek i wykluwa się w Wylegarni/Hive (`Factory=UnitType`, „stocznia” larw: dron ma `Naval=yes` i `BuiltAt=SCZHAT,SCZHIV`).
3. Dron idzie na komórkę i robi deploy: kokon (Buildup), potem budynek, potem jego własny creep.

`Add-ZergBuilder` dokłada do tego **strażnika**: tag komórki na celu („Entered by <dom Zergów>”) gasi trigger zapasowy. Jeśli w ciągu `$Watchdog` sekund (domyślnie 300) żaden dron nie doszedł (brak kasy, fabryki albo produkcja AI nie zadziałała), ta sama drużyna wykluwa się akcją `80` przy Wylegarni. Baza rośnie w każdym przypadku.

## Użycie

```powershell
. "$tools\MissionKit.ps1"     # po zdefiniowaniu Team/Trigger/Ev/Act/Reinf/Enable/Disable w generatorze
Add-ZergBuilder 'Nod1' $H.Nod1 22 $nodes['Nod1'] 300 110 'zbC'
#               dom    nr domu wp Wylegarni  plan (typ, lewy-górny x, y)  start  co ile s  prefiks kluczy
```

Wymagania w mapie:
- typy dronów `SCZD<x>` w mapie (domknięcie typów SC), w mapie: `Owner=` z domami gniazd, `TechLevel` ≤ poziomu domu, **bez `Prerequisite`** (grupy `[PrerequisiteGroups]` frakcji, np. `ZHATCHERY`, w misji kampanii nie istnieją);
- dom: `IQ=5`, kredyty (ARKA 4: 8000 na gniazdo), Wylegarnia albo Hive;
- **creep pod każdym polem budynku** (`patch-zergbuild.ps1`; wyjątek: Hatchery/Lair/Hive). Generator ARKA 4 wybiera miejsca tylko w odległości ≤ 7,5 pola od źródła creepu: dziura Wylegarni/Hive leży na polu (1,1) fundamentu, dziura kolonii na (0,0), żyły rosną w kole o promieniu ok. 8,5. Kolonia zaplanowana wcześniej też liczy się jako źródło;
- creep w misji kampanii: zob. „Creep w misji kampanii” w [[missions/arka-04-zielony-krysztal]] (`VeinGrowthEnabled`, animacje-siewniki, `ImmuneToVeins`).

**Położenie budynku:** `UnitClass::Try_To_Deploy` stawia lewy górny róg fundamentu w komórce drona + `AdjacentCoord[7]` (NW, czyli −1, −1), chyba że typ to „mobile deployer”. Funkcja wysyła więc drona na (róg + 1, róg + 1).

## Ograniczenia i ryzyka **(niezweryfikowane w grze)**

- Czy AI produkuje drony w „stoczni” larw (Vinifera `Naval`/`BuiltAt` dla domu komputera w misji). Jeśli nie, budowę ciągnie strażnik (`80`), a dron jest wtedy darmowy.
- Dron, który nie może się rozstawić (brak creepu, zajęte pole), stoi na miejscu. Po `9 Deploy` w skrypcie nie ma nic więcej, bo `37` mogłoby usunąć drona w trakcie deployu.
- Brak odbudowy: zniszczony budynek z planu nie wraca (tag drużyny nie przechodzi na budynek po deployu, więc nie ma jak rozpoznać, który zniknął).
- Tempo creepu: pierwsze drony ruszają od 300 s. Do tego czasu creep wokół Wylegarni powinien urosnąć (`VeinholeGrowthRate=60` klatek, 1–5 pól na krok).
