docker run --rm -v "$(pwd)"/mosquitto/config:/mosquitto/config eclipse-mosquitto:2 \
  mosquitto_passwd -b /mosquitto/config/passwords admin m0squitt0!