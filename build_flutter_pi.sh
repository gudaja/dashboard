#!/bin/bash

# Skrypt do budowania aplikacji Flutter dla Flutter Pi w Dockerze
#
# WAŻNE: Ten skrypt NIE montuje katalogów hosta do kontenera (nie używa -v)
# Zamiast tego:
# 1. Tworzy kontener
# 2. Kopiuje pliki źródłowe DO kontenera
# 3. Buduje aplikację wewnątrz kontenera
# 4. Kopiuje wyniki Z kontenera do katalogu build/
#
# Dzięki temu Docker nie zmienia uprawnień plików na hoście!
#
set -e

# Kolory dla czytelności
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Nazwa obrazu Docker
IMAGE_NAME="dashboard-flutter-pi-builder"
CONTAINER_NAME="dashboard-flutter-pi-build"

# Katalog z aplikacją Flutter (example w przypadku biblioteki)
APP_DIR="example"

# Architektura docelowa (domyślnie arm64, można zmienić na arm)
ARCH="${1:-arm64}"
# CPU docelowy (domyślnie generic - działa na wszystkich Pi, w tym Pi 5)
# Dostępne: generic, pi4, pi3
CPU="${2:-generic}"
# Tryb budowania (domyślnie release)
BUILD_MODE="${3:-release}"

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Flutter Pi Builder${NC}"
echo -e "${BLUE}====================================${NC}"
echo -e "Architektura: ${GREEN}${ARCH}${NC}"
echo -e "CPU: ${GREEN}${CPU}${NC}"
echo -e "Tryb: ${GREEN}${BUILD_MODE}${NC}"
echo -e "${BLUE}====================================${NC}"

# Sprawdź czy obraz Docker istnieje
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo -e "${BLUE}Budowanie obrazu Docker...${NC}"
    docker build -t $IMAGE_NAME .
else
    echo -e "${GREEN}Obraz Docker już istnieje${NC}"
    read -p "Czy chcesz przebudować obraz? (t/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Tt]$ ]]; then
        echo -e "${BLUE}Przebudowywanie obrazu Docker...${NC}"
        docker build -t $IMAGE_NAME .
    fi
fi

# Usuń stary kontener jeśli istnieje
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo -e "${BLUE}Usuwanie starego kontenera...${NC}"
    docker rm -f $CONTAINER_NAME 2>/dev/null || true
fi

echo -e "${BLUE}Tworzenie kontenera...${NC}"
# Utwórz kontener bez uruchamiania
docker create --name $CONTAINER_NAME \
    -w /app \
    $IMAGE_NAME \
    /bin/bash -c "
        set -e
        
        echo 'Aktualizowanie ścieżki do biblioteki dashboard...'
        # Zmień path: .. na path: /dashboard_lib w pubspec.yaml
        sed -i 's|path: \.\.|path: /dashboard_lib|g' pubspec.yaml
        
        echo 'Czyszczenie poprzednich buildów...'
        flutter clean
        
        echo 'Pobieranie zależności...'
        flutter pub get
        
        echo 'Budowanie aplikacji dla Flutter Pi...'
        export PATH=\"\$PATH:\$HOME/.pub-cache/bin\"
        
        if [ '$BUILD_MODE' == 'release' ]; then
            flutterpi_tool build --arch=$ARCH --cpu=$CPU --release
        else
            flutterpi_tool build --arch=$ARCH --cpu=$CPU
        fi
        
        echo 'Budowanie zakończone!'
        echo 'Pliki znajdują się w: build/flutter_assets/'
    " > /dev/null

echo -e "${BLUE}Kopiowanie plików źródłowych do kontenera...${NC}"
# Kopiuj bibliotekę dashboard (główny projekt) do /dashboard_lib/
docker cp ./lib $CONTAINER_NAME:/dashboard_lib/
docker cp ./pubspec.yaml $CONTAINER_NAME:/dashboard_lib/

# Kopiuj aplikację example do kontenera
docker cp ./${APP_DIR}/lib $CONTAINER_NAME:/app/
docker cp ./${APP_DIR}/assets $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/pubspec.yaml $CONTAINER_NAME:/app/
docker cp ./${APP_DIR}/pubspec.lock $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/analysis_options.yaml $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/android $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/ios $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/linux $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/macos $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/web $CONTAINER_NAME:/app/ 2>/dev/null || true
docker cp ./${APP_DIR}/windows $CONTAINER_NAME:/app/ 2>/dev/null || true

echo -e "${BLUE}Uruchamianie budowania w kontenerze...${NC}"
# Uruchom kontener i zaczekaj na zakończenie
docker start -a $CONTAINER_NAME

# Sprawdź status
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${BLUE}Kopiowanie wyników budowania z kontenera...${NC}"
    # Utwórz katalog build jeśli nie istnieje
    mkdir -p build
    
    # Skopiuj wyniki z kontenera do głównego katalogu build/
    docker cp $CONTAINER_NAME:/app/build/flutter_assets ./build/
    
    echo -e "${GREEN}Pliki skopiowane do build/flutter_assets/${NC}"
    
    # Skopiuj również do example/build/ dla kompatybilności
    mkdir -p ${APP_DIR}/build
    cp -r ./build/flutter_assets ${APP_DIR}/build/
    echo -e "${GREEN}Pliki skopiowane również do ${APP_DIR}/build/flutter_assets/${NC}"
fi

# Sprawdź czy budowanie się powiodło
if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}Budowanie zakończone sukcesem!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "Pliki wyjściowe znajdują się w: ${BLUE}build/flutter_assets/${NC}"
    echo ""
    echo -e "${BLUE}Aby wgrać aplikację na Raspberry Pi:${NC}"
    echo -e "1. Skopiuj zawartość ${BLUE}build/flutter_assets/${NC} na Raspberry Pi"
    echo -e "2. Uruchom: ${GREEN}flutter-pi /ścieżka/do/flutter_assets${NC}"
else
    echo -e "${RED}====================================${NC}"
    echo -e "${RED}Budowanie nie powiodło się!${NC}"
    echo -e "${RED}====================================${NC}"
    exit 1
fi

# Usuń kontener
echo -e "${BLUE}Czyszczenie...${NC}"
docker rm $CONTAINER_NAME

echo -e "${GREEN}Gotowe!${NC}"

