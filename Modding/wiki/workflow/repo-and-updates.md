# Repozytorium git i aktualizacje DTA

Jak nasze zmiany w instalacji DTA są trzymane w gicie (repo leży w folderze gry) i jak odtworzyć je po aktualizacji klienta:
`tools/dta-capture.ps1` (zapis stanu), `tools/dta-precheck.ps1` (przed aktualizacją), `tools/dta-restore.ps1` (po aktualizacji).

Źródła: `version` (manifest 16.2.2), `version_u` (manifest 16.2.3 pobrany przez klienta 2026-10-27), `Client/client.log`
(przebieg aktualizatora), pliki 16.2.3 z mirrora, `tools/dta-*.ps1`, testy w piaskownicy 2026-10-27. Łatki:
[[engine/game-exe-patching]].

## Układ

Repo = folder gry. `.gitignore` ignoruje **wszystko** (`/*`) poza `Modding/`, `CLAUDE.md`, `README.md`, `.gitignore`,
`.gitattributes` i blokiem generowanym przez `dta-capture.ps1` (`# >>> dta-capture` … `# <<< dta-capture`). Pliki gry są
śledzone **na miejscu**, bez kopii.

`dta-capture.ps1` porównuje każdy plik folderu gry z manifestem klienta `version` (MD5 każdego pliku DTA) i dzieli je na:

| Rodzaj | Co to jest | Jak przechowywany |
|---|---|---|
| `new` | nie jest plikiem DTA: nasze MIX-y (`ECACHE78`–`90`, `96`–`99`, `SideC/sidenc/Speech07–09`), mapy `Maps/Custom`, misje ARKA, INI modów, `MOVIES/ARKA02B.MP4`, ikony i ekrany frakcji w `Resources` | git, na miejscu |
| `modified` | plik DTA, który zmieniamy: `Rules.ini`, `Art.ini`, `Sound.ini`, `MPMaps.ini`, `Resources/GameOptions.ini`, `Resources/SkirmishLobby.ini`, `Maps/Missions/FRSTBITE.MAP` | git, na miejscu; czysty oryginał DTA w `Modding/dta/base/` (baza merge'a) |
| `patched` | binarka łatana skryptami (`sync.json` → `patched`): `game.exe` (`patch-game.ps1 -FlyDebug`), `Vinifera.dll` (`patch-vinifera.ps1`) | **nie w gicie**: odbudowywana z czystego pliku DTA; capture sprawdza, że wychodzi bit w bit to samo (`reproducible`) |

- `Modding/dta/state.json`: lista plików z rodzajem i hashami (`base` = czysty DTA, `ours` = nasz), wersja DTA. Bez znacznika
  czasu, więc niezmieniona instalacja daje niezmieniony plik.
- `Modding/dta/sync.json`: konfiguracja. `ignore` = wyrażenia regularne na pliki runtime (zapisy, logi, `Settings.ini`,
  `spawn*.ini`, `.bak`, `Client/`, `Debug/`), `patched` = skrypty łatek, `mirror`, `maxFileMB` (90, limit GitHuba to 100).
- `Modding/dta/dta-version.ini`: kopia manifestu, do którego należą bazy.
- `Modding/.dta-cache/` (**tylko lokalnie**, ignorowany): czyste i załatane binarki według hasha, pobrane pliki, kopie
  konfliktów. To zabezpieczenie `-OnPatchFail KeepOld`.
- `.gitattributes`: `* -text`. Git nie zmienia końców linii, bo restore porównuje pliki po MD5 (INI DTA mają CRLF, wiki LF).
- Pliki, które klient kopiuje sam (nie nasze): `MIX/ECACHE95.MIX` (z `Resources/ECache95.mix`, por. MIX 91–95 w
  [[workflow/known-mistakes]]), `language.dll` (z `Resources/language_*.dll`), `MIX/Expand99.mix` = dodatek VSCORES z `[AddOns]`.
  Pliki z datą 02.04.2026 w `Resources/` (`terranicon.png`, `l480s61.pcx`…) są nasze: `Copy-Item` zachowuje datę oryginału.

## Jak aktualizator klienta traktuje nasze pliki

- **Sprawdzenie** aktualizacji porównuje manifesty (lokalny `version` z serwerowym) i w `client.log` wypisuje tylko pliki
  różnicy wersji („Local file X is different”, 10 plików dla 16.2.2 → 16.2.3). **Sama aktualizacja robi więcej** (zobaczone
  2026-10-27): przywróciła *każdy* plik DTA różny od manifestu, czyli wszystkie nasze `modified` (także niezmienione między
  wersjami `Art.ini`, `Sound.ini`…) i `game.exe`. Po każdej aktualizacji trzeba więc uruchomić restore.
- Przy każdej aktualizacji klient wykonuje też skrypty serwera `preupdateexec` i `updateexec` (sekcje `[Delete]`, `[Rename]`,
  `[ForceDeleteFolder]`…). `preupdateexec` usuwa **`MIX/ECache99.mix`** i **`INI/BattleE.ini`** (stare nazwy DTA), czyli nasz
  ówczesny MIX Marine'a ([[mods/starcraft-marine]]) i rejestrację misji ARKA. Restore przywraca je z gita, a precheck je
  wypisuje (`DELETED`). Marine został 2026-10-27 przeniesiony na `ECACHE77` (99 jest odtąd zakazany, [[engine/shp-graphics]]);
  `BattleE.ini` musi zostać (nazwę ustala `Resources/ClientDefinitions.ini` `BattleFSFileName=`), więc wraca przez restore.
- Gdy klient znajdzie aktualizację, zapisuje nowy manifest jako `version_u` (jeszcze przed instalacją).
- Hash w manifeście: 16 bajtów MD5 zapisanych dziesiętnie jeden po drugim, potem `,rozmiar w KB` (`Get-DtaHash` w
  `tools/dta-common.ps1`).
- Mirror `https://dta.cnc-comm.com/updates/<ścieżka>` serwuje surowe pliki **bieżącej** wersji (hash zgodny z manifestem).
  Starszych wersji tam nie ma.

## Praca codzienna

Po każdej zmianie modu: `powershell -File Modding\tools\dta-capture.ps1`, potem `git add -A`, `git commit` (i `git push`).
**Bez atrybucji AI** (prośba użytkownika 2026-10-28): w commitach, tagach, opisach wydań i PR-ów nie dopisywać
`Co-Authored-By: Claude …`, `🤖 Generated with Claude Code` ani podobnych linii; autorem commitów jest tylko użytkownik
(`Zema`). Ta zasada ma pierwszeństwo przed domyślną atrybucją narzędzia.
Nowe pliki modów wchodzą do bloku `.gitignore` same. Capture trwa około 20 s (z weryfikacją łatek; `-SkipVerify` szybciej).
Ostrzeżenia, na które trzeba zareagować:
- `NOT reproducible`: skrypty łatek nie dają już zainstalowanej binarki (np. ktoś łatał ręcznie albo zmienił skrypt bez
  ponownego nałożenia). Napraw, zanim zatwierdzisz.
- `> maxFileMB, NOT captured`: plik za duży dla GitHuba (np. zainstalowany dodatek FMV); dopisz go do `ignore`.
- `git tracks X but it is not in the state`: plik został usunięty z modów, `git rm --cached` go.

## Przed aktualizacją DTA

`dta-precheck.ps1`: czyta `version_u` (albo pobiera manifest z mirrora), pobiera tylko nowe wersje **naszych** plików
i próbuje na kopiach tego, co zrobi restore: merge'y plików `modified`, łańcuchy łatek na nowych binarkach, kolizje nazw,
nasze pliki z list `[Delete]` skryptów `preupdateexec`/`updateexec` (`DELETED`) i pliki, które aktualizacja nadpisze (`OVERWRITE`).
Kończy werdyktem. Niczego w folderze gry nie zapisuje.

## Po aktualizacji DTA (albo naprawie plików w kliencie)

Zamknij klienta i grę. `dta-restore.ps1 -DryRun` (plan), potem `dta-restore.ps1`. Źródłem naszych plików jest **git HEAD**,
więc ostatni capture musi być zatwierdzony (restore to sprawdza). Dla każdego pliku ze stanu:

| Rodzaj | Sytuacja | Działanie |
|---|---|---|
| `new` | brak / usunięty | przywrócony z gita |
| `new` | DTA dodało plik o tej nazwie | nasz wraca, plik DTA jako `<plik>.dta-new` (WARN) |
| `modified` | DTA położyło oryginał tej samej wersji | nasz z gita |
| `modified` | DTA **zmieniło** plik | 3-way merge `git merge-file` (baza = `Modding/dta/base`, nasz = HEAD, ich = nowy plik); konfliktowe fragmenty biorą **naszą** stronę, wersja diff3 ze znacznikami w `.dta-cache/conflicts/`; `<plik>.bak` = nowy oryginał |
| `patched` | czysty plik DTA (stary lub nowy) | łańcuch łatek na kopii; ten sam plik DTA → wynik musi być identyczny bit w bit |
| `patched` | łatki odmawiają nowej binarki | `-OnPatchFail KeepOld` (domyślnie): wraca nasza stara załatana binarka i jej `.bak` z `.dta-cache` (stan **pinned**, mody działają na starej binarce); `UseNew`: zostaje nowa, niezałatana |
| dowolny | plik nie pasuje ani do DTA, ani do stanu | lokalne, niezapisane zmiany: pominięty (WARN), chyba że `-Force` |

Bez błędów restore sam uruchamia `dta-capture.ps1 -Force` (nowe bazy, nowa wersja w stanie). Potem: test w grze, commit.
Restore można powtarzać. Binarka **pinned** jest przy każdym restore ponownie próbowana na pliku z bieżącego manifestu,
więc po przeniesieniu łatek wystarczy uruchomić restore jeszcze raz.

## Nowy komputer albo świeża instalacja DTA

W folderze zainstalowanego DTA (nie klonować do pustego folderu: gra potrzebuje plików DTA):

```
git init -b main
git remote add origin <url>
git fetch origin
git reset origin/main
git checkout -- Modding CLAUDE.md README.md .gitignore .gitattributes
powershell -ExecutionPolicy Bypass -File Modding\tools\dta-restore.ps1
```

`git reset` (bez `--hard`) ustawia indeks na repo, a pliki DTA na dysku zostają. Restore przywraca nasze pliki, scala
zmienione i łata binarki. Ograniczenie: binarka **pinned** wymaga `.dta-cache` ze starego komputera (mirror ma tylko bieżącą
wersję); bez niego zostaje niezałatana.

## Aktualizacja 16.2.2 → 16.2.3 (2026-10-27, wykonana)

Użytkownik zaktualizował DTA. Restore przywrócił 7 plików `modified` i 2 usunięte pliki `new`, scalił `Rules.ini` bez
konfliktów, nałożył wszystkie łatki `game.exe` (razem z nową `patch-airboard.ps1`), a Viniferę najpierw przypiął do naszej
16.2.2. Potem łatki Vinifery zostały **przeniesione na 16.2.3**:
- Wzorce bajtów każdego miejsca są w nowej DLL jednoznaczne. Deasemblacja otoczenia jest identyczna (te same rejestry, ramka
  stosu, pola struktur); przesunęły się tylko adresy (`Place_Object` +0x1323, `IdleRate` +0x1D01, `_Harvested` +0x1346,
  `AnimClassExt::_AI` +0x5B5) i thunki do funkcji gry. Offsety pól z nowego `Vinifera.pdb` bez zmian.
- Skrypty `patch-vinifera-*.ps1` mają tabelę `$builds` z adresami obu wersji, wybieraną po `TimeDateStamp` nagłówka PE
  (`6AC3EA33` = 16.2.2, `6AD94075` = 16.2.3; łatki go nie zmieniają). Jaskinie veins generuje skrypt (wcześniej stały zrzut
  nasm pod `0x106DB100`), więc pasują do każdego adresu sekcji `.scdock`.
- Testy: na 16.2.2 skrypty dają bit w bit dawną załataną DLL; na 16.2.3 łatka, ponowne uruchomienie (bez zmian), `-Revert`
  (= czysty plik); deasemblacja wszystkich haków i jaskiń w nowej DLL (powroty i thunki poprawne). Zainstalowane przez restore:
  stan bez *pinned*, `reproducible=True`. **Test w grze: niezweryfikowane w grze.**
- Port następnej wersji: `llvm-pdbutil dump -publics Vinifera.pdb` (adresy funkcji), wyszukanie oryginalnych wzorców z nagłówków
  skryptów, porównanie deasemblacji starej i nowej DLL, nowy wpis w `$builds` każdego skryptu.

## Stan przed aktualizacją (2026-10-27, DTA 16.2.2, dostępna 16.2.3)

- Klient pobrał już `version_u` (16.2.3). Zmienia 10 plików, w tym nasze `INI/Rules.ini` i `Vinifera.dll`.
- `Rules.ini`: nasze 154 linie (animacje SC w liście animacji) scalają się z 16.2.3 bez konfliktów.
- `Vinifera.dll` 16.2.3: **wszystkie trzy łatki odmawiają** (`patch-vinifera-workers.ps1`: inne bajty pod `0x100BCA54`,
  `patch-vinifera-overlord.ps1`: pod `0x100C5929`, `patch-vinifera-veins.ps1` wymaga sekcji pierwszej). Po aktualizacji restore
  zostawi naszą Viniferę 16.2.2 (pinned): robotnicy SC, rozsiewacze creepu i Overlord jako silos działają dalej, ale bez
  poprawek Vinifery z 16.2.3. Żeby przejść na nową, łatki trzeba przenieść: nagłówki skryptów opisują oryginalne instrukcje
  każdego miejsca, więc w nowej DLL szuka się tych samych wzorców bajtów (adresy się przesunęły).
- Odtwarzalność: `game.exe` i `Vinifera.dll` z czystych `.bak` + skryptów dają bit w bit zainstalowane pliki. `game.exe`
  wymaga wariantu `-Debug` łatki fly-hover (logowanie `FLY …`), stąd `-FlyDebug` w `sync.json`.
- Testy w piaskownicy (klon repo w scratchpadzie): (A) czyste pliki DTA w miejsce naszych i dwa nasze pliki usunięte →
  restore → wszystkie 71 plików identyczne z instalacją; (B) symulacja aktualizacji 16.2.3 (tylko 10 plików podmienionych jak
  przez aktualizator) → `Rules.ini` scalony, Vinifera pinned, ponowny restore niczego nie zmienia.

## Pułapki

- **Nigdy** `git checkout`/`git stash`/`git reset --hard` na plikach DTA po aktualizacji: nadpisze nową wersję DTA bez merge'a.
  Zawsze `dta-restore.ps1`. Capture po aktualizacji, a przed restore, odmawia (wersja DTA ≠ wersja stanu).
- Repo zawiera grafikę i dźwięki StarCrafta (Blizzard) oraz pliki DTA: **repo na GitHubie prywatne**.
- MIX-y są binarne: każda przebudowa dużego MIX-a (np. `ECACHE86`, 19 MB) dokłada nową kopię do historii. Przy rozroście
  można przejść na Git LFS (git-lfs 3.7 jest zainstalowany), ale darmowy limit LFS na GitHubie to 1 GB.
- PowerShell 5.1: stderr programu natywnego przekierowany `2>&1` przy `ErrorActionPreference = 'Stop'` staje się wyjątkiem
  (`git checkout` pisze „Updated 1 path” na stderr). Wywołania gita w `dta-common.ps1` lokalnie przełączają na `Continue`.
- Repo leży na OneDrive: OneDrive synchronizuje też `.git`. Przy dużych operacjach (pierwszy push, przebudowa MIX-ów) lepiej
  wstrzymać synchronizację.
