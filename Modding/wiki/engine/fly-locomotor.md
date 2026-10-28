# Lokomotor Fly na pojazdach: dlaczego lądują i łatka `game.exe`

Pojazd (`VehicleType`) z lokomotorem samolotu `{4A582746-9839-11d1-B709-00A024DDAFD1}` lata, ale silnik każe mu lądować przy każdym
zatrzymaniu. Same klucze INI tego nie zmienią, dlatego jest łatka binarna `Modding/tools/patch-flyhover.ps1`.

Źródła: `game.exe` (TS 2.03 + DTA, CRC `0x3E8F84B0`, deasemblacja capstone przez `pixi`), `Vinifera.pdb` (rozkład klas przez
`llvm-pdbutil dump -types`), źródła Vinifery i TSpp na GitHubie (`src/locomotors/flylocomotion.h`, `aircraftext_hooks.cpp`,
`buildingext_hooks.cpp`), logi `Debug/DEBUG_25-10-2026_02-*.LOG`, test użytkownika 2026-10-25.

## Wzorzec w grze
`[HUNTSEEK1]` (Hunter-Seeker) to `VehicleType` z `Locomotor=Fly`, `FlightLevel=400` (per typ), `MovementZone=Fly`.
Okręty SC w tej wersji: [[mods/starcraft-terran-units]] (`SCWRAF`, `SCVALF`, `SCVESF`, `SCBCF`).

## Budowa w fabryce
Fabryka z bramą (`WeaponsFactory` + wyjazd przez drzwi) jest zła dla latających pojazdów. Działa „stocznia” Vinifery:
budynek `Factory=UnitType`, `WeaponsFactory=yes`, `Naval=yes` (+ `ExclusiveFactory=yes`), jednostka `Naval=yes` + `BuiltAt=<budynek>`.
Hak `_BuildingClass_Exit_Object_Naval_Patch` stawia produkt na wolnej komórce obok (`Nearby_Location`). Potwierdzone w grze (Starport).

## Pola `FlyLocomotionClass` (obiekt; metody COM dostają `this` = obiekt+4)
`+0x08` LinkedTo, `+0x14` DestinationCoord, `+0x2C` IsMoving, `+0x30` FlightLevel, `+0x38` TargetSpeed (double), `+0x40` CurrentSpeed
(double), `+0x48` IsTakingOff, `+0x49` IsLanding, `+0x4A` WasLanding, `+0x54` IsElevating. Vtable `0x6D0188`: `Process` `0x499600`,
`Move_To` `0x4997C0`, `Stop_Moving` `0x499AB0`, `Is_Moving` `0x499550`, `Apparent_Speed` `0x49CEC0` (jedyny hak Vinifery).
`TechnoClass`: `+0x11C` TarCom, `+0x134` Ammo, `+0x210` EMPFramesRemaining; `What_Am_I()` = vtable `+0x78` (`RTTI_UNIT=1`, `RTTI_AIRCRAFT=2`), ale **tylko dla obiektów `ObjectClass`**; dla dowolnego
`AbstractClass*` (np. `CellClass`) RTTI daje interfejs `[obj+4]` → `call [ecx+0Ch]` (stdcall), zob. [[engine/spawners]].

## Skąd lądowanie
1. `Move_To(COORD_NONE)` (jednostka się zatrzymuje): pyta obiekt o `IFlyControl::Landing_Altitude`. Pojazd nie ma `IFlyControl`
   (mają go tylko samoloty), więc wysokość lądowania = 0 i zawsze `IsLanding=1` w bieżącym miejscu.
2. W `0x499F20` (co klatkę): dotarł do celu, `TargetSpeed == 0` i brak `TarCom` (albo `Ammo == 0`) → `IsLanding=1`.
3. `Stop_Moving`: szuka wolnej komórki obok i każe tam usiąść.
4. **Główna droga po każdym rozkazie ruchu:** w trasie do celu (`0x49BBA0`, miejsce `0x49C537`–`0x49C566`) przy odległości < `0x80`
   leptonów od celu, bez `IsElevating` i przy małej prędkości → `IsLanding=1`. (Gałąź z `IFlyControl`/`Ammo == 0` dotyczy tylko
   `IsElevating`.) Pierwsza wersja łatki tego nie miała i test 2026-10-25 wykazał, że okręty dalej siadają.
Inne zapisy `IsLanding=1` w kodzie Fly: `0x49CBA0` (nikt jej nie wywołuje) i gałąź `IsElevating` + `Ammo == 0` (nie dotyczy).
Wywołania `+0x1A8`/`+0x1AC` w `Process` to `MissionClass::Commence`/`Ready_To_Commence` (z PDB), nie lądowanie.
Lądowanie wykonuje `0x499CA0` tylko przy `IsLanding`/`IsTakingOff`. Przy `Dest = NONE` żaden kod ruchu nie działa, więc jednostka wisi.
Lawirowanie przy ataku wynikało z tego samego: zatrzymanie w zasięgu → start lądowania → ruch → przelot.

## Łatka `patch-flyhover.ps1`
Trzy skoki do jaskini kodu (zera na końcu `.text`, `0x6C9A40–0x6C9B00`). Dla obiektów, które **nie** są samolotem:
- A (`0x4998AC`): `Move_To(NONE)` = `IsMoving=0`, prędkości 0, `Dest=NONE`, bez lądowania (wiszenie w miejscu);
- B (`0x49AEDA`): pomija lądowanie po dolocie;
- C (`0x49C566`, dodane po teście 1): pomija lądowanie przy celu;
- D (`0x499AC7`): `Stop_Moving` = `Move_To(NONE)`;
- E (`0x49CCC1`, po teście 2): `Do_Turn` obraca `SecondaryFacing` (`+0x1C8`), czyli kadłub samolotu, ale w pojeździe to **wieżyczka**.
  Okręt bez wieżyczki nie obracał się do celu (`FIRE_FACING`), więc podlatywał i lawirował. Strzelał w miejscu tylko wtedy, gdy cel
  akurat był przed nim. Łatka: nie-samoloty obracają `PrimaryFacing` (`+0x1B0`).

Test 2 (łatka A–D): okręty **cały czas latają** (potwierdzone w grze), ale czasem lawirują przy ataku → łatka E.
- F (procedura „dotarłem”, `0x6C9B80`, wywoływana z B i C, po teście 3: E nie pomogło w pełni): `IsMoving` zeruje **tylko**
  procedura lądowania (`0x49BB43`). Bez lądowania lokomotor wiecznie zgłaszał „lecę”, więc misja ruchu się nie kończyła, a jednostka
  krążyła wokół punktu celu jak samolot nad lotniskiem. Lawirowała tylko czasem, bo `Move_To(NONE)` od misji (np. przy celu
  w zasięgu) to przerywało. F: `IsMoving=0`, `IsElevating=0`, prędkości 0, `Dest=NONE`, czyli to samo co łatka A. **(niezweryfikowane w grze)**
- G (`0x49BE59`, po teście 4: „lawiruje, gdy cel jest za daleko”): lot do celu (`0x49BBA0`) tylko ustawia `PrimaryFacing.Set_Desired`
  w stronę celu i leci dalej do przodu, skręcając z `ROT`. Cel w środku okręgu skrętu = krążenie. Samoloty mają osobną gałąź
  (`IFlyControl`, ataki z przelotu przy różnicy > 45° w promieniu `0x300`). Łatka: nie-samolot odchylony od kierunku do celu
  o więcej niż 45° (`0x2000`) ma `CurrentSpeed=0`, więc najpierw obraca się w miejscu jak helikopter. Test 5: z progiem 22,5° i niskim
  `ROT` (3–8) okręty „tańczyły” (stań, obróć się, ruszaj, znowu stań), dlatego próg zwiększono do 45°, a `ROT` okrętów podniesiono
  (Wraith 24, Valkyrie 18, Vessel 16, BC 12).
- Test 6: okręty „świrują i obracają się jak powalone”. Przyczyna: łatka E kierowała `Do_Turn` (logika strzału, co klatkę w stronę
  wroga) na kadłub także w locie, a lot do celu ciągnie kadłub w stronę punktu docelowego. Oba kierunki walczyły, a G zatrzymywała
  okręt przy każdym szarpnięciu. Poprawka E: kadłub tylko przy zawisie (`Dest.X == COORD_NONE.X`, `[edx+10h]`), w locie oryginał
  (`SecondaryFacing`, bez skutku). **(niezweryfikowane w grze)**
  Prędkość docelowa przy celu: < `0x80` → 0, < `0x200` → 0,5, < `0x300` → 0,75 (`0x49C537`–`0x49C5A9`).
**Diagnostyka (`-Debug`, po teście 7: „dalej się kręcą”):** zaczepy na wejściu `Move_To` (`0x4997C0`), `Stop_Moving` (`0x499AB0`)
i `Do_Turn` (`0x49CCB0`) oraz w ARRIVE i G piszą do logu gry (`Debug/DEBUG_*.LOG`) przez printf gry `0x4082D0` (przechwycony przez
Vinifera) linie `FLY <ms GetTickCount> MoveTo|Stop|Turn|Arrive|TurnInPlace u=<jednostka> from=<adres wywołującego>`. Tylko
nie-samoloty. `GetTickCount` z IAT `[0x6CA134]`. ARRIVE przeniesione do `0x6C9C40`, zaczepy w `0x6C9CC0–0x6C9FC0`.
**Wynik logu (test 8, `DEBUG_25-10-2026_13-21-47.LOG`, 170 tys. linii `FLY`):**
- `Do_Turn` **ani razu** (łatka E nie ma znaczenia dla ataku). `MoveTo` głównie z `0x4A4B0E` i `0x40A46D`, `Stop` z `0x4A4B62`
  (logika podejścia do celu jednostki, co ~400 ms).
- Kręcenie: okręt obraca się do punktu (`TurnInPlace diff 7CD4 → 299C`), rusza na 1–2 klatki, **przelatuje nad punktem**
  (`diff` skacze na `7FF8` ≈ 180°), obraca się, znowu przelatuje… Silnik uznaje dotarcie tylko przy < `0x80` i prawie zerowej
  prędkości, a lotnik nigdy tego nie spełnia (samoloty kończą lot lądowaniem).
- Poprawka (w jaskini G, przed obrotem w miejscu): nie-samolot bliżej niż `0x100` (1 pole) od celu → ARRIVE od razu. **(niezweryfikowane w grze)**
  Ryzyko: jeśli punkt podejścia jest na samej granicy zasięgu, okręt może zawisnąć tuż poza zasięgiem. Wtedy zmniejszyć promień.
- Test 9 (`DEBUG_25-10-2026_13-52-49.LOG`): **okręty leżały na ziemi**. Nowa jednostka dostaje `MoveTo` do pola obok Starportu
  (< 1 pole), więc ARRIVE następowało przed startem, co 0,4 s w kółko. Poprawka: ARRIVE w promieniu pola tylko gdy
  `IsElevating == 0` (tak chroni się też oryginalne lądowanie przy celu) i `HeightAGL` (vfunc `+0x19C`) ≥ `FlightLevel − 0x40`.
  Uwaga: `ObjectClass+0x28` to `Strength`, nie wysokość (z PDB; `Position` = `+0x40`).
- Test 10 (`DEBUG_25-10-2026_14-13-20.LOG`): okręty latają, ale przy dalekim celu **obracają się bez końca** nad punktem podejścia
  (`TurnInPlace diff 7FFD → 3332 → 7FFD…`: punkt pod samym okrętem, kierunek do niego skacze o 180°). ARRIVE się nie
  uruchamiało, bo `IsElevating` = `0x49D2D0` = „cel lotu w powietrzu (`Dest.Z` > teren + `0x78`) **albo** jest `TarCom`”,
  czyli przy ataku zawsze 1. Pole `FlightLevel` na wzgórzach = FL typu + wysokość terenu. Nowy warunek: < 1 pole
  i `HeightAGL ≥ FlightLevel typu (TechnoType vfunc +0xB4) − 0x40`, bez `IsElevating`.
- Test 11 (`DEBUG_25-10-2026_17-39-21.LOG`): **prawie działa** (latają, startują, nie kręcą się), ale przy dalekim celu okręt
  **zamierał przed celem**: ten sam `MoveTo` (np. `22144,17792`) co 0,4 s i od razu ARRIVE. ARRIVE w promieniu 1 pola zostawiało
  okręt tuż przed polem podejścia, z którego dopiero jest zasięg. Poprawka: w promieniu 1 pola okręt **pełznie z prędkością 25%**
  (`TargetSpeed = CurrentSpeed = 0.25`), a ARRIVE następuje dopiero < `0x40`.
- Test 12: „jest lepiej”, ale **w trybie guard okręty same nie atakują**. Przyczyna: koniec prawdziwego lądowania (`0x49BB43–0x49BB76`)
  robi `IsMoving=0`, `Move_To(NONE)` **i `LinkedTo->Assign_Destination(nullptr, true)`** (vfunc `+0x350`, czyści `NavCom`). ARRIVE
  tego nie robiło, więc misja ruchu nigdy się nie kończyła (log: ten sam `MoveTo` co 0,4 s z `0x40A46D`/`0x4A4B0E` + `Arrive`),
  a jednostka w misji ruchu nie szuka celów (`Target_Something_Nearby` działa w `FootClass::Mission_Guard`, hak Vinifery
  `0x4A1AAE`). ARRIVE woła teraz `Assign_Destination(nullptr, true)`. **(niezweryfikowane w grze)**
- Przy okazji (PDB): `TechnoClass` vtable `+0x2C4` = `Is_Renovator`, `+0x2B0` = `Threat_Range`, `+0x2E0` = `Target_Something_Nearby`,
  `+0x2F4` = `Greatest_Threat`; `Evaluate_Object` ok. `0x62D0F0`, odległość do celu liczona w 3D.
Skrypt ma `-FromBackup` (zaczyna od `game.exe.bak`), bo zmiana kodu w jaskini nie pasuje do sprawdzania „oryginał albo nowa wersja”.

## Automatyczne celowanie w lotników (łatka `patch-flyertarget.ps1`, 2026-10-27)

Zgłoszenie z ARKA 1: Marines i Rocket Soldierzy w Guard nie strzelali sami do Mutaliska, choć na rozkaz trafiali. Przyczyna w `game.exe` (`Game.pdb` + capstone):
- `TechnoClass::Greatest_Threat` (`0x62DC80`) szuka celów w powietrzu tylko wtedy, gdy metoda ma `THREAT_AIR`. Daje ją `WeaponTypeClass::Allowed_Threats` (`0x681360`), gdy pocisk broni ma `AA=yes` (`AG=yes` dodaje cele naziemne `0xB8`).
- Ten skan przechodzi listę warstwy TOP (`0x7A2000`) i bierze z niej tylko `RTTI_AIRCRAFT` (2) oraz piechotę z `IsJumpJet` (InfantryType `+0x4B6`).
- Latający pojazd Fly to `RTTI_UNIT` (1) i też jest w warstwie TOP: `FlyLocomotionClass::In_Which_Layer` (`0x49CD90`) zwraca 4, gdy `HeightAGL > 0`, w przeciwnym razie 2. Pętla go jednak pomija.
- Zwykły skan komórek (`Evaluate_Cell`, `0x62D8D0`) czyta listy okupantów komórki. `FootClass::Mark` (`0x4A0590`) wpisuje tam tylko obiekty z warstwy GROUND, więc lotnika i tam nie ma.

Łatka zmienia `cmp eax,2 / je` na `dec eax / cmp al,1 / jbe`, więc pętla przyjmuje RTTI 1 i 2. Dalej działa jak dla samolotów: pomija obiekty, które wylądowały (`In_Which_Layer` = GROUND), a `Evaluate_Object` (zastąpione przez Viniferę) sprawdza właściciela, zasięg, widoczność i maskę typów. Działa wszędzie, także w skirmishu: AI też będzie samo strzelać do latających pojazdów gracza. Hak Vinifery w tej funkcji (`0x62DD70`, medycy) jest wcześniej i nie przeszkadza. **Potwierdzone w grze 2026-10-27** (ARKA 1: Marines i Rocket Soldierzy w Guard sami strzelają do Mutaliska). Wyjątek od 2026-10-28: AA Aliantów nie wybiera lotników SC samo (pancerze Vinifery, [[engine/air-armor]]).
**Uwaga (sesja Zergów, 2026-10-25):** `game.exe` ma drugą łatkę, `tools/patch-buildup.ps1` (długie Buildupy Zergów), z jaskinią pod
`0x6C9FC0–0x6C9FCB`, czyli zaraz za `$caveEnd` tej łatki. `-FromBackup` ją kasuje, więc potem trzeba uruchomić `patch-buildup.ps1`
(bez niej morfy Zergów nigdy się nie kończą). Nie rozszerzać jaskiń poza `0x6C9FC0` ([[engine/buildup-timing]]).
Samoloty idą oryginalną ścieżką. Skrypt sprawdza oryginalne bajty, robi `game.exe.bak` i ma `-Revert` oraz `-Exe <kopia>` do testów.
Miejsca już połatane pomija, więc nowsza wersja skryptu dokłada brakujące do starej łatki (sprawdzone: wynik identyczny jak łatka
na czystym pliku, `-Revert` przywraca oryginał bajt w bajt). Test 1 (łatka A/B/D, CRC `0x80AD1062` w `LaunchVinifera.log`):
bez crasha, ale okręty nadal siadały → dodane C.
Syringe/Vinifera nie sprawdzają sumy `game.exe` (Vinifera nie używa `declhost`). Uwagi: aktualizacja klienta DTA może przywrócić
`game.exe` (wtedy uruchomić skrypt ponownie); gra sieciowa z kimś bez łatki może się rozsynchronizować.
**(niezweryfikowane w grze)**: wiszenie bez rozkazu, obrót do celu i ciągły ogień z zawisu, zachowanie Hunter-Seekera.
