# Dźwięki: Sound.ini i pliki AUD

Jak DTA przechowuje dźwięki i jak dodać własne.

Źródła: `INI/Sound.ini`, `MIX/Sounds.mix` (565 plików `.aud`), nagłówki `rocket1.aud`/`jyes1.aud`, `tools/ModTools.cs` (`Aud`).

## Zasada

- Nazwa w `[SoundList]` (np. `700=SCMAYES0`) → plik **`SCMAYES0.AUD`** szukany w MIX-ach i ścieżkach wyszukiwania.
  DTA nie używa `audio.bag`. Wszystkie efekty i głosy to luźne `.aud` w `Sounds.mix`.
- `[SoundList]` jest u góry Sound.ini. Nowe wpisy dopisuj **wewnątrz** tej sekcji (po `999=BOOP`), z kluczami, które nie
  kolidują z istniejącymi (zajęte 000–578, 998, 999; mod StarCraft używa 700–713).
- Opcjonalna sekcja `[NAZWA]` nadpisuje `[Defaults]` (`Limit=3`, `Range=5`, `Priority=10`, `Volume=1.0`).
- Sound.ini to osobny plik, więc mapa ani opcja gry nie mogą go rozszerzyć. Trzeba edytować sam plik (kopia: `Sound.ini.bak`).

## Format AUD (Westwood)

- Nagłówek 12 B: `uint16 rate`, `uint32 rozmiar_danych` (z nagłówkami bloków), `uint32 rozmiar_wyjścia` (bajty PCM),
  `byte flags` (2 = 16-bit), `byte typ` (**99 = IMA ADPCM**).
- Bloki: `uint16 rozmiar_skompresowany` (≤ 512), `uint16 rozmiar_wyjścia` (≤ 2048), `uint32 0x0000DEAF`, dane.
  Stan IMA przechodzi między blokami, **najpierw młodszy półbajt** (test korelacji: 0,999).
- DTA: **22 050 Hz, 16-bit, mono**. WAV-y SD ze StarCrafta mają dokładnie ten format.

## Użycie w jednostce i broni

`VoiceSelect=`, `VoiceMove=`, `VoiceAttack=` (lista, losowy wybór), `VoiceDeploy=` (Vinifera), `Report=` w broni i animacji.

- `VoiceDeploy` gra Vinifera w `Player_Assign_Mission(MISSION_UNLOAD)`, tylko gdy globalne `AllowVoice` jest ustawione.
  Hipoteza: działa przy deploy **kliknięciem myszą** na jednostkę, a nie klawiszem D, który wysyła rozkaz bez odpowiedzi
  głosowej. W teście użytkownika (prawdopodobnie klawisz D) dźwięku stimpacka nie było **(do sprawdzenia)**.
- **`VoiceSelect=` działa też na budynkach** (deasemblacja `game.exe`; w grze niezweryfikowane). `TechnoClass::Select` (`0x62F900`)
  po udanym `ObjectClass::Select` sprawdza tylko, czy dom jest graczem i czy `AllowVoice` jest ustawione, potem woła
  `Response_Select` (slot vtable `0x2CC`). `Response_Select` (`0x637330`) jest wspólny dla wszystkich 6 klas techno, także
  `BuildingClass` (vtable `0x6CC2F8`): losuje dźwięk z wektora `VoiceSelect` typu (`TechnoTypeClass+0x27C`). Nie ma filtra na
  budynki. Żaden budynek w Rules.ini DTA nie ma `VoiceSelect`, więc to tylko kwestia dopisania klucza.
  Dźwięki budynków SC leżą w CASC: `SD/sound/{terran,protoss,zerg}/bldg/*wht00.wav` (np. `tacwht00.wav` = Academy), po jednym na budynek.
  Wdrożone w [[mods/sc-building-sounds]] (przypisanie z `units.dat`, część budynków w SC tylko klika `Misc\Button.wav`).
- Dźwięk śmierci przez `Report=` animacji `Explosion=` działa tylko wtedy, gdy animacja jest globalna (zob. [[engine/shp-graphics]]).
Mowa EVA to pliki `00-iNNN.aud` w `SPEECH0x.MIX` (per strona).
