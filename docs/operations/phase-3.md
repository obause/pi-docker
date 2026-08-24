# Phase 3: Zuverlässigkeit und Wartbarkeit

Stand: 24. August 2026

## Dauerhafter administrativer Zugriff

Der Host-Alias `pi` auf dem Administrations-Laptop verwendet eine explizite
Public-Key-Referenz und `IdentitiesOnly yes`. Dadurch bietet OpenSSH nur den
zugehörigen Schlüssel aus dem 1Password-SSH-Agent an und läuft nicht mehr in
`Too many authentication failures`.

Der Raspberry Pi verwendet für `obause/pi-docker` einen eigenen
schreibberechtigten GitHub-Deploy-Key. Der Schlüssel ist auf genau dieses
Repository begrenzt. `origin` nutzt SSH; Schlüsselpfad und SSH-Optionen sind
ausschließlich in der lokalen Git-Konfiguration dieses Repositories gesetzt.
Fetch und Dry-Run-Push wurden erfolgreich geprüft.

Der private Deploy-Key bleibt ausschließlich auf dem Pi und wird bewusst nicht
nach Git oder Borg kopiert. Das Restore-Verfahren durch Neugenerierung und
Austausch des öffentlichen Deploy-Keys steht in `backup.md`.

## Reliability-Inventur

- Host: vier CPU-Kerne, 3,7 GiB RAM, cgroup v2
- elf laufende Container
- Pi-hole war zunächst der einzige Dienst mit Docker-Healthcheck; inzwischen
  besitzen alle dafür geeigneten Kernkomponenten einen Funktionscheck
- noch keine allgemein wirksamen RAM-Limits; Agent Zero ist bereits auf zwei
  CPU-Kerne begrenzt
- Portainer besitzt direkten Docker-Socket-Zugriff
- Home Assistant läuft nicht mehr privilegiert und behält gezielt `NET_ADMIN`
  sowie `NET_RAW`
- Agent Zero ist nicht privilegiert, auf zwei CPUs begrenzt und besitzt keinen
  direkten Docker-Socket-Mount

Docker liefert auf diesem Host derzeit keine nutzbaren Container-RAM-Werte.
Beim Neuerstellen von Agent Zero meldete Docker außerdem ausdrücklich, dass
der Kernel Memory-Limits nicht unterstützt beziehungsweise der Controller
nicht eingehängt ist; das vorhandene `mem_limit: 2g` wurde verworfen.
Ursache ist der noch laufende Kernel-Parameter `cgroup_disable=memory`. Die
aktuelle `/boot/firmware/cmdline.txt` enthält ihn nicht mehr und der Kernel ist
mit `CONFIG_MEMCG=y` gebaut. Der nächste kontrollierte Neustart sollte den
Memory-Controller daher ohne weitere Konfigurationsänderung aktivieren. Erst
danach werden Speicherverbrauch und sinnvolle Limits neu bewertet.

## Mosquitto und Zigbee2MQTT

Mosquitto prüft nun lokal, ob der Broker auf Container-Port 1883 lauscht.
Zigbee2MQTT prüft sein lokales HTTP-Frontend auf Port 8080. Beide Checks nutzen
nur bereits im jeweiligen Image vorhandene Werkzeuge und benötigen keine
zusätzlichen Zugangsdaten.

Zigbee2MQTT startet über `depends_on.condition: service_healthy` erst, nachdem
Mosquitto healthy ist. Nach der gezielten Neuerstellung waren beide Container
healthy, ohne Neustarts, der aktive Mosquitto-Secret-Mount stimmte und vier
MQTT-Verbindungen sowie das Zigbee2MQTT-Frontend waren aktiv.

Im Startfenster traten drei Geräte-Konfigurationsversuche mit
`UNSUPPORTED_ATTRIBUTE` und ZCL-Timeout auf. Es gab keine Adapter-, Coordinator-,
MQTT- oder Netzwerkabbrüche. Diese gerätespezifischen Meldungen werden getrennt
von der Container-Health behandelt und bei Bedarf anhand des betroffenen
Gerätemodells untersucht.

## Home Assistant, Matter und Agent Zero

Home Assistant prüft seinen lokalen HTTP-Endpunkt auf Port 8123, Matter seinen
Endpunkt auf Port 5580. Beide verwenden dafür das bereits im Image vorhandene
Python-Standardmodul. Nach der gezielten Neuerstellung waren beide Container
healthy und ohne Neustarts; Home Assistant antwortete mit HTTP 200 und stellte
die Matter-WebSocket-Verbindung ohne Fehler wieder her.

Agent Zero prüft seinen lokalen HTTP-Endpunkt auf Container-Port 80. Die
Anwendung benötigt auf dem Raspberry Pi bei einem Kaltstart deutlich länger
als eine Minute, während sie CPU-intensiv initialisiert. Das Healthcheck-
Startfenster beträgt deshalb drei Minuten. Datenvolume und OAuth-/Chat-Zustand
blieben unverändert; nach der Initialisierung waren Healthcheck und die nur an
`127.0.0.1:50080` veröffentlichte Oberfläche healthy beziehungsweise HTTP 200.

## Traefik und Docker-Socket-Proxy

Der Socket-Proxy prüft lokal Dockers `_ping`-Endpunkt auf Port 2375. Traefik
startet erst, nachdem der Proxy healthy ist. Traefiks offizieller interner
`/ping`-Endpunkt ist in der statischen Konfiguration aktiviert und wird mit dem
im Image enthaltenen Befehl `traefik healthcheck` geprüft.

Nach der gezielten Neuerstellung waren beide Container healthy, ohne Neustarts
oder neue Fehler. Die TLS-Routen für Pi-hole, Zigbee2MQTT, Portainer und das
Traefik-Dashboard antworteten weiterhin mit den erwarteten HTTP-Statuscodes.

Portainers Image enthält weder Shell noch HTTP-Client und der vorhandene
Portainer-Binary bietet keinen erfolgreichen eingebauten Healthcheck. Portainer
wird deshalb später über das Host-Monitoring seines HTTPS-Endpunkts geprüft.
Für Govee2MQTT und Cloudflare-DDNS wird ebenfalls kein künstlicher reiner
Prozesscheck ergänzt; ihre Funktionsprüfung gehört in das externe Monitoring.

## Privilegien

Home Assistant verwendet die Bluetooth-Integration und sieht einen lokalen
Bluetooth-Controller. `privileged: true` wurde dennoch entfernt, weil D-Bus
sowie die von Home Assistant für vollständige Bluetooth-Verwaltung geforderten
Capabilities `NET_ADMIN` und `NET_RAW` bereits gezielt vorhanden sind.

Nach der Neuerstellung war Home Assistant healthy und HTTP 200. Der gleiche
Bluetooth-Controller blieb sichtbar, `bluetoothctl show` funktionierte, Matter
verband sich wieder und es traten keine Bluetooth-Berechtigungs- oder
kritischen Fehler auf.

Matter behält `apparmor=unconfined`, da dies Teil der offiziellen
Container-Empfehlung für Bluetooth-Kommissionierung ist. Portainer behält den
direkten Docker-Socket, weil er als vollständige lokale Docker-Verwaltung
eingesetzt wird. Der Zugriff ist damit bewusst administrativ und nicht
Least-Privilege.

## Lokaler Gesundheitsmonitor

`scripts/pi-health-check` prüft alle fünf Minuten unabhängig von Docker
Compose den Betriebszustand des Hosts:

- alle elf erwarteten Container müssen laufen; vorhandene Docker-Healthchecks
  dürfen weder `unhealthy` noch dauerhaft `starting` sein
- der Borg-Timer muss aktiv und der letzte Backup-Lauf erfolgreich sein
- die Root-Partition darf nicht zu mindestens 85 Prozent belegt sein
- Home Assistant, Matter und Agent Zero werden über ihre Loopback-Endpunkte
  geprüft
- Pi-hole, Zigbee2MQTT, Portainer und Traefik werden über ihre lokalen
  Traefik-Routen geprüft; `--resolve` macht diese Tests unabhängig von DNS

Der gehärtete One-shot-Dienst `pi-health-check.service` läuft als root, damit
er Docker und systemd auslesen kann. `pi-health-check.timer` startet ihn fünf
Minuten nach dem Boot und danach im Fünf-Minuten-Takt. Erfolg und konkrete
Fehler stehen im Journal:

```sh
systemctl status pi-health-check.timer
journalctl -u pi-health-check.service -n 30 --no-pager
sudo systemctl start pi-health-check.service
```

Die installierten Dateien liegen unter `/usr/local/sbin` beziehungsweise
`/etc/systemd/system`; ihre versionierten Quellen liegen in `scripts/` und
`systemd/`. Benachrichtigungen werden separat ergänzt, sobald der gewünschte
Kanal feststeht. Bis dahin liefert der Monitor lokal eine einheitliche,
maschinenlesbare Grundlage ohne Zugangsdaten.
