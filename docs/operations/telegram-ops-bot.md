# Telegram Operations Bot – Phase A und B

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
ausschließlich fest codierte Leseabfragen an. Ungültige oder zusätzliche
Argumente werden verworfen. Das Hilfsprogramm bietet keine Shell-, Restart-,
Schreib-, Update- oder Backup-Aktion und gibt weder Logs der Anwendungen noch
Secrets, Gerätenamen, Adressen, Mounts oder Umgebungsvariablen aus.

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
