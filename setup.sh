#!/bin/bash
set -e

echo "Setting up Zigbee2MQTT and matter environment..."

# Create directories
mkdir -p mosquitto/{config,data,log}
mkdir -p zigbee2mqtt/data/ota
mkdir -p matter-server/data

# Ensure files exist from examples if they don't already
[ ! -f mosquitto/config/mosquitto.conf ] && touch mosquitto/config/mosquitto.conf
[ ! -f .env ] && cp .env.example .env

echo "✓ Directories and files prepared"

echo "
Next steps:
1. Start services:
   docker compose up -d
2. Access UI: http://localhost:8080"

