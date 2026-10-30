# Plan: AI Protossów (skirmish + ARKA 6) wzorowane na AI StarCrafta

Studium z 2026-10-30 (prośba użytkownika: „dorób AI protossów, inspiruj się AI ze SC, a czego brakuje, bierz z silnika i misji DTA; najpierw inżynieria wsteczna”). Jak gra Protoss w SC, co silnik TS pozwala z tego odtworzyć i projekt wdrożenia. **Wdrożone 2026-10-30 w [[mods/protoss-ai]]**, ale inaczej niż w projekcie A niżej: w skirmishu domyślnie działa Advanced AI DTA, które wyłącza AITriggery ([[engine/advanced-ai]]). Zamiast triggerów strony 9 są więc taktyki `House=8`. Łatka Vinifery przenosi Probe'a i MCV do kolejki morskiej (Advanced AI stawia Robotics/Stargate na lądzie samo), a w klasycznym AI dodatkowo kieruje na wodę tylko budynki `WaterBound`. Decyzje użytkownika („pracuj z ograniczeniami, jakikolwiek koszt”): łatka Vinifery tak, styl melee z elementami kampanii.

Źródła: CASC StarCrafta `scripts/aiscript.bin`, `scripts/bwscript.bin`, `rez/stat_txt.tbl`, `campaign/terran/terran07/staredit/scenario.chk` (T7), `campaign/protoss/protoss01/...` (P1); dekoder z tablicą opkodów z PyMS `AIBIN.py` (listingi wszystkich 293 skryptów: `%TEMP%\claude\…\scratchpad\scai\listings\`, w tym `PMCx`, `PMCu`, `PLOx`, `PMEx`, `PHIx`, `PSUx`, `chk_t07.txt`), [[engine/skirmish-ai]], [[mods/protoss-faction]], [[engine/zerg-ai]], [[missions/arka-06-ogien-z-nieba]].

## Jak gra Protoss w SC

Czas: `wait` liczy klatki, na Fastest 23,8 klatki/s (3000 klatek ≈ 126 s).

**Melee (`PMCx`, Brood War):**
- **Gospodarka:** Probe'y najpierw do 8, potem do 27 (limit). Każdy etap budowy czeka na liczbę Probe'ów. Pylony stawia z wyprzedzeniem zapasu (`farms_timing`).
- **Otwarcia losowe:**
  - 12,5%: działka i szybka ekspansja (Forge → 6 Photon Cannonów);
  - 14,5% przeciw Terran/Protoss: Dark Templar i Storm;
  - inaczej Gateway ×2–3 i Zealoty, Shield Battery.
- **Reakcja na rywala:** jeśli wróg ma Citadel of Adun, AI idzie w Robotics i Observera (wykrywanie).
- **Ataki po kamieniach milowych armii, nie po zegarze:**
  - fala 1: 12 Zealotów;
  - fala 2: 12 Zealotów, 6 Dragoonów, 2 DT;
  - fala 3: 12 Zealotów, 8 Scoutów, 4 Corsairy;
  - potem pętla: 10 Scoutów, 8 Corsairów i 5 Carrierów co ok. 38 s.
- **Tech:** Cybernetics Core, Forge, Dragoony, Citadel, Templar Archives, Robotics + Shuttle, Stargate, Observatory, Support Bay, Fleet Beacon, Arbiter Tribunal.
- **Produkcja w wątkach:** stale 12 Zealotów, 6 Dragoonów (po Cyber Core), 8 Corsairów i 10 Scoutów (po Stargate).
- **Ulepszenia:** osobny wątek na budynek, każde po liczbie jednostek (Leg Enhancements przy 12 Zealotach, Singularity przy 6 Dragoonach).
- **Ekspansje:** w ustalonych punktach budowy, „panika” poniżej 7500 minerałów w bazie, `expand(99)` co ok. 5 min. Każda nowa baza: Nexus, Pylon, Probe'y, do 6 działek. `player_need` odbudowuje stracone budynki techniczne.
- **Obrona (`defensebuild`/`defenseuse`):** na atak z ziemi 2 Zealoty, 1 Dragoon, 1 Reaver, 1 DT, 1 Archon, 1 Carrier, 1 Scout. Na lotników nad ziemią Dragoon, Scout, Archon, Carrier. High Templar pilnują Nexusa, minerałów i gazu (`place_guard`).
- **Mapy wyspowe:** Probe'y, Shuttle'e, w końcu armia powietrzna.

**Kampania (`PLOx`/`PMEx`/`PHIx`/`PSUx` = Easy/Medium/Difficult/Insane):**
- Budowa to stała lista życzeń (Nexus, 6 Probe'ów, Gateway, Cyber Core, Forge, na Difficult też Stargate i Robotics), którą silnik odbudowuje.
- Ataki **na zegar:** `wait` → zbiórka → `attack_do`. Fale rosną:
  - Difficult: co 126 s 3 Zealoty → 4 Zealoty + 2 Dragoony → 6 Zealotów + 4 Dragoony + 2 Scouty → 6 Zealotów + 4 Dragoony + Reaver → … → pętla z Carrierami, Archonami i Arbitrem;
  - Easy: od 189 s, małe fale co 126–252 s.
- Obrońcy stali: 2 Zealoty + Dragoon, Dragoon na lotników, Corsair + Scout. Od Medium dochodzi Reaver, na Difficult DT, Archon i Carrier.
- Insane: ściąga kasę (`give_money`), 4 ekspansje, do 12 działek.

**T7 „Biting the Bullet” (mapa ARKA 6):** w oryginale **Protossi nie mają AI**. Gracze 6 i 8 (plemię Akilae) są „Rescue-Passive”. Gantrithor, 27 Scoutów i 2 Carriery pojawiają się z triggera przy zachodniej krawędzi po zniszczeniu Zergów. Grają tylko Zergi (`Te7s`, `Te7m`, `Ter7` + desanty z triggerów). Fale Fenixa z [[plans/campaign-arka]] to nasz pomysł, nie kopia SC. **P1 „First Strike”** (Antioch): baza Protossów i Fenix też są pasywni, AI ma tylko Zerg.

## Co da się przenieść na silnik TS

| SC | TS / DTA | Uwagi |
|---|---|---|
| lista budowy, odbudowa | plan bazy z `[AI]` + `AIBuildThis` (skirmish), węzły `NodeCount` (misja) | kolejność wynika z wymagań i kolejności `[BuildingTypes]` ([[engine/skirmish-ai]]) |
| Pylon = zapas | wstawianie `RegularPowerPlant=SCPPYL` przy braku prądu | działa samo, bo budynki mają `Power=-10…-40` |
| zasięg Pylonów | AI go **nie sprawdza** | baza AI rośnie wokół Nexusa; dla gracza bez zmian |
| `train`/`attack_add` | drużyny (TaskForce + ScriptType + TeamType) z AI-triggerów | warunki „dom posiada X” zamiast `wait_build`; wagi zamiast losowych otwarć |
| `defensebuild` | drużyny `IsBaseDefense=yes` (`11,10` Area Guard), wzorzec `se09` | silnik sam odpowiada na atak (`ComputerBaseDefenseResponse`) |
| `place_guard` HT | drużyna 2 High Templarów z Area Guard przy Nexusie | |
| fale po armii | AI-trigger z warunkiem „dom posiada ≥ N X”, drużyna ataku `11,14` Hunt albo cel | |
| `wait` (kampania) | misja: triggery czasu + `4 Create Team` (wzorzec `Add-ZergAI`) | |
| ekspansje | MCV `SCPDNEX` z AI-triggera „replace MCV” (DTA `E_GDI replace MCV`) | **(niezweryfikowane)**, AI TS rozstawia MCV skryptem, nie wybiera złoża |
| ulepszenia | budynki-ulepszenia z [[mods/starcraft-research]] (`PowersUpBuilding`) | AI stawia je jako węzły, jeśli `AIBuildThis=yes` |
| czary, Hallucination, Recall | brak | jak u gracza |

## Projekt wdrożenia

**A. Skirmish: nowa warstwa kodu mapy** `INI/Map Code/SC Factions/110 Protoss AI.ini`, generowana przez `tools/build-protossai.ps1` ([[engine/map-code-layers]]):
1. **Listy `[AI]`** powtórzone w całości z Protossami: `BuildPower` +`SCPPYL`, `BuildRefinery` +`SCPASM` (bez tego crash), `BuildBarracks` +`SCPGAT`, `BuildWeapons` +`SCPROB`, `BuildDefense`/`BuildPDefense`/`BuildAA` +`SCPCAN`, `BuildTech` +`SCPCYB`. Wcześniej sprawdzić, że żaden typ DTA z tych list nie ma `GDI2` w `Owner`.
2. **`AIBuildThis=yes`** na budynkach Protossów (gracza nie dotyczy). Shield Battery i laboratoria badań: do decyzji, czy AI je stawia.
3. **Łatka `Vinifera.dll`:** gałąź „stocznia na wodzie” w `_Find_Build_Location` tylko dla `WaterBound=yes`, żeby Robotics i Stargate stawały na lądzie. Skrypt `patch-vinifera-navalai.ps1` dopisany do `patch-vinifera.ps1` ([[engine/game-exe-patching]]). Bez łatki AI ma tylko Gateway i działka.
4. **AI-triggery strony 9:**
   - rozstawienie `SCPDNEX` (kopia `MCV_DEPLOY`);
   - Probe'y przez drużynę „górnicy” (2 Probe'y, `11,9` Harvest, warunek „mniej niż N Probe'ów”), bo zastępczy zbieracz silnika trafia do kolejki lądowej;
   - obrona bazy (2 Zealoty + Dragoon; Dragoon/Scout na lotników; 2 High Templarów przy Nexusie);
   - fale jak w `PMCx`/`PHIx`, odblokowywane posiadaniem Gateway → Cyber Core → Robotics/Support Bay → Stargate/Fleet Beacon → Tribunal;
   - nękanie DT po Templar Archives;
   - wersje E/M/H z liczebnością z `PLOx`/`PMEx`/`PHIx`.
5. **Kontrola:** skrypt sprawdza, że każdy typ z drużyn jest do zbudowania przez `GDI2` (TechLevel ≤ 7, `Owner`, `BuiltAt`), inaczej drużyna czeka wiecznie.

**B. ARKA 6:** te same drużyny jako moduł `tools/ProtossAI.ps1` (`Add-ProtossAI`, wzór [[engine/zerg-ai]] `Add-ZergAI`). Dom Fenixa z `IQ=5`, Nexusem i węzłami bazy w strefie zachodniej, produkcja w Gatewayu przez `4 Create Team` + zapłata, przywołanie „przez Pylony”, fale na zegar jak w kampanii SC, obrona i kontratak. Zniszczenie 3 Pylonów = koniec dosyłania (`Lost`). Po rozejmie domy przestają walczyć.

## Rozstrzygnięcia (2026-10-30)

1. Łatka `Vinifera.dll`: tak (`patch-vinifera-navalai.ps1`).
2. Skirmish: taktyki Advanced AI po kamieniach milowych i czasie (melee `PMCx`) plus obrona i fale jak w kampanii.
3. ARKA 6: moduł `ProtossAI.ps1` (`Add-ProtossAI`). Baza Fenixa z produkcją, przywołaniem przy Pylonach i końcem po zniszczeniu wszystkich Pylonów. Podłączenie, gdy skrypt misji dostanie domy i triggery.
4. Otwarte: AITriggery strony 9 dla gry bez Advanced AI (projekt A, pkt 4) nie są zrobione.
