# Supermoce

Jakie supermoce są w DTA i jak je podpiąć pod dowolny budynek.

Źródła: `INI/Rules.ini` (`[SuperWeaponTypes]` linia ~34284, budynki z `SuperWeapon=`), `Maps/Missions/FRSTBITE.MAP` (`[MultiLauncher]`).

## Lista `[SuperWeaponTypes]`

| ID | Nazwa w grze | Kto ma w Rules |
|---|---|---|
| `MultiSpecial` | Nuclear Strike | `RAMSLO` Missile Silo (Allies, Soviet; wymaga `RATECH`) |
| `IonCannonSpecial` | Ion Cannon | `EYE` (GDI), `COMM1` (ukryty) |
| `ChemicalSpecial` | Chemical Missile | `TMPL` Temple of Nod |
| `VortexSpecial` | Chrono Vortex | `RAPDOX` Chronosphere (Allies, wymaga `RAATEK`) |
| `DropPodSpecial` | Paratroopers | — |
| `AirstrikeSpecial` | Airstrike | — (używa broni `MultiLauncher`) |
| `EMPulseSpecial` | Chrono Vortex (EMP) | — |
| `HuntSeekSpecial` | Chrono Tank | — |
| `FirestormSpecial` | Firestorm | — |

## Podpinanie

Budynek dostaje supermoc kluczem `SuperWeapon=` (drugą przez `SuperWeapon2=`):
```ini
[AWEAP]
SuperWeapon=IonCannonSpecial
```
Wybieraj budynek, który ma **tylko strona gracza** (np. `AWEAP`, `RATENT`). Gdyby to był budynek wspólny
(`RADOME`: Allies,Soviet), supermoc dostałoby też AI wroga.

## Pułapki

- **Każdy silos DTA ma własną supermoc:** `RAMSLO` → `MultiSpecial`, `TMPL` → `ChemicalSpecial`, `RAPDOX` → `VortexSpecial`
  (wszystkie `Type=MultiMissile`/`ChemMissile`, `NukeSilo=yes`). Typ `MultiMissile` to w DTA ogólny „start z silosu”: broń supermocy
  (`WeaponType=NukeWeaponS2`, głowica `NukeImpactWH` → `NUKEINIT` → `NUKEDOWN` → `ATOMEXPL`) leci z budynku, a silos gra `SpecialAnim`.
  Nowy silos `SCNUKE` z **pożyczonym** `MultiSpecial` (i z definicją tylko w opcji gry) nigdy nie startował: `SPECIAL_PLACE` w logu,
  silos się nie otwiera, zero komunikatów. Ani `Powered`, ani wyrównanie kluczy z `RAMSLO`, ani `IsTemple` nie pomogły.
  Prawdopodobnie silnik/Vinifera wiąże supermoc z jednym typem budynku (pole `SuperWeaponTypeClass::AuxBuilding`).
  **Poprawka 2026-10-25 (niezweryfikowane w grze):** własna supermoc `SCNukeSpecial` (kopia `MultiSpecial`)
  i `SCNUKE` dopisany też do `Rules.ini` (`[BuildingTypes]` na końcu, `[SuperWeaponTypes] 10=`, `TechLevel=-1`; włącza go opcja gry).
- **Każda supermoc musi mieć własne `Action=` (przyczyna niestrzelającej nuki Terran, 2026-10-25).** Klik na mapie
  (`0x004790CD`) woła `SuperWeaponTypeClass::From_Action` (`0x0060D5F0`): bierze **pierwszą** supermoc z listy, której `Action`
  (`+0x84`) równa się akcji kursora, i wysyła `SPECIAL_PLACE` z jej numerem. Dlatego DTA daje każdej supermocy inną akcję
  (`MultiSpecial`=`DropPod`, `ChemicalSpecial`=`IonCannon`, `IonCannonSpecial`=`ChemBomb`, `VortexSpecial`=`EMPulse`,
  `AirstrikeSpecial`=`Nuke`, `EMPulseSpecial`=`DontUse8`, `DropPodSpecial`=`ParaDrop`). Kopia `MultiSpecial` z `Action=DropPod`
  odpala sowiecką `MultiSpecial`. Gracz bez `RAMSLO` jej nie ma, więc nic się nie dzieje, a własna supermoc zostaje „gotowa”.
  Wolne akcje z kursorem nuki (`INI/Action.ini`, kursor `AirStrike`): **`NuclearStrike2`**, **`NuclearStrike3`**
  (tak robi DTA w mapach `red_line.map`, `se11.map`). `SCNukeSpecial` = `NuclearStrike2`, test `SCNukeTest` = `NuclearStrike3`
  (test usunięty; od 2026-10-25 `NuclearStrike3` ma `SCZWrathSpecial` Overminda Zergów, [[mods/zerg-heroes]]). Wolnych akcji z celownikiem już nie ma
  (zostały tylko `DontUse2–8` z kursorem zwykłym).
  Potwierdzone sondą pamięci [`Modding/tools/nukeprobe.ps1`]: 21× `SPECIAL_PLACE`, a `SCNukeTest` dalej `IsReady=1` z niezmienionym timerem.
  **Po zmianie akcji (test 2026-10-25 03:07–03:16):** `SCNUKER` (6×) i `SCNUKE` (7×) dostają misję `0x15`, `Status` przechodzi
  `1 → 3` (`LAUNCH_UP` → rakieta wystrzelona) i wraca do `Guard`, a supermoc ładuje się od nowa.
  **Użytkownik potwierdził w grze: nuka `SCNUKE` działa.** Test `SCNUKER`/`SCNukeTest` usunięty, `RechargeTime=9.5` przywrócony.
- **Jak `game.exe` odpala supermoc (disassembly 2026-10-25, wersja DTA):**
  - Klik → `From_Action` (wyżej) → `SPECIAL_PLACE` → `HouseClass::Place_Special_Blast` (`0x004BE9E0`, bez warunków) → `SuperClass::Discharged` (`0x0060B8E0`).
    `Discharged` woła `Place` tylko gdy timer ładowania chodzi (`Control.Started` `+0x1C` ≠ -1) oraz `+0x29` i `+0x2B` (`IsReady`) ≠ 0.
    Po `Place` zawsze zeruje `IsReady` (supermoc ładuje się od nowa, nawet gdy start się nie udał).
  - `Place` (`0x0060BF70`): `switch` po `Type=` (`+0x7C`). `MultiMissile` (0) i `ChemMissile` (5) idą **tą samą gałęzią** `0x0060C1A7`.
    Wcześniejsza notka, że `ChemMissile` szuka budynków `IsTemple`, była błędna: `+0x823` to `EMPulseCannon`, `IsTemple` to `+0x804`.
  - Pętla `0x0060C41C`: przechodzi po **typach** budynków (`0x7E21A4`, liczba `0x7E21B0`) i bierze **pierwszy** z `NukeSilo` (`+0x81A`),
    którego `SuperWeapon`/`SuperWeapon2` (`+0x830`/`+0x834`, indeks supermocy z `From_Name`) = `HeapID` supermocy (`+0x60`,
    ustawiany w konstruktorze). Potem `HouseClass::Find_Building(typ)` (`0x004C0240`: licznik domu `+0x328` > 0, potem szuka budynku
    gracza nie w limbo) i `Assign_Mission(0x15)`. Jeśli nie znajdzie budynku, **nie szuka dalej**.
  - Wniosek: silos z cudzą supermocą (`MultiSpecial`) nie zadziała, bo pierwszym pasującym typem jest `RAMSLO`.
    Z **własną** supermocą statycznie wszystko się zgadza, a mimo to test `SCNUKER` (grafika RA, własna `SCNukeTest`) nie strzela.
    Przyczyna jest w czasie gry. Do diagnozy służy sonda pamięci `nukeprobe.ps1` (zob. [[mods/starcraft-terran-buildings]]).
- **Z kodu Vinifery** (`src/extensions/building/buildingext_hooks.cpp`, kopia w `%TEMP%\vinsrc`): `Mission_Missile` silosu to
  `INITIAL` (gra `SpecialAnim`) → `DOOR_OPENING` (czeka na `SpecialAnimTwo`) → `LAUNCH_UP` → `LAUNCH_DOWN` (czeka na `SpecialAnimThree`).
  `AuxBuilding` supermocy to tylko warunek: budynek daje supermoc, gdy dom ma `AuxBuilding` jako spełnione wymaganie (`_Fetch_Super_Weapon`).
  Wybór budynku startowego robi oryginalny `SuperClass::Place` w `game.exe` (Vinifera tylko podmienia ID supermocy, hak 0x0060C49E).
- Ikonka jest, ale kliknięcie nie daje celownika (brak `SPECIAL_PLACE` w logu) = supermoc niegotowa: ładuje się albo jest wstrzymana
  przez brak prądu przy `IsPowered=true`. Dla `SCNukeSpecial` ustawione `IsPowered=false`, `SCNUKE Powered=no` **(niezweryfikowane)**.
- **Nie dawaj supermocy `AuxBuilding=` = budynek, który ją daje.** Z `AuxBuilding=SCNUKE` silos zniknął z paska budowy
  (wygląda na to, że `AuxBuilding` to budynek wymagany, więc silos wymagał sam siebie). Klucz usunięty. Żaden silos DTA go nie ma.

- **Nowy silos atomowy (`NukeSilo=yes`, `MultiSpecial`/`ChemicalSpecial`) bez sekwencji `SpecialAnim` nie wystrzeli.**
  Celowanie działa, ale pocisk nie startuje (test `SCNUKE`, 2026-10-24). Wszystkie silosy DTA (`RAMSLO`, `TMPL`) mają w Art.ini
  `SpecialAnim` (otwarcie, `StartAnims=NUKEUP1RA`/`NUKEUP1` = wznosząca się rakieta), `SpecialAnimTwo` (pętla
  `LoopCount=31`), `SpecialAnimThree` (zamknięcie), wersje `…Damaged` i `HideDuringSpecialAnim=yes`. W anim `End=` to
  **liczba klatek**, nie ostatnia klatka. Animacje trzeba zarejestrować w `Rules.ini [Animations]` (zob. [[engine/adding-new-types]]).
  Wzorzec zrobiony od zera: `SCNUKE_A1…A3D` w [[mods/starcraft-terran-buildings]].

- Frostbite nadpisuje `[MultiLauncher]` (głowica atomowa), więc `AirstrikeSpecial` byłby tam atomowym nalotem.
- `RAIRON` Iron Curtain ma `TechLevel=-1` i nie ma przypisanej supermocy.
