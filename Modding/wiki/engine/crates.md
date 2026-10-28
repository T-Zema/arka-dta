# Skrzynki (crates) i zawieszenie gry przy skrzynce „Unit”

Skrzynka z jednostką losuje pojazd, który gracz może posiadać. Dom bez takiego pojazdu zawiesza grę w nieskończonej pętli. Każda nowa frakcja musi mieć choć jeden pojazd z `CrateGoodie=yes`.

Źródła: `INI/Rules.ini` (`[CrateRules]`, `[Powerups]`, komentarz `CrateGoodie` w nagłówku typów), `Debug/DEBUG_25-10-2026_19-23-21.LOG`
(ostatnia linia przed zawieszeniem: `Crate at 89,136 contains a unit`), skan `CrateGoodie=` w Rules + Enhance + plikach frakcji i opcji.

## Mechanika

- `[Powerups]`: `Unit=70,<none>` to waga skrzynki z pojazdem (obok `Money`, `Armor`, `Veteran`, `HealBase`…; `Invulnerability` w DTA odtwarza
  leczenie obszarowe `AREAHEAL`, zob. [[mods/protoss-faction]], Shield Battery).
- Skrzynka „Unit” losuje typy z `[VehicleTypes]` tak długo, aż trafi na pojazd z **`CrateGoodie=yes`** i `Owner=`, który obejmuje dom gracza.
  Jeśli takiego typu nie ma, losowanie się nie kończy: gra stoi, a w `Debug/` nie powstaje `EXCEPT_*.TXT`
  (mechanizm wywnioskowany z objawu i skanu INI, **(niezweryfikowane w kodzie)**).
- Stan na 2026-10-25: 16 pojazdów DTA ma `CrateGoodie=yes`. GDI 13, Nod 11, Allies 12, Soviet 12, `GDI1` (Terran, klon Aliantów) 12,
  **`Nod1` (Zerg) 0, `GDI2` (Protoss) 0**. Hydralisk Zergów wziął skrzynkę i gra się zawiesiła (test użytkownika).

## Poprawka (blok „Crate goodies (SC factions)” w warstwie `INI/Map Code/SC Factions/900 Hand edits.ini`)

Powtórzone sekcje (klient je scala, późniejszy klucz wygrywa, [[engine/ini-layering]]) z `CrateGoodie=yes`:
Zerg `SCZMUT` Mutalisk, `SCZQUN` Queen, `SCZGRD` Guardian, a Protoss `SCPREAV` Reaver, `SCPSCOU` Scout, `SCPCORS` Corsair.
Blok jest osobny, w górnej, ręcznej warstwie kodu mapy ([[engine/map-code-layers]]), więc generatory frakcji (`build-sczergbase.ps1`, `build-scprotoss.ps1`) i badań go nie nadpisują.
**Nowa frakcja lub dom: dopisz tu co najmniej jeden pojazd z jej `Owner=`.**
