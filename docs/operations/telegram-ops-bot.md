# Telegram Operations Bot und Agent-Zugriff – Phase A bis D

Stand: 24. August 2026

## Umfang

Phase A ergänzt den bisherigen ausgehenden Telegram-Zustandsmelder um einen
privaten, rein lesenden Operations Bot. Der Dienst verwendet Long Polling und
öffnet deshalb keinen eingehenden Port auf dem Raspberry Pi.

Unterstützte Befehle:

- `/status`: kompakter Gesamtzustand
- `/zigbee`: aggregierter Funkpfad ohne Gerätebezeichnungen oder Adressen
- `/containers`: Lauf- und Health-Zustand der erwarteten Container
- `/backup`: letzter Borg-Lauf und nächster Timer-Termin
- `/host`: Uptime, Temperatur, Last, RAM, Datenträger und Drosselung
- `/alerts`: aktive Meldungen des sicheren Host-Healthchecks
- `/help` und `/start`: Hilfe beziehungsweise Schaltflächenmenü

Normale Textnachrichten liefern die Hilfe. Schaltflächen erlauben Navigation
und Aktualisierung der Statusansicht.

## Phase B: Diagnose und Verlauf

Phase B ergänzt zwei Befehle, ohne die rein lesende Sicherheitsgrenze zu
verändern:

- `/diagnose` öffnet eine geführte Diagnose für Gesamtbild, Zigbee, Container,
  Backup und Host
- `/history` fasst den Health- und Backupverlauf über 24 Stunden oder sieben
  Tage zusammen

Kurze freie Texte werden deterministisch einem Diagnosepfad zugeordnet. Dazu
gehören beispielsweise `Zigbee geht nicht`, `Backup prüfen`, `Docker Problem`
oder `Speicher prüfen`. Es wird dafür weder ein Sprachmodell aufgerufen noch
eine Shell aus Benutzereingaben gebaut.

Die Diagnoseansichten verbinden aktuelle Zustände mit sicheren, aggregierten
Signalen:

- Zigbee: MQTT-Verbindung, Alter und Fortschritt des Funkzählers sowie reine
  Anzahlen für Koordinator-, MQTT-, Timeout- und Gerätekonfigurationssignale
- Container: Lauf-/Health-Zustände, Neustartzähler und heuristische
  Fehleranzahlen der letzten Stunde
- Backup: Timer, letztes Ergebnis, nächster Lauf sowie Start-/Erfolgs-/Fehler-
  zähler aus dem systemd-Journal
- Host: Speicher, Inodes, RAM, Swap, Temperatur, Drosselung, fehlgeschlagene
  Units und aggregierte Kernel-Signale

Der Verlauf basiert auf dem persistenten systemd-Journal. Er zählt erfolgreiche
und fehlgeschlagene Health-Prüfläufe, ordnet Meldungen festen Kategorien zu und
zeigt den aktuellen Zustand. Logtexte aus Docker, Zigbee2MQTT, Borg oder dem
Kernel werden nie an Telegram übertragen. Die Diagnosezähler sind bewusst als
Hinweise und nicht als eindeutige Einzelereignisse gekennzeichnet.

## Phase C: Bestätigte Wartung

`/maintenance` öffnet die zustandsändernde Wartungsansicht. `/restart` zeigt
die feste Containerliste; `/restart <name>` bereitet den Neustart eines exakt
benannten Containers vor. Unterstützt werden:

- den vorhandenen Host-Healthcheck einmal ausführen
- einen Borg-Backup-Lauf im Hintergrund starten
- genau einen der elf bekannten Container neu starten
- einen Raspberry-Pi-Neustart mit 15 Sekunden Vorlauf planen

Die Auswahl führt noch keine Aktion aus. Der lokale root-Dienst erzeugt dafür
ein kryptografisch zufälliges Einmal-Token, speichert Aktion und Ablaufzeit nur
im Arbeitsspeicher und liefert eine Beschreibung der Auswirkung. Erst der
zweite Telegram-Button bestätigt dieses Token serverseitig. Tokens verfallen
nach 90 Sekunden, werden nach Bestätigung oder Abbruch entfernt und überstehen
keinen Neustart des lokalen Dienstes.

Chat-/Benutzer-Allowlist und Tokenprüfung wirken gemeinsam: Telegrams Button
ist keine Berechtigung, und der Bot kann keine vom lokalen Dienst unbekannte
Aktion oder ein zusätzliches Argument einschleusen. Der lokale Socket-Dienst
akzeptiert ausschließlich:

- `health-check`, `backup` und `reboot`
- `restart` für einen Namen aus derselben fest codierten Container-Allowlist

Ausführung und Ergebnis werden ohne Token, Chat-ID oder Benutzer-ID im
systemd-Journal des Statusdienstes protokolliert. Docker-Prune, automatische
Image-/Systemupdates, Compose-Änderungen und freie Shellbefehle sind nicht Teil
von Phase C. Solche Änderungen benötigen einen individuellen Plan und gehören
in die kontrollierte Agent-Zero-Integration von Phase D.

## Sicherheitsmodell

`pi-ops-bot.service` läuft als eigener Systembenutzer `pi-ops-bot` mit
gehärteten systemd-Einstellungen. Das bestehende Secret bleibt root-eigen und
im Modus `0600`; systemd stellt dem Prozess ausschließlich eine temporäre,
schreibgeschützte Credential-Kopie zur Verfügung.

Der Bot akzeptiert ausschließlich Nachrichten aus dem bei der Einrichtung
gespeicherten privaten Chat und vom zugehörigen Benutzer. Alle anderen Updates
werden ohne Antwort verworfen. Die Prüfung findet serverseitig statt und ist
von Telegrams sichtbarem Befehlsmenü unabhängig.

Für Statusdaten besitzt der Bot weder Docker-Socket-Zugriff noch Sudo-Rechte.
Ein separater lokaler Dienst läuft als root ohne Netzwerkzugriff und nimmt über
den gruppengeschützten Unix-Socket `/run/pi-ops-status/status.sock`
ausschließlich fest codierte Statusabfragen und das Bestätigungsprotokoll aus
Phase C an. Ungültige Aktionen, Ziele oder zusätzliche Argumente werden
verworfen. Freie Shell-, Prune-, Update- oder Konfigurationsaktionen existieren
nicht. Statusausgaben enthalten weder Logs der Anwendungen noch Secrets,
Gerätenamen, Adressen, Mounts oder Umgebungsvariablen.

Der Long-Polling-Offset liegt unter `/var/lib/pi-ops-bot/offset`, damit bereits
verarbeitete Nachrichten nach einem Neustart nicht erneut ausgeführt werden.

## Betrieb

```sh
systemctl status pi-ops-bot.service
systemctl status pi-ops-status-server.service
journalctl -u pi-ops-bot.service -n 30 --no-pager
sudo systemctl restart pi-ops-bot.service
```

Im Journal stehen nur allgemeine Verbindungs- und Verarbeitungsfehler. Token,
Chat-ID und Benutzer-ID werden nicht protokolliert.

## Phase D: Agent Zero mit Host-Gateway

Für freie, natürlichsprachliche Administrationsaufgaben verwendet Agent Zero
seine eigene Telegram-Integration. Der Operations Bot aus Phase A bis C bleibt
der deterministische Kanal für Status, Diagnose und bestätigte Standardaktionen;
der Agent-Zero-Bot ist der bewusst leistungsfähigere Kanal für individuelle
Analyse- und Änderungsaufgaben.

Auf dem Raspberry Pi läuft der offizielle A0 Connector als
`a0-host-gateway.service`. Er verbindet sich ausschließlich mit der lokal auf
`127.0.0.1:50080` veröffentlichten Agent-Zero-Instanz. Als primärer Arbeitsordner
ist `/home/obause/pi-docker` gesetzt. Freigegeben sind:

- Dateien lesen
- Dateien schreiben
- Befehle auf dem Host ausführen

Browser- und Computersteuerung sind deaktiviert. Das Gateway startet als
Benutzer `obause`; dessen bewusst vorhandene passwortlose Sudo-Berechtigung
ermöglicht Agent Zero vollständigen Hostzugriff. Das ist keine Sandbox-Grenze:
Eine bestätigte Agentenaufgabe kann Docker, systemd, Pakete und Dateien außerhalb
des Repositories verändern. Die Sicherheit beruht deshalb auf dem privaten
Telegram-Bot, dessen Benutzer-Allowlist, der Kontrolle der Aufgaben und der
Nachvollziehbarkeit in Agent Zero.

Der Gateway-Modus ist nicht an einen einzelnen Chat gebunden. Dadurch können
auch von Telegram erzeugte Agent-Zero-Kontexte dieselben Host-Werkzeuge nutzen.
Fortschritt, Werkzeugaufrufe, Warteschlange und Abbruch laufen nativ über die
Agent-Zero-Telegram-Integration; ein zusätzlicher API-Token-Bridge-Dienst ist
nicht erforderlich.

Da der Gateway-Prozess ein EOF auf stdin als reguläres Launcher-Ende behandelt,
hält die Startdatei einen privaten FIFO unter
`/run/a0-host-gateway/control` offen. Der Pfad ist nur für `obause` zugänglich
und verhindert die sonst bei systemd sofort eintretende Neustartschleife. Er
bleibt zugleich der vom Connector vorgesehene lokale JSONL-Steuerkanal.

### Betrieb des Host-Gateways

```sh
systemctl status a0-host-gateway.service
journalctl -u a0-host-gateway.service -n 50 --no-pager
sudo systemctl restart a0-host-gateway.service
/home/obause/.local/bin/a0 --version
```

Der Dienst enthält keine Telegram- oder Agent-Zero-Tokens. Updates des A0
Connectors werden bewusst nicht automatisch installiert und müssen nach
Prüfung des offiziellen Installers manuell erfolgen.
