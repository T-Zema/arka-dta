# Debugowanie i weryfikacja zmian

Gdzie szukać przyczyny crasha i jak sprawdzić, czy silnik wczytał zmianę.

Źródła: `Debug/` (DEBUG_*.LOG, EXCEPT_*.TXT, STACK_*.LOG, CRASHDUMP_*.DMP), `spawn.ini`.

## Pliki

- `Debug/DEBUG_<data>.LOG`: pełny log każdego uruchomienia gry.
- `Debug/EXCEPT_<data>.TXT` + `STACK_*.LOG` + `CRASHDUMP_*.DMP`: powstają tylko przy crashu.
  Seria crashy z 19-10-2026 jest sprzed tych modów (stan zastany).

## Co sprawdzać w logu

- `Read_Scenario_INI - Filename is spawnmap.ini`, `[Spawner] Start_Game`: start misji.
- `Calling Rule->Addition() with scenario overrides` + `Rules: Processing <Typ> (Count: N)`: przetwarzanie nadpisań z mapy.
  **Wzrost `Count`** względem pierwszego przebiegu oznacza, że mapa dodała nowe typy. Przy modzie z nowymi
  jednostkami `UnitTypes`/`InfantryTypes` powinny wzrosnąć o ich liczbę.
- `[WARNING]`: brakujące pliki (np. `Failed to load MAPS*.MIX!` jest normalne).

## Procedura przy crashu

1. Najnowszy `EXCEPT_*.TXT`: adres i moduł.
2. Ostatnie linie `DEBUG_*.LOG` przed crashem: na jakim typie albo etapie się zatrzymał.
3. Bisekcja: wyłączaj połowę nowych sekcji w mapie, aż crash zniknie.
4. Zawsze można wrócić do `<plik>.bak` albo do `original/` w archiwum moda.

Crash w kodzie `game.exe` (adres w `Call Stack` z nazwą funkcji z `Game.pdb`, śmieciowy EIP jak `0x66666666`): najpierw
podejrzewaj własne łatki binarne, cofnij je (`tools/patch-game.ps1 -Revert`) i zobacz [[engine/game-exe-patching]].
Zachowanie silnika bez crasha: sonda pamięci (`tools/*probe.ps1`). Lista dotychczasowych pomyłek: [[workflow/known-mistakes]].
