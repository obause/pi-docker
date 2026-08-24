# Phase 2: Secrets und Laufzeitdaten

## Zielstruktur

```text
/home/obause/pi-docker/       # versionierbare Konfiguration und Dokumentation
/home/obause/pi-docker/runtime -> /srv/pi-docker
/srv/pi-docker/               # Laufzeitdaten und gesicherte Altstände
/etc/pi-docker/secrets/       # hostlokale Zugangsdaten
```

## Block A

Durchgeführt am 23. August 2026:

- unmittelbar vorher ein erfolgreiches Borg-Backup erstellt
- `docker/.env` nach `/etc/pi-docker/secrets/compose.env` migriert
- Zugriff auf die Secret-Ablage auf `root:docker` mit restriktiven Rechten begrenzt
- am bisherigen Pfad einen Symlink angelegt, damit normale Compose-Befehle weiter funktionieren
- elf nicht mehr verwendete Altvariablen entfernt
- den inaktiven `wg-easy`-Service aus der Compose-Datei entfernt
- alte WireGuard-Dateien unter `/srv/pi-docker/retired/wireguard` gesichert
- einen bequemen `runtime`-Symlink auf `/srv/pi-docker` angelegt
- Git-Ignore-Regeln für Secrets und zukünftige Runtime-Migrationen ergänzt

Die vorherige `.env` und Compose-Datei liegen mit Root-only-Rechten unter `/srv/pi-docker/retired`. Sie dürfen nicht zurück in Git kopiert werden.

## Compose-Umgebung

Die produktiven Werte liegen in:

```text
/etc/pi-docker/secrets/compose.env
```

Der kompatible Einstiegspunkt ist:

```text
/home/obause/pi-docker/docker/.env
```

Die Datei `docker/.env.example` enthält ausschließlich Variablennamen und Beispielwerte.

## Git-Index und Historie

Durchgeführt am 24. August 2026:

- 184 Secret-, Identitäts- und Runtime-Dateien aus dem aktuellen Git-Index entfernt
- die Arbeitskopien beziehungsweise migrierten Laufzeitdaten dabei nicht gelöscht
- den vorherigen Index Root-only unter `/srv/pi-docker/retired/git-index.pre-phase2` gesichert
- kontrolliert, dass keine aktuelle getrackte Konfigurationsdatei mehr auf die geprüften Private-Key-, Passwort-, Token- oder Secret-Muster anspricht
- die außerhalb dieses Docker-Umbaus liegende `zsh/.zshrc` bewusst nicht verändert

Die Historie umfasst 19 Commits; frühere Secret-Dateien sind dort weiterhin in einem bis fünf Commits erreichbar. Auf ausdrückliche Betreiberentscheidung werden weder die Commit-Historie umgeschrieben noch die darin früher enthaltenen Zugangsdaten allein deswegen rotiert. Der aktuelle Index bleibt dennoch von diesen Dateien bereinigt.

## Mosquitto

Die produktive Passwortdatei liegt außerhalb des Repositories:

```text
/etc/pi-docker/secrets/mosquitto.passwords
```

Sie wird read-only nach `/mosquitto/config/passwords` in den Container eingebunden. Frühere Varianten liegen mit Root-only-Rechten unter `/srv/pi-docker/retired/mosquitto.passwords.pre-phase2` und `/srv/pi-docker/retired/mosquitto.passwords.repo-copy.pre-index-cleanup`. Nach dem Entfernen des alten Mountpoint-Inodes wurde ausschließlich Mosquitto neu erstellt; aktiver Host- und Container-Hash stimmen überein und Zigbee2MQTT blieb aktiv.

## Traefik

Der private TLS-Key liegt außerhalb des Repositories:

```text
/etc/pi-docker/secrets/traefik/bause.lan.key
```

Er wird über `/run/secrets/traefik` read-only eingebunden. Das öffentliche mkcert-Zertifikat bleibt unter `docker/traefik/certs` versionierbar. Der derzeit leere, aber zukünftig zustandsbehaftete ACME-Ordner liegt unter:

```text
/srv/pi-docker/traefik/acme
```

Die Zertifikatszuordnung steht in `docker/traefik/dynamic/tls.yml`. Traefik lädt
TLS-Zertifikate über den bereits aktivierten dynamischen File-Provider; die
statische `traefik.yml` enthält daher bewusst keinen `tls:`-Block.

Die vorherigen Traefik-Dateien liegen Root-only unter `/srv/pi-docker/retired`.

## Pi-hole

Der persistente Pi-hole-v6-Zustand liegt außerhalb des Repositories:

```text
/srv/pi-docker/pihole/etc-pihole
```

Das Webpasswort wird nicht mehr als Klartext-Umgebungsvariable an den Container
übergeben. Pi-hole verwendet den bereits vorhandenen Passwort-Hash in seinem
persistenten `pihole.toml`. Nach einem erfolgreichen manuellen Login-Test wurde
der nicht mehr verwendete Klartextwert auch aus der aktiven geschützten
`compose.env` entfernt.

Der alte `/etc/dnsmasq.d`-Mount wurde entfernt. Pi-hole hatte ihn mit
`misc.etc_dnsmasq_d=false` nachweislich deaktiviert; die vorhandene lokale
Wildcard-Datei bleibt für eine mögliche spätere Entscheidung Root-only unter
`/srv/pi-docker/retired` erhalten. Der fehlerhafte alte Log-Mount, dessen
Hostquelle ein Verzeichnis statt einer Datei war, wurde ebenfalls entfernt.

## Home Assistant

Der vollständige beschreibbare Home-Assistant-Zustand liegt unter:

```text
/srv/pi-docker/home-assistant/config
```

Dieser Pfad wird als `/config` eingebunden. Folgende bewusst versionierte
Konfigurationen werden aus `docker/home-assistant` darübergelegt und bleiben
für Änderungen über die Weboberfläche beschreibbar:

- `configuration.yaml`, `automations.yaml`, `scripts.yaml`, `scenes.yaml`
- `blueprints`, `custom_components`, `themes`
- `ui_lovelace_minimalist`

Nicht versionierte Inhalte wie `.storage`, `.cloud`, Recorder-Datenbank, Logs,
Cache, `www`, `image` und native Home-Assistant-Backups verbleiben im
Runtime-Verzeichnis. Die zwei bereits vorhandenen lokalen Änderungen an den
Nordic-Theme-Dateien wurden bei der Migration unverändert erhalten.

Die bisher getrackte `secrets.yaml` liegt nun Root-only unter:

```text
/etc/pi-docker/secrets/home-assistant/secrets.yaml
```

Sie wird read-only nach `/config/secrets.yaml` eingebunden. Zum
Migrationszeitpunkt enthielt die Konfiguration keine aktive `!secret`-Referenz;
die Datei wurde dennoch für spätere Nutzung erhalten. Eine Bereinigung des
bereits vorhandenen Git-Verlaufs erfolgt nur nach einer separaten Entscheidung.

Der Borg-Exclude-Satz wurde um den neuen Runtime-Pfad ergänzt. Live-Recorder-
Datenbank, Logs, Cache, `deps`, `tts` und Lockdatei werden nicht archiviert;
die nativen Home-Assistant-Backups bleiben als konsistente Restore-Punkte im
Borg-Backup enthalten.

## Zigbee2MQTT

Das vollständige Zigbee2MQTT-Datenverzeichnis liegt unter:

```text
/srv/pi-docker/zigbee2mqtt/data
```

Es enthält Konfiguration, Zigbee-Netzwerkidentität, Coordinator-Backup,
Gerätedatenbank und persistenten Zustand und wird geschlossen nach `/app/data`
eingebunden. Der Hostzugriff ist auf den Besitzer beschränkt.

Compose übergibt MQTT-Benutzer und -Passwort über die von Zigbee2MQTT
unterstützten Variablen `ZIGBEE2MQTT_CONFIG_MQTT_USER` und
`ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD` aus der geschützten `compose.env`. Die alten
Konfigurations-Backups wurden von diesen Werten bereinigt. Die aktuell
eingesetzte Zigbee2MQTT-Version schreibt die per Umgebungsvariable gesetzten
Werte beim Start entgegen der Dokumentation wieder in `configuration.yaml`.
Diese technisch bedingte Runtime-Kopie liegt deshalb ausschließlich außerhalb
von Git in einem Verzeichnis mit Modus `0700`; die Datei selbst hat Modus
`0600`.

Netzwerkschlüssel und PAN-Identität verbleiben ebenfalls bewusst im geschützten
Runtime-Verzeichnis, da sie zusammen mit `database.db` und
`coordinator_backup.json` für eine Wiederherstellung ohne erneutes Pairing
benötigt werden.

Nur `data/log` ist vom Borg-Backup ausgeschlossen, weil genau dieser laufend
beschriebene Logpfad zuvor eine Borg-Warnung ausgelöst hat. Die kritischen
State- und Coordinator-Dateien bleiben im Backup enthalten.

## Agent Zero

Agent Zero läuft bewusst als separates Compose-Projekt unter
`docker/agent-zero`. `Dockerfile` und `compose.yml` sind deklarativ und
enthielten beim Abschluss-Audit keine eingebetteten Private-Key-, Passwort-,
Token- oder Secret-Muster.

Der vollständige Anwendungs-, OAuth-, Chat- und Connector-Zustand liegt im
benannten Docker-Volume `agent-zero-data`, das nach `/a0/usr` eingebunden ist.
Das Volume wird über `/var/lib/docker/volumes` vom Borg-Backup erfasst. Die
Weboberfläche ist ausschließlich an `127.0.0.1:50080` gebunden. Der CLI-
Connector mit Hostzugriff bleibt damit vom Container-Dateisystem getrennt und
soll weiterhin nur kontrolliert für konkrete Aufgaben verwendet werden.

## Matter Server

Der vollständige Fabric-, Node- und CHIP-Zustand liegt unter:

```text
/srv/pi-docker/matter-server/data
```

Der Ordner wird als `/data` eingebunden und vom Server explizit als
`--storage-path /data` verwendet. Er enthält unter anderem `chip.json`, die
Node-State-Datei samt Backup, CHIP-INI-Dateien und die PAA-Rootzertifikate.
Ein Verlust der Fabric- oder Node-Daten kann erneutes Commissioning erfordern;
deshalb wird der Ordner geschlossen verschoben und vollständig durch Borg
gesichert.

Der Hostzugriff auf das Runtime-Verzeichnis ist auf den Besitzer beschränkt.
Die zuvor 158 getrackten Matter-State-/Zertifikatsdateien wurden aus dem
aktuellen Git-Index entfernt. Nach der Migration waren 159 Dateien vorhanden;
der Server lauschte auf Port 5580, Home Assistant stellte seine WebSocket-
Verbindung wieder her und nach der Startphase traten keine neuen Fehler auf.
Das anschließend erzeugte Borg-Archiv enthält 161 Einträge unter dem Matter-
Pfad einschließlich aller vier zentralen CHIP-Dateien.

Eine Migration auf den neueren matter.js-basierten Server ist ein separater
späterer Upgrade-Schritt und ausdrücklich nicht Teil dieser reinen
Pfadmigration.

## Bewusste Folgeentscheidungen

- keine Umschreibung von `origin/main` mit `git filter-repo`
- keine Rotation von Zugangsdaten allein aufgrund der früheren Git-Versionierung
- die umfangreichen Home-Assistant-`custom_components` bleiben vorerst versioniert
