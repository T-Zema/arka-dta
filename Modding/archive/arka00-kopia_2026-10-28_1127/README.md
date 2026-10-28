# Kopia ARKA 0 przed reczna edycja mapy (2026-10-28 11:27)

Uzytkownik edytuje mape recznie (edytor), to jest stan sprzed tej edycji.

- arka00.map (+ .png): misja, Maps/Missions/
- arka00_gibraltar.map (+ .png): teren, Maps/Custom/
- build-arka00-mission.ps1, build-arka-gibraltar.ps1, build-gun100t.ps1, MissionKit.ps1: generatory w tym stanie

Przywrocenie: skopiuj arka00.map do Maps/Missions/ (i arka00_gibraltar.map do Maps/Custom/).
UWAGA: build-arka00-mission.ps1 nadpisuje Maps/Missions/arka00.map w calosci, a build-arka-gibraltar.ps1
nadpisuje Maps/Custom/arka00_gibraltar.map. Reczne zmiany w mapie znikna przy nastepnym uruchomieniu generatora,
dopoki nie zostana przeniesione do skryptu.
