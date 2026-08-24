# Phase 1: Stabilisierung

Stand: 23. August 2026

## Durchgeführt

- BorgBackup 1.2.4 installiert.
- Dediziertes SSH-Schlüsselpaar für den Storage-Box-Sub-Account angelegt.
- Hetzner-Host-Keys gegen den bereits am Laptop bestätigten Schlüssel geprüft und separat gepinnt.
- Borg-Repository `pi-borg` auf der Storage Box angelegt; Speicherung auf Wunsch ohne zusätzliche Borg-Verschlüsselung.
- Erstes Archiv vollständig mit `borg check --verify-data` geprüft.
- Test-Restore einer systemd-Datei erfolgreich durchgeführt.
- Täglichen Backup-Timer mit Aufbewahrung für 7 tägliche, 4 wöchentliche und 6 monatliche Archive aktiviert.
- Nicht mehr verwendeten Container `wg-easy` entfernt.
- Alte Agent-Zero-v2.9-Images gezielt entfernt.
- Docker global auf den rotierenden und komprimierten `local`-Logging-Treiber umgestellt.
- Alle aktiven Compose-Container neu erstellt und deren Logtreiber geprüft.
- systemd-Journal auf 500 MB und 30 Tage begrenzt.

## Ergebnis

- Alle elf aktuellen Container laufen.
- Pi-hole meldet `healthy`.
- Home Assistant antwortet auf Port 8123.
- MQTT und Matter sind erreichbar.
- Zigbee2MQTT ist gestartet und mit MQTT verbunden.
- Die Containerlogs belegen nach der Umstellung weniger als 1 MB statt zuvor ungefähr 14 GB.
- Das systemd-Journal belegt ungefähr 464 MB statt zuvor 3,6 GB.
- Der freie Speicher stieg von ungefähr 6,7 GB auf mehr als 20 GB.

## Bewusste Einschränkungen

- Das Borg-Repository ist nicht zusätzlich verschlüsselt; nur der Transport erfolgt über SSH.
- Die laufende Home-Assistant-SQLite-Datei ist vom Borg-Dateibackup ausgeschlossen. Stattdessen werden die von Home Assistant erzeugten Backup-Archive gesichert.
- Memory-Limits funktionieren erst nach Aktivierung des Memory-Cgroup-Controllers und einem späteren Reboot.
- Die Bereinigung von Geheimnissen und Laufzeitdaten aus Git ist nicht Teil dieser Phase.
