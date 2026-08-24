# Docker-Logging

Docker verwendet global den `local`-Logging-Treiber mit Rotation und Kompression.

Konfiguration: `/etc/docker/daemon.json`

```json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "20m",
    "max-file": "5"
  }
}
```

Pro Container werden maximal fünf Logsegmente mit jeweils ungefähr 20 MB vorgehalten. Der `local`-Treiber komprimiert rotierte Segmente automatisch.

Die Einstellung gilt nur für neu erstellte Container. Nach einer Änderung müssen die Compose-Container neu erstellt werden.

Prüfen:

```bash
docker info --format '{{.LoggingDriver}}'
docker inspect --format '{{.HostConfig.LogConfig.Type}}' CONTAINER
docker system df
df -h /
```

Logs werden weiterhin normal gelesen:

```bash
docker logs --since 30m CONTAINER
docker compose logs --since 30m SERVICE
```

## systemd-Journal

Das persistente Host-Journal ist über `/etc/systemd/journald.conf.d/10-size.conf` begrenzt:

- maximal 500 MB
- mindestens 1 GB freier Speicher bleibt unberührt
- maximale Aufbewahrung 30 Tage
- Kompression aktiviert

Prüfen:

```bash
journalctl --disk-usage
systemd-analyze cat-config systemd/journald.conf
```
