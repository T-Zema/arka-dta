# Przegląd: DTA jako platforma do modowania

Czym jest instalacja DTA, gdzie co leży i jak się do niej podchodzi przy modowaniu.

Źródła: katalog gry, `Debug/DEBUG_23-10-2026_08-59-14.LOG`, `INI/Rules.ini` (`[Sides]`, `[Houses]`).

## Silnik

- **Tiberian Sun** (`game.exe`) z rozszerzeniem **Vinifera** (`Vinifera.dll`, `LaunchVinifera.dat`).
  Vinifera dodaje m.in. `$Inherits=` w INI, `Modifier.<armor>=` w głowicach, `CellSpread`/`PercentAtMax`,
  `CanShakeScreen`, `Totable`, `[PrerequisiteGroups]` oraz rozszerzenia typów (log pokazuje
  `Processing ...TypeExtensions`).
- Klient **DTA.exe** (XNA/CnCNet): lobby, kampanie, generowanie `spawn.ini` + `spawnmap.ini`.
- Grafika jednostek to **SHP** (`Voxel=no` prawie wszędzie), nie voxele.

## Strony i domy

- `[Sides]`: `GDISide`, `NodSide`, `AlliesSide`, `SovietSide` (+ `Neutral`, `Special`).
- `[Houses]`: 0=GDI, 1=Nod, 2=Allies, 3=Soviet, 4=Neutral, 5=Special, 6–13 = GDI1/Nod1/GDI2/Nod2/Allies1/Allies2/Soviet1/Soviet2.
- `Owner=` jednostki odnosi się do tych nazw domów. W misjach są też domy pomocnicze (np. `Soviet2`, `Soviet3`).
- Indeksy domów są „twarde” (klient, triggery misji). Szczegóły i pułapki przy dodawaniu frakcji: [[engine/sides-and-houses]], [[plans/new-faction]].

## Najważniejsze mechanizmy

- [[engine/ini-layering]]: kolejność, w jakiej silnik nakłada INI (Rules → mapa → opcje gry).
- [[engine/tech-and-prerequisites]]: dlaczego jednostkę da się albo nie da zbudować.
- [[engine/adding-new-types]]: jak dodać zupełnie nową jednostkę bez ruszania Rules.ini.
- [[engine/weapons-and-warheads]]: bronie, głowice, lasery, tesla, railgun, jumpjet.
- [[engine/houses-economy]]: kasa, mnożniki budowania i siły.
- [[engine/superweapons]]: supermoce i ich podpinanie pod budynki.
- [[engine/client-lobby-options]]: własne checkboxy w lobby skirmisha.
- [[engine/debugging]]: logi, crashe, jak weryfikować zmiany.

## Zasada bezpieczeństwa

Zmiany robimy **w mapie albo w opcji gry**, a nie w `INI/Rules.ini`, chyba że użytkownik wyraźnie chce
inaczej. Powód: zmieniony Rules.ini psuje grę online (niezgodne pliki), a aktualizacje klienta go nadpisują.
