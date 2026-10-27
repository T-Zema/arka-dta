# Filmy briefingu (jak w StarCrafcie)

Film przed misją ARKA w stylu briefingu StarCrafta. Po lewej są portrety rozmówców (szum, mówiący się podświetla), po prawej pisany na żywo zapis łączności i ramka celów misji, w tle dźwięki transmisji. Film składa skrypt z pliku JSON, a gra odtwarza go jako `Brief=` mapy. **(niezweryfikowane w grze: pierwszy test to `ARKA02B` w misji 2)**

Źródła: napisy w `Vinifera.dll` (backendy filmów), `Debug/DEBUG_*.LOG` (ścieżka wyszukiwania, ostrzeżenia filmów), `[Basic]` misji DTA w `Maps/Missions/*.map`, `tools/build-briefing.ps1`, `briefings/arka02.json`.

## Jak gra znajduje film

- `[Basic]` mapy: `Intro=`, `Brief=`, `Win=`, `Lose=`, `Action=`, `PostScore=` z nazwą filmu bez rozszerzenia. Misje DTA używają starych filmów C&C, np. `Brief=NODSWEEP`, `Win=NUKE`.
- Vinifera ma, obok starego VQA, „nowoczesne” backendy: `MediaFoundationMovieBackend` i `AVIMovieDecoderBackend`. Nazwę `X.VQA` próbuje rozwiązać do `X.MP4`, `X.WMV` albo `X.AVI` (ostrzeżenie w logu: `Failed to resolve modern movie filename for "SCORE.VQA"`).
- Ścieżka wyszukiwania z logu: `SearchPath: ;SOUNDS;SPEECH;MUSIC;INI;MIX;MOVIES;MAPS`. Filmy ARKA leżą więc w **`MOVIES\`** w katalogu gry (folder założony 2026-10-27).
- W tej instalacji nie ma `MOVIES*.MIX` (log: `Failed to load MOVIES*.MIX!`), więc filmy kampanii DTA się nie odtwarzają. Pakiet filmów DTA to osobne pobranie.
- W logu odtwarzanie widać jako `Play_Movie "…" with …`. Po pierwszym teście sprawdzić tam, czy `ARKA02B` ruszył.

## Generator `tools/build-briefing.ps1`

```
powershell -NoProfile -File Modding\tools\build-briefing.ps1 -Spec Modding\briefings\arka02.json -Preview   # 5 klatek PNG do oceny
powershell -NoProfile -File Modding\tools\build-briefing.ps1 -Spec Modding\briefings\arka02.json            # MOVIES\ARKA02B.MP4
```

- **Spec JSON (UTF-8):** `movie`, `title`, `place`, `link`, `speakers` (`key`, `name`, `tint`, `intercept` = czerwona plakietka „PRZECHWYCONO” i więcej szumu), `lines` (`speaker`, `text`), `objectives` (`text`, `warn` = czerwony warunek porażki). Tekst jest rysowany na obrazie, więc polskie litery są tu w porządku (w `[Tutorial]` mapy już nie).
- **Portrety:** `Modding/briefings/portraits/<key>.png` (dowolny rozmiar, przycięty do kafla 214×105). Bez pliku jest sylwetka w kolorze postaci. Kafel postaci, która jeszcze nie mówiła, pokazuje „BRAK SYGNAŁU”.
- **Czas:** wejście 1,6 s, każda kwestia to 0,4 s + 40 znaków/s pisania + 1,7 s pauzy, potem cele co 0,9 s i 4 s na koniec. Misja 2: 33,9 s.
- **Obraz:** 1280×720, 30 kl./s, klatki PNG z System.Drawing (C# w skrypcie), H.264 `yuv420p` + AAC, `+faststart` (ffmpeg przez `pixi exec --spec ffmpeg`).
- **Dźwięk** syntetyzowany w skrypcie: buczenie łącza, dwutonowy sygnał na początku kwestii, szum dla przechwyconych, stukanie pisania, sygnał na każdy cel. Głosy można dodać później jako ścieżkę.
- Mapa podpina film w generatorze misji: `Brief = 'ARKA02B'` w `[Basic]` (`build-arka02-mission.ps1`).

## Pułapki

- Skrypt ma polskie litery w C#, więc musi mieć **UTF-8 z BOM**, bo Windows PowerShell 5.1 czyta plik bez BOM jako ANSI (krzaki „ÅÄ…” w filmie).
- Nagły restart systemu w trakcie zapisu zostawił `build-briefing.ps1` jako BOM + same zera (2026-10-27). Po restarcie sprawdzać pliki ostatnio pisane (szukać długich ciągów bajtów 0).
