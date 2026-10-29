# Muzyka StarCrafta w DTA

Wszystkie 23 utwory z SC:R użytkownika jako tematy DTA: 14 w losowej playliście gry, 9 krótkich (ready room, zwycięstwo, porażka) do wyzwalaczy.

Źródła: CASC `SD/music/*.wav` (instalacja `C:\Program Files (x86)\StarCraft`, [[engine/starcraft-assets]]), `INI/Theme.ini`, `MIX/Scores.mix`, `MIX/Scores01.mix`, `tools/build-scmusic.ps1`.

## Stan

Zainstalowany 2026-10-29, **nietestowany w grze**. Przebudowa: `Modding/tools/build-scmusic.ps1 -Install` (bez `-Install` tylko AUD-y do `%TEMP%\scmusic`). Kopia `INI/Theme.ini.bak`.

## Jak to działa

- Muzyka TS/DTA to Westwood AUD IMA ADPCM: wszystkie utwory w `Scores.mix`/`Scores01.mix` mają 22 050 Hz, mono, `flags=2`, typ 99. SC ma w `SD/music/` WAV 22 050 Hz 16-bit stereo; skrypt miksuje do mono i koduje przez `Aud.Encode` z `ModTools.cs`.
- Głośność: RMS utworów DTA to 4,8–6,2 tys., SC 3,5–8,6 tys. (pomiar 2026-10-29), więc wzmocnienie 1.0.
- Pliki leżą **luzem w `MUSIC\`** (`SC*.AUD`, razem 43 MB), bo `MUSIC` jest na ścieżce wyszukiwania silnika (`;SOUNDS;SPEECH;MUSIC;...`, [[engine/briefing-movies]]). W ECACHE MIX ~43 MB wisiałoby w pamięci; tematy i tak są strumieniowane z pliku **(niezweryfikowane w grze: że silnik znajduje luźny AUD w `MUSIC\`)**. Gdyby nie znalazł: spakować AUD-y do wolnego `ECACHEnn.MIX` (wolne 06–75).
- `Theme.ini`: blok `; >>> SC music themes` na końcu `[Themes]` (indeksy po ostatnim utworze DTA) i blok `; >>> SC music sections` na końcu pliku.

## Utwory

| Indeks | ID | Plik SC | Playlista |
|---|---|---|---|
| 89 | `SCTITLE` | `title` | tak |
| 90–93 | `SCTERR1–4` | `terran1–4` | tak |
| 94–97 | `SCZERG1–4` | `zerg1–4` | tak |
| 98–101 | `SCPROT1–4` | `protoss1–4` | tak |
| 102 | `SCRFZERG` | `radiofreezerg` | tak |
| 103–105 | `SCTRDY`, `SCZRDY`, `SCPRDY` | `trdyroom`, `zrdyroom`, `prdyroom` | nie (`Normal=no`, `Repeat=no`) |
| 106–108 | `SCTVICT`, `SCZVICT`, `SCPVICT` | `tvict`, `zvict`, `pvict` | nie |
| 109–111 | `SCTDEF`, `SCZDEF`, `SCPDEF` | `tdefeat`, `zdefeat`, `pdefeat` | nie |

Utwory spoza playlisty mają `Repeat=no`, bo wyzwalacz nie może grać tematu z `Repeat=yes` (komentarz DTA przy `RAMAP`). W misjach ARKA: akcja `20` Play Music Theme z indeksem z tabeli albo `[Basic] Theme=SCTERR1` ([[engine/triggers-and-dialogue]]).

## Pomysły na później

- `Side=` w sekcjach utworów, żeby frakcje SC słyszały tylko SC, a klasyczne tylko DTA (nie zrobione, użytkownik prosił tylko o dodanie).
- Muzyka SC jako domyślny temat misji ARKA na Mar Sarze / Tarsonis.
