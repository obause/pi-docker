#!/usr/bin/env node
'use strict';

const fs = require('fs');
const mqtt = require('mqtt');
const yaml = require('js-yaml');

const config = yaml.load(fs.readFileSync('/app/data/configuration.yaml', 'utf8'));
const baseTopic = config.mqtt?.base_topic || 'zigbee2mqtt';
let finished = false;

function finish(code, message) {
    if (finished) return;
    finished = true;
    clearTimeout(timer);
    process.stdout.write(`${message}\n`);
    client.end(true, {}, () => process.exit(code));
    setTimeout(() => process.exit(code), 1000).unref();
}

const client = mqtt.connect(config.mqtt.server, {
    username: process.env.ZIGBEE2MQTT_CONFIG_MQTT_USER || config.mqtt.user,
    password: process.env.ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD || config.mqtt.password,
    connectTimeout: 5000,
    reconnectPeriod: 0,
});

const timer = setTimeout(
    () => finish(1, 'ERROR Zigbee health snapshot timed out'),
    10000,
);

client.on('error', () => finish(1, 'ERROR Zigbee health MQTT connection failed'));

client.on('connect', () => {
    client.subscribe(`${baseTopic}/bridge/health`, {qos: 0}, (error) => {
        if (error) finish(1, 'ERROR Zigbee health subscription failed');
    });
});

client.on('message', (_topic, payloadBuffer) => {
    let payload;
    try {
        payload = JSON.parse(payloadBuffer.toString('utf8'));
    } catch {
        finish(1, 'ERROR Zigbee health payload is invalid');
        return;
    }

    const responseTime = Number(payload.response_time);
    const uptime = Number(payload.process?.uptime_sec);
    const mqttConnected = payload.mqtt?.connected === true;
    const devices = payload.devices;
    if (!Number.isFinite(responseTime) || !Number.isFinite(uptime) || !devices || typeof devices !== 'object') {
        finish(1, 'ERROR Zigbee health payload is incomplete');
        return;
    }

    const messageCounts = Object.values(devices).map((device) => Number(device?.messages) || 0);
    const totalMessages = messageCounts.reduce((total, count) => total + count, 0);
    const activeDevices = messageCounts.filter((count) => count > 0).length;
    finish(
        mqttConnected ? 0 : 1,
        [
            Math.floor(responseTime / 1000),
            Math.floor(uptime),
            mqttConnected ? 1 : 0,
            messageCounts.length,
            activeDevices,
            totalMessages,
        ].join(' '),
    );
});
