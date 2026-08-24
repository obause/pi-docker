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
- Pi-hole war zunächst der einzige Dienst mit Docker-Healthcheck
- keine Compose-RAM- oder Prozesslimits
- Portainer besitzt direkten Docker-Socket-Zugriff
- Home Assistant läuft `privileged` mit `NET_ADMIN` und `NET_RAW`
- Agent Zero ist nicht privilegiert, auf zwei CPUs begrenzt und besitzt keinen
  direkten Docker-Socket-Mount

Docker liefert auf diesem Host derzeit keine nutzbaren Container-RAM-Werte.
Beim Neuerstellen von Agent Zero meldete Docker außerdem ausdrücklich, dass
der Kernel Memory-Limits nicht unterstützt beziehungsweise der Controller
nicht eingehängt ist; das vorhandene `mem_limit: 2g` wurde verworfen.
Speicherlimits werden deshalb erst nach einer separaten Prüfung der
Memory-Controller-Konfiguration festgelegt.

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
