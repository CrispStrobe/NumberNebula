# Space Theming for New Game Ideas

> Naming conventions, narrative strings, visual concepts, and i18n keys for the 28 game ideas from `GAME_IDEAS.md`.
> All user-facing strings are designed for `app_en.arb` / `app_de.arb` (ARB i18n format).
> Voice matches existing style: mission-briefing tone, "Commander" address, space metaphors for math concepts.

---

## Existing Theme Inventory (avoid overlap)

Already used in the 24 current games:
- Wormholes, cosmic triangles, asteroids, quantum pyramids, cryptex locks, signal triangulation
- Arithmancer/neural AI combat, gravity sling/planet hopping, hyperdrive gates
- Anomaly scan, 3D blocks, cargo-loader, robot path, solar panels, grid filler
- Space station gridlock, constellation puzzles

**Available space concepts for new games:**
Nebulae, star forges, black holes, supernovae, comets, moons, terraforming, deep space probes, alien archaeology, space docks, shield arrays, warp cores, star maps, galactic trade, space lighthouses, crystal caves, ion storms, plasma conduits, gravity wells, stellar nurseries, dark matter, antimatter, orbital mechanics, communication relays

---

## Game Theming Table

| # | GAME_IDEAS name | Space Title (EN) | Space Title (DE) | Concept | Icon/Visual |
|---|----------------|-----------------|-----------------|---------|-------------|
| 1 | Number Grid | **Nebula Matrix** | **Nebel-Matrix** | Fill a cosmic grid to stabilize a nebula's energy field | Glowing grid floating in colorful nebula clouds |
| 2 | Magic Star | **Star Forge** | **Sternen-Schmiede** | Align energy nodes in a stellar forge to ignite a new star | Constellation nodes connected by glowing plasma lines |
| 3 | Codebreaker | *already exists* | *bereits vorhanden* | (Existing: Codebreaker) | -- |
| 4 | Balance Lab | **Gravity Well** | **Gravitationsfeld** | Balance masses on cosmic scales to calibrate a gravity well | Floating balance scales with planets/moons as weights |
| 5 | Lights Out | **Dark Matter Grid** | **Dunkelmaterie-Gitter** | Toggle dark matter nodes to illuminate a sector of space | Grid of glowing/dark nodes on starfield background |
| 6 | Color Map | **Sector Painter** | **Sektor-Maler** | Color star map sectors so no bordering sectors share a frequency | Top-down galaxy map with colored regions |
| 7 | Path Finder | *already exists* | *bereits vorhanden* | (Existing: Path Finder + Robot Path) | -- |
| 8 | Who Has What | **Crew Manifest** | **Crew-Manifest** | Match alien crew members to their ships, tools, and home planets | Character cards with alien portraits and item icons |
| 9 | Tower Skyline | **Orbital Towers** | **Orbital-Turme** | Build a space city skyline visible from observation satellites | 3D towers on a platform with camera angles from edges |
| 10 | Honeycomb Fill | **Hive Station** | **Bienen-Station** | Fill hexagonal cells in a space station module with energy cores | Hexagonal grid with glowing amber cells, bee-drone mascot |
| 11 | Code Lock | **Vault Cracker** | **Tresor-Knacker** | Crack the combination to an ancient alien vault using clue attempts | Spinning combination dials with alien glyphs |
| 12 | Alien Arithmetic | *already exists (ArithmeticSquare + Crosswords)* | *bereits vorhanden* | Enhance existing games with new theming | -- |
| 13 | Monster Math | **Xenobiology Lab** | **Xenobiologie-Labor** | Count alien creatures by their traits (eyes, legs, tentacles) | Animated alien creatures with visible countable features |
| 14 | Paper Fold | **Warp Fold** | **Warp-Faltung** | Predict how space fabric looks when folded through a warp gate | Translucent paper with stars visible through it |
| 15 | Nim & Strategy | **Asteroid Duel** | **Asteroiden-Duell** | Two commanders take turns mining asteroids -- last to mine loses | Asteroid piles with mining laser effects |
| 16 | Cipher Trail | **Comm Relay** | **Komm-Relais** | Decode garbled transmissions from deep space communication relays | Signal wave display with letter substitution interface |
| 17 | Domino Tile | **Hull Plating** | **Rumpf-Panzerung** | Tile the hull of a damaged ship with armor plates | Ship cross-section with plate-shaped pieces to place |
| 18 | Digital Detective | **Circuit Repair** | **Schaltkreis-Reparatur** | Fix crossed wires in the ship's digital display system | 7-segment display with draggable wire connections |
| 19 | Sequence Builder | **Ion Chain** | **Ionen-Kette** | String ions in the correct sequence for a plasma conduit | Glowing beads on a horizontal rail with constraint markers |
| 20 | Dice Detective | **Cube Scanner** | **Wurfel-Scanner** | Scan alien cubes to deduce hidden face values | 3D rotating cubes with scanner beam effect |
| 21 | Clock Logic | **Chrono Repair** | **Chrono-Reparatur** | Fix malfunctioning clocks on a relativistic space station | Analog + digital clocks with glitch effects |
| 22 | Parking Puzzle | **Dock Clearance** | **Dock-Freigabe** | Slide ships in a crowded space dock to let yours launch | Top-down dock with colorful ships, launch tube at edge |
| 23 | Card Edge Match | **Relic Assembly** | **Relikte-Puzzle** | Assemble alien artifact fragments so glyphs match at edges | Stone/crystal tablet pieces with glowing alien symbols |
| 24 | Sorting Puzzle | **Launch Sequence** | **Start-Sequenz** | Reorder ships in the launch queue using minimum swaps | Ships in a queue with numbered positions, swap animation |
| 25 | Word Nebula | **Star Chart Scan** | **Sternkarten-Scan** | Find hidden constellation names in a letter grid star chart | Letter grid overlaid on starfield, found words glow |
| 26 | Chimera Lab | **Creature Forge** | **Kreaturen-Schmiede** | Combine alien body parts to discover all possible species | Split-flap display of alien heads/bodies/tails |
| 27 | Liar's Table | **Alien Tribunal** | **Alien-Tribunal** | Determine which alien delegates tell truth vs. lie from statements | Courtroom scene with alien portraits and speech bubbles |
| 28 | Coin Change | **Galactic Market** | **Galaktischer Markt** | Pay exact amounts using alien currency denominations | Market stall with alien coins of different shapes/values |

---

## i18n String Templates

Below are the ARB keys and EN/DE strings for each new game. They follow the existing pattern:
`{gameKey}Title`, `{gameKey}Desc`, `{gameKey}Instructions`, `{gameKey}WinTitle`, `{gameKey}WinDesc`, `{gameKey}LoseTitle`, `{gameKey}LoseDesc`

---

### 1. Nebula Matrix (Number Grid)

```json
"nebulaMatrixTitle": "Nebula Matrix",
"nebulaMatrixDesc": "Stabilize the energy field! Fill every row, column, and zone of the nebula grid so no frequency repeats. One wrong resonance and the nebula collapses!",
"nebulaMatrixInstructions": "Place numbers so each row and column contains every value exactly once. Colored zones must also contain each value once.",
"nebulaMatrixWinTitle": "Nebula Stabilized!",
"nebulaMatrixWinDesc": "The energy field is perfectly balanced! You earned {bonusScore} resonance points for your precision.",
"nebulaMatrixLoseTitle": "Field Collapse!",
"nebulaMatrixLoseDesc": "Conflicting frequencies destabilized the nebula. Recalibrate your matrix and try again, Commander."
```

```json
"nebulaMatrixTitle": "Nebel-Matrix",
"nebulaMatrixDesc": "Stabilisiere das Energiefeld! Fulle jede Zeile, Spalte und Zone des Nebelgitters, sodass sich keine Frequenz wiederholt. Eine falsche Resonanz und der Nebel kollabiert!",
"nebulaMatrixInstructions": "Platziere Zahlen, sodass jede Zeile und Spalte jeden Wert genau einmal enthalt. Farbige Zonen mussen ebenfalls jeden Wert einmal enthalten.",
"nebulaMatrixWinTitle": "Nebel stabilisiert!",
"nebulaMatrixWinDesc": "Das Energiefeld ist perfekt ausbalanciert! Du hast {bonusScore} Resonanzpunkte fur deine Prazision verdient.",
"nebulaMatrixLoseTitle": "Feldkollaps!",
"nebulaMatrixLoseDesc": "Widerspruchliche Frequenzen haben den Nebel destabilisiert. Kalibriere deine Matrix neu, Commander."
```

---

### 2. Star Forge (Magic Star)

```json
"starForgeTitle": "Star Forge",
"starForgeDesc": "Ignite a new star! Distribute energy values across the forge nodes so every plasma arm carries the same total charge. The star ignites when all arms align!",
"starForgeInstructions": "Place numbers in the empty nodes. Each line through the star must have the same sum.",
"starForgeWinTitle": "Star Ignited!",
"starForgeWinDesc": "A brilliant new star blazes to life! Your forge mastery earned {bonusScore} fusion points.",
"starForgeLoseTitle": "Forge Misfire!",
"starForgeLoseDesc": "The energy imbalance caused a plasma leak. Redistribute the charge and try again, Commander."
```

```json
"starForgeTitle": "Sternen-Schmiede",
"starForgeDesc": "Entzunde einen neuen Stern! Verteile Energiewerte auf die Schmiedeknoten, sodass jeder Plasmaarm die gleiche Gesamtladung tragt. Der Stern entzundet sich, wenn alle Arme ubereinstimmen!",
"starForgeInstructions": "Platziere Zahlen in die leeren Knoten. Jede Linie durch den Stern muss die gleiche Summe haben.",
"starForgeWinTitle": "Stern entzundet!",
"starForgeWinDesc": "Ein strahlender neuer Stern erwacht zum Leben! Deine Schmiedekunst hat {bonusScore} Fusionspunkte eingebracht.",
"starForgeLoseTitle": "Schmiedefehler!",
"starForgeLoseDesc": "Das Energieungleichgewicht hat ein Plasmaleck verursacht. Verteile die Ladung neu, Commander."
```

---

### 4. Gravity Well (Balance Lab)

```json
"gravityWellTitle": "Gravity Well",
"gravityWellDesc": "Calibrate the gravity well! Place celestial masses on cosmic scales until perfect equilibrium is achieved. The warp drive won't engage without balanced gravity.",
"gravityWellInstructions": "Determine the weight of each object by reading the balanced scales. Drag your answer onto the target scale.",
"gravityWellWinTitle": "Gravity Calibrated!",
"gravityWellWinDesc": "Perfect equilibrium achieved! The warp drive hums to life. You earned {bonusScore} calibration points.",
"gravityWellLoseTitle": "Gravitational Anomaly!",
"gravityWellLoseDesc": "The imbalanced gravity well warped the local spacetime. Recalculate the masses, Commander."
```

```json
"gravityWellTitle": "Gravitationsfeld",
"gravityWellDesc": "Kalibriere das Gravitationsfeld! Platziere Himmelsmassen auf kosmischen Waagen, bis ein perfektes Gleichgewicht erreicht ist. Der Warpantrieb funktioniert nur bei ausgeglichener Gravitation.",
"gravityWellInstructions": "Bestimme das Gewicht jedes Objekts anhand der balancierten Waagen. Ziehe deine Antwort auf die Zielwaage.",
"gravityWellWinTitle": "Gravitation kalibriert!",
"gravityWellWinDesc": "Perfektes Gleichgewicht erreicht! Der Warpantrieb summt zum Leben. Du hast {bonusScore} Kalibrierungspunkte verdient.",
"gravityWellLoseTitle": "Gravitationsanomalie!",
"gravityWellLoseDesc": "Das unausgeglichene Gravitationsfeld hat die lokale Raumzeit verzerrt. Berechne die Massen neu, Commander."
```

---

### 5. Dark Matter Grid (Lights Out)

```json
"darkMatterGridTitle": "Dark Matter Grid",
"darkMatterGridDesc": "Dark matter has blanketed this sector! Toggle the nodes to push back the darkness. But beware -- each node affects its neighbors!",
"darkMatterGridInstructions": "Tap a node to toggle it and all adjacent nodes. Light up the entire grid to clear the sector.",
"darkMatterGridWinTitle": "Sector Illuminated!",
"darkMatterGridWinDesc": "The dark matter recedes! You cleared the grid in {moves} moves and earned {bonusScore} photon points.",
"darkMatterGridLoseTitle": "Darkness Persists!",
"darkMatterGridLoseDesc": "The dark matter grid remains unstable. Think about which nodes affect which neighbors, Commander."
```

```json
"darkMatterGridTitle": "Dunkelmaterie-Gitter",
"darkMatterGridDesc": "Dunkelmaterie hat diesen Sektor verhullt! Schalte die Knoten um, um die Dunkelheit zuruckzudrangen. Aber Vorsicht -- jeder Knoten beeinflusst seine Nachbarn!",
"darkMatterGridInstructions": "Tippe auf einen Knoten, um ihn und alle benachbarten Knoten umzuschalten. Erleuchte das gesamte Gitter, um den Sektor zu befreien.",
"darkMatterGridWinTitle": "Sektor erleuchtet!",
"darkMatterGridWinDesc": "Die Dunkelmaterie weicht zuruck! Du hast das Gitter in {moves} Zugen befreit und {bonusScore} Photonenpunkte verdient.",
"darkMatterGridLoseTitle": "Dunkelheit bleibt!",
"darkMatterGridLoseDesc": "Das Dunkelmaterie-Gitter bleibt instabil. Uberlege, welche Knoten welche Nachbarn beeinflussen, Commander."
```

---

### 6. Sector Painter (Color Map)

```json
"sectorPainterTitle": "Sector Painter",
"sectorPainterDesc": "Assign communication frequencies to star map sectors! Bordering sectors must use different frequencies to avoid signal interference.",
"sectorPainterInstructions": "Color each sector so no two adjacent sectors share the same color. Use as few colors as possible!",
"sectorPainterWinTitle": "Frequencies Assigned!",
"sectorPainterWinDesc": "Zero interference across the star map! You solved it with only {colors} frequencies, earning {bonusScore} points.",
"sectorPainterLoseTitle": "Signal Interference!",
"sectorPainterLoseDesc": "Adjacent sectors are broadcasting on the same frequency! Reassign the channels, Commander."
```

```json
"sectorPainterTitle": "Sektor-Maler",
"sectorPainterDesc": "Weise Kommunikationsfrequenzen den Sternkarten-Sektoren zu! Angrenzende Sektoren mussen verschiedene Frequenzen nutzen, um Signalstorungen zu vermeiden.",
"sectorPainterInstructions": "Farbe jeden Sektor ein, sodass keine zwei benachbarten Sektoren die gleiche Farbe haben. Verwende so wenige Farben wie moglich!",
"sectorPainterWinTitle": "Frequenzen zugewiesen!",
"sectorPainterWinDesc": "Keine Interferenz auf der gesamten Sternkarte! Du hast es mit nur {colors} Frequenzen gelost und {bonusScore} Punkte verdient.",
"sectorPainterLoseTitle": "Signalinterferenz!",
"sectorPainterLoseDesc": "Benachbarte Sektoren senden auf der gleichen Frequenz! Weise die Kanale neu zu, Commander."
```

---

### 8. Crew Manifest (Who Has What)

```json
"crewManifestTitle": "Crew Manifest",
"crewManifestDesc": "The crew database is scrambled! Use the clues from the ship's log to match each crew member to their role, quarters, and home planet.",
"crewManifestInstructions": "Read the clues and mark the logic grid. An X means 'not possible', a check means 'confirmed match'.",
"crewManifestWinTitle": "Manifest Restored!",
"crewManifestWinDesc": "Every crew member accounted for! Your detective work earned {bonusScore} intelligence points.",
"crewManifestLoseTitle": "Database Error!",
"crewManifestLoseDesc": "The manifest contains contradictions. Re-read the clues carefully, Commander."
```

```json
"crewManifestTitle": "Crew-Manifest",
"crewManifestDesc": "Die Crew-Datenbank ist durcheinander! Nutze die Hinweise aus dem Schiffslogbuch, um jedes Crew-Mitglied seiner Rolle, Kabine und seinem Heimatplaneten zuzuordnen.",
"crewManifestInstructions": "Lies die Hinweise und markiere das Logikgitter. Ein X bedeutet 'nicht moglich', ein Haken bedeutet 'bestatigter Treffer'.",
"crewManifestWinTitle": "Manifest wiederhergestellt!",
"crewManifestWinDesc": "Jedes Crew-Mitglied zugeordnet! Deine Detektivarbeit hat {bonusScore} Intelligenzpunkte eingebracht.",
"crewManifestLoseTitle": "Datenbankfehler!",
"crewManifestLoseDesc": "Das Manifest enthalt Widerspruche. Lies die Hinweise sorgfaltig noch einmal, Commander."
```

---

### 9. Orbital Towers (Tower Skyline)

```json
"orbitalTowersTitle": "Orbital Towers",
"orbitalTowersDesc": "Build a space city on the orbital platform! The satellite cameras on each edge report how many towers they can see. Taller towers hide shorter ones behind them.",
"orbitalTowersInstructions": "Place towers of height 1 to {size} so each row and column has every height once. Edge clues show how many towers are visible from that direction.",
"orbitalTowersWinTitle": "City Constructed!",
"orbitalTowersWinDesc": "The orbital city rises into view! All satellite readings match perfectly. You earned {bonusScore} construction credits.",
"orbitalTowersLoseTitle": "Blueprint Mismatch!",
"orbitalTowersLoseDesc": "The satellite cameras don't match your layout. Remember: tall towers block the view of shorter ones behind them, Commander."
```

```json
"orbitalTowersTitle": "Orbital-Turme",
"orbitalTowersDesc": "Baue eine Weltraumstadt auf der Orbitalplattform! Die Satellitenkameras an jedem Rand melden, wie viele Turme sie sehen konnen. Hohere Turme verbergen niedrigere hinter sich.",
"orbitalTowersInstructions": "Platziere Turme der Hohe 1 bis {size}, sodass jede Zeile und Spalte jede Hohe einmal hat. Randhinweise zeigen, wie viele Turme aus dieser Richtung sichtbar sind.",
"orbitalTowersWinTitle": "Stadt errichtet!",
"orbitalTowersWinDesc": "Die Orbitalstadt erhebt sich! Alle Satellitenwerte stimmen perfekt uberein. Du hast {bonusScore} Baukredite verdient.",
"orbitalTowersLoseTitle": "Bauplanfehler!",
"orbitalTowersLoseDesc": "Die Satellitenkameras stimmen nicht mit deinem Layout uberein. Denke daran: Hohe Turme blockieren die Sicht auf niedrigere dahinter, Commander."
```

---

### 10. Hive Station (Honeycomb Fill)

```json
"hiveStationTitle": "Hive Station",
"hiveStationDesc": "The station's energy hive needs charging! Each cell displays how many of its neighbors hold an energy core. Deduce which cells need power!",
"hiveStationInstructions": "Tap hexagonal cells to fill them with energy. The number in each cell tells you how many adjacent cells contain energy.",
"hiveStationWinTitle": "Hive Charged!",
"hiveStationWinDesc": "All energy cores placed correctly! The station hums with power. You earned {bonusScore} charge points.",
"hiveStationLoseTitle": "Power Mismatch!",
"hiveStationLoseDesc": "Some cells report the wrong neighbor count. Check your energy placement, Commander."
```

```json
"hiveStationTitle": "Bienen-Station",
"hiveStationDesc": "Der Energiebienenstock der Station muss aufgeladen werden! Jede Zelle zeigt an, wie viele ihrer Nachbarn einen Energiekern enthalten. Finde heraus, welche Zellen Energie brauchen!",
"hiveStationInstructions": "Tippe auf sechseckige Zellen, um sie mit Energie zu fullen. Die Zahl in jeder Zelle sagt dir, wie viele benachbarte Zellen Energie enthalten.",
"hiveStationWinTitle": "Bienenstock geladen!",
"hiveStationWinDesc": "Alle Energiekerne korrekt platziert! Die Station summt vor Energie. Du hast {bonusScore} Ladepunkte verdient.",
"hiveStationLoseTitle": "Energiefehler!",
"hiveStationLoseDesc": "Einige Zellen melden die falsche Nachbarzahl. Uberprufe deine Energieplatzierung, Commander."
```

---

### 11. Vault Cracker (Code Lock)

```json
"vaultCrackerTitle": "Vault Cracker",
"vaultCrackerDesc": "An ancient alien vault blocks your path! Each failed attempt reveals clues: which digits are correct, misplaced, or completely wrong. Deduce the combination!",
"vaultCrackerInstructions": "Study each clue attempt. Green = correct digit, correct position. Yellow = correct digit, wrong position. Gray = digit not in code.",
"vaultCrackerWinTitle": "Vault Breached!",
"vaultCrackerWinDesc": "The vault doors swing open! You cracked the code in {attempts} attempts, earning {bonusScore} archaeology points.",
"vaultCrackerLoseTitle": "Vault Sealed!",
"vaultCrackerLoseDesc": "Too many failed attempts triggered the lockout. Analyze the clue patterns more carefully, Commander."
```

```json
"vaultCrackerTitle": "Tresor-Knacker",
"vaultCrackerDesc": "Ein uralter Alien-Tresor blockiert deinen Weg! Jeder Fehlversuch enthullt Hinweise: welche Ziffern korrekt, falsch platziert oder vollig falsch sind. Finde die Kombination!",
"vaultCrackerInstructions": "Studiere jeden Hinweisversuch. Grun = richtige Ziffer, richtige Position. Gelb = richtige Ziffer, falsche Position. Grau = Ziffer nicht im Code.",
"vaultCrackerWinTitle": "Tresor geoffnet!",
"vaultCrackerWinDesc": "Die Tresorturen schwingen auf! Du hast den Code in {attempts} Versuchen geknackt und {bonusScore} Archaologiepunkte verdient.",
"vaultCrackerLoseTitle": "Tresor versiegelt!",
"vaultCrackerLoseDesc": "Zu viele Fehlversuche haben die Sperre ausgelost. Analysiere die Hinweismuster sorgfaltiger, Commander."
```

---

### 13. Xenobiology Lab (Monster Math)

```json
"xenobiologyLabTitle": "Xenobiology Lab",
"xenobiologyLabDesc": "A new species has been discovered! Each subspecies has different numbers of eyes, tentacles, and legs. Use the census data to classify the colony!",
"xenobiologyLabInstructions": "Two alien types live together. You know the total eyes and legs. Figure out how many of each type there are!",
"xenobiologyLabWinTitle": "Species Cataloged!",
"xenobiologyLabWinDesc": "Field report filed! Your xenobiology skills earned {bonusScore} research credits.",
"xenobiologyLabLoseTitle": "Census Error!",
"xenobiologyLabLoseDesc": "The numbers don't add up. Double-check the trait counts for each subspecies, Commander."
```

```json
"xenobiologyLabTitle": "Xenobiologie-Labor",
"xenobiologyLabDesc": "Eine neue Spezies wurde entdeckt! Jede Unterart hat verschiedene Anzahlen von Augen, Tentakeln und Beinen. Nutze die Volkszahlungsdaten, um die Kolonie zu klassifizieren!",
"xenobiologyLabInstructions": "Zwei Alien-Typen leben zusammen. Du kennst die Gesamtzahl der Augen und Beine. Finde heraus, wie viele von jedem Typ es gibt!",
"xenobiologyLabWinTitle": "Spezies katalogisiert!",
"xenobiologyLabWinDesc": "Feldbericht eingereicht! Deine Xenobiologie-Fahigkeiten haben {bonusScore} Forschungskredite eingebracht.",
"xenobiologyLabLoseTitle": "Volkszahlungsfehler!",
"xenobiologyLabLoseDesc": "Die Zahlen stimmen nicht uberein. Uberprufe die Merkmalszahlen fur jede Unterart, Commander."
```

---

### 14. Warp Fold (Paper Fold)

```json
"warpFoldTitle": "Warp Fold",
"warpFoldDesc": "The warp drive folds space itself! Predict what the star chart looks like after space has been folded and cut. Spatial intuition is your only tool!",
"warpFoldInstructions": "Watch the folding animation, then choose which unfolded result is correct.",
"warpFoldWinTitle": "Space Unfolded!",
"warpFoldWinDesc": "Your spatial reasoning is flawless! You earned {bonusScore} dimensional points.",
"warpFoldLoseTitle": "Dimensional Mishap!",
"warpFoldLoseDesc": "The unfolded space didn't match your prediction. Trace the folds step by step, Commander."
```

```json
"warpFoldTitle": "Warp-Faltung",
"warpFoldDesc": "Der Warpantrieb faltet den Raum selbst! Sage voraus, wie die Sternkarte nach der Raumfaltung und dem Schnitt aussieht. Raumliches Vorstellungsvermogen ist dein einziges Werkzeug!",
"warpFoldInstructions": "Beobachte die Faltanimation und wahle dann das korrekte entfaltete Ergebnis.",
"warpFoldWinTitle": "Raum entfaltet!",
"warpFoldWinDesc": "Dein raumliches Denken ist makellos! Du hast {bonusScore} Dimensionspunkte verdient.",
"warpFoldLoseTitle": "Dimensionspanne!",
"warpFoldLoseDesc": "Der entfaltete Raum stimmte nicht mit deiner Vorhersage uberein. Verfolge die Faltungen Schritt fur Schritt, Commander."
```

---

### 15. Asteroid Duel (Nim)

```json
"asteroidDuelTitle": "Asteroid Duel",
"asteroidDuelDesc": "A strategic standoff in the asteroid belt! Take turns mining rocks with your opponent. The commander who takes the last asteroid loses. Think ahead!",
"asteroidDuelInstructions": "Choose 1 to {max} asteroids per turn. Force your opponent to take the last one!",
"asteroidDuelWinTitle": "Duel Won!",
"asteroidDuelWinDesc": "Superior strategy! Your opponent is stranded. You earned {bonusScore} tactical points.",
"asteroidDuelLoseTitle": "Outmaneuvered!",
"asteroidDuelLoseDesc": "Your opponent forced you into the last asteroid. Study the patterns -- there's always a winning strategy, Commander."
```

```json
"asteroidDuelTitle": "Asteroiden-Duell",
"asteroidDuelDesc": "Ein strategisches Patt im Asteroidengurtel! Baut abwechselnd Gesteinsbrocken ab. Der Commander, der den letzten Asteroiden nimmt, verliert. Denke voraus!",
"asteroidDuelInstructions": "Wahle 1 bis {max} Asteroiden pro Zug. Zwinge deinen Gegner, den letzten zu nehmen!",
"asteroidDuelWinTitle": "Duell gewonnen!",
"asteroidDuelWinDesc": "Uberlegene Strategie! Dein Gegner ist gestrandet. Du hast {bonusScore} Taktikpunkte verdient.",
"asteroidDuelLoseTitle": "Ausmanoveriert!",
"asteroidDuelLoseDesc": "Dein Gegner hat dich zum letzten Asteroiden gezwungen. Studiere die Muster -- es gibt immer eine Gewinnstrategie, Commander."
```

---

### 16. Comm Relay (Cipher)

```json
"commRelayTitle": "Comm Relay",
"commRelayDesc": "A garbled transmission from deep space! The communication relay has shifted every letter. Crack the cipher to read the original message!",
"commRelayInstructions": "Each letter has been shifted by a fixed amount in the alphabet. Find the shift and decode the message.",
"commRelayWinTitle": "Message Decoded!",
"commRelayWinDesc": "The transmission reads loud and clear! You earned {bonusScore} intelligence points.",
"commRelayLoseTitle": "Static!",
"commRelayLoseDesc": "The message remains garbled. Try different shift values, Commander."
```

```json
"commRelayTitle": "Komm-Relais",
"commRelayDesc": "Eine verzerrte Ubertragung aus dem tiefen Weltraum! Das Kommunikationsrelais hat jeden Buchstaben verschoben. Knacke die Chiffre, um die Originalnachricht zu lesen!",
"commRelayInstructions": "Jeder Buchstabe wurde um einen festen Betrag im Alphabet verschoben. Finde die Verschiebung und entschlussle die Nachricht.",
"commRelayWinTitle": "Nachricht entschlusselt!",
"commRelayWinDesc": "Die Ubertragung ist klar und deutlich! Du hast {bonusScore} Intelligenzpunkte verdient.",
"commRelayLoseTitle": "Rauschen!",
"commRelayLoseDesc": "Die Nachricht bleibt verzerrt. Probiere verschiedene Verschiebungswerte, Commander."
```

---

### 17. Hull Plating (Domino Tile)

```json
"hullPlatingTitle": "Hull Plating",
"hullPlatingDesc": "The ship's hull took a hit! Cover the damaged section with armor plates. Every gap must be sealed, and plates must alternate dark and light for structural integrity.",
"hullPlatingInstructions": "Drag armor plates onto the damaged hull. Cover every cell. Dark and light plates must alternate.",
"hullPlatingWinTitle": "Hull Sealed!",
"hullPlatingWinDesc": "The breach is patched! The ship is space-worthy again. You earned {bonusScore} repair credits.",
"hullPlatingLoseTitle": "Breach Remains!",
"hullPlatingLoseDesc": "Gaps remain in the hull plating. Try a different arrangement, Commander."
```

```json
"hullPlatingTitle": "Rumpf-Panzerung",
"hullPlatingDesc": "Der Schiffsrumpf wurde getroffen! Decke den beschadigten Bereich mit Panzerplatten ab. Jede Lucke muss versiegelt werden, und Platten mussen fur die Strukturintegritat abwechselnd dunkel und hell sein.",
"hullPlatingInstructions": "Ziehe Panzerplatten auf den beschadigten Rumpf. Decke jede Zelle ab. Dunkle und helle Platten mussen abwechseln.",
"hullPlatingWinTitle": "Rumpf versiegelt!",
"hullPlatingWinDesc": "Das Leck ist geflickt! Das Schiff ist wieder weltraumtauglich. Du hast {bonusScore} Reparaturkredite verdient.",
"hullPlatingLoseTitle": "Leck bleibt!",
"hullPlatingLoseDesc": "Es gibt noch Lucken in der Rumpfpanzerung. Versuche eine andere Anordnung, Commander."
```

---

### 18. Circuit Repair (Digital Detective)

```json
"circuitRepairTitle": "Circuit Repair",
"circuitRepairDesc": "The cockpit display is glitching! Two wires got crossed in the 7-segment circuit. Figure out which segments were swapped and fix the readout!",
"circuitRepairInstructions": "The display shows wrong digits because two wire connections are swapped. Find which two segments to swap back.",
"circuitRepairWinTitle": "Display Fixed!",
"circuitRepairWinDesc": "Clear readout restored! Your electrical skills earned {bonusScore} tech points.",
"circuitRepairLoseTitle": "Still Glitching!",
"circuitRepairLoseDesc": "The display is still showing wrong digits. Think about which two segments, when swapped, make all digits valid, Commander."
```

```json
"circuitRepairTitle": "Schaltkreis-Reparatur",
"circuitRepairDesc": "Das Cockpit-Display spinnt! Zwei Drahte wurden im 7-Segment-Schaltkreis vertauscht. Finde heraus, welche Segmente vertauscht wurden, und repariere die Anzeige!",
"circuitRepairInstructions": "Die Anzeige zeigt falsche Ziffern, weil zwei Drahtverbindungen vertauscht sind. Finde heraus, welche zwei Segmente zuruckgetauscht werden mussen.",
"circuitRepairWinTitle": "Display repariert!",
"circuitRepairWinDesc": "Klare Anzeige wiederhergestellt! Deine Elektrokenntnisse haben {bonusScore} Technikpunkte eingebracht.",
"circuitRepairLoseTitle": "Immer noch gestort!",
"circuitRepairLoseDesc": "Die Anzeige zeigt immer noch falsche Ziffern. Uberlege, welche zwei Segmente, wenn vertauscht, alle Ziffern gultig machen, Commander."
```

---

### 19. Ion Chain (Sequence Builder)

```json
"ionChainTitle": "Ion Chain",
"ionChainDesc": "String ions along the plasma conduit! Each ion type has rules about which neighbors it tolerates. Build the chain without causing a reaction!",
"ionChainInstructions": "Place ions in sequence. Read the constraint rules: some types cannot be adjacent, others must alternate.",
"ionChainWinTitle": "Conduit Stable!",
"ionChainWinDesc": "The plasma flows smoothly through your ion chain! You earned {bonusScore} chemistry points.",
"ionChainLoseTitle": "Chain Reaction!",
"ionChainLoseDesc": "Incompatible ions caused a plasma surge! Check the adjacency rules, Commander."
```

```json
"ionChainTitle": "Ionen-Kette",
"ionChainDesc": "Reihe Ionen entlang der Plasmaleitung auf! Jeder Ionentyp hat Regeln, welche Nachbarn er toleriert. Baue die Kette, ohne eine Reaktion auszulosen!",
"ionChainInstructions": "Platziere Ionen in der Reihenfolge. Lies die Einschrankungsregeln: Einige Typen durfen nicht nebeneinander stehen, andere mussen abwechseln.",
"ionChainWinTitle": "Leitung stabil!",
"ionChainWinDesc": "Das Plasma flie\u00dft glatt durch deine Ionenkette! Du hast {bonusScore} Chemiepunkte verdient.",
"ionChainLoseTitle": "Kettenreaktion!",
"ionChainLoseDesc": "Inkompatible Ionen haben einen Plasmaschub verursacht! Uberprufe die Nachbarschaftsregeln, Commander."
```

---

### 20. Cube Scanner (Dice Detective)

```json
"cubeScannerTitle": "Cube Scanner",
"cubeScannerDesc": "Alien data cubes have been recovered! Your scanner reveals some faces, but others are hidden. Use the rule -- opposite faces always sum to 7 -- to deduce the hidden values.",
"cubeScannerInstructions": "Study the visible faces of each cube. Opposite faces sum to 7. Determine the hidden face values.",
"cubeScannerWinTitle": "Cubes Decoded!",
"cubeScannerWinDesc": "All cube data extracted! Your analysis earned {bonusScore} scanner points.",
"cubeScannerLoseTitle": "Scan Incomplete!",
"cubeScannerLoseDesc": "Some face values are wrong. Remember: opposite faces always sum to 7, Commander."
```

```json
"cubeScannerTitle": "Wurfel-Scanner",
"cubeScannerDesc": "Alien-Datenwurfel wurden geborgen! Dein Scanner zeigt einige Seiten, aber andere sind verborgen. Nutze die Regel -- gegenuber liegende Seiten ergeben immer 7 -- um die versteckten Werte zu bestimmen.",
"cubeScannerInstructions": "Studiere die sichtbaren Seiten jedes Wurfels. Gegenuber liegende Seiten ergeben 7. Bestimme die versteckten Seitenwerte.",
"cubeScannerWinTitle": "Wurfel entschlusselt!",
"cubeScannerWinDesc": "Alle Wurfeldaten extrahiert! Deine Analyse hat {bonusScore} Scannerpunkte eingebracht.",
"cubeScannerLoseTitle": "Scan unvollstandig!",
"cubeScannerLoseDesc": "Einige Seitenwerte sind falsch. Denke daran: Gegenuber liegende Seiten ergeben immer 7, Commander."
```

---

### 21. Chrono Repair (Clock Logic)

```json
"chronoRepairTitle": "Chrono Repair",
"chronoRepairDesc": "Relativistic effects have scrambled the station clocks! Some run fast, some are mirrored, some have broken segments. Deduce the real time!",
"chronoRepairInstructions": "Each clock has a specific malfunction (offset, mirror, broken segments). Figure out the correct time.",
"chronoRepairWinTitle": "Time Synchronized!",
"chronoRepairWinDesc": "All clocks show the correct time! You earned {bonusScore} temporal points.",
"chronoRepairLoseTitle": "Still Out of Sync!",
"chronoRepairLoseDesc": "The displayed time is incorrect. Consider the specific malfunction of each clock, Commander."
```

```json
"chronoRepairTitle": "Chrono-Reparatur",
"chronoRepairDesc": "Relativistische Effekte haben die Stationsuhren durcheinander gebracht! Manche gehen vor, manche sind gespiegelt, manche haben defekte Segmente. Finde die richtige Uhrzeit!",
"chronoRepairInstructions": "Jede Uhr hat eine bestimmte Fehlfunktion (Versatz, Spiegelung, defekte Segmente). Finde die korrekte Uhrzeit heraus.",
"chronoRepairWinTitle": "Zeit synchronisiert!",
"chronoRepairWinDesc": "Alle Uhren zeigen die korrekte Zeit! Du hast {bonusScore} Temporalpunkte verdient.",
"chronoRepairLoseTitle": "Immer noch asynchron!",
"chronoRepairLoseDesc": "Die angezeigte Zeit ist falsch. Beachte die spezifische Fehlfunktion jeder Uhr, Commander."
```

---

### 22. Dock Clearance (Parking Puzzle)

```json
"dockClearanceTitle": "Dock Clearance",
"dockClearanceDesc": "The space dock is jammed! Slide the parked ships to clear a path for your vessel to reach the launch tube. No diagonal moves -- ships only slide along their axis!",
"dockClearanceInstructions": "Slide ships horizontally or vertically to create a clear path. Get the red ship to the exit!",
"dockClearanceWinTitle": "Launch Clear!",
"dockClearanceWinDesc": "Your ship rockets out of the dock! Cleared in {moves} moves, earning {bonusScore} docking credits.",
"dockClearanceLoseTitle": "Still Jammed!",
"dockClearanceLoseDesc": "No clear path to the exit. Try sliding different ships first, Commander."
```

```json
"dockClearanceTitle": "Dock-Freigabe",
"dockClearanceDesc": "Das Raumdock ist verstopft! Verschiebe die geparkten Schiffe, um einen Weg fur dein Raumschiff zur Startschleuse freizumachen. Keine Diagonalbewegungen -- Schiffe gleiten nur entlang ihrer Achse!",
"dockClearanceInstructions": "Verschiebe Schiffe horizontal oder vertikal, um einen freien Weg zu schaffen. Bringe das rote Schiff zum Ausgang!",
"dockClearanceWinTitle": "Start frei!",
"dockClearanceWinDesc": "Dein Schiff schie\u00dft aus dem Dock! In {moves} Zugen freigegeben, {bonusScore} Dock-Kredite verdient.",
"dockClearanceLoseTitle": "Immer noch blockiert!",
"dockClearanceLoseDesc": "Kein freier Weg zum Ausgang. Versuche, zuerst andere Schiffe zu verschieben, Commander."
```

---

### 23. Relic Assembly (Card Edge Match)

```json
"relicAssemblyTitle": "Relic Assembly",
"relicAssemblyDesc": "Ancient alien tablet fragments have been excavated! Arrange the pieces so the glyphs on touching edges match perfectly. The artifact holds the key to the next star system!",
"relicAssemblyInstructions": "Place and rotate tablet pieces in the grid. Touching edges must show matching glyphs.",
"relicAssemblyWinTitle": "Artifact Restored!",
"relicAssemblyWinDesc": "The ancient tablet glows with power! Your archaeology earned {bonusScore} discovery points.",
"relicAssemblyLoseTitle": "Fragments Misaligned!",
"relicAssemblyLoseDesc": "Some edge glyphs don't match their neighbors. Try rotating or repositioning the pieces, Commander."
```

```json
"relicAssemblyTitle": "Relikte-Puzzle",
"relicAssemblyDesc": "Uralte Alien-Tafelfragmente wurden ausgegraben! Ordne die Stucke an, sodass die Glyphen an beruhrenden Kanten perfekt ubereinstimmen. Das Artefakt birgt den Schlussel zum nachsten Sternensystem!",
"relicAssemblyInstructions": "Platziere und drehe Tafelstucke im Gitter. Beruhrende Kanten mussen ubereinstimmende Glyphen zeigen.",
"relicAssemblyWinTitle": "Artefakt restauriert!",
"relicAssemblyWinDesc": "Die uralte Tafel leuchtet voller Kraft! Deine Archaologie hat {bonusScore} Entdeckungspunkte eingebracht.",
"relicAssemblyLoseTitle": "Fragmente falsch ausgerichtet!",
"relicAssemblyLoseDesc": "Einige Kantenglyphen stimmen nicht mit ihren Nachbarn uberein. Versuche die Stucke zu drehen oder neu zu positionieren, Commander."
```

---

### 24. Launch Sequence (Sorting Puzzle)

```json
"launchSequenceTitle": "Launch Sequence",
"launchSequenceDesc": "The launch queue is scrambled! Reorder the fleet by swapping adjacent ships. Get them in the correct sequence using the fewest swaps possible!",
"launchSequenceInstructions": "Tap two adjacent ships to swap them. Arrange all ships in the correct order. Fewer swaps = more points!",
"launchSequenceWinTitle": "Fleet Launched!",
"launchSequenceWinDesc": "Perfect sequence! You sorted the fleet in {moves} swaps (optimal: {optimal}), earning {bonusScore} efficiency points.",
"launchSequenceLoseTitle": "Sequence Error!",
"launchSequenceLoseDesc": "The fleet is still out of order. Keep swapping adjacent ships, Commander."
```

```json
"launchSequenceTitle": "Start-Sequenz",
"launchSequenceDesc": "Die Startreihenfolge ist durcheinander! Ordne die Flotte durch Tauschen benachbarter Schiffe neu. Bringe sie mit so wenigen Tauschvorgangen wie moglich in die richtige Reihenfolge!",
"launchSequenceInstructions": "Tippe auf zwei benachbarte Schiffe, um sie zu tauschen. Ordne alle Schiffe in der richtigen Reihenfolge. Weniger Tausche = mehr Punkte!",
"launchSequenceWinTitle": "Flotte gestartet!",
"launchSequenceWinDesc": "Perfekte Reihenfolge! Du hast die Flotte in {moves} Tauschen sortiert (optimal: {optimal}) und {bonusScore} Effizienzpunkte verdient.",
"launchSequenceLoseTitle": "Sequenzfehler!",
"launchSequenceLoseDesc": "Die Flotte ist immer noch durcheinander. Tausche weiter benachbarte Schiffe, Commander."
```

---

### 25. Star Chart Scan (Word Nebula)

```json
"starChartScanTitle": "Star Chart Scan",
"starChartScanDesc": "Hidden constellation names are embedded in this star chart data! Scan horizontally, vertically, and diagonally to find them all. One letter will remain unclaimed...",
"starChartScanInstructions": "Swipe across letters to highlight hidden words. Words can run in any direction. Find all words to reveal the mystery letter!",
"starChartScanWinTitle": "Chart Decoded!",
"starChartScanWinDesc": "All constellations found! The mystery letter is '{letter}'. You earned {bonusScore} cartography points.",
"starChartScanLoseTitle": "Scan Incomplete!",
"starChartScanLoseDesc": "Some constellations remain hidden in the data. Try scanning diagonally too, Commander."
```

```json
"starChartScanTitle": "Sternkarten-Scan",
"starChartScanDesc": "Versteckte Sternbildnamen sind in diesen Sternkartendaten eingebettet! Scanne horizontal, vertikal und diagonal, um sie alle zu finden. Ein Buchstabe bleibt ubrig...",
"starChartScanInstructions": "Wische uber Buchstaben, um versteckte Worter zu markieren. Worter konnen in jeder Richtung verlaufen. Finde alle Worter, um den Geheimnisbuchstaben zu enthullen!",
"starChartScanWinTitle": "Karte entschlusselt!",
"starChartScanWinDesc": "Alle Sternbilder gefunden! Der Geheimnisbuchstabe ist '{letter}'. Du hast {bonusScore} Kartografiepunkte verdient.",
"starChartScanLoseTitle": "Scan unvollstandig!",
"starChartScanLoseDesc": "Einige Sternbilder sind noch in den Daten verborgen. Versuche auch diagonal zu scannen, Commander."
```

---

### 26. Creature Forge (Chimera Lab)

```json
"creatureForgeTitle": "Creature Forge",
"creatureForgeDesc": "The xenobiology bay has parts from multiple alien species! Combine heads, bodies, and tails to discover every possible creature. How many unique beings can you create?",
"creatureForgeInstructions": "Swipe through heads, bodies, and tails. Count all unique combinations, then enter your answer.",
"creatureForgeWinTitle": "Species Catalog Complete!",
"creatureForgeWinDesc": "You discovered all {count} possible creatures! Your curiosity earned {bonusScore} biology points.",
"creatureForgeLoseTitle": "Missing Species!",
"creatureForgeLoseDesc": "You haven't found all the combinations yet. Remember: each head can pair with each body AND each tail, Commander."
```

```json
"creatureForgeTitle": "Kreaturen-Schmiede",
"creatureForgeDesc": "Die Xenobiologie-Bucht hat Teile von mehreren Alien-Spezies! Kombiniere Kopfe, Korper und Schwanze, um jede mogliche Kreatur zu entdecken. Wie viele einzigartige Wesen kannst du erschaffen?",
"creatureForgeInstructions": "Wische durch Kopfe, Korper und Schwanze. Zahle alle einzigartigen Kombinationen und gib deine Antwort ein.",
"creatureForgeWinTitle": "Spezieskatalog vollstandig!",
"creatureForgeWinDesc": "Du hast alle {count} moglichen Kreaturen entdeckt! Deine Neugier hat {bonusScore} Biologiepunkte eingebracht.",
"creatureForgeLoseTitle": "Fehlende Spezies!",
"creatureForgeLoseDesc": "Du hast noch nicht alle Kombinationen gefunden. Denke daran: Jeder Kopf kann mit jedem Korper UND jedem Schwanz kombiniert werden, Commander."
```

---

### 27. Alien Tribunal (Liar's Table)

```json
"alienTribunalTitle": "Alien Tribunal",
"alienTribunalDesc": "Galactic delegates are testifying, but some always lie! Truth-tellers always speak truth, liars always lie. Study their statements and identify who is trustworthy!",
"alienTribunalInstructions": "Read each delegate's statement. Mark each as 'Truth-Teller' or 'Liar'. All statements must be consistent with your assignments.",
"alienTribunalWinTitle": "Justice Served!",
"alienTribunalWinDesc": "The tribunal's verdict is sound! Your deduction earned {bonusScore} diplomacy points.",
"alienTribunalLoseTitle": "Mistrial!",
"alienTribunalLoseDesc": "Your assignments are contradictory. If someone is a truth-teller, their statements must be true, Commander."
```

```json
"alienTribunalTitle": "Alien-Tribunal",
"alienTribunalDesc": "Galaktische Delegierte sagen aus, aber manche lugen immer! Wahrheitssprecher sagen immer die Wahrheit, Lugner lugen immer. Studiere ihre Aussagen und finde heraus, wer vertrauenswurdig ist!",
"alienTribunalInstructions": "Lies die Aussage jedes Delegierten. Markiere jeden als 'Wahrheitssprecher' oder 'Lugner'. Alle Aussagen mussen mit deinen Zuweisungen ubereinstimmen.",
"alienTribunalWinTitle": "Gerechtigkeit!",
"alienTribunalWinDesc": "Das Urteil des Tribunals ist fundiert! Deine Deduktion hat {bonusScore} Diplomatiepunkte eingebracht.",
"alienTribunalLoseTitle": "Fehlurteil!",
"alienTribunalLoseDesc": "Deine Zuweisungen sind widerspruchlich. Wenn jemand ein Wahrheitssprecher ist, mussen seine Aussagen wahr sein, Commander."
```

---

### 28. Galactic Market (Coin Change)

```json
"galacticMarketTitle": "Galactic Market",
"galacticMarketDesc": "Welcome to the alien bazaar! Pay the exact price using the local currency. Some denominations are scarce -- find the combination that works!",
"galacticMarketInstructions": "Drag coins onto the payment pad to reach the exact target amount. Use as few coins as possible for bonus points!",
"galacticMarketWinTitle": "Purchase Complete!",
"galacticMarketWinDesc": "Exact change tendered! You used only {coins} coins, earning {bonusScore} trade points.",
"galacticMarketLoseTitle": "Incorrect Amount!",
"galacticMarketLoseDesc": "The merchant frowns -- that's not the right amount. Try a different combination of coins, Commander."
```

```json
"galacticMarketTitle": "Galaktischer Markt",
"galacticMarketDesc": "Willkommen auf dem Alien-Basar! Bezahle den genauen Preis mit der lokalen Wahrung. Manche Munzwerte sind knapp -- finde die Kombination, die funktioniert!",
"galacticMarketInstructions": "Ziehe Munzen auf das Bezahlfeld, um den genauen Zielbetrag zu erreichen. Benutze so wenige Munzen wie moglich fur Bonuspunkte!",
"galacticMarketWinTitle": "Kauf abgeschlossen!",
"galacticMarketWinDesc": "Passendes Wechselgeld! Du hast nur {coins} Munzen verwendet und {bonusScore} Handelspunkte verdient.",
"galacticMarketLoseTitle": "Falscher Betrag!",
"galacticMarketLoseDesc": "Der Handler runzelt die Stirn -- das ist nicht der richtige Betrag. Versuche eine andere Munzkombination, Commander."
```

---

## Visual Design Guide

### Color Assignments per Game

Each game gets a unique gradient from the existing palette, cycling through to avoid repetition:

| Game | Primary Color | Secondary Color | Icon Concept |
|------|--------------|----------------|--------------|
| Nebula Matrix | `#6B48FF` (purple) | `#FF6B9D` (pink) | Grid of stars in nebula cloud |
| Star Forge | `#FFD700` (gold) | `#FF6B35` (orange) | 5-pointed star with glowing nodes |
| Gravity Well | `#06FFA5` (green) | `#00C9DB` (teal) | Balance scale with planet weights |
| Dark Matter Grid | `#1A1A2E` (dark) | `#6B48FF` (purple) | Grid with light/dark cells |
| Sector Painter | `#FF6B35` (orange) | `#FFD700` (gold) | Star map with colored regions |
| Crew Manifest | `#00C9DB` (teal) | `#06FFA5` (green) | Clipboard with alien silhouettes |
| Orbital Towers | `#E63946` (red) | `#FFD700` (gold) | City skyline on platform |
| Hive Station | `#FFD700` (gold) | `#FF6B35` (orange) | Hexagonal honeycomb pattern |
| Vault Cracker | `#6B48FF` (purple) | `#E63946` (red) | Combination lock with alien glyphs |
| Xenobiology Lab | `#06FFA5` (green) | `#FFD700` (gold) | Alien creature with magnifier |
| Warp Fold | `#FF69B4` (pink) | `#6B48FF` (purple) | Folded paper with star pattern |
| Asteroid Duel | `#E63946` (red) | `#FF6B35` (orange) | Two ships facing asteroid piles |
| Comm Relay | `#00C9DB` (teal) | `#6B48FF` (purple) | Satellite dish with signal waves |
| Hull Plating | `#8B8B8B` (steel) | `#00C9DB` (teal) | Ship hull with tile pieces |
| Circuit Repair | `#FFD700` (gold) | `#E63946` (red) | 7-segment display with sparks |
| Ion Chain | `#06FFA5` (green) | `#00C9DB` (teal) | Glowing beads on a rail |
| Cube Scanner | `#6B48FF` (purple) | `#FF69B4` (pink) | 3D cube with scanner beam |
| Chrono Repair | `#FFD700` (gold) | `#6B48FF` (purple) | Clock face with glitch effect |
| Dock Clearance | `#E63946` (red) | `#00C9DB` (teal) | Top-down dock with ships |
| Relic Assembly | `#FF6B35` (orange) | `#FFD700` (gold) | Stone tablets with glowing edges |
| Launch Sequence | `#E63946` (red) | `#FFD700` (gold) | Numbered ships in a queue |
| Star Chart Scan | `#00C9DB` (teal) | `#FFD700` (gold) | Letter grid on starfield |
| Creature Forge | `#06FFA5` (green) | `#FF69B4` (pink) | Three-part alien mix-and-match |
| Alien Tribunal | `#6B48FF` (purple) | `#E63946` (red) | Alien faces with speech bubbles |
| Galactic Market | `#FFD700` (gold) | `#06FFA5` (green) | Alien coins on market stall |

### Shared UI Elements

All new games should use these existing components:
- **SpaceGrotesk** font family
- **Card radius**: 20px with gradient backgrounds
- **Win dialog**: Full-screen overlay with star burst animation
- **Score display**: Top bar with `Hull Integrity` (lives), score, timer
- **Number/item tray**: Bottom panel for draggable elements
- **Hint button**: Top-right corner, costs 1 hull point
- **Undo button**: Circular arrow icon, available in placement games

### Animation Principles

1. **Placement feedback**: Cell glows green (valid) or pulses red (conflict) on drag release
2. **Line completion**: When a row/column/line satisfies its constraint, it flashes and dims to "solved" state
3. **Victory**: Star-burst particle effect + ship flies off screen + score tally
4. **Failure**: Screen shake + red flash + "hull damage" crack overlay
5. **Hint reveal**: Beam of light illuminates the target cell/position from above

---

## Advent Calendar Mode Strings

```json
"adventCalendarTitle": "Advent Mission Log",
"adventCalendarDesc": "24 daily missions in December! Each solution reveals a letter. Collect all 24 to decode the secret message on Christmas Eve!",
"adventCalendarDay": "Mission Day {day}",
"adventCalendarLocked": "This mission unlocks on December {day}.",
"adventCalendarLetterRevealed": "Letter revealed: {letter}! Place it in slot {slot}.",
"adventCalendarDecryptTitle": "Decrypt the Message!",
"adventCalendarDecryptDesc": "You've collected all 24 letters! The secret message reads:",
"adventCalendarSecretMessage": "{message}",
"adventCalendarProgress": "{completed} of 24 missions complete"
```

```json
"adventCalendarTitle": "Advents-Missionslog",
"adventCalendarDesc": "24 tagliche Missionen im Dezember! Jede Losung enthullt einen Buchstaben. Sammle alle 24, um die geheime Nachricht an Heiligabend zu entschlusseln!",
"adventCalendarDay": "Missionstag {day}",
"adventCalendarLocked": "Diese Mission wird am {day}. Dezember freigeschaltet.",
"adventCalendarLetterRevealed": "Buchstabe enthullt: {letter}! Platziere ihn in Feld {slot}.",
"adventCalendarDecryptTitle": "Entschlussle die Nachricht!",
"adventCalendarDecryptDesc": "Du hast alle 24 Buchstaben gesammelt! Die geheime Nachricht lautet:",
"adventCalendarSecretMessage": "{message}",
"adventCalendarProgress": "{completed} von 24 Missionen abgeschlossen"
```
