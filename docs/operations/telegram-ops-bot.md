# Telegram Operations Bot – Phase A

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

## Sicherheitsmodell

`pi-ops-bot.service` läuft als eigener Systembenutzer `pi-ops-bot` mit
gehärteten systemd-Einstellungen. Das bestehende Secret bleibt root-eigen und
im Modus `0600`; systemd stellt dem Prozess ausschließlich eine temporäre,
schreibgeschützte Credential-Kopie zur Verfügung.

Der Bot akzeptiert ausschließlich Nachrichten aus dem bei der Einrichtung
gespeicherten privaten Chat und vom zugehörigen Benutzer. Alle anderen Updates
werden ohne Antwort verworfen. Die Prüfung findet serverseitig statt und ist
von Telegrams sichtbarem Befehlsmenü unabhängig.

Für Statusdaten besitzt der Dienst keinen Docker-Socket-Zugriff. Die
Sudoers-Regel erlaubt ausschließlich sechs vollständige Aufrufe von
`/usr/local/sbin/pi-ops-status` mit einem jeweils festen Argument. Das
Hilfsprogramm bietet keine Shell-, Restart-, Schreib-, Update- oder
Backup-Aktion und gibt weder Logs der Anwendungen noch Secrets, Gerätenamen,
Adressen, Mounts oder Umgebungsvariablen aus.

Der Long-Polling-Offset liegt unter `/var/lib/pi-ops-bot/offset`, damit bereits
verarbeitete Nachrichten nach einem Neustart nicht erneut ausgeführt werden.

## Betrieb

```sh
systemctl status pi-ops-bot.service
journalctl -u pi-ops-bot.service -n 30 --no-pager
sudo systemctl restart pi-ops-bot.service
```

Im Journal stehen nur allgemeine Verbindungs- und Verarbeitungsfehler. Token,
Chat-ID und Benutzer-ID werden nicht protokolliert.
