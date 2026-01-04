#!/bin/bash

# Skrypt do wgrywania aplikacji Flutter Pi na Raspberry Pi
set -e

# Kolory
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Sprawdź parametry
if [ $# -lt 1 ]; then
    echo -e "${RED}Użycie: $0 <adres_raspberry_pi> [ścieżka_docelowa] [użytkownik] [hasło]${NC}"
    echo -e "Przykład: $0 raspberrypi.local"
    echo -e "Przykład: $0 raspberrypi.local /home/pi/dashboard pi raspberry"
    echo -e "Przykład: $0 192.168.1.100 /home/pi/dashboard pi mojehaslo"
    echo ""
    echo -e "${YELLOW}Uwaga: Domyślne hasło to 'raspberry'${NC}"
    exit 1
fi

PI_HOST="$1"
PI_PATH="${2:-/home/pi/dashboard}"
PI_USER="${3:-pi}"
PI_PASSWORD="${4:-raspberry}"

# Sprawdź czy sshpass jest zainstalowane
USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    USE_SSHPASS=true
    echo -e "${GREEN}Używam automatycznego logowania z hasłem${NC}"
else
    echo -e "${YELLOW}Uwaga: sshpass nie jest zainstalowane${NC}"
    echo -e "${YELLOW}Jeśli nie masz skonfigurowanych kluczy SSH, zainstaluj sshpass:${NC}"
    echo -e "${YELLOW}  sudo apt-get install sshpass${NC}"
    echo ""
fi

# Funkcje pomocnicze dla SSH/SCP/RSYNC z/bez sshpass
run_ssh() {
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "${PI_PASSWORD}" ssh "$@"
    else
        ssh "$@"
    fi
}

run_scp() {
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "${PI_PASSWORD}" scp "$@"
    else
        scp "$@"
    fi
}

run_rsync() {
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "${PI_PASSWORD}" rsync "$@"
    else
        rsync "$@"
    fi
}

# Sprawdź czy pliki zostały zbudowane (szukaj w głównym build/ lub example/build/)
BUILD_DIR=""
if [ -d "build/flutter_assets" ]; then
    BUILD_DIR="build/flutter_assets"
elif [ -d "example/build/flutter_assets" ]; then
    BUILD_DIR="example/build/flutter_assets"
else
    echo -e "${RED}Błąd: Nie znaleziono katalogu build/flutter_assets${NC}"
    echo -e "${YELLOW}Najpierw uruchom: ./build_flutter_pi.sh${NC}"
    exit 1
fi
echo -e "${GREEN}Znaleziono pliki w: ${BUILD_DIR}${NC}"

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Deploy Flutter Pi na Raspberry Pi${NC}"
echo -e "${BLUE}====================================${NC}"
echo -e "Host: ${GREEN}${PI_USER}@${PI_HOST}${NC}"
echo -e "Ścieżka: ${GREEN}${PI_PATH}${NC}"
echo -e "${BLUE}====================================${NC}"

# Sprawdź połączenie z Raspberry Pi
echo -e "${BLUE}Sprawdzanie połączenia...${NC}"
if ! run_ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "echo 'OK'" > /dev/null 2>&1; then
    echo -e "${RED}Błąd: Nie można połączyć się z ${PI_USER}@${PI_HOST}${NC}"
    echo -e "${YELLOW}Sprawdź:${NC}"
    echo -e "1. Czy Raspberry Pi jest włączone i dostępne w sieci"
    echo -e "2. Czy hasło jest poprawne (domyślnie: raspberry)"
    if [ "$USE_SSHPASS" = false ]; then
        echo -e "3. Zainstaluj sshpass lub skonfiguruj klucze SSH (ssh-copy-id ${PI_USER}@${PI_HOST})"
    fi
    exit 1
fi

echo -e "${GREEN}Połączenie OK${NC}"

# Utwórz katalog na Raspberry Pi jeśli nie istnieje
echo -e "${BLUE}Tworzenie katalogu docelowego...${NC}"
run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "mkdir -p ${PI_PATH}"

# Kopiuj pliki
echo -e "${BLUE}Kopiowanie plików aplikacji z ${BUILD_DIR}...${NC}"
if [ "$USE_SSHPASS" = true ]; then
    # rsync z sshpass - używamy zmiennej środowiskowej SSHPASS z opcją -e
    export SSHPASS="${PI_PASSWORD}"
    sshpass -e rsync -avz --progress -e "ssh -o StrictHostKeyChecking=no" "${BUILD_DIR}/" "${PI_USER}@${PI_HOST}:${PI_PATH}/"
    unset SSHPASS
else
    rsync -avz --progress -e "ssh -o StrictHostKeyChecking=no" "${BUILD_DIR}/" "${PI_USER}@${PI_HOST}:${PI_PATH}/"
fi

# Kopiuj instrukcję
if [ -f "RUN_ON_PI.txt" ]; then
    echo -e "${BLUE}Kopiowanie instrukcji...${NC}"
    run_scp -o StrictHostKeyChecking=no RUN_ON_PI.txt "${PI_USER}@${PI_HOST}:${PI_PATH}/../RUN_ON_PI.txt" 2>/dev/null || true
fi

# Kopiuj skrypt uruchamiający
if [ -f "start.sh" ]; then
    echo -e "${BLUE}Kopiowanie skryptu uruchamiającego...${NC}"
    run_scp -o StrictHostKeyChecking=no start.sh "${PI_USER}@${PI_HOST}:${PI_PATH}/start.sh"
    # Nadaj uprawnienia wykonywania
    run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "chmod +x ${PI_PATH}/start.sh"
    echo -e "${GREEN}Skrypt start.sh został skopiowany i ma uprawnienia wykonywania${NC}"
fi

# Konfiguracja systemd service
if [ -f "dashboard.service" ]; then
    echo -e "${BLUE}Instalowanie systemd service...${NC}"
    
    # Kopiuj plik service do katalogu tymczasowego
    run_scp -o StrictHostKeyChecking=no dashboard.service "${PI_USER}@${PI_HOST}:/tmp/dashboard.service"
    
    # Zaktualizuj ścieżki w pliku service jeśli są inne niż domyślne
    if [ "${PI_PATH}" != "/home/pi/dashboard" ]; then
        echo -e "${YELLOW}Dostosowywanie ścieżek w pliku service...${NC}"
        run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sed -i 's|/home/pi/dashboard|${PI_PATH}|g' /tmp/dashboard.service"
    fi
    
    # Zaktualizuj użytkownika w pliku service jeśli jest inny niż domyślny
    if [ "${PI_USER}" != "pi" ]; then
        echo -e "${YELLOW}Dostosowywanie użytkownika w pliku service...${NC}"
        run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sed -i 's|User=pi|User=${PI_USER}|g' /tmp/dashboard.service"
        run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sed -i 's|Group=pi|Group=${PI_USER}|g' /tmp/dashboard.service"
    fi
    
    # Przenieś plik service do /etc/systemd/system (wymaga sudo)
    run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo mv /tmp/dashboard.service /etc/systemd/system/dashboard.service"
    
    # Przeładuj konfigurację systemd
    run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo systemctl daemon-reload"
    
    # Włącz autostart
    run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo systemctl enable dashboard.service"
    
    echo -e "${GREEN}Service systemd został zainstalowany i włączony do autostartu${NC}"
    
    # Sprawdź czy serwis już działa i zrestartuj go po aktualizacji
    if run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo systemctl is-active --quiet dashboard" 2>/dev/null; then
        echo -e "${YELLOW}Serwis jest uruchomiony - restartuję po aktualizacji...${NC}"
        run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo systemctl restart dashboard"
        echo -e "${GREEN}Serwis został zrestartowany z nową wersją${NC}"
    fi
    echo ""
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Wgrywanie zakończone sukcesem!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    
    # Jeśli zainstalowano service systemd
    if [ -f "dashboard.service" ]; then
        echo -e "${BLUE}Zarządzanie serwisem systemd:${NC}"
        echo -e "${GREEN}• Uruchom serwis:${NC}     sudo systemctl start dashboard"
        echo -e "${GREEN}• Zatrzymaj serwis:${NC}   sudo systemctl stop dashboard"
        echo -e "${GREEN}• Restart serwisu:${NC}    sudo systemctl restart dashboard"
        echo -e "${GREEN}• Status serwisu:${NC}     sudo systemctl status dashboard"
        echo -e "${GREEN}• Logi serwisu:${NC}       journalctl -u dashboard -f"
        echo -e "${GREEN}• Wyłącz autostart:${NC}  sudo systemctl disable dashboard"
        echo ""
        echo -e "${YELLOW}Service został włączony do autostartu przy restarcie systemu${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}Inne opcje uruchomienia aplikacji:${NC}"
    echo -e "${GREEN}Opcja 1 (skrypt uruchamiający):${NC}"
    echo -e "  ${GREEN}ssh ${PI_USER}@${PI_HOST}${NC}"
    echo -e "  ${GREEN}cd ${PI_PATH}${NC}"
    echo -e "  ${GREEN}./start.sh${NC}"
    echo ""
    echo -e "${GREEN}Opcja 2 (bezpośrednio flutter-pi):${NC}"
    echo -e "  ${GREEN}ssh ${PI_USER}@${PI_HOST}${NC}"
    echo -e "  ${GREEN}flutter-pi --release -d\"217,136\" ${PI_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}Uwaga: Aplikacja musi być uruchomiona z konsoli (nie X11)${NC}"
    echo -e "${YELLOW}Uwaga: Użyj --release jeśli zbudowano w trybie release (domyślnie)${NC}"
    echo ""
    
    # Zapytaj czy uruchomić service teraz
    if [ -f "dashboard.service" ]; then
        read -p "Czy chcesz uruchomić serwis systemd teraz? (t/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Tt]$ ]]; then
            echo -e "${BLUE}Uruchamianie serwisu...${NC}"
            run_ssh -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "sudo systemctl start dashboard"
            echo -e "${GREEN}Serwis został uruchomiony!${NC}"
            echo -e "${BLUE}Sprawdź status: ${GREEN}ssh ${PI_USER}@${PI_HOST} 'sudo systemctl status dashboard'${NC}"
        fi
    else
        read -p "Czy chcesz uruchomić aplikację teraz? (t/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Tt]$ ]]; then
            echo -e "${BLUE}Uruchamianie aplikacji w trybie release...${NC}"
            run_ssh -t -o StrictHostKeyChecking=no "${PI_USER}@${PI_HOST}" "cd ${PI_PATH} && ./start.sh"
        fi
    fi
else
    echo -e "${RED}====================================${NC}"
    echo -e "${RED}Wystąpił błąd podczas kopiowania!${NC}"
    echo -e "${RED}====================================${NC}"
    exit 1
fi

