# Własne opcje w lobby skirmisha (checkbox → plik INI)

Klient DTA pozwala dodać checkbox, który po zaznaczeniu dokleja plik INI do mapy. To najczystszy sposób na mod, który da się włączać i wyłączać.

Źródła: `Resources/SkirmishLobby.ini` (`[GameOptionsPanel]`, `[chk*]`), `Resources/GlobalThemeSettings.ini` (`CHECKBOX_SPACING=23`), `INI/Game Options/*.ini`.

## Przepis

1. Plik z nadpisaniami: `INI/Game Options/<Nazwa>.ini`. Format jak sekcje mapy, bez nagłówka (np. `Immune Harvesters.ini`).
2. Rejestracja kontrolki w `[GameOptionsPanel]` (kolejny wolny numer):
   ```ini
   $CC34=chkSuperMod:GameLobbyCheckBox
   ```
3. Sekcja kontrolki:
   ```ini
   [chkSuperMod]
   Text=SUPER MOD
   CustomIniPath=INI/Game Options/Super Mod.ini
   Checked=False
   ToolTip=...
   MapScoringMode=DenyWhenChecked
   $X=getX(cmbClassicEnhanced)
   $Y=getBottom($ParentControl) - 38
   ```
   Inne przydatne klucze: `Reversed=yes` (zaznaczony = plik NIE jest doklejany), `SpawnIniOption=` (zamiast pliku
   ustawia klucz w `spawn.ini`), `Visible=False`, `Enabled=False`.

## Układ

- Panel `GameOptionsPanel` ma `$Height=266`. Obie kolumny checkboxów (X=128 i X=270, start Y=9, co 23 px,
  po 11 pozycji) są **pełne**.
- Wolne miejsce udało się zrobić tylko w lewym dolnym rogu: ukryty `chkIngameAllying` (w skirmishu i tak
  zablokowany: `Enabled=False`, `AllowChecking=false`) dostał `Visible=False`, a na jego pozycji stoi nowy checkbox.
- Kolejne opcje wymagałyby powiększenia panelu albo zamiany checkboxa na dropdown **(niezweryfikowane)**.

## Pułapki

- Aktualizacja klienta może nadpisać `SkirmishLobby.ini`. Kopia oryginału leży w `SkirmishLobby.ini.bak`
  oraz w [[mods/super-mod-v1]] w archiwum.
- Opcja dotyczy **wszystkich graczy** w meczu, także AI.
- Klient może liczyć sumy kontrolne plików w `INI/` (w tym `Game Options`) dla gry online. Dodatkowy plik może
  wywołać ostrzeżenie o zmodyfikowanych plikach **(niezweryfikowane)**.
