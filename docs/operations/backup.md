# Offsite-Backup

Der Raspberry Pi sichert seine persistente Konfiguration und Docker-Daten täglich mit BorgBackup in eine dedizierte Hetzner Storage Box.

## Ziel und Sicherheit

- Repository: `ssh://u355613-sub6@u355613-sub6.your-storagebox.de:23/./pi-borg`
- Transport: SSH mit einem dedizierten Schlüssel
- Host-Key-Prüfung: dedizierte, fest hinterlegte `known_hosts`-Datei
- Verschlüsselung im Borg-Repository: deaktiviert

Die SSH-Verbindung schützt die Übertragung. Die gespeicherten Backup-Inhalte sind auf der Storage Box jedoch nicht zusätzlich verschlüsselt. Zugriff auf den Storage-Box-Account ermöglicht daher auch Zugriff auf die gesicherten Konfigurationen und Geheimnisse.

## Umfang

Gesichert werden:

- `/home/obause/pi-docker`
- relevante benutzerspezifische systemd- und CLI-Dateien
- `/etc`
- `/boot/firmware`
- Cron-Konfiguration
- alle Daten unter `/var/lib/docker/volumes`
- ausgelagerte Laufzeitdaten und gesicherte Altstände unter `/srv/pi-docker`

Nicht gesichert werden Docker-Images, Container-Layer, Container-JSON-Logs, Git-Objekte, Anwendungscaches, der regenerierbare Govee2MQTT-Cache und die im laufenden Betrieb veränderte Home-Assistant-SQLite-Datei. Images können aus den Compose-Dateien erneut bezogen werden. Die von Home Assistant unter `/srv/pi-docker/home-assistant/config/backups` erzeugten, konsistenten Backup-Archive werden mitgesichert und enthalten den wiederherstellbaren Home-Assistant-Zustand. Ebenso werden die kritischen Zigbee2MQTT- und Matter-Zustände unter `/srv/pi-docker` sowie Agent Zeros benanntes Volume `agent-zero-data` gesichert; nur der laufend veränderte Zigbee2MQTT-Logordner ist ausgeschlossen.

## Zeitplan und Aufbewahrung

Der Timer startet täglich um 06:30 Uhr Europe/Berlin mit bis zu 15 Minuten zufälliger Verzögerung.

- 7 tägliche Backups
- 4 wöchentliche Backups
- 6 monatliche Backups

## Bedienung

Status des Timers:

```bash
systemctl status pi-borg-backup.timer
systemctl list-timers pi-borg-backup.timer
```

Backup manuell starten:

```bash
sudo systemctl start pi-borg-backup.service
journalctl -u pi-borg-backup.service -f
```

Archive anzeigen:

```bash
sudo BORG_RSH='ssh -F /dev/null -i /home/obause/.ssh/id_ed25519_storagebox_backup -o IdentitiesOnly=yes -o UserKnownHostsFile=/home/obause/.ssh/known_hosts_storagebox -o StrictHostKeyChecking=yes' \
  borg list --remote-path=borg-1.2 \
  ssh://u355613-sub6@u355613-sub6.your-storagebox.de:23/./pi-borg
```

## Wiederherstellung

Ein einzelnes Archiv zunächst in ein leeres temporäres Verzeichnis extrahieren und die Dateien prüfen. Nicht direkt über ein laufendes System extrahieren.

```bash
mkdir restore
cd restore
sudo BORG_RSH='ssh -F /dev/null -i /home/obause/.ssh/id_ed25519_storagebox_backup -o IdentitiesOnly=yes -o UserKnownHostsFile=/home/obause/.ssh/known_hosts_storagebox -o StrictHostKeyChecking=yes' \
  borg extract --remote-path=borg-1.2 \
  ssh://u355613-sub6@u355613-sub6.your-storagebox.de:23/./pi-borg::ARCHIVNAME
```

Nach einer vollständigen Neuinstallation muss zuerst ein neuer SSH-Key beim Storage-Box-Sub-Account hinterlegt werden. Der Borg-Inhalt benötigt keine zusätzliche Passphrase.

### GitHub-Deploy-Key

Der private GitHub-Deploy-Key für `obause/pi-docker` liegt ausschließlich auf dem Pi und wird bewusst weder nach Git noch in das Borg-Repository kopiert. Nach einem vollständigen Hostverlust:

1. auf dem neuen Pi ein dediziertes Ed25519-Schlüsselpaar erzeugen
2. den öffentlichen Schlüssel in GitHub als schreibberechtigten Deploy-Key ausschließlich für `obause/pi-docker` registrieren
3. `origin` auf `git@github.com:obause/pi-docker.git` setzen
4. den Schlüssel mit `core.sshCommand` nur in der lokalen Git-Konfiguration dieses Repositories auswählen
5. `git fetch` und `git push --dry-run` prüfen

Der alte Deploy-Key wird danach in GitHub entfernt. Persönliche GitHub-Tokens oder private Laptop-Schlüssel gehören nicht auf den Pi.

### Servicezustand wiederherstellen

Laufzeitdaten niemals direkt über einen schreibenden Container extrahieren. Für Home Assistant, Zigbee2MQTT, Pi-hole oder Matter gilt:

1. den betroffenen Container stoppen
2. das Archiv in ein leeres temporäres Verzeichnis extrahieren
3. Dateianzahl, Eigentümer, Rechte und die erwarteten Kerndateien prüfen
4. den bisherigen Runtime-Pfad zusätzlich sichern
5. die geprüften Daten in den jeweiligen Pfad unter `/srv/pi-docker` übernehmen
6. nur den betroffenen Container starten und dessen Logs sowie Anwendung prüfen

Für Matter müssen mindestens `chip.json`, `chip_factory.ini`, `chip_config.ini`, `chip_counters.ini`, die numerische Node-State-Datei und `credentials/` vorhanden sein. Für Zigbee2MQTT sind insbesondere `database.db`, `coordinator_backup.json`, `state.json` und `configuration.yaml` relevant.

## Konsistenzhinweis

Das Backup liest die Daten des laufenden Systems. Home-Assistant-Backups im Verzeichnis `/srv/pi-docker/home-assistant/config/backups` werden mitgesichert. Für Datenbanken anderer Dienste sollte später zusätzlich ein anwendungsspezifischer Export- oder kurzer Quiesce-Schritt ergänzt werden.
