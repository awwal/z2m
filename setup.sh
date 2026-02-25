#!/bin/bash
set -e

echo "Setting up Zigbee2MQTT environment..."

# Create directories
mkdir -p mosquitto/{config,data,log}
mkdir -p zigbee2mqtt/{config,data/ota}

# Ensure files exist (if they don't already)
touch mosquitto/config/mosquitto.conf
touch zigbee2mqtt/config/configuration.yaml
touch zigbee2mqtt/config/devices.yaml

cp .env.example .env

echo "✓ Directories and files prepared"

echo "
Next steps:
1. Start services:
   docker compose up -d
2. Access UI: http://localhost:8080"

