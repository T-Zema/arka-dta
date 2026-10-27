# Klify, brzegi i klify wodne: łączenie kafli

Jak układać wieloczęściowe kafle klifów i brzegów DTA tak, żeby się stykały, oraz którą stronę klifu gra traktuje jako „górę”.

Źródła: `Map Editor/Editor/Config/ConnectedTileDrawer.ini` (konfiguracja narzędzia „connected tiles” edytora WAE),
statystyka połączeń w 270 mapach Temperate (2026-10-24), arkusze kafli `cliff*.tem`, `wcliff*.tem`, `beach*.tem`,
implementacja w `Modding/tools/ScToDta.cs` (`ConnectedSet`, `Chain`).

## Zestawy

W `ConnectedTileDrawer.ini` są m.in. `TemperateCliffSet` (33 elementy, zestaw kafli `Cliffs`), `TemperateWaterCliffSet`
(26, `Water Cliffs`), `TemperateShoreSet` (64, `Shores`), `TemperateSmallShoreSet`, drogi i rzeki, oraz odpowiedniki Snow/Desert.
Sekcja `[Zestaw.i]`: `TileSet`, `TileIndices` (warianty o tym samym kształcie), `ConnectionPoint0/1=x,y` (komórka względem
początku szablonu), `.Directions` (8 znaków), `.Side=Front/Back`, opcjonalnie `Foundation`.

- Znaki `Directions` od lewej: **N, NE, E, SE, S, SW, W, NW**. W komórkach: N = `(0,−1)` (ekran: prawo-góra),
  E = `(+1,0)` (prawo-dół), S = `(0,+1)` (lewo-dół), W = `(−1,0)` (lewo-góra), NW = góra ekranu, SE = dół ekranu.
- Element z jednym punktem to **zakończenie**. Klify mają zakończenia, a Water Cliffs i Shores nie mają, więc ich łańcuchy
  muszą wychodzić poza mapę albo dochodzić do innego łańcucha.

## Reguła łączenia (potwierdzona)

Element B pasuje do punktu A, gdy **komórka punktu B = komórka punktu A + kierunek d**, `d` jest w `Directions` A,
przeciwny kierunek `(d+4) mod 8` jest w `Directions` B, a `Side` obu punktów jest taka sama. Na 270 mapach tak stykało się
~43,6 tys. par sąsiednich klifów. Inne układy to przypadkowe sąsiedztwo.

## Która strona jest wyżej (klify)

DTA nie ma wysokości, ale grafika klifu ma „górę” i „dół”. Z budowy narożników wynika:

| Punkt | Kierunki | Front | Back |
|---|---|---|---|
| „E-W” (poziomy na ekranie, łączenia W/E/N/S) | | góra po stronie **N ekranu** (płaskowyż nad klifem) | góra po stronie **S ekranu** |
| „N-S” (pionowy, łączenia NW/SE) | zawiera NW lub SE | góra po stronie **E ekranu** | góra po stronie **W ekranu** |

Kształty: elementy E-W dają linię poziomą albo ukośną pod ~26,6° (izometryczną), N-S dają pion albo strome skosy.
W obrębie szablonu klifu komórki `0` (trawa) leżą zwykle po dolnej stronie, `7` to ściana skalna.
Water Cliffs orientuje się tak samo (góra = ląd). Shores najprościej po kodach komórek, ale **woda w szablonach plaży ma
kod `9` albo `1`** (`1` = płytka woda, przejezdna; `2` = piasek, `0` = trawa). Sprawdzone na renderze kawałków
`TemperateShoreSet` 2026-10-26. Wiele kawałków ma tylko `0/1/2`, więc koszt liczony po samym `9` widzi cały szablon jako
ląd. Łańcuch plaży wędrował wtedy 1–2 komórki w głąb lądu (schodki trawy od strony morza), a na cyplu Europa Point
ułożył się odwrotnie (woda od strony lądu). Poprawka w `DesignToDta.Beaches`: koszt za wodę na lądzie i ląd na wodzie po
równo plus sonda 2 komórki za częścią mokrą (musi być woda) i za suchą (musi być ląd). [[missions/arka-00-gibraltar]]

Plaże są potrzebne tam, gdzie ma lądować desant z morza: poduszkowce (`SpeedType=Hover`) i `LST` (`Amphibious`) nie
przejadą przez skalne komórki klifów wodnych.

## Automatyczne układanie (jak w ScToDta.cs)

1. Kontur obszaru (płaskowyżu, jeziora) śledzony po krawędziach między komórkami, z prawymi skrętami.
2. Kontur cięty na łuki: rampa (brak klifu), krawędź mapy, odcinek oddany innemu łańcuchowi (płaskowyż nad wodą → Water Cliffs).
3. Na każdy łuk A*: stan = otwarty punkt połączenia, ruch = dołożenie elementu zgodnie z regułą wyżej, koszt = skała na
   płaskowyżu lub nizinie, zła orientacja (sondy 2–4 komórki w stronę „góry” i „dołu”), wyjście poza korytarz ±3 komórki.
   Postęp liczony **wzdłuż ścieżki łuku** (okno przesuwane do przodu), bo inaczej łańcuch skraca sobie drogę, gdy początek
   i koniec łuku leżą blisko siebie (np. jezioro w rogu mapy). Nowy element nie może nachodzić na **żaden** wcześniejszy
   element łańcucha: w wąskim kanale (2–3 komórki) łańcuch potrafił zejść jednym brzegiem i wrócić po tym samym.
   W klifach wodnych stronę wody sprawdza się tylko w komórce tuż obok punktu, bo dalej w wąskim kanale leży już drugi brzeg.
4. Koniec łuku: przy rampie zakończenie, przy krawędzi mapy wyjście poza `LocalSize`, przy wodzie dojście do wody.
   Bez tego zostają przesmyki, którymi da się wjechać na odcięty płaskowyż.
