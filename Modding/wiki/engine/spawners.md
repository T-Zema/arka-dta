# Jednostki wypuszczające samoloty (spawner Vinifery) i generator niewidzialności

Jak w DTA działają lotniskowce (jednostka wypuszcza samoloty, które wracają i się odnawiają) i jakie są granice: co może być
„matką”, co może być wypuszczane, gdzie działa ukrywanie sojuszników.

Źródła: `INI/Rules.ini` (`[CARRIER]`, `[CARRTRUK]`, `[HornetLauncher]`, `[TruckHornetLauncher]`, `[ORCAHORN]`, `[DLHORNET]`, `[SBOATMSL]`,
`[P941MISSILE]`, `[SGEN]`, `[DMSA]`, `[MAD]`, `[DESCORTG]`, `[AircraftTypes]`), `INI/Art.ini` (`[ORCAHORN]`, `[ORCAHORNS]`), napisy
w `game.exe` i `Vinifera.dll`, kod Vinifery na GitHubie (`src/extensions/aircraft/aircraftext_hooks.cpp`).

## Lotniskowiec (spawner)

- **Matka:** dowolna jednostka. W DTA to statek `[CARRIER]` (Aircraft Carrier GDI, 2700) i **pojazd gąsienicowy** `[CARRTRUK]`
  (Drone Launcher). Klucze Vinifery na matce:
  ```ini
  Primary=HornetLauncher      ; broń z Spawner=yes
  Spawns=ORCAHORN             ; AircraftType wypuszczany
  SpawnsNumber=4              ; ile naraz
  SpawnRegenRate=900          ; po ilu klatkach odnawia zestrzelony
  SpawnReloadRate=100         ; przezbrojenie po powrocie
  SpawnSpawnRate=25           ; odstęp między startami
  SpawnLogicRate=5
  MaxRandomSpawnOffset=15
  ```
- **Broń startowa:** `Spawner=yes`, `Damage=1`, `Warhead=Super`, `Projectile=Invisible`, `OmniFire=yes`, zasięg 18–40.
  Zasięg broni = odległość, na jaką matka wysyła samoloty. Pocisk z `AA=yes` (np. `Invisible3`) pozwala startować też na cele powietrzne.
- **Wypuszczany typ:** musi być `AircraftType` (`Spawned=yes`, `Ammo=`, `Landable=yes`, `Selectable=no`, `Insignificant=yes`,
  lokomotor samolotu). Wcześniej odkryte: spawner nie działa dla piechoty ani pojazdów ([[mods/starcraft-research]], mina).
  Vinifera pozwala, żeby wypuszczone samoloty startowały w powietrzu i dzieliły komórkę z matką.
- Inne spawnery w DTA: rakiety okrętów (`SBOATMSL`, `P941MISSILE`, `SpawnReloadRate=0` = nie wracają).

## Powrót do matki (ważne)

`SpawnManagerClass::AI` (stan `Returning`) przyjmuje samolot tylko w komórce matki i przy `|Z(samolot) − Z(matka)| < 20`; wyjątek
(`Z(samolot) ≤ Z(matka) + 20`) dla matek z `HoverLocomotionClass`. **Matka nie może wisieć w powietrzu** (lokomotor Fly z `FlightLevel`):
samoloty wtedy nigdy nie wracają, chyba że lata na ich wysokości przelotowej (Carrier Protossów, testy 2026-10-25). Pierwsze rozwiązanie: matka na ziemi, np. jak poduszkowce DTA
(Drive + `SpeedType=Hover` + `MovementZone=Fly`). **Ale** wtedy samoloty z `Landable=yes` wiszą wokół niej na wysokości 450 (test 5). Wersja obecna: matka z lokomotorem Fly i `FlightLevel=450` (= `[General] FlightLevel`), samolot z `Landable=no` i `FlightLevel=450`, czyli obie na tej samej wysokości ([[mods/protoss-faction]]).

**Fale:** menedżer wypuszcza nową falę (`Launching`) tylko, gdy **wszystkie** samoloty są `Preparing` albo `Dead`, a z `Cooldown`
wraca do `Idle` dopiero, gdy żaden nie jest `Attacking` ani `Returning`. Jeden samolot, który krąży (nie może wylądować albo
ciągle „atakuje”), blokuje matkę na stałe. Sprawdzony cykl DTA (`DLHORNET`): `Ammo=1` + broń `Burst=2`, `ROF=3`, `Range=3.2`,
`MinimumRange=1.5`, czyli jeden przelot, dwa strzały i powrót. Spawner niczego nie loguje (stanów nie widać w `Debug/*.LOG`).

**Potwierdzone w kodzie tej wersji Vinifery** (`Vinifera.pdb`: `SpawnManagerClass::AI` = RVA `0x157E33`; deasemblacja capstone przez
`pixi exec`): przy `0x101580B8` porównanie komórek spawnu i matki, przy `0x101580CB` `abs(Z_spawn − Z_matki) < 0x14` (Z = pole obiektu
`+0x48`), potem wyjątek Hover (`Z_spawn ≤ Z_matki + 0x14`). Do pomiaru w grze: `Modding/tools/spawnprobe.ps1` (tylko odczyt pamięci).
Loguje co pół sekundy pozycję X/Y/Z, komórkę, misję i `limbo` Carrierów i Interceptorów do `tools/spawnprobe.log`.

**Pomiar sondą (2026-10-26, Carrier Fly na Z = 450, Interceptor `Landable=no`, `FlightLevel=450`):** Interceptory startują, dostają
cel (`Attack`), strzelają (amunicja 1 → 0) i przechodzą w powrót. Wtedy jednak mają **pusty cel ruchu (`NavCom` = 0)**, stoją
w miejscu ataku (8–10 pól od Carriera) i przełączają misję `Move`/`Guard`. Spawner przy każdej nieudanej próbie lądowania daje
tylko `Assign_Mission(MISSION_MOVE)`, bez nowego celu. Zadokowały wyłącznie, gdy były już przy Carrierze (ta sama komórka, Z 450).
Wniosek: samolot z **`Landable=no` nie przyjmuje matki jako celu lotu**. Potrzebne jest `Landable=yes` (jak Hornety DTA) i matka
na wysokości przelotowej samolotu. Sonda: `tools/spawnprobe.ps1` (przesunięcia z `Vinifera.pdb`: `AircraftClass::Class` +0x354,
`AttacksRemaining` +0x36C, `TechnoClass::Ammo` +0x134, `TarCom` +0x11C, `FootClass::NavCom` +0x278, `UnitClass::Class` +0x360).

**Przyczyna i łatka (2026-10-26).** Winny nie jest spawner, tylko `game.exe`: `AircraftClass::Assign_Destination` (`0x40E1B0`, adres
z `Game.pdb`) zaczyna od `if (target->In_Air()) { FootClass::Assign_Destination(nullptr); return; }` (slot vtable `+0x58` =
`AbstractClass::In_Air`, z `Vinifera.pdb`). Samolot nigdy nie przyjmuje latającego obiektu jako celu lotu, więc wracający
Interceptor dostaje `NavCom` = 0. Łatka **`tools/patch-spawnreturn.ps1`** zamienia 7 bajtów pod `0x40E1C5` na `jmp` do jaskini
`0x86CF00` (zerowy ogon sekcji `.p_text`, wykonywalnej; ogon `.text` zajmują łatki lotników i morfów). Jaskinia zostawia test
`In_Air()`, a dla celu w powietrzu pyta o RTTI tym samym wywołaniem interfejsu, którego funkcja używa pod `0x40E1E1`
(`mov ecx,[edi+4] / lea eax,[edi+4] / push eax / call [ecx+0Ch]`). Odrzuca tylko `RTTI_AIRCRAFT` (2), więc latające pojazdy
(Carrier Protossów, okręty Terran) są przyjmowane. Skrypt sprawdza oryginalne bajty (jaskinia musi być zerowa), robi
`game.exe.bak` i ma `-Revert`. Test na kopii: deasemblacja poprawna, drugie uruchomienie daje „already patched”, a po cofnięciu
plik jest identyczny z oryginałem. Bajty za `VirtualSize` sekcji są w pamięci (strona pliku), tak jak jaskinie lotników w `.text`.

**Pierwsza wersja łatki CRASHOWAŁA** (2026-10-26, `EXCEPTION_ACCESS_VIOLATION` pod `0x66666666`, stos
`AircraftClass::Assign_Destination 0x40E1C8`). Zmieniała 7 bajtów w miejscu: `call [eax+78h]` (What_Am_I) / `cmp al,2` / `jne`.
Celem lotu bywa jednak **`CellClass`** (vtable `0x6CCE98`), a ta nie jest `ObjectClass` i nie ma `What_Am_I` w slocie `+0x78`.
Lekcja: na wskaźniku `AbstractClass*` wolno wołać tylko sloty `AbstractClass` (np. `+0x58` In_Air), a RTTI brać przez interfejs
`[obj+4]`. Skrypt rozpoznaje bajty tej wersji i nadpisuje je. Ogólne zasady łatania: [[engine/game-exe-patching]]. **Wszystkie łatki `game.exe` naraz
(np. po aktualizacji DTA): `tools/patch-game.ps1`** (lotnicy, morfy Zergów, powrót spawnów; rozpoznaje wariant `-Debug` łatki lotników).
`patch-flyhover.ps1 -FromBackup` startuje od czystej kopii, więc po nim trzeba puścić `patch-game.ps1`.
**Działa w grze (sonda + potwierdzenie użytkownika, 2026-10-26):** brak crasha, gra zakończona normalnie (exit code 0). Interceptory bez amunicji dostają
`Move` z `NavCom` = adres swojego Carriera, a potem dokują (`limbo` 0→1). W ~3,5 min walki było 297 wylotów i powrotów,
a najdłuższe wiszenie bez rozkazu powrotu trwało ~5 s. Uwaga przy czytaniu sondy: gdy numer klatki stoi, gra jest
spauzowana lub zakończona, a „wiszące” jednostki tylko tak wyglądają.

## Grafika samolotów: tylko voxel

Wszystkie 20 typów z `[AircraftTypes]` DTA ma w Art.ini `Voxel=yes` (wyjątek `P941MISSILE` nie ma sekcji art). Vinifera nie dodaje
rysowania samolotów SHP (`aircraftext_hooks.cpp` ma tylko łatkę Carryalla). Samolot SHP nie był testowany **(niezweryfikowane)**.
Bezpiecznie: `Image=` istniejącego voxela, np. `ORCAHORNS` (Hornet Drone Launchera). Dlatego „latające SHP” w modach SC to
pojazdy z lokomotorem Fly ([[engine/fly-locomotor]]).

## Ukrywanie sojuszników

`CloakGenerator=yes` + `CloakRadiusInCells=` ma w DTA tylko budynek `[SGEN]` (Stealth Generator Nod, `Powered=true`).
`CloakRadiusInCells` występuje też na budynkach z deployu (`DMSA`, `MAD`, `DESCORTG`), ale tam jako promień innych efektów.
Jednostka może ukrywać sojuszników tylko pośrednio: `DeploysInto=` budynek-generator, a `UndeploysInto=` z powrotem (Arbiter w
[[mods/protoss-faction]]). `game.exe` zna też `IsMobileStealth` (kierunek przed deployem, nie generator w ruchu).
