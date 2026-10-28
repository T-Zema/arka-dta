# Instalator i deinstalator modów (DTA-SCMod-Setup.exe)

Jeden plik `Modding/dist/DTA-SCMod-Setup.exe` instaluje wszystkie nasze mody (frakcje i jednostki SC, mapy, kampania ARKA,
edytor map) w **innej** kopii DTA i zostawia deinstalator, który przywraca oryginalne pliki DTA. Wygląd: tło menu głównego
klienta DTA, przyciski Classic, zielenie DTA, animowane portrety SC (Raynor, Kerrigan zainfekowana, Zeratul) i dźwięki interfejsu SC.

Źródła: `tools/ScModSetup.cs` (program), `tools/build-installer.ps1` (budowanie), `Modding/installer/assets/` (grafika
i dźwięki), `Modding/dta/state.json` (lista plików, [[workflow/repo-and-updates]]), CASC StarCrafta ([[engine/starcraft-assets]]),
`Resources/DTA Theme/MainMenu/mainmenubg.png`, `Resources/Classic Theme/MainMenu/button1*.png`. Testy w piaskownicy 2026-10-28.

## Budowanie

```
powershell -ExecutionPolicy Bypass -File Modding\tools\build-installer.ps1            # pełny instalator (~2 min)
powershell -ExecutionPolicy Bypass -File Modding\tools\build-installer.ps1 -NoPayload # sam program, do oglądania okna
```

- **Najpierw `dta-capture.ps1`**: pakiet bierze listę plików ze `state.json`, a treść z dysku. Plik różny od ostatniego
  capture daje ostrzeżenie (pakowany jest stan z dysku). Plik ze stanu, którego nie ma na dysku, przerywa budowanie.
- Pakiet: `files/<ścieżka>` (322 pliki, 246 MB) + `base/<ścieżka>` (czysty plik DTA każdego pliku `modified`/`patched`
  z `Find-DtaPristine`) + `manifest.json` (ścieżka, rodzaj, skrót nasz i bazowy, rozmiar, wersja DTA). Zip 127 MB, exe 130 MB.
- Układ exe: `[program][zip][int64 długość zipa]["SCMODPK1"]`. Program bez doklejonego zipa = deinstalator.
- Kompilacja: `csc.exe` z .NET Framework 4 (C# 5, bez SDK), zasoby z `Modding/installer/assets` (`/resource`), ikona klienta
  DTA, manifest `asInvoker` (bez niego Windows żąda admina dla exe z „Setup” w nazwie) i `dpiAware`.
- Assety SC tworzone tylko gdy ich brak albo z `-Assets`: portrety `HD2/portrait/<bohater>/<x>fid00–02, tlk00.webm`
  (224×240, 10 klatek po 10 FPS) → ffmpeg (pixi) → paski JPEG; dźwięki `SD/sound/misc/button.wav`, `glue/mouseover.wav`,
  `misc/transmission.wav`, `glue/scorefillend.wav`, `misc/buzz.wav`, `glue/swishin.wav`.
- `Modding/dist/` jest w `.gitignore` (exe za duży dla GitHuba). Assety (2,2 MB) są w gicie.

## Wydanie (release na GitHubie)

1. `dta-capture.ps1`, potem `build-installer.ps1 -Version <RRRR.MM.DD>` i test w piaskownicy (5 scenariuszy niżej).
2. Nowa sekcja na górze `Modding/CHANGELOG.txt` (dla graczy, po polsku; stan testów i znane ograniczenia uczciwie).
3. Commit całego stanu, `git push`, tag `v<wersja>` na tym commicie.
4. `gh release create v<wersja> Modding/dist/DTA-SCMod-Setup.exe Modding/CHANGELOG.txt --notes-file …` w `T-Zema/arka-dta`
   (repo prywatne; zasób 130 MB mieści się w limicie 2 GB na plik wydania). `gh` na tym komputerze nie jest zalogowany:
   token z menedżera poświadczeń gita (`git credential fill`) jako `GH_TOKEN` tylko na czas polecenia.

Wydania: `v2026.10.28` (pierwsze, DTA 16.2.3).

## Co robi instalator

- Szuka folderu gry: argument, folder exe, `HKCU\Software\DTA-SCMod\GamePath`, `Pulpit\Dawn of the Tiberium Age`; przycisk
  ZMIEŃ. Folder DTA = `game.exe` + plik `version`. Wersja DTA z `version` porównana z pakietem (inna: pytanie przed instalacją).
- **Odmawia instalacji w folderze roboczym** (`.git` + `Modding/dta/state.json`): mod już tam jest, a deinstalacja skasowałaby
  pliki robocze.
- Odmawia, gdy z tego folderu działa gra albo klient.
- Dla każdego pliku: już nasz → bez zapisu (dla `modified`/`patched` do kopii trafia czysty plik z `base/` pakietu); inny →
  kopia do `<gra>/SCMod/backup/<ścieżka>`, potem nasz plik i kontrola skrótu. Plik `modified`/`patched` inny niż baza DTA
  (inna wersja DTA) → ostrzeżenie, wersja moda wygrywa (jak *pinned* w `dta-restore`).
- `<gra>/SCMod/install.json`: wpis na plik (`created` albo `replaced` + skrót oryginału) i lista utworzonych folderów;
  zapisywany co 40 plików i na końcu (przerwana instalacja da się odinstalować).
- Deinstalator `<gra>/SCMod/Odinstaluj SC Mod.exe` + wpis w Panelu sterowania (`HKCU\...\Uninstall\DTA-SCMod-<id>`, bez admina).
- Ponowne uruchomienie = **NAPRAW** (ta sama wersja) albo **AKTUALIZUJ** (inna wersja pakietu): po aktualizacji klienta DTA
  przywraca nasze pliki; plik, który DTA zmieniła od instalacji, staje się nowym oryginałem w kopii (ostrzeżenie).

## Co robi deinstalator

- Od końca listy: `created` → usuwa, jeśli to nadal nasz plik; `replaced` → przywraca kopię, jeśli jest tam nasz plik albo
  go brak. Plik zmieniony po instalacji (np. nowa wersja DTA po aktualizacji klienta) zostaje (ostrzeżenie) — po aktualizacji
  DTA deinstalacja zostawia więc nowe pliki DTA, a nie stare kopie.
- Usuwa puste foldery, które utworzył instalator, wpis w rejestrze, `SCMod/backup` i `install.json`. Uruchomiony z `SCMod`
  kasuje swój folder po wyjściu (`cmd /c ping … & rmdir`).

## Tryby bez okna (testy)

- `DTA-SCMod-Setup.exe /install "<gra>"`, `… /uninstall "<gra>"`: kod wyjścia 0 OK, 1 ostrzeżenia, 2 błąd; log
  `%TEMP%\DTA-SCMod-setup.log` (UTF-8 bez BOM).
- `… /shot <png> [idle|busy|done|ask|hover]`: rysuje okno 1280×720 do PNG bez pokazywania go. **Nie uruchamiać okna
  w trakcie sesji użytkownika**: 2026-10-28 testowe okno wyskoczyło nad grą pełnoekranową. Do sprawdzania wyglądu wystarczy `/shot`.

## Testy (2026-10-28, piaskownica w scratchpadzie, wszystko PASS)

Sztuczna „czysta DTA” (`version`, bazy plików `modified`, czyste `game.exe`/`Vinifera.dll`, obcy plik o nazwie naszego):
1. instalacja → 322 pliki = nasze, obcy plik w kopii, plik niezwiązany nietknięty, wpis w rejestrze;
2. ponowna instalacja → 0 zapisów;
3. deinstalacja z `SCMod` → folder identyczny z czystym (skróty wszystkich plików), bez nowych folderów, `SCMod` zniknął, wpis usunięty;
4. pliki już nasze bez `install.json` → instalacja → deinstalacja → czysta DTA (oryginały z `base/` pakietu);
5. „aktualizacja DTA” (`Rules.ini` zmieniony, `BattleE.ini` usunięty) → NAPRAW (kod 1) → nasze pliki wróciły → deinstalacja
   zostawia nowszy `Rules.ini` DTA.

Okno zweryfikowane tylko przez `/shot` i jedno uruchomienie (odpowiada); **kliknięcia w GUI niezweryfikowane przez użytkownika**.
Mody w zainstalowanej kopii: tak jak w folderze roboczym (to te same pliki, bit w bit).
