#!/bin/bash

# Skrypt uruchamiający aplikację Flutter Pi na Raspberry Pi
# Użycie: ./start.sh [opcje]
#
# Opcje flutter-pi:
#   --release     - tryb release (wymagany jeśli zbudowano w trybie release)
#   -d"W,H"       - wymiary ekranu (opcjonalne)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Użyj lokalnego runnera lub systemowego flutter-pi
if [ -x "$SCRIPT_DIR/flutter-pi" ]; then
    "$SCRIPT_DIR/flutter-pi" --release -d"217,136" "$SCRIPT_DIR"
elif command -v flutter-pi &> /dev/null; then
    flutter-pi --release -d"217,136" "$SCRIPT_DIR" 
else
    echo "Błąd: flutter-pi nie znaleziony!"
    echo ""
    echo "Zainstaluj flutter-pi na Raspberry Pi:"
    echo "  sudo apt update"
    echo "  sudo apt install -y cmake libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev \\"
    echo "      libdrm-dev libgbm-dev libsystemd-dev libinput-dev libudev-dev libxkbcommon-dev"
    echo "  git clone --recursive https://github.com/ardera/flutter-pi.git"
    echo "  cd flutter-pi && mkdir build && cd build"
    echo "  cmake .. && make -j\$(nproc) && sudo make install"
    exit 1
fi
