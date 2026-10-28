# Dźwięki zaznaczania budynków SC

Budynki Terran, Zergów i Protossów odtwarzają przy zaznaczeniu swój dźwięk ze StarCrafta (np. Academy `tacwht00`), tak jak w SC. Stan: zainstalowany 2026-10-26, **niezweryfikowane w grze**.

Źródła: `arr/units.dat` (pola „What Sound Start/End”, offsety 9524/9980), `arr/sfxdata.dat/.tbl` z CASC SC: Remastered; deasemblacja `game.exe` ([[engine/sounds-aud]]); `INI/Game Options/StarCraft.ini`, `INI/Map Code/SC Factions/`, `INI/Sound.ini`.

## Jak to działa

- Silnik gra `VoiceSelect=` także dla budynków: `TechnoClass::Select` nie filtruje klasy obiektu (szczegóły w [[engine/sounds-aud]]).
  Dźwięk słychać tylko przy zaznaczeniu **własnego** budynku (jak u jednostek).
- Który dźwięk przypisać, wynika z danych SC (`units.dat` → `sfxdata`), a nie z nazw plików. Część budynków w SC tylko **klika**
  (`Misc\Button.wav`): Command Center, Barracks, Factory, Starport, Bunker, Infested Command Center, Mature Chrysalis, Stargate.
  Robotics Support Bay gra `Misc\UPiWht00.wav`, oba Overmindy `ZO1Wht00`, oba Cerebraty `ZCbWht00`.
- Dodatkowo:
  - 11 latających wersji budynków Terran (`<ID>F`, [[mods/starcraft-terran-buildings]]) ma ten sam dźwięk co budynek, jak w SC;
  - rozstawione jednostki-budynki (`SCSIEGB`, `SCSIEGB2`, `SCHEROB`, `SCZLRB`, `SCZLRB2`, `SCPARBD`, `SCPARBD2`) dostają
    `VoiceSelect` swojej formy ruchomej (z `UndeploysInto=`), czyli np. Siege Tank w Siege Mode mówi jak czołg.
- Badania (`SCR*`, `SCY*`, `SCQ*`) i miny pajęcze nie mają dźwięku.

## Pliki

| Co | Gdzie |
|---|---|
| Generator | `Modding/tools/build-scbldgsounds.ps1` (bez parametrów buduje tylko MIX, `-Install` także INI) |
| Dźwięki | `MIX/ECACHE79.MIX`: 47 plików `SBW*.AUD` (`SBW` + rdzeń nazwy SC, np. `SBWTAC`, `SBWZHA`, `SBWPNE`, `SBWBUTTO`) |
| Sound.ini | `[SoundList]` klucze `SBW01`–`SBW47` (na końcu sekcji) |
| INI budynków | blok `; >>> SC building select sounds` na końcu `StarCraft.ini` (Terran) i w warstwie `INI/Map Code/SC Factions/050 SC building select sounds.ini` (Zerg, Protoss; [[engine/map-code-layers]]); tylko `VoiceSelect=` |

Blok działa, bo klient scala powtórzone sekcje i późniejszy klucz wygrywa ([[engine/ini-layering]]). Generatory innych modów
podmieniają swoje bloki w miejscu, więc ten blok zostaje na końcu (w kodzie mapy: nad warstwami frakcji, bohaterów i badań Zergów). Ponowne uruchomienie generatora podmienia własne wpisy.

**Numer MIX:** `game.exe` ładuje `ECACHE%02d.MIX` w pętli od 99 do 0 i pomija brakujące (`0x4E3F77`), więc 06–79 też działają.
Wybrałem 79, żeby zostawić wolne 81.

## Odinstalowanie

Usuń `MIX/ECACHE79.MIX`, blok `SC building select sounds` ze `StarCraft.ini`, warstwę `INI/Map Code/SC Factions/050 SC building select sounds.ini`
(w warstwie nad nią, `060 SC workers.ini`, ustaw `BasedOn=040 Zerg research.ini`) i linie `SBW01`–`SBW47` z `Sound.ini`
(kopie: `.bak` obok plików, jeśli nie istniały wcześniej).

## Głośność pojedynczego dźwięku

Tabela `$Gain` w generatorze (np. `SBWTAC = 2.5`, Academy głośniej na prośbę użytkownika 2026-10-26), potem uruchomić skrypt
bez `-Install` (przebudowuje tylko MIX, przy zamkniętej grze). WAV-y SC mają szczyty ok. 100% skali, więc zwykłe mnożenie
przesterowałoby dźwięk. Skrypt używa miękkiego limitera `tanh(g·x)/tanh(g)`: ciche części rosną ok. `g` razy, szczyty zostają
pod pełną skalą. Alternatywa: `Volume=` w sekcji `[SBW…]` Sound.ini. DTA ma tam wartości 1.5 (`MWAVE1`, `CHRONO3`), ale czy
silnik nie obcina ich do 1.0, nie sprawdzałem **(niezweryfikowane w grze)**.

## Do sprawdzenia w grze

- Czy dźwięk gra przy kliknięciu budynku (i czy nie gra przy budynkach wroga).
- Głośność: domyślne `[Defaults]` z Sound.ini (`Volume=1.0`). Jeśli za cicho lub za głośno, dodać sekcje `[SBW…]` w bloku Sound.ini.
