# Projekt misji ARKA: zasady z recenzji

Zasady rozgrywki dla każdej nowej i zmienianej misji ARKA (i innych misji robionych w tym repo). Mają sprawić, że gracz chce rozbudować bazę i wyjść z niej. Wzięły się z recenzji kolegi użytkownika po zagraniu preludium [[missions/arka-00-triggers]] (2026-10-27): „misje są mało angażujące, bo nie ma sensu rozwijać bazy; trzeba więcej harrasu ze strony AI”. Sprawdzaj tę stronę przed zamknięciem projektu misji i przy każdej zmianie fal.

Źródła: recenzja (wiadomość użytkownika 2026-10-27), `Modding/tools/build-arka00-mission.ps1`, `build-arka-gibraltar.ps1`, `MissionKit.ps1`, misje DTA (`cra10`, `cr08`, `chainbreaker`: skrypty `0,3`; `cr05`, `a_bridge_too_few`: akcja `106`), `INI/Rules.ini` (`[Ore]`, `[OREMINE]`, `[CrateRules]`).

## Problem

Misja obronna z licznikiem (ARKA 0: 30 minut) i bogatą bazą startową nie daje powodu do budowy: fale idą prosto na cel, kasa wystarcza, a na mapie nie ma czego zbierać (w v2 ok. 15 komórek rudy). Gracz siedzi w bazie i czeka.

## Zasady

1. **Ekonomia warta wysiłku.** Na mapie mają być co najmniej trzy złoża w różnej odległości i o różnym ryzyku:
   - bezpieczne, blisko bazy;
   - bogate, ale wystawione na atak (na Gibraltarze: Skała, poziom 1, największe z trzech pól; razem ok. 380 komórek rudy);
   - sporne, na trasie wroga (lotnisko);
   - **kopalnia** (`OREMINE`, `TiberiumToSpawn=3`, rośnie wokół niej ruda; `[Ore]` sama się nie rozrasta, `SpreadPercentage=0`) daleko od bazy, żeby opłacało się ją trzymać.
   
   Ruda to `ZORE01–04` (nakładki 147–150), w DTA nazywana złotem.
2. **Łupy poza bazą.** Skrzynki z pieniędzmi w ciekawych miejscach (kościół, garnizon, magazyn): `Add-MoneyCrate x y kwota 'tekst'` z [[engine/triggers-and-dialogue]] (pułapka 9). Kwoty zauważalne: 1500–5000 przy 10 000 na start.
3. **Harras AI przez całą misję**, nie tylko duże fale:
   - małe, szybkie oddziały co 3–5 minut, **powtarzane** do końca (trigger `-Repeat -Disabled` z `Elapsed`, włączany raz; wzór w ARKA 0, 1 i 2);
   - cel to gospodarka, nie od razu główny budynek: `16,<wp złoża>` (atak w ruchu na pole), `0,3` (atak na zbieracze), potem `16,10` / `0,9` (elektrownie) i `11,14` (polowanie);
   - każdy kierunek inny (północ / Skała / morze albo tunel), żeby gracz musiał mieć obronę przy każdym złożu, a nie tylko przy bramie;
   - tekst tylko przy pierwszym rajdzie danego rodzaju, powtórki bez tekstu (inaczej zalewają dialog);
   - finał wyłącza rajdy (`54 Disable`).
4. **Powód do rozbudowy:** cele dodatkowe za bazą (zakładnik, budynek do przejęcia, kopalnia), które wymagają oddziału, a nie tylko obrony.
5. **Mapa czytelna:** drogi prowadzą gdzieś, jak w misjach DTA ([[workflow/mission-maps]], „Drogi”).
6. **Najpierw przeczytać, potem walczyć** (lekcja użytkownika po teście ARKA 0, 2026-10-29: „jak lecą teksty, to daj graczowi przeczytać i potem zwiększ dynamikę gry”). Podczas dialogu fabularnego (łańcuch 2+ kwestii) nie przychodzi żadna fala, desant ani rajd; tempo rośnie dopiero po ostatniej kwestii. Fala zapowiedziana pierwszą kwestią łańcucha może przyjść razem z nią. W generatorze:
   - `Test-QuietDialogue` z `MissionKit.ps1` (po `Set-DialoguePacing`, **przed** `Add-Difficulty`) daje `WARN`, gdy wróg (akcje `7`/`80` z drużyną spoza sojuszników gracza, także kolejne odpalenia powtarzanych rajdów) przychodzi w trakcie dialogu. Misja ma mieć 0 WARN; naprawa = przesunąć falę przed dialog albo za niego, nie skracać dialogu;
   - odstępy między kwestiami liczyć hojnie: w ARKA 0 `$GameSecPerReal = 4.5` (domyślnie 3 było za mało, zob. [[engine/triggers-and-dialogue]] „Tempo dialogów”);
   - kwestie zależne od zdarzeń (odbicie zakładnika, przejęcie) nie mają znanego czasu. Trzymać je krótkie (2–3 kwestie) albo dawać je wtedy, gdy wiadomo, że jest spokojnie.

## Lista kontrolna nowej misji

- [ ] 3+ złoża (bezpieczne / bogate na widoku / sporne) i kopalnia; waypoint przy każdym (cel rajdów).
- [ ] 1–4 skrzynki z pieniędzmi w ciekawych miejscach, waypoint przy każdej.
- [ ] Rajdy powtarzane na każde złoże, `0,3` w skrypcie, wyłączane w finale.
- [ ] Oś czasu tekstów 0 WARN po dodaniu rajdów (`Test-TextTimeline`).
- [ ] Żadna fala w trakcie dialogu: `Test-QuietDialogue` 0 WARN (zasada 6).
- [ ] Drogi bez wolnych końców (`free ends 0` w logu terenu).

## Stan w misjach

| Misja | Złoża | Łupy | Harras |
|---|---|---|---|
| ARKA 0 ([[missions/arka-00-triggers]]) | Skała (wp 47), lotnisko (39), Windmill Hill + `OREMINE` (38) | złoto ukryte w kościele: inżynier wchodzi do The Convent, 5000 (skrzynki na Skale usunięte); armata 100 Ton Gun za 4 inżynierów | 3 rajdy powtarzane od 692 / 933 / 1157 s, co 224 / 291 / 246 s (od 2026-10-29: harmonogram ×1,12) |
| ARKA 1 ([[missions/arka-01-marsara]]) | do przejrzenia | – | fala powtarzana co 300 s od 1500 s |
| ARKA 2 ([[missions/arka-02-ewakuacja]]) | do przejrzenia | – | najazd powtarzany co 450 s od 1500 s |
| ARKA 4 ([[missions/arka-04-zielony-krysztal]]) | pole bazy ubogie (wp 15), NW (20, lekko strzeżone), centrum (21, w gnieździe), Stickler Woods (39, najbogatsze, gniazdo NE), przy Hive (41); przy każdym kopalnia **niebieskich kryształów** (`OREMINE2` z `TiberiumToSpawn=6`; złota brak na prośbę użytkownika) | 4 skrzynki: Norad II 3000, centrum 2000, Stickler 2500, NW 1500 | rajdy powtarzane `0,3`: centrum → NW od 900 co 600, Hive → Stickler od 1500 co 720, zachód → pole bazy od 1300 co 540; wyłączane przy ostatniej fali; AI Zergów dobudowuje kolonie |
| ARKA 5 ([[missions/arka-05-tarsonis]]) | **same kryształy** (bez złota, życzenie użytkownika): nad kraterem (wp 15, bezpieczne), zachodnia równina + kopalnia kryształów `OREMINE2` (52, sporne), wschodnia równina (53, najbogatsze), minerały SC w 3 miastach (22/27/32) | 4 skrzynki w dzielnicach: Delta 3000, Nova 2500, Omega 2500, Gamma 2000 (wp 24/29/34/38) | 3 strumienie z nadajników, desant Overlordami (W na 52, SW na Omegę, SE na 53, wszystkie `0,3`) od 800 / 1050 / 1300 s co 600 / 660 / 540 s, póki stoi nadajnik; północ na wp 15 od 1600 co 780; Mutaliski od 2100 co 900 (rozsunięte po uwadze „za szybko”); walki w mieście w tle; wyłączane przy ewakuacji |

Wszystko **(niezweryfikowane w grze)**: czy `Elapsed` w powtarzalnym triggerze odlicza od nowa po każdym odpaleniu, czy drewniana skrzynka w misji solo daje `SoloCrateMoney` obok akcji `106`, i czy `0,3` znajduje zbieracz gracza na drugim końcu mapy.
