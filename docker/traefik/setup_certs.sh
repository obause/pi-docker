# mkcert installieren (Debian/Raspbian)
#sudo apt update && sudo apt install -y libnss3-tools
#curl -L https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-arm -o mkcert
#chmod +x mkcert && sudo mv mkcert /usr/local/bin/

# CA installieren (legt Root-CA im Nutzerprofil an)
mkcert -install

# Wildcard-Zertifikate erstellen
mkdir -p /home/obause/pi-docker/docker/traefik/certs
mkcert -cert-file /home/obause/pi-docker/docker/traefik/certs/bause.lan.crt \
       -key-file  /home/obause/pi-docker/docker/traefik/certs/bause.lan.key \
       "*.bause.lan" bause.lan