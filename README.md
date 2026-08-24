# pi-docker

Dieses Repository beschreibt die Docker-Services und wesentliche Host-Konfiguration des Raspberry Pi. Deklarative Konfiguration bleibt in Git; beschreibbare Laufzeitdaten liegen unter `/srv/pi-docker` und Geheimnisse unter `/etc/pi-docker/secrets`.

Die Trennung ist auf dem Host umgesetzt und die betreffenden Dateien sind aus dem aktuellen Git-Index entfernt. Ältere Commits enthalten weiterhin frühere Geheimnisse und Zustandsdaten. Auf ausdrückliche Betreiberentscheidung bleiben diese Historie und die bestehenden Zugangsdaten unverändert.

## Betrieb

- [Offsite-Backup](docs/operations/backup.md)
- [Docker- und Host-Logging](docs/operations/logging.md)
- [Phase-1-Änderungsbericht](docs/operations/phase-1.md)
- [Phase 2: Secrets und Laufzeitdaten](docs/operations/phase-2.md)
- [Phase 3: Zuverlässigkeit und Wartbarkeit](docs/operations/phase-3.md)

## Wichtige Befehle

```bash
cd /home/obause/pi-docker/docker
docker compose ps
docker compose logs --since 30m SERVICE
docker compose config -q
```

Agent Zero läuft als separates Compose-Projekt:

```bash
cd /home/obause/pi-docker/docker/agent-zero
docker compose ps
```

Backupstatus:

```bash
systemctl status pi-borg-backup.timer
systemctl status pi-borg-backup.service
```

Vor Änderungen an persistenten Daten zuerst das Offsite-Backup prüfen oder manuell starten. Geheimnisse und private Schlüssel dürfen nicht neu zu Git hinzugefügt werden.

## Datenklassen

```text
/home/obause/pi-docker/       versionierbare Konfiguration und Dokumentation
/srv/pi-docker/               beschreibbare Laufzeit- und Wiederherstellungsdaten
/etc/pi-docker/secrets/       hostlokale Geheimnisse
/srv/pi-docker/retired/       root-only gesicherte Altstände
```

Der Symlink `/home/obause/pi-docker/runtime` zeigt auf `/srv/pi-docker`. Die produktive Compose-Umgebung bleibt über `docker/.env` erreichbar; dieser Pfad ist ein nicht versionierter Symlink auf die geschützte Hostdatei.

## GitHub-Zugriff vom Pi

Das Repository verwendet einen eigenen schreibberechtigten GitHub-Deploy-Key, der ausschließlich für `obause/pi-docker` gilt. `origin` verwendet SSH; der zugehörige Schlüssel und die SSH-Optionen sind nur in der lokalen Git-Konfiguration dieses Repositories hinterlegt. Dadurch benötigt der Pi weder einen persönlichen GitHub-Token noch Agent-Forwarding vom Laptop.

Der private Deploy-Key wird bewusst nicht kopiert oder in Git beziehungsweise Borg archiviert. Bei einem vollständigen Host-Restore wird ein neues Schlüsselpaar erzeugt und der öffentliche Deploy-Key in GitHub ersetzt.
