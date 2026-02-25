# Zigbee2MQTT Docker Compose Setup

Complete Docker Compose configuration for integrating a SMLIGHT SLZB-MRW10U Zigbee coordinator with Home Assistant via MQTT.

## 📖 Overview

This setup creates a containerized home automation stack consisting of:
- **Mosquitto**: MQTT message broker for device communication.
- **Zigbee2MQTT**: Bridge between Zigbee devices and MQTT.
- **SLZB-MRW10U**: SMLIGHT Zigbee coordinator (network-connected via EZSP).

### Architecture
```
Zigbee Devices
      ↓
SLZB-MRW10U (slzb-mrw10u.local:6053 via EZSP)
      ↓
Zigbee2MQTT (Docker Container)
      ↓
Mosquitto MQTT Broker (Docker Container)
      ↓
Home Assistant
```

## 🚀 Quick Start

### 1. Run Setup Script
```bash
chmod +x setup.sh
./setup.sh
```
This creates the necessary directory structure and configuration files.

### 2. Start Services
```bash
docker compose up -d
```

### 3. Verify Status
```bash
./health-check.sh
```
Access the Zigbee2MQTT Web UI at: `http://localhost:8080`

## ⚙️ Configuration

### Hardware Requirements
- **SMLIGHT SLZB-MRW10U**: Zigbee coordinator (EZSP protocol).
- **Network**: Device must be on the same network as the Docker host.
- **mDNS**: Required for resolving `slzb-mrw10u.local`.

### Default Credentials
| User | Password | Notes |
|------|----------|-------|
| `zigbee2mqtt` | `zigbee2mqtt` | Used by Z2M service |
| `homeassistant` | `zigbee2mqtt` | For Home Assistant integration |
| `admin` | `zigbee2mqtt` | For administrative access |

> **Security Tip**: Change default passwords using `mosquitto_passwd` within the container.

### Regional Settings
Default: **America/Toronto (EST/EDT)**, Zigbee **Channel 11**.
To customize:
1. Update `TZ` in `docker-compose.yml`.
2. Update `channel` in `zigbee2mqtt/config/configuration.yaml`.

## 🛠️ Management & Maintenance

### Common Commands
- **View Logs**: `docker compose logs -f`
- **Restart Services**: `docker compose restart`
- **Stop Services**: `docker compose down`
- **Check Status**: `docker compose ps`

### Backup & Restore
Use the provided script for managing backups:
```bash
./backup-restore.sh backup          # Create a backup
./backup-restore.sh list            # List available backups
./backup-restore.sh restore <file>  # Restore from a backup
```

### Updates
```bash
docker compose pull
docker compose up -d
```

## 🏡 Home Assistant Integration

### MQTT Configuration
Add the following to your Home Assistant `configuration.yaml`:
```yaml
mqtt:
  broker: <DOCKER_HOST_IP>
  port: 1883
  username: homeassistant
  password: zigbee2mqtt
  discovery: true
```
Zigbee2MQTT automatically publishes discovery info to `homeassistant/`.

## ❓ Troubleshooting

### Connection Issues
- **Coordinator unreachable**: Verify `ping slzb-mrw10u.local` works from the host.
- **Port 6053 blocked**: Ensure no firewall is blocking TCP traffic to the coordinator.
- **MQTT failed**: Check `mosquitto` logs and verify credentials in `.env` and `configuration.yaml`.

### Pairing Devices
1. Enable pairing in the Z2M Web UI ("Permit join").
2. Put your Zigbee device into pairing mode (usually by holding a reset button).
3. Keep the device close to the coordinator (or a router) during pairing.

## 📂 Project Structure
- `docker-compose.yml`: Main orchestration.
- `setup.sh`: Initial environment preparation.
- `health-check.sh`: Monitoring and diagnostics.
- `backup-restore.sh`: Data protection.
- `mosquitto/config/`: MQTT broker settings (ACL, passwd, conf).
- `zigbee2mqtt/config/`: Bridge settings and device database.

---
*For detailed documentation, refer to the comments within the configuration files.*

