# Glossary (German → English identifiers)

Terms from the menus, dialogs, INI and manual. Use the English identifier when naming
functions, fields and structs in Ghidra and in reimplementation code.

| German | English identifier | Notes |
|---|---|---|
| Korn | grain | food; distributed to the population each turn |
| Land (ha, Hufe) | land | in hectares; 1 Hufe ≈ 40 ha |
| Taler | taler / money | currency |
| Einwohner, Bevölkerung | population | |
| Zufriedenheit | happiness | needed for promotion, low → revolution |
| Geburten-/Sterberate | birth_rate / death_rate | driven by grain |
| Steuern und Gesetze | taxes / laws | |
| Gebäude | building | Kornspeicher (granary), Mühle (mill), Markt (market), Schmiede (smithy), Wirtshaus (tavern), Palast (palace), Kathedrale (cathedral), Mauer (wall), Lager (warehouse) |
| Güter, Waren | goods | traded on the market |
| Titel, Beförderung, Rang | title, promotion, rank | Kaiser = emperor = win |
| Ruhm | fame | |
| Magie, Zauber, Fluch | magic, spell, curse | e.g. Heilende Hände (healing hands) |
| Karma | karma | |
| Militär, Truppen, Einheit | military, troops, unit | |
| Truppen aufstellen | recruit / deploy troops | dialog ANORDNENDLG |
| Manöver | manoeuvre | training |
| Krieg, Schlacht, Feldschlacht | war, battle, field battle | Schlacht-Timer in INI |
| Plündern, Brandschatzen | plunder, pillage | after a won battle |
| Held, Kollektivheld | hero, collective hero | |
| Miliz, Söldner, Sold | militia, mercenary, pay | |
| Diplomatie | diplomacy | |
| Entwicklungshilfe | aid / donation | |
| Abkommen, Handelsabkommen, Friedensvertrag | treaty, trade agreement, peace treaty | |
| Tribut | tribute | |
| Sabotage, Saboteur, Geheimdienst | sabotage, saboteur, intelligence | |
| Revolution, Aufstand | revolution, uprising | dialog AUFSTANDDLG |
| Bankrott | bankruptcy | dialogs BANKGNADENDLG, BANKPFANDDLG |
| Runde, Jahr | turn, year | one turn = one year |
| Spieler, CP (Computerspieler) | player, cpu_player | names in INI: `*Otto*` etc. |
| Geschichtsschreibung | autosave | INI/menu option 601 |
| Krach & Geschrei | sound effects | option 602 |
| Schalmeienklänge | music | option 603 |
| Annalen, Rekorde | annals, records (high scores) | KAISER.REC, KAISER.SCO |
| Spielstand | savegame | `*.KSR` |

## Countries (Länder)

Sachsen, Holstein, Hessen, Bayern, Preußen, Baden, Thüringen, Westfalen, Böhmen, Franken.
Each has an adjective form in the INI (e.g. *Sächsische*), used in unit names like "Sächsische Ritter".
