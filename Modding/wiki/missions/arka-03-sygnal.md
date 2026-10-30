# ARKA 3 „Sygnał z nieba” (Antiga Prime, 2499): mapa i misja

Trzecia misja z [[plans/campaign-arka]], **misja „covert”** (prośba użytkownika 2026-10-30: mniej rozbudowy bazy, inna niż poprzednie). Kerrigan w maskowaniu oślepia 2 wieże obserwacyjne, potem obóz jeniecki, psi-nadajnik Mengska (wybór) i Command Center garnizonu Konfederacji. Teren to mapa kampanii SC **T5 „Revolution”** (w SC właśnie powstanie na Antidze i debiut Kerrigan) obrócona o 90° w prawo, a w prawym górnym rogu stoi **baza z misji 4** wycięta z T6 „Norad II” (ten sam teren, te same budynki, bez namiotu Einsteina). Kompletna od startu do wygranej, **(niezweryfikowane w grze)**.

Źródła: CASC `SD/campaign/Terran/Terran05/staredit/scenario.chk` (T5, 96×96 badlands) i `Terran06` (róg bazy), zrzut startu misji 4 od użytkownika (2026-10-30: „uznaj, że to jest górny prawy róg mapy, pole walki skieruj na dół”), `Modding/tools/build-arka03-antiga.ps1`, `Modding/tools/build-arka03-mission.ps1`, `Maps/Missions/arka04.map` (układ bazy), `INI/Game Options/StarCraft.ini` (`[SCGHOST]`, `[SCMTUR]`, `[SCCOMS]`, `[SCBARR]`), `INI/Rules.ini` (`[AHPAD]`, `[OverlayTypes]` 001 `CYCL`), `Map Editor/FinalSun/FSData.ini` (zdarzenia 6, 34, 44), [[missions/arka-04-zielony-krysztal]], [[missions/arka-05-tarsonis]] (Kerrigan, psi-nadajnik).

## Pliki

| Plik | Rola |
|---|---|
| `Maps/Custom/arka03_antiga.map` (+ `.png`) | teren (skirmish „Custom Map”), waypointy 10–61, 2 kopalnie; **nadpisywany** przez skrypt terenu |
| `Maps/Missions/arka03.map` | misja; **nadpisywana** przez skrypt misji |
| `INI/BattleE.ini` | wpis `M_ARKA03`; skrypt **scala** |
| `Modding/tools/build-arka03-antiga.ps1` | teren: T5 obrócona + róg T6, groble, zoom 1,5, TEMPERATE, grunt i drzewa rogu jak w misji 4, waypointy, mapa ASCII |
| `Modding/tools/build-arka03-mission.ps1` | misja: typy SC, Kerrigan, wieże, obóz jeniecki, garnizon, domy, 8 drużyn, 123 triggery, 58 tekstów, kontrole |
| `%TEMP%\arka03-terrain\` | `ascii.txt` (1 znak = 1 kafel kompozytu: `.` nizina, `H` płaskowyż, `~` woda, `^` klif, `$` kryształy, `R` brzeg bez elementu, `B` most; małe litery = nieosiągalne), `grid.png`, `reach.png`, `sc.png`, render |
| `%TEMP%\arka03-mission\log.txt` | oś czasu tekstów, odległości wież od straży, kontrole |

```powershell
powershell -NoProfile -File Modding\tools\build-arka03-antiga.ps1           # teren z renderem (ok. 2 min)
powershell -NoProfile -File Modding\tools\build-arka03-mission.ps1 -Render  # misja
```

## Teren

- **Kompozyt na poziomie minikafli SC:** T5 obrócona `(x, y) → (H−1−y, x)` (start T5 z lewego górnego rogu idzie w prawy górny, baza Konfederacji T5 na dół w prawo, róg buntowników T5 w lewy górny). Obie mapy to badlands. Wklejka T6 (kafle po zoomie x 0–72, y 84–144 → x 72–144, y 0–60) zastępuje flagi i kolory minikafli, więc konwerter sam rysuje klify i brzegi przez szew. Pas 10 kafli wzdłuż szwu rozstrzyga gładki szum (postrzępiony brzeg zamiast linijki), a płaskowyż T6 nie wchodzi w pas.
- **Przesunięcie x musi być parzyste:** wtedy każda komórka DTA rogu to cała komórka mapy misji 4 (ta sama `Size`). Komórka misji 3 = komórka misji 4 + **(−48, −120)**. Z tego korzystają waypointy 10–21, grunt rogu (szum misji 4 w jej komórkach), drzewa rogu (kopiowane z `arka04_antiga.map`) i budynki bazy (z `arka04.map`).
- **Groble** przez jezioro (ciemne „mosty” T5 to doodady nie do przejścia): wyspa obok bazy ↔ zachodni brzeg (obóz Synów Korhalu) i wyspa SW ↔ brzeg pod płaskowyżem. Mają 9 kafli szerokości. Węższe pasy kończyły jako brukowana „piła” w wodzie, zob. [[engine/starcraft-maps]] „Brzegi i przesmyki”.
- Kontrole: 0 nieudanych łańcuchów, 51 waypointów osiągalnych z ARKI, 13 011 z 14 072 otwartych pól osiągalnych (reszta to dekoracyjny płaskowyż T6 w rogu NE). Surowe krawędzie ląd/woda: 4.
- Pułapka PowerShella przy rysowaniu grobli: `[Math]::Min(1, x)` wybrało przeciążenie `int` i zaokrągliło ułamek, więc grobla miała tylko końce. Liczyć na `0.0`/`1.0`.

## Waypointy (kontrakt teren ↔ misja)

| Nr | Co | Nr | Co |
|---|---|---|---|
| 10–19 | baza z misji 4 (ARKA, armia, koszary, lądowisko na miejscu ConYardu, rafineria, fabryka, 2 elektrownie, Kerrigan na miejscu laboratorium, radar) | 20, 21 | linie bunkrów N i E |
| 22–24 | obóz Synów Korhalu (CC, koszary, wyjście) | 25, 26 | grobla A, grobla B |
| 27 | brzeg SW pod płaskowyżem | 28 / 29, 57 | wieża 1 (dolina SE) / jej straże |
| 30 / 31 | wieża 2 (ścieżka nad jeziorem) / straż | 32–34 | obóz jeniecki: blok, brama, straż |
| 35 / 36 | przedmieścia Antigi / posterunek | 37–42 | garnizon: CC, koszary, fabryka, rampa, obrona N, kryształy |
| 43 | psi-nadajnik | 44–47 | wloty Zergów: S, E, NE, latające SW |
| 48 | zbiórka patroli Konfederacji | 50–53 | skrzynki: przedmieścia, wyspa, wyspa SW, magazyn garnizonu |
| 54–56 | pola: obóz, płaskowyż centralny (kopalnia), wyspa SW (kopalnia) | 58–61 | trasa Synów Korhalu, środek płaskowyżu B, brzeg SW, zachodni pas |

## Misja

**Domy:** `Allies` gracz (3000, TechLevel 6, śmigłowce, **bez MCV**: `AMCV TechLevel=-1`), `GDI` garnizon Konfederacji (ciemnoczerwony), `Soviet` Synowie Korhalu (złoci), `Soviet1` psi-nadajnik (sojusznik garnizonu i Zergów, nie gracza), `Nod1` Zergi, `Allies1` jeńcy (ukryty sojusznik wszystkich), `Neutral` przedmieścia.

**Budynki neutralne SC** ([[mods/sc-neutral-buildings]], od 2026-10-30): w przedmieściach Starbase `SCNSTB` (stacja kosmiczna w środku) i Power Generator `SCNGEN` (generator miejski), w garnizonie Ion Cannon `SCNION` (ozdoba, nie strzela).

**Nowe typy w mapie:** `ARKKERR` (Kerrigan: Ghost SC z misji 5, 2700 HP, broń ×3, samoleczenie, **`Cloakable=yes`**), `ARKTOWR` (wieża obserwacyjna: obraz Missile Turret, bez broni, `Sensors=yes`, `Sight=9`, 1500 HP), `ARKJAIL` (blok obozu: obraz Barracks), `ARKPSIE` (psi-nadajnik jak w misji 5), `ARKRAYN`, `ARKEINST`.

**Mechanika skradania:**
- straże wież stoją 16–21 pól od wieży; Kerrigan ukryta jest dla nich niewidoczna, a wieża widzi ją tylko z bliska i sama nie strzela;
- **wyłączenie wieży:** jednostka gracza wchodzi w strefę 3 pól wokół wieży (`1 Entered by` na komórkach) → zmienna, potem w łańcuchu tagu wieży (`13 Elapsed 1`, wzór cra12) `14 Change House` → Neutral. Zmiana domu nie idzie z triggera komórki, bo ten mógłby przenieść wchodzącą jednostkę;
- **alarm:** Kerrigan trafiona przez garnizon (`44 Attacked by` GDI na jej tagu, łańcuch z „Kerrigan zginęła”) albo wieża ostrzelana (`6`) lub zniszczona → zmienna 2: pościg przy wieży i co 420 s oddział (4 Marines, 2 Goliathy, Siege Tank, Vulture) na bazę. Zniszczona wieża też zalicza cel 1.

**Przebieg (sekundy gry, `$GameSecPerReal = 4.5` jak ARKA 0):**

| Kiedy | Co |
|---|---|
| 1–500 | Mengsk przedstawia Kerrigan, dialog z planu (Kerrigan i Tanya, Raynor patrzy), **cel 1** (2 wieże), wskazówki o maskowaniu i alarmie, Stavros: lądowisko, bez placu budowy |
| 700, potem co 480 | patrol Konfederacji (2 Vulture, 2 Marines) na rafinerię gracza (`0,3`) |
| obie wieże | Mengsk, natarcia Synów Korhalu z obozu groblą B na garnizon (co 540 s), **cel 2** (obóz jeniecki) |
| gracz za ogrodzeniem albo blok zniszczony | `36 All change house`: 6 buntowników przechodzi do gracza |
| wieże + obóz, najpóźniej 1800 s | +60 s: Zergi (muzyka `SCTERR2`), fale z S i E na garnizon, rajd z NE na rafinerię, Mutaliski; **cel 4** (CC garnizonu) |
| Tanya przy nadajniku (`34` na jej tagu), dowolna jednostka przy nim albo 420 s po Zergach (Stavros) | dialog z planu (Tanya, Einstein, Kerrigan do Raynora), **wybór**: zniszcz nadajnik albo zostaw |
| nadajnik zniszczony | fale Zergów ustają, Mengsk: „Zapamiętam to” |
| CC garnizonu zniszczone (`48`) | porażki wyłączone, jeńcy wychodzą sami (jeśli nie byli uwolnieni), mowa Mengska, kwestia zależna od wyboru, ognisko Raynor–Kerrigan, **wygrana** |

**Porażka:** ARKA (20 000 HP, można naprawiać), Einstein, Tanya, Raynor, Kerrigan, utrata wszystkiego.

**Zasady z [[workflow/mission-design]]:** pole przy bazie ubogie, pola na wyspie, w obozie, na płaskowyżu centralnym (kopalnia, sporne) i na wyspie SW (kopalnia), kryształy garnizonu; 4 skrzynki (przedmieścia 2000, wyspa 1500, wyspa SW 2500, magazyn garnizonu 3000) i skrzynka odkrycia mapy; rajdy powtarzane na rafinerię (Konfederacja, potem Zergi), wyłączane przy upadku garnizonu; przypominajki celów 1, 2, 4 i postęp „wieże 1 z 2”. Oś tekstów 0 WARN, cisza w dialogach 0 WARN.

**Odstępstwa od planu:** Synowie Korhalu nie przechodzą do misji 4 jako oddział, a mniejsza kasa w misji 4 też nie, bo misje ARKA to osobne bitwy; wybór komentuje tylko Mengsk. Lotnictwo to lądowisko w bazie (`AHPAD` na miejscu ConYardu misji 4), śmigłowiec trzeba zbudować.

## Do sprawdzenia w grze

- Czy Ghost `Cloakable=yes` naprawdę się maskuje i czy wieża (`Sensors=yes`) go odkrywa dla garnizonu.
- Czy `14 Change House` w łańcuchu tagu wieży zmienia dom wieży (a nie Kerrigan) i czy `44 Attacked by` łapie strzały garnizonu.
- Czy straże nie widzą Kerrigan przy wieży 1 (posterunek przedmieść stoi 13 pól od niej).
- Promień `34 Comes near waypoint` dla Tanyi; zapasowo działa strefa i podpowiedź Stavrosa.
- Czy buntownicy (`Allies1`, misja `Sleep`) przechodzą do gracza po wejściu za ogrodzenie (brama na rogu, 2 pola).
