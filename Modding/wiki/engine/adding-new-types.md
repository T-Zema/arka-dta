# Dodawanie nowych typów jednostek i budynków (bez Rules.ini)

Mapa albo opcja gry może zarejestrować zupełnie nowy typ. Tak robią oficjalne mapy DTA (np. Bunzilla w `bunny_lockdown.map`).

Źródła: `Maps/Co-Op/bunny_lockdown.map`, `Maps/Default/the_experiment_lab.map`, `Maps/Default/car_park.map`, log Debug (liczniki typów rosną po wczytaniu scenariusza), `INI/Game Options/Super Mod.ini`.

## Przepis

1. **Rejestracja na liście** w mapie / opcji gry (klucze dowolne, byle unikalne w tym pliku):
   ```ini
   [VehicleTypes]
   SM01=SMFLYMAM
   [InfantryTypes]
   SM01=SMTESLACMD
   [BuildingTypes]
   FB1=FBROBLI
   ```
   Klucze z Rules.ini (`A_01=...`) nie kolidują, bo silnik szuka po wartości (find-or-make).
2. **Pełna sekcja typu.** `$Inherits` z Rules nie działa (zob. [[engine/ini-layering]]), więc kopiujemy
   wszystkie klucze z jednostki-wzorca: `Locomotor`, `MovementZone`, `SpeedType`, `Category`, głosy, `Explosion` itd.
   Bez `Locomotor` jednostka się nie porusza.
3. **Grafika przez `Image=`.** Art.ini nie da się rozszerzyć z mapy. Pożyczamy więc grafikę istniejącej
   jednostki: `Image=4TNK` daje wygląd, `Cameo` i FLH z sekcji `[4TNK]` w Art.ini.
4. **Bronie, głowice i pociski** z Rules wolno używać po nazwie (`Primary=120mmRA`). Nowe definiujemy w tym samym pliku.
   Silnik tworzy je przy pierwszym odwołaniu, rejestrować nie trzeba.
5. **Animacje** (`AnimList=`, `Anim=`) muszą istnieć jako sekcje w **Art.ini** (np. `ATOMSFX`, `TWLT100`, `CRUMUZ_N`, `GFIRE1`).
6. **`ScrapExplosion=` obok `Explosion=`.** Opcja lobby „Scrap Debris” (domyślnie włączona) każe Vinifera podmienić
   listę `Explosion` na `ScrapExplosion` (`technotypeext.cpp`: `if (IsScrapMetal) Explosion = ScrapExplosion`).
   Typ bez `ScrapExplosion` ginie wtedy **bez animacji i bez dźwięku** (przypadek marines SC). Wzorce DTA: `FRAGG1_SCRAP`,
   `ART-EXPU_SCRAP`, budynki `FBALL1_SCRAP,FBALL2_SCRAP,FBALL3_SCRAP`.
7. **Unikalne ID** z prefiksem moda (`SM…` dla Super Mod, `FB…` dla Frostbite), żeby nie trafić na istniejącą sekcję w Rules.

## Nowe budynki: klucze, bez których budynek „stoi, ale nie działa”

- **Rafineria i lądowa fabryka pojazdów potrzebują `Bib=yes`.** Mają go wszystkie w DTA (`PROC`, `TDPROC`, `RAPROC`,
  `WEAP`, `AFLD`, `RAWEAP`; bez niego tylko stocznia `GSYRD`). Bez bibu harvester nie ma gdzie zadokować:
  krąży i nie rozładowuje się, a log pokazuje serię `Regular findpath failure` z jednej komórki
  (przypadek `SCREFI`, zob. [[mods/starcraft-terran-buildings]]). Rafineria musi też być na liście `Dock=` harvestera.
- **Nowy Construction Yard musi trafić do `[AI] BuildConst=`** (w Rules: `GFACT,NFACT,AFACT,SFACT`). Vinifera
  (`_HouseClass_Has_Prerequisites_BuildConst`) pozwala budować cokolwiek tylko, gdy dom ma typ z tej listy.
  Samo `ConstructionYard=yes` + `Factory=BuildingType` nie wystarcza. Objaw: MCV rozkłada się w nowy conyard, ale pasek budowy
  jest pusty. Gdy gracz ma obok zwykły conyard, wszystko wygląda dobrze, więc błąd wychodzi dopiero przy starcie samym MCV
  (przypadek `SCCC`, 2026-10-24). Ta sama lista steruje też rozkładaniem MCV (`UnitClass_What_Action_BuildConst`) i AI.
- Animacje budynku (`TurretAnim`, `ActiveAnim`…) trzeba zarejestrować w `[Animations]` **w Rules.ini**, nie w opcji gry,
  bo ich SHP ładują się z teatrem przed doklejeniem opcji (zob. [[engine/shp-graphics]]).

## Jednostki bez ikonki: postaw na mapie

Grafiki „bossów” (króliki `BUNZILLA`, `BUNNYBR`…, `BRIG`) nie mają `Cameo`. Nie dajemy ich do budowania
(`TechLevel=-1`), tylko dopisujemy do sekcji mapy:
```ini
[Units]      ; N=Dom,Typ,HP(256=100%),X,Y,Kierunek,Misja,Tag,Weteran,Grupa,NaMoście,...
47=Allies,FBBRIGCHEM,256,93,89,64,Guard,None,0,-1,0,-1,0,0
[Infantry]   ; N=Dom,Typ,HP,X,Y,Podkomórka(0-4),Misja,Kierunek,Tag,...
59=Allies,FBBUNZILLA,256,86,90,0,Guard,64,None,0,-1,0,1,0
```
Wolne pola: zbuduj siatkę zajętości z `[Structures]` (+ `Foundation=` z Art.ini), `[Units]`, `[Infantry]`
i `[Terrain]` (klucz = `y*1000 + x`). Skrypt jest w [[workflow/tooling]].

## Latające pojazdy (jumpjet)

Silnik obsługuje pojazdy SHP z lokomotorem jumpjet (wzorzec: `[TRANV]`, cywilny Chinook jako pojazd):
```ini
Locomotor={92612C46-F71F-11d1-AC9F-006008055BB5}
MovementZone=Fly
JumpjetSpeed=14
JumpjetClimb=10.0
JumpjetCruiseHeight=400
JumpjetAcceleration=0.5
JumpjetTurnRate=5
JumpjetNoWobbles=true
```
Piechota latająca: wzorzec `[JUMPJET]` (`JumpJet=yes` + ten sam lokomotor, `MoveToShroud=no`).
Pojazd z wieżą w trybie jumpjet (Flying Mammoth) jest **(niezweryfikowane w grze)**.

**Test 2026-10-25 (okręty SC):** pojazd jumpjet **ląduje, gdy stoi**, a na ziemi nie obraca się do celu, więc strzela tylko raz.
TS nie ma `BalloonHover` (brak w `game.exe`). Jednostka bojowa, która ma stale latać, powinna być **piechotą** `JumpJet=yes`
(wisi w powietrzu, sekwencje `Hover`/`FireFly`). Wzorzec: `SCWRAI` w [[mods/starcraft-terran-units]].
Użytkownik ocenił piechotę jumpjet jako słabą (8 kierunków, szczegóły nieznane).

**Pojazd z lokomotorem samolotu (Fly)** `{4A582746-9839-11d1-B709-00A024DDAFD1}`: TS sam tak robi Hunter-Seekera
(`[HUNTSEEK1]`: `VehicleType`, `FlightLevel=` per typ, `MovementZone=Fly`). Testowe okręty `SCWRAF` i spółka **(niezweryfikowane w grze)**.
Samoloty (`[AircraftTypes]`) muszą być wokselami, a bezczynne lądują. Nowy jumpjet Vinifery (`NewJumpjetLocomotionClass`) też ląduje
przy braku celu (kod na GitHubie: `src/new/locomotion/newjumpjetlocomotion.cpp`, `Process_Hover`).

Inne lokomotory: gąsienice/koła `{4A582741-9839-11d1-B709-00A024DDAFD1}`, piechota `{4A582744-9839-11d1-B709-00A024DDAFD1}`.

**Nowa piechota musi mieć `Locomotor={4A582744-…}` i `MovementZone=Infantry`** (ma je każda piechota DTA). Bez nich piechota
co prawda chodzi, ale stojąc ciągle się kręci, „teleportuje się” w obrębie komórki i nie atakuje. Tak było z Zergami
2026-10-25 (zob. [[mods/starcraft-zerg]]). Najpewniej silnik bierze wtedy domyślny lokomotor pojazdów.
