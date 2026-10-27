# Transporty: kto wsiada, kiedy i jak (piechota, pojazdy, transport w powietrzu)

Jak `game.exe` (TS 2.03 + DTA) decyduje, czy jednostka może wsiąść do transportu, i dlaczego latający transport SC (Dropship, Shuttle)
przyjmuje pasażerów w powietrzu bez łatania exe. Ustalone z deasemblacji 2026-10-27, **(niezweryfikowane w grze)**.

Źródła: `game.exe` + `Game.pdb` (capstone, `vdis.py`), `Vinifera.pdb` (pola klas), `INI/Rules.ini` (`[LST]`, `[NLST]`, `[APC]`),
`INI/Game Options/StarCraft.ini` (`[SCDROP]`), `INI/Map Code/Terran Faction.ini` (`[SCPSHUT]`, `[SCPSHUT2]`).

## Klucze

- `Passengers=N` (`TechnoType+0x31C`, `Max_Passengers`): liczba miejsc. **Każdy pasażer zajmuje 1 miejsce**, czołg tyle samo co
  Marine (TS nie ma `Size`/`SizeLimit` z RA2).
- `IsVehicleTransport=yes` (`TechnoType+0x449`): klucz dodany przez DTA do `game.exe` (napis w `.p_text` `0x86D5FA`, odczyt w
  `TechnoTypeClass::Read_INI` `0x63BA43` → `0x86BE30`). Bez niego wsiada **tylko prawdziwa piechota** (`[InfantryTypes]`). Z nim
  także pojazdy, ale nie inny transport z `IsVehicleTransport` (tak działają poduszkowce `LST`/`NLST`).
- Jednostki SC „piechota” (`SCMARINE`, Firebat, Ghost, Medic, wszystkie jednostki Gatewaya) są w modzie **pojazdami SHP**, więc
  do transportu wsiadają dopiero przy `IsVehicleTransport=yes`.

## Przebieg wsiadania (adresy w `game.exe`)

1. **Kursor „wsiądź”** (`What_Action` pasażera na transporcie):
   - piechota: `InfantryClass::What_Action` `0x4D7449`–`0x4D74C7`;
   - pojazd: kod DTA `0x86BE60` (koniec `UnitClass::What_Action`): transport to `UnitClass`, `Passengers > 0`, `IsVehicleTransport`.
   W obu: **lokomotor transportu nie może się ruszać** (`ILocomotion::Is_Moving`, slot `+0x10`), inaczej kursor „nie można” (`ACTION_NOMOVE` 0x1E).
   Potem pytanie `RADIO_CAN_LOAD` (15) do transportu, `RADIO_ROGER` = `ACTION_ENTER` (3).
2. **`RADIO_CAN_LOAD` w transporcie** (`UnitClass::Receive_Message` `0x64F57B`): sojusznik, wolne miejsce i komórka pod transportem
   **nie jest wodą ani brzegiem**. Wysokości transportu nikt nie sprawdza.
3. **Dokowanie** (`RADIO_DOCKING` 14, `0x64F734`): transport nie może się ruszać ani mieć `NavCom` (`+0x278`), potem `RADIO_MOVE_HERE`
   każe pasażerowi jechać do komórki transportu.
4. **Wejście** (`Per_Cell_Process` pasażera): piechota w **tej samej komórce** co transport (`0x4D3A14`), pojazd w promieniu ±2 komórek
   (kod DTA `0x86BF90` → `0x6515DF`), potem `CargoClass::Attach`. Porównywane są tylko komórki (`Get_Cell`), wysokość nie.
5. **Rozładunek** (`UnitClass::Mission_Unload` `0x6540C0`): transport musi stać (`Is_Moving`), pasażerowie wychodzą na wolne pola
   wokół komórki transportu, na ziemi (`Get_Cell_Height`, `Closest_Free_Spot`). Lądować nie trzeba.

## Co z tego wynika dla latających transportów

- `Is_Moving` lokomotora **Fly** (`0x499550`) = `IsMoving` (`+0x2C`) albo `PitchAngle > 0`. Łatka `patch-flyhover.ps1`
  ([[engine/fly-locomotor]]) zeruje `IsMoving` i `NavCom` przy zawisie, więc wiszący transport Fly przyjmuje pasażerów.
- Lokomotor **jumpjet** (`0x4F9620`, `Is_Moving` = pole `+0x20`) zatrzymany zawsze opada i siada. Dlatego Dropship był „na ziemi albo
  w ruchu” i nie dało się do niego wsiąść w powietrzu.
- Warunek dla gracza: **transport musi stać** (zawisnąć). Do lecącego nie wsiądziesz (kursor „nie można”).
- Nad wodą i brzegiem `RADIO_CAN_LOAD` odmawia (z myślą o poduszkowcach).

## Zastosowanie (2026-10-27, prośba użytkownika: „ludziki i czołgi mają wsiadać do statku, który jest na górze”)

| Transport | Zmiana |
|---|---|
| `SCDROP` Dropship ([[mods/starcraft-terran-units]]) | `IsVehicleTransport=yes`; jumpjet → Fly (`FlightLevel=450`, `ROT` 8 → 16), `Naval=yes` + `BuiltAt=SCSTAR` (ze Starportu, jak okręty), nowy opis |
| `SCPSHUT`, `SCPSHUT2` Shuttle ([[mods/protoss-faction]]) | `IsVehicleTransport=yes`, `PipScale=Passengers`, nowy opis; to samo w `tools/build-scprotoss.ps1` |

Overlord Zergów nie jest transportem (`Passengers` brak, zob. [[mods/zerg-faction]]).

**Możliwe skutki uboczne (niezweryfikowane):** do transportu da się prawdopodobnie wsadzić też latające jednostki bez
`IsVehicleTransport` (Wraith, Mutalisk) i sojusznicze jednostki innych frakcji, bo kod DTA tego nie sprawdza. Misja ARKA 2
(`Maps/Missions/arka02.map`) ma własną kopię `[SCDROP]` w wersji jumpjet, zmiana jej nie dotyczy, dopóki misja nie zostanie
wygenerowana ponownie (`tools/build-arka02-mission.ps1`).
