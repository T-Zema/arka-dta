# Dawn of the Tiberium Age: prywatne mody

Mody do **Dawn of the Tiberium Age** (DTA, silnik Tiberian Sun + Vinifera): frakcje StarCrafta (Terranie, Zergowie,
Protossi), łatki `game.exe` i `Vinifera.dll`, mapy SC, kampania „ARKA: Błąd znaku” oraz wiki z całą wiedzą o modowaniu.
Do użytku prywatnego. Repo zawiera zasoby StarCrafta i pliki DTA, więc **musi pozostać prywatne**.

## Jak to działa

Repo leży **w folderze zainstalowanej gry**. Git ignoruje wszystko poza:

- `Modding/`: wiki (`Modding/index.md` czytaj jako pierwszy), narzędzia (`Modding/tools/`), archiwa, surowe źródła,
  stan synchronizacji (`Modding/dta/`);
- plikami gry, które są nasze albo przez nas zmienione. Ich listę `.gitignore` generuje `Modding/tools/dta-capture.ps1`.

`game.exe` i `Vinifera.dll` nie są w repo: skrypty łatek odbudowują je bit w bit z czystych plików DTA.

## Polecenia

Wszystkie uruchamia się z folderu gry, przy zamkniętej grze:

| Kiedy | Polecenie |
|---|---|
| po każdej zmianie modu | `powershell -File Modding\tools\dta-capture.ps1`, potem `git add -A` i `git commit` |
| klient zgłasza aktualizację DTA | `powershell -File Modding\tools\dta-precheck.ps1` (co aktualizacja zrobi z naszymi zmianami) |
| po aktualizacji albo naprawie plików | `powershell -File Modding\tools\dta-restore.ps1` (najpierw `-DryRun`), test w grze, commit |

Restore przywraca nasze pliki z gita. Pliki zmienione przez DTA scala 3-way merge'em (nasze zmiany + zmiany DTA), a binarki
łata od nowa. Jeśli łatka nie pasuje do nowej wersji binarki, zostawia poprzednią załataną binarkę z lokalnego cache'u.

Szczegóły, instalacja na nowym komputerze i pułapki: [Modding/wiki/workflow/repo-and-updates.md](Modding/wiki/workflow/repo-and-updates.md).
