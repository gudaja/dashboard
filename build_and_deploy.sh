#!/bin/bash

# Skrypt łączący budowanie i wdrażanie aplikacji Flutter Pi
set -e

# Kolory
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Sprawdź parametry
if [ $# -lt 1 ]; then
    echo -e "${RED}Użycie: $0 <adres_raspberry_pi> [architektura] [cpu] [tryb] [hasło]${NC}"
    echo ""
    echo -e "${YELLOW}Przykłady:${NC}"
    echo -e "  $0 raspberrypi.local"
    echo -e "  $0 192.168.1.100 arm64 pi4 release"
    echo -e "  $0 raspberrypi.local arm64 pi3 release raspberry"
    echo -e "  $0 raspberrypi.local arm64 generic release mojehaslo"
    echo ""
    echo -e "${YELLOW}Parametry:${NC}"
    echo -e "  adres_raspberry_pi - adres IP lub hostname Raspberry Pi"
    echo -e "  architektura       - arm64 (domyślnie) lub arm"
    echo -e "  cpu                - generic (domyślnie), pi4, pi3"
    echo -e "  tryb               - release (domyślnie) lub debug"
    echo -e "  hasło              - raspberry (domyślnie)"
    exit 1
fi

PI_HOST="$1"
ARCH="${2:-arm64}"
CPU="${3:-generic}"
BUILD_MODE="${4:-release}"
PI_PASSWORD="${5:-raspberry}"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Flutter Pi - Build & Deploy${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Target: ${GREEN}${PI_HOST}${NC}"
echo -e "Arch: ${GREEN}${ARCH}${NC}, CPU: ${GREEN}${CPU}${NC}, Mode: ${GREEN}${BUILD_MODE}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Krok 1: Budowanie
echo -e "${BLUE}[1/2] Budowanie aplikacji...${NC}"
./build_flutter_pi.sh "$ARCH" "$CPU" "$BUILD_MODE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Budowanie nie powiodło się!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Budowanie zakończone!${NC}"
echo ""

# Krok 2: Wdrażanie
echo -e "${BLUE}[2/2] Wdrażanie na Raspberry Pi...${NC}"
./deploy_to_pi.sh "$PI_HOST" "/home/pi/dashboard" "pi" "$PI_PASSWORD"

if [ $? -ne 0 ]; then
    echo -e "${RED}Wdrażanie nie powiodło się!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Gotowe!${NC}"
echo -e "${GREEN}======================================${NC}"

