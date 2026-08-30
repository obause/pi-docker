# DNS-Zuverlaessigkeit und Ausfallanalyse

Stand: 28. August 2026

## Befund

Die DNS-Ausfaelle am 26. und 28. August waren keine isolierten Abstuerze des
Pi-hole-Prozesses. In beiden Zeitraeumen konnten Docker-Healthchecks fuer
mehrere voneinander unabhaengige Container nicht mehr gestartet oder beendet
werden. Beim zweiten Vorfall meldete der Kernel zusaetzlich einen seit mehr als
120 Sekunden blockierten Worker im SD/MMC-Pfad (`mmc_rescan`/
`__mmc_claim_host`). Gleichzeitig wurde `systemd-journald` vom Watchdog beendet
und ersetzte anschliessend ein unvollstaendiges Journal.

Es gab keine Hinweise auf einen OOM-Kill, Unterspannung, CPU-Throttling oder
eine volle Root-Partition. Das Fehlerbild spricht daher mit hoher
Wahrscheinlichkeit fuer einen hostweiten I/O-Stillstand der SD-Karte. Der
vollstaendig belegte Swap auf derselben SD-Karte und die hohe Speichernutzung
durch Agent Zero und Home Assistant vergroessern dieses Risiko.

Pi-hole verstaerkte die I/O-Last durch eine rund 630 MB grosse FTL-Datenbank mit
etwa 100.000 neuen Abfragen pro Tag. Nicht erreichbare IPv6-Upstreams erzeugten
ausserdem fortlaufend Fehlversuche. Zwei weitere Altwerte verwiesen noch auf
die fruehere Adresse `192.168.178.41` und auf das falsche Reverse-Netz
`192.168.2.0/24`.

## Sofortmassnahmen

- Das Pi-hole-Image ist vorerst auf die bereits eingesetzte Version
  `2026.04.1` festgelegt. Ein Update erfolgt separat mit eigenem Funktionstest.
- Pi-hole verwendet nur noch vier erreichbare IPv4-Upstreams.
- Die langfristige DNS-Historie ist auf 14 Tage begrenzt.
- Host-Antwort und Reverse-DNS entsprechen wieder `192.168.178.5` sowie
  `192.168.178.0/24`.
- Docker prueft nun echte DNS-Aufloesung statt nur den Containerzustand.
- Der Host-Healthcheck prueft DNS ueber UDP und TCP. Alle Docker-Abfragen haben
  harte Zeitlimits, damit ein haengender Docker-Daemon nicht erneut den
  kompletten Monitor blockiert.
- Der Monitor meldet zusaetzlich kritischen RAM-/Swap-Druck.

Die vorhandene Langzeitdatenbank wird nicht geloescht. Nach Ablauf der neuen
14-Tage-Grenze entfernt FTL alte Eintraege automatisch. WAL bleibt aktiviert,
wie von Pi-hole fuer lokale Datentraeger empfohlen.

## Speicher

Der Raspberry Pi hat 3,7 GiB nutzbaren RAM. Agent Zero benoetigte je nach
Speicherzustand rund 0,9 bis 1,5 GiB, Home Assistant rund 0,9 GiB. Das in
Compose deklarierte
Agent-Zero-Limit ist derzeit wirkungslos, weil der Kernel den Memory-Cgroup-
Controller nicht bereitstellt.

Als kurzfristige Entlastung ersetzt komprimierter ZRAM-Swap den Swap auf der
SD-Karte. Das verhindert einen erheblichen Teil der zufaelligen Schreib- und
Lesezugriffe auf Flash. Es ersetzt jedoch keine dauerhaft zuverlaessige
Systemplatte.

Installiert ist Debians `zram-tools`. Die versionierte Konfiguration liegt in
`config/zram/zramswap` und erzeugt ein ZRAM-Geraet mit 25 Prozent des
Arbeitsspeichers, schneller LZ4-Kompression und Prioritaet 100. Der bisherige
Dienst `dphys-swapfile` ist deaktiviert, damit `/var/swap` weder jetzt noch
nach einem Neustart wieder aktiviert wird.

## Dauerhafte Loesung und DNS-Fallback

Die robuste Speicherloesung ist die Migration des Root-Dateisystems auf eine
USB-SSD oder mindestens der Austausch gegen eine neue High-Endurance-SD-Karte.
Nach zwei hostweiten MMC-Stillstaenden darf die bestehende Karte nicht mehr als
langfristig zuverlaessig betrachtet werden.

Ein zweiter DNS-Container auf demselben Pi ist kein echter Fallback: Bei einem
Host- oder SD-Ausfall faellt er gleichzeitig aus. Fuer ausfallsicheres DNS wird
ein Resolver auf einem zweiten physischen Geraet benoetigt. Alternativ kann der
Router bei Nichterreichbarkeit von Pi-hole auf einen externen Resolver
zurueckfallen; dann wird die Werbeblockierung waehrend des Ausfalls umgangen.

Entschieden ist, Pi-hole vorerst weiterhin direkt per DHCP an die Clients zu
verteilen. Dadurch bleiben detaillierte Clientstatistiken und clientbezogene
Regeln erhalten. Ein FRITZ!Box-Proxy mit oeffentlichem Fallback wird deshalb
nicht eingerichtet. Bis zur Neueinrichtung des NAS besteht bewusst noch keine
vom Raspberry Pi unabhaengige DNS-Redundanz.

Das NAS ist als spaetere zweite physische DNS-Instanz vorgesehen. Beide
Resolver muessen dieselben lokalen Eintraege, Blocklisten und clientbezogenen
Regeln erhalten. Der NAS-Resolver braucht eine feste Adresse und eigene
oeffentliche Upstreams, damit sein Start nicht vom Raspberry Pi abhaengt. Wie
beide DNS-Adressen an die Clients verteilt werden, wird bei der NAS-Einrichtung
separat festgelegt, da die FRITZ!Box-Oberflaeche fuer den lokalen DNSv4-Server
nur ein einzelnes Feld bereitstellt.

## Neustartpruefung

Der kontrollierte Neustart am 28. August war erfolgreich. ZRAM wurde mit rund
949 MiB automatisch aktiviert, waehrend `dphys-swapfile` inaktiv blieb. Alle
elf Container erreichten ihren erwarteten Zustand; Agent Zero benoetigte dabei
rund fuenf Minuten. Pi-hole beantwortete anschliessend DNS-Anfragen vom Host
und aus dem LAN ueber UDP und TCP. Es gab keine neuen MMC-, I/O-, OOM- oder
Unterspannungsmeldungen und keine fehlgeschlagenen Systemdienste.

## Agent Zero stillgelegt

Die Langzeitbeobachtung bis zum 30. August zeigte, dass Agent Zero auf diesem
4-GB-Host zu wenig Reserve fuer die uebrigen Produktivdienste laesst. Nach rund
19 Stunden waren 944 von 949 MiB ZRAM belegt. Direkt nach dem reversiblen Stopp
stieg der freie RAM von 78 auf 901 MiB; die ZRAM-Belegung sank um rund 545 MiB.

Agent Zero startet deshalb nicht mehr automatisch und gehoert nicht mehr zum
Produktiv-Healthcheck. Container, Image, Einstellungen und das durch Borg
gesicherte Volume `agent-zero-data` bleiben fuer eine spaetere Migration auf
das NAS erhalten. Pi-hole, Home Assistant und alle anderen Kerncontainer
blieben waehrend und nach der Umstellung gesund.

Der spaetere kontrollierte Ausfalltest muss mindestens pruefen:

1. Pi-hole-Container stoppen und DNS-Verhalten eines LAN-Clients beobachten.
2. Pi-hole starten und Wiederherstellung ueber UDP und TCP bestaetigen.
3. Telegram-Warnung und Entwarnung pruefen.
4. Den gewaehlten externen oder zweiten lokalen Resolver als getrennte
   Fehlerdomaene verifizieren.
