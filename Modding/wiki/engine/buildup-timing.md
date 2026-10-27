# Czas animacji budowy (Buildup) i czas produkcji: skąd się biorą i jak je zmienić

Animacja budowy każdego budynku trwa w silniku prawie tyle samo, ok. 81 ticków, bez względu na liczbę klatek. Czas produkcji wynika z ceny, a Vinifera pozwala go przeskalować dla każdego typu osobno. Dłuższy Buildup wymaga łatki `game.exe` (`tools/patch-buildup.ps1`).

Źródła: deasemblacja `game.exe` (TS 2.03 + DTA, capstone przez `pixi exec`, skrypty w scratchpadzie sesji mapowej: `tsdisasm.py`, `tsscan.py`, `tscave.py`),
Vinifera `src/extensions/techno/technoext.cpp` (`TechnoClassExtension::Time_To_Build`), `src/extensions/factory/factoryext_hooks.cpp` (`FactoryClassExt::_Start`),
`src/extensions/building/buildingext_hooks.cpp` (`_Shape_Number`), `INI/Rules.ini [General]` (`BuildSpeed`, `BuildupTime`, `MultipleFactory`).

## Buildup

- `BuildingClass::Begin_Mode` (`0x42F020`) bierze etap i tempo gotowe z typu: `Anims[BSTATE_CONSTRUCTION]` = `{Start +0x538, Count +0x53C, Rate +0x540}`.
- Tempo liczy się raz, przy ładowaniu `<Buildup>.SHP`:
  - `0x4403DD` (funkcja `0x440370`) i `0x443C7B`: `Count = klatki SHP / 2` (bez cieni), `Rate = ftol(BuildupTime × 900 / Count)`.
    Tą ścieżką idą zwykłe budynki DTA (`NewTheater=no`). `BuildupTime=.09` daje 81 ticków na całą animację.
  - `0x43FD52`: `Count = wszystkie klatki`, `Rate = 75 / Count` (dzielenie całkowite). To budynki z grafiką zależną od teatru.
- Skutki:
  - Liczba klatek nie zmienia długości, tylko płynność.
  - Przy ponad 81 (75) klatkach `Rate = 0` i budowa **nigdy się nie kończy**.
  - `BuildupTime` jest globalne dla wszystkich budynków.
- Sprzedaż (`MISSION_DECONSTRUCTION`) odtwarza Buildup od końca w tym samym tempie (`_Shape_Number` Vinifery).

### Łatka `tools/patch-buildup.ps1`

`Rate ≥ 1` we wszystkich trzech miejscach (jaskinia **`0x6C9FC0`**: `call _ftol; test eax,eax; jnz; inc eax; ret`, oraz przepisane 17 bajtów pod `0x43FD56`).
**Konflikt 2026-10-25:** jaskinia była najpierw pod `0x6C9C40`. Nowa wersja `patch-flyhover.ps1` (procedura F i jaskinie H–Str do `0x6C9FC0`)
nałożona przez `-FromBackup` zajęła to miejsce i skasowała tę łatkę. `build-sczergbase.ps1` wykrył brak łatki i odmówił instalacji.
Jaskinia jest teraz w ostatnich 64 bajtach `.text` (`0x6C9FC0–0x6CA000`). **Po każdym `patch-flyhover.ps1 -FromBackup` trzeba uruchomić
`patch-buildup.ps1`**, bo przywrócenie oryginału kasuje tę łatkę.
Buildup z N > 81 klatkami trwa wtedy dokładnie **N ticków** (1 klatka na tick), a krótsze się nie zmieniają, więc zwykłe budynki DTA działają po staremu.
Zastosowanie: morf budynków Zergów ([[mods/zerg-faction]]). `-Revert` przywraca oryginalne bajty. Jaskinia leży zaraz za jaskiniami
[[engine/fly-locomotor]] (`patch-flyhover.ps1`, do `0x6C9C40`). `patch-flyhover.ps1 -FromBackup` odtwarza `game.exe.bak`, a to kasuje tę łatkę:
trzeba ją wtedy puścić ponownie. Aktualizacja klienta DTA, która podmieni `game.exe`, też ją usuwa.
- Powtórzone klatki mogą w SHP wskazywać te same dane (offset w nagłówku klatki), więc 864 klatki morfu Hatchery to 334 KB (`ScZerg.WriteShared`).

### Ticki a sekundy

Ticki to klatki logiki gry. „Minuta” z Rules (`BuildSpeed`, `BuildupTime`) to 900 ticków, co odpowiada 15 FPS.
**Zmierzone w grze 2026-10-25 (`tools/morphprobe.ps1`, licznik `Frame` 0x7E4924): 45,2 klatki na sekundę** przy domyślnej prędkości
skirmisha (`spawn.ini` `GameSpeed=1`), choć lobby opisuje ją jako „60 FPS” (`Resources/SkirmishLobby.ini` `cmbGameSpeedCap`: Maximum, 60, 45…).
W praktyce wszystko trwa więc 3× krócej, niż wynika z „minut”. Morfy Zergów liczę przy 45 FPS (pierwsza wersja liczyła w „minutach”
i była 4× za szybka, druga zakładała 60 FPS z opisu lobby; zob. [[mods/zerg-faction]]).

## Czas produkcji

- Bazowo `Cost × BuildSpeed` (`0.8` min na 1000 kredytów, 900 ticków = 1 „minuta”), czyli `koszt × 0,72` ticka.
- Vinifera `Time_To_Build`: × `BuildSpeedBias` domu, × **`BuildTimeMultiplier=`** typu (Vinifera, issue #657), ÷ kara za brak prądu,
  × `MultipleFactory` (0.75) za każdą dodatkową fabrykę tej samej kategorii. Fabryki „naval” (`Naval=yes`) liczą się osobno (`Factory_Count(RTTI, PRODFLAG_NAVAL)`).
- Fabryka dzieli czas na **54 kroki** z tempem co najmniej 1 tick (`FactoryClassExt::_Start`, `clamp(time / 54, 1, 255)`), więc nic nie buduje się krócej niż 54 ticki.
