# Instalator i deinstalator modów (DTA-SCMod-Setup.exe)

Jeden plik `Modding/dist/DTA-SCMod-Setup.exe` instaluje wszystkie nasze mody (frakcje i jednostki SC, mapy, kampania ARKA,
edytor map) w **innej** kopii DTA i zostawia deinstalator, który przywraca oryginalne pliki DTA. Wygląd (od 2026-10-29, na
prośbę użytkownika „jak prawdziwy installer SC”, poprzedni z portretami uznany za „AI slop”): instalator StarCrafta z 1998.

Źródła: `tools/ScModSetup.cs` (program), `tools/build-installer.ps1` (budowanie), `Modding/installer/assets/` (grafika,
fonty, dźwięki), `Modding/dta/state.json` (lista plików, [[workflow/repo-and-updates]]), CASC StarCrafta ([[engine/starcraft-assets]]),
`StarCraft/x86_64/StarCraft.exe` (ikona). Testy w piaskownicy 2026-10-28.

## Wygląd (styl instalatora SC)

- Okno 640×480 jak oryginał, zwykły pasek tytułu Windows z ikoną StarCrafta; skala **najwyżej ×1,5** (960×720 na 1080p),
  mniejsza na małych ekranach. Przy ×2 bitmapowy font był „pikselowy” (uwaga użytkownika 2026-10-29). Tekst poza skalą 1:1
  jest powiększany najbliższym sąsiadem do następnej całkowitej skali i wygładzany w dół do dokładnej (ostre litery bez kloców).
- Tło `SD/glue/palnl/backgnd` (księżyc nad skałami), przyciemnione u góry i z lewej. Logo wycięte z ekranu tytułowego
  `SD/glue/title/title` (górne 126 px, dodane trybem „lighten”, bo leży na czerni); zielony napis „BROOD WAR” zgaszony do
  poziomu poświaty. Logo Blizzarda w prawym dolnym rogu, z tego samego obrazu.
- Pod logo (wyśrodkowane, rysowane na żywo): „TIBERIUM AGE” (zielony jak „Brood War”, nieco niżej, żeby nie dotykał liter),
  „ARKA: BŁĄD ZNAKU” / „ARKA: SIGN ERROR” (stalowa rampa), mniejszym fontem „DTA & SC mashup”.
- Menu po lewej: żółty tekst bitmapowym fontem SC1 (`SD/font/font16x.fnt`, główna pozycja ×1,5), podświetlenie jaśniejszą
  rampą, nieaktywne szare; „Język”, a osobno na dole „Zakończ instalator”. Linie informacyjne `font14`, dialogi `font16`.
- **Mało technicznych szczegółów** (prośba użytkownika 2026-10-29): w menu tylko wersja (i zainstalowana), folder gry
  i jedna linia statusu, gdy coś wymaga uwagi (brak DTA, inna wersja DTA, folder roboczy). Bez liczby plików, MB, dat,
  ścieżek do deinstalatora, nazw plików DTA w dialogach.
- Dialogi: panel `SD/glue/palmm/popopup` (rozciągany 9-slice, czerwone linie przekolorowane na złoto, własne przyciski).
- Ekran postępu: nagłówek, jedno zdanie („Kopiowanie plików moda…”), pasek. Po końcu: „Gotowe.” albo „Uwagi: N”, pozycje
  „Uruchom DTA”, „Szczegóły” (log silnika, kółko myszy przewija), „Powrót do menu”, „Zakończ instalator”. Log zapisywany
  też do `%TEMP%\DTA-SCMod-setup.log`.

## Język (polski / angielski)

- Cały instalator, dialogi i komunikaty silnika (log, błędy) są w dwóch językach: pary `L.T("polski", "English")` w kodzie.
- **Domyślnie angielski** (prośba użytkownika 2026-10-29, także w trybie bez okna). Pozycja menu „Language: English” /
  „Język: polski” przełącza od razu; wybór zapisany w `HKCU\Software\DTA-SCMod\Language` (`pl`/`en`), deinstalacja go nie
  kasuje. Ekran wyboru języka przy pierwszym starcie był, ale go usunięto (zbędny przy domyślnym angielskim).
- Tytuł kampanii po angielsku: **„ARKA: Sign Error”** (Einstein „pomylił znak”, czyli kierunek ± skoku, [[plans/campaign-arka]]).
- Język dotyczy tylko instalatora; treść moda (dialogi kampanii ARKA) jest po polsku, co mówi angielski ekran „About”.
- **Fonty SC1** (format FNT): `"FONT"`, pierwszy i ostatni znak, maks. szerokość, wysokość, offset u32 na znak; znak = w, h,
  x, y + bajty RLE (`pominięcie << 3 | odcień`). Odcień 1 najjaśniejszy … 4 najciemniejszy, 7 cień; kolory z rampy (w grze
  `glue/*/tfont.pcx`: 6 ramp po 8, menu SC1 jest zielone, instalator ma własną żółtą). HD-owe `font/*.fnt` to atlasy DDS —
  używać SD. Fonty są Latin-1: polskie litery składane w programie (akcent z é/É, ogonek = lustrzana cedylla z ç/Ç, kropka
  z `.`, kreska ł rysowana). TTF-y z CASC (`BLIZZARD-REGULAR`, `Eurostile`) to zwykłe fonty Remastered, nie font menu SC1.

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
- Assety tworzone tylko gdy ich brak albo z `-Assets`, wszystkie z lokalnego StarCrafta: obrazy glue SD (DDS 32-bit bez
  kompresji → PNG: `glue_bg`, `glue_title`, `glue_popup`), fonty `font16x/16/14.fnt`, dźwięki `SD/sound/misc/button.wav`,
  `glue/mouseover.wav`, `glue/scorefillend.wav`, `misc/buzz.wav`, `glue/swishin.wav`, ikona z zasobów `StarCraft.exe`
  (`RT_GROUP_ICON` → `.ico`; brak → ikona klienta DTA). Każdy plik z folderu assetów trafia do exe jako zasób.
- `Modding/dist/` jest w `.gitignore` (exe za duży dla GitHuba). Assety (0,7 MB) są w gicie.

## Wydanie (release na GitHubie)

1. `dta-capture.ps1`, potem `build-installer.ps1 -Version <RRRR.MM.DD>` i test w piaskownicy (5 scenariuszy niżej).
2. Nowa sekcja na górze `Modding/CHANGELOG.txt` (dla graczy; stan testów i znane ograniczenia uczciwie). Od 2026.10.29
   **dwujęzycznie: najpierw po angielsku, potem po polsku** (prośba użytkownika: „domyślnie pokazuj po angielsku”);
   opis wydania na GitHubie tak samo (EN, potem PL). Starsze sekcje zostają po polsku.
   Exe zablokowane (użytkownik ma otwarty instalator): budować z `-Out Modding\dist\v<wersja>\DTA-SCMod-Setup.exe`.
3. Commit całego stanu, `git push`, tag `v<wersja>` na tym commicie.
4. `gh release create v<wersja> Modding/dist/DTA-SCMod-Setup.exe Modding/CHANGELOG.txt --notes-file …` w `T-Zema/arka-dta`
   (repo prywatne; zasób 130 MB mieści się w limicie 2 GB na plik wydania). `gh` na tym komputerze nie jest zalogowany:
   token z menedżera poświadczeń gita (`git credential fill`) jako `GH_TOKEN` tylko na czas polecenia. **W Bashu**
   (`printf 'protocol=https\nhost=github.com\n\n' | git credential fill`): pipe z PowerShella 5.1 daje
   „refusing to work with credential missing protocol field” (2026-10-28).
   Zmiana po wypchnięciu taga, a przed utworzeniem release'u: przesunąć tag (`git tag -f` + `push -f`) tylko za zgodą użytkownika.
   Tytuł wydania krótko: `--title "ARKA <wersja>"` (np. `ARKA 2026.10.28`, prośba użytkownika 2026-10-28).
   Opis wydania i commit bez linii o Claude / AI (zob. [[workflow/repo-and-updates]], „Bez atrybucji AI”).

Wydania: `v2026.10.28` (pierwsze, DTA 16.2.3), `v2026.10.28.2` (poziomy trudności ARKA, warstwy kodu frakcji; 334 pliki,
testy piaskownicy 5/5 PASS), `v2026.10.29` (instalator w stylu SC, EN/PL; muzyka SC; poprawki ARKA 0/1/2/4, przypominajki
celów; 358 plików, 165 MB, piaskownica 5/5 PASS, pierwszy dwujęzyczny changelog). Przed tym wydaniem capture złapał
`.claude/scheduled_tasks.lock` (plik Claude Code w folderze gry) jako plik moda: `^\.claude/` dodane do `ignore` w `sync.json`. Drugie wydanie tego samego dnia dostaje sufiks `.2` (wersja to tekst, NAPRAW/AKTUALIZUJ widzi różnicę).

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
- `… /shot <png> [idle|busy|done|details|ask|about|hover] [uninstall] [pl|en]`: rysuje okno w skali ×1,5 (960×720)
  do PNG bez pokazywania (stany ustawiane ręcznie, silnik nie rusza)
  go. **Nie uruchamiać okna w trakcie sesji użytkownika**: 2026-10-28 testowe okno wyskoczyło nad grą pełnoekranową.
  Do sprawdzania wyglądu wystarczy `/shot`. Tryb instalatora wymaga paczki: do podglądu wystarczy exe z `-NoPayload` +
  doklejony zip z samym `manifest.json` (pusta lista plików albo sztuczne wpisy) i trailer `SCMODPK1`.

## Testy (2026-10-28, piaskownica w scratchpadzie, wszystko PASS)

Sztuczna „czysta DTA” (`version`, bazy plików `modified`, czyste `game.exe`/`Vinifera.dll`, obcy plik o nazwie naszego):
1. instalacja → 322 pliki = nasze, obcy plik w kopii, plik niezwiązany nietknięty, wpis w rejestrze;
2. ponowna instalacja → 0 zapisów;
3. deinstalacja z `SCMod` → folder identyczny z czystym (skróty wszystkich plików), bez nowych folderów, `SCMod` zniknął, wpis usunięty;
4. pliki już nasze bez `install.json` → instalacja → deinstalacja → czysta DTA (oryginały z `base/` pakietu);
5. „aktualizacja DTA” (`Rules.ini` zmieniony, `BattleE.ini` usunięty) → NAPRAW (kod 1) → nasze pliki wróciły → deinstalacja
   zostawia nowszy `Rules.ini` DTA.

Okno zweryfikowane tylko przez `/shot` i jedno uruchomienie (odpowiada); **kliknięcia w GUI niezweryfikowane przez użytkownika**.
Nowy wygląd (2026-10-29): wszystkie stany sprawdzone przez `/shot`; okna nie uruchamiano, silnik instalacji bez zmian
(doszło tylko wywołanie `OnFile`) — **(niezweryfikowane w grze/GUI przez użytkownika)**.
Mody w zainstalowanej kopii: tak jak w folderze roboczym (to te same pliki, bit w bit).
