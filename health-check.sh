#!/bin/bash

# Health Check and Monitoring Script for Zigbee2MQTT Docker Stack
# Usage: ./health-check.sh [--watch] [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
WATCH_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done


print_status() {
    local status=$1
    local message=$2

    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}


check_containers() {
    echo -e "${BLUE}=== Container Status ===${NC}"

    if ! docker compose ps &> /dev/null; then
        print_status "error" "Docker Compose not available or project not started"
        return 1
    fi

    local mosquitto_status=$(docker compose ps mosquitto --format '{{.State}}' 2>/dev/null || echo "unknown")
    local z2m_status=$(docker compose ps zigbee2mqtt --format '{{.State}}' 2>/dev/null || echo "unknown")
    local matter_status=$(docker compose ps matter-server --format '{{.State}}' 2>/dev/null || echo "unknown")

    if [ "$mosquitto_status" = "running" ]; then
        print_status "ok" "Mosquitto is running"
    else
        print_status "error" "Mosquitto is not running (state: $mosquitto_status)"
    fi

    if [ "$z2m_status" = "running" ]; then
        print_status "ok" "Zigbee2MQTT is running"
    else
        print_status "error" "Zigbee2MQTT is not running (state: $z2m_status)"
    fi

    if [ "$matter_status" = "running" ]; then
        print_status "ok" "Matter Server is running"
    else
        print_status "error" "Matter Server is not running (state: $matter_status)"
    fi
}

check_service_health() {
    echo -e "\n${BLUE}=== Service Health ===${NC}"

    # Load .env if it exists
    if [ -f .env ]; then
        # Robustly load .env variables
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ ! "$line" =~ ^# && "$line" =~ = ]]; then
                export "${line%%=*}"="${line#*=}"
            fi
        done < .env
    fi

    local ui_port=${Z2M_UI_PORT:-8080}

    # Check Mosquitto health
    if docker exec mosquitto mosquitto_sub -h localhost -t '$SYS/broker/uptime' -W 1 &> /dev/null; then
        print_status "ok" "Mosquitto is responding"
    else
        print_status "error" "Mosquitto is not responding"
    fi

    # Check Zigbee2MQTT web UI
    if curl -s "http://localhost:${ui_port}" > /dev/null 2>&1; then
        print_status "ok" "Zigbee2MQTT UI is accessible (port ${ui_port})"
    else
        print_status "error" "Zigbee2MQTT UI is not accessible (port ${ui_port})"
    fi

    # Check Matter Server
    if curl -s "http://localhost:5580" > /dev/null 2>&1; then
        print_status "ok" "Matter Server is responding (port 5580)"
    else
        print_status "error" "Matter Server is not responding (port 5580)"
    fi
}

check_connectivity() {
    echo -e "\n${BLUE}=== Network Connectivity ===${NC}"

    # Check internal network
    if docker exec zigbee2mqtt ping -c 1 mosquitto &> /dev/null; then
        print_status "ok" "Zigbee2MQTT -> Mosquitto connection"
    else
        print_status "error" "Zigbee2MQTT -> Mosquitto connection failed"
    fi

    # Check coordinator connectivity
    local coordinator_host="slzb-mrw10u.local"
    if [[ -n "$Z2M_SERIAL_PORT" ]]; then
        # Extract host from tcp://host:port or similar
        coordinator_host=$(echo "$Z2M_SERIAL_PORT" | sed -E 's|.*//([^:/]+).*|\1|')
    fi

    if docker exec zigbee2mqtt ping -c 1 "$coordinator_host" &> /dev/null; then
        print_status "ok" "Zigbee Coordinator ($coordinator_host) is reachable"
    else
        print_status "warn" "Zigbee Coordinator ($coordinator_host) is not reachable"
    fi
}

check_resources() {
    echo -e "\n${BLUE}=== Resource Usage ===${NC}"

    if command -v docker &> /dev/null; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
    fi
}

check_logs() {
    echo -e "\n${BLUE}=== Recent Errors in Logs ===${NC}"

    local mosquitto_errors=$(docker logs --tail 50 mosquitto 2>/dev/null | grep -iE "error|failed" | head -3)
    if [ -n "$mosquitto_errors" ]; then
        print_status "warn" "Mosquitto recent errors:"
        echo "$mosquitto_errors" | while read -r line; do
            echo "  $line"
        done
    else
        print_status "ok" "No recent errors in Mosquitto logs"
    fi

    local z2m_errors=$(docker logs --tail 50 zigbee2mqtt 2>/dev/null | grep -iE "error|failed" | head -3)
    if [ -n "$z2m_errors" ]; then
        print_status "warn" "Zigbee2MQTT recent errors:"
        echo "$z2m_errors" | while read -r line; do
            echo "  $line"
        done
    else
        print_status "ok" "No recent errors in Zigbee2MQTT logs"
    fi

    local matter_errors=$(docker logs --tail 50 matter-server 2>/dev/null | grep -iE "error|failed" | head -3)
    if [ -n "$matter_errors" ]; then
        print_status "warn" "Matter Server recent errors:"
        echo "$matter_errors" | while read -r line; do
            echo "  $line"
        done
    else
        print_status "ok" "No recent errors in Matter Server logs"
    fi
}

run_all_checks() {
    check_containers || return 1
    check_service_health
    check_connectivity
    check_resources
    check_logs

    echo -e "\n${BLUE}=== Health Check Complete ===${NC}"
}

watch_health() {
    while true; do
        clear
        echo "Zigbee2MQTT Health Monitor (Press Ctrl+C to exit)"
        echo "Last update: $(date)"
        echo ""
        run_all_checks
        echo ""
        echo "Refreshing in 10 seconds..."
        sleep 10
    done
}

# Main execution
if [ "$WATCH_MODE" = true ]; then
    watch_health
else
    run_all_checks
fi

