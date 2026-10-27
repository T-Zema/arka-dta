# Mod: Overlord jako silos

Overlordy Zergów podnoszą pojemność silosów gracza o 100, jak Supply Depot, Pylon i Creep Colony. Zainstalowany 2026-10-27 na
prośbę użytkownika (wariant A z [[plans/overlord-storage]]). **Test użytkownika 2026-10-27: Overlord podnosi limit kredytów**
(działa). Przy tym teście wyszedł zły dźwięk śmierci Overlorda, poprawiony w [[mods/zerg-faction]] (dźwięki śmierci pojazdów).

Źródła: [[engine/houses-economy]] (jak działają silosy), deasemblacja `game.exe` (`HouseClass::Tracking_Active_Add` `0x4C45D0`,
`Tracking_Active_Remove` `0x4C4450`, wywołania z `TechnoClass::Unlimbo`/`Limbo`/`Captured`), `Vinifera.dll`
(`HouseClassExt::_Harvested` `0x100C5806`, źródło `houseext_hooks.cpp`), `Vinifera.pdb` (`UnitTypeClass::IsToHarvest` `+0x48E`,
`IsToVeinHarvest` `+0x48F`), kod Vinifery `technoext_hooks.cpp` `_Draw_Pips`.

## Jak działa

- `[SCZOVL]`, `[SCZOVL2]`, `[SCZHYG]` (Yggdrasill): `Storage=100`, w bloku `; >>> SC balance (user)` w
  `INI/Map Code/Terran Faction.ini` (przeżywa generatory).
- **Łatka `game.exe`** `tools/patch-overlordstorage.ps1` (w `patch-game.ps1`): pojazd z `Storage > 0`, który nie jest zbieraczem
  ani „weederem”, dodaje swoje `Storage` do `House->Capacity`, gdy pojawia się na mapie lub zostaje przejęty, i odejmuje je, gdy
  znika z mapy (śmierć, wejście do transportu, przejęcie przez wroga). Robotnicy (`SCZWORK Storage=13` to ładunek) się nie liczą.
- **Łatka `Vinifera.dll`** `tools/patch-vinifera-overlord.ps1` (nowa sekcja `.scstor` za `.scdock`): urobek, który mieści się
  pod limitem domu, ale nie w magazynach budynków, trafia do **pierwszego budynku-silosu** gracza (Hatchery, Lair, Hive,
  Extractor, Creep Colony), ponad jego własne `Storage`.
- Kasa leży więc w budynkach, a Overlord tylko podnosi limit. **Śmierć Overlorda nie zabiera kredytów**, tylko obniża limit
  (nowy urobek przepada, dopóki zapas nie spadnie poniżej limitu). Zniszczenie przepełnionego budynku zabiera całą jego zawartość.
- Wydawanie (`Spend_Money`) zdejmuje kredyty z dowolnego budynku, więc przepełnienie wypłaca się normalnie. Pasek budynku z
  `PipScale=Tiberium` jest po prostu pełny (Vinifera rysuje najwyżej `Max_Pips`).
- Dotyczy gracza: AI w skirmishu i opcja „No Silos” omijają silosy ([[engine/houses-economy]]).
- Ogólna zmiana silnika: dowolny pojazd z `Storage=` bez `Harvester=yes` jest teraz silosem. Nadwyżkę ponad budynki (np. gdy
  limit liczy budynek jeszcze nieaktywny) dostaje silos zamiast przepaść; w klasycznych frakcjach praktycznie się to nie zdarza.

## Instalacja i odinstalowanie

- Instalacja (przy zamkniętej grze): `tools/patch-game.ps1`, potem `tools/patch-vinifera-overlord.ps1`. Po aktualizacji DTA
  kolejność dla `Vinifera.dll`: `patch-vinifera-workers.ps1` → `patch-vinifera-veins.ps1` → `patch-vinifera-overlord.ps1`.
- Odinstalowanie: `patch-vinifera-overlord.ps1 -Revert`, `patch-overlordstorage.ps1 -Revert` i usunięcie trzech sekcji z bloku
  balansu. Cofnięcie robotników odmawia, dopóki `.scstor` istnieje (`patch-vinifera-workers.ps1` szuka teraz `.scdock` po nazwie).
- Test na kopiach (2026-10-27): obie łatki, ponowne uruchomienie („already patched”), deasemblacja, `-Revert` → hash równy
  oryginałowi.

## Do sprawdzenia w grze

1. Gracz Zergiem, kilka Overlordów, dużo robotników: EVA nie mówi „Silos needed” przy zapasie ponad Hatchery + Extractor.
2. Licznik kredytów rośnie ponad pojemność budynków. Wydawanie działa.
3. Śmierć Overlorda przy pełnych silosach: kasa zostaje, limit spada.
