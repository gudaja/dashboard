# Flutter Pi - Instrukcja Budowania

## O projekcie

Ten projekt to **biblioteka Flutter Dashboard**. Skrypty budowania kompilują aplikację przykładową z katalogu `example/`, która korzysta z tej biblioteki.

## Wymagania

- Docker zainstalowany na systemie
- Minimum 4GB wolnego miejsca na dysku

## Jak uruchomić budowanie

### Podstawowe użycie (domyślne ustawienia)

```bash
./build_flutter_pi.sh
```

Domyślnie buduje dla:
- Architektura: **arm64**
- CPU: **generic** (działa na wszystkich Raspberry Pi, w tym Pi 5)
- Tryb: **release**

### Zaawansowane użycie

```bash
./build_flutter_pi.sh [ARCHITEKTURA] [CPU] [TRYB]
```

#### Parametry:

**ARCHITEKTURA:**
- `arm64` - dla Raspberry Pi 3/4 (64-bit)
- `arm` - dla starszych modeli (32-bit)

**CPU:**
- `generic` - Uniwersalny (domyślnie, działa na wszystkich Raspberry Pi, w tym Pi 5)
- `pi4` - Raspberry Pi 4 (zoptymalizowany dla Cortex-A72)
- `pi3` - Raspberry Pi 3 (zoptymalizowany dla Cortex-A53)

**UWAGA:** Raspberry Pi 5 nie ma jeszcze dedykowanej optymalizacji w flutterpi_tool. Użyj `generic` (domyślnie), które działa na Pi 5 bez problemu.

**TRYB:**
- `release` - tryb produkcyjny (zoptymalizowany)
- `debug` - tryb debugowania

### Przykłady:

```bash
# Uniwersalny build (działa na Pi 3/4/5) - DOMYŚLNIE
./build_flutter_pi.sh
# lub jawnie:
./build_flutter_pi.sh arm64 generic release

# Zoptymalizowany dla Raspberry Pi 4
./build_flutter_pi.sh arm64 pi4 release

# Zoptymalizowany dla Raspberry Pi 3
./build_flutter_pi.sh arm64 pi3 release

# Tryb debug (uniwersalny)
./build_flutter_pi.sh arm64 generic debug
```

**Dla Raspberry Pi 5:** Użyj `generic` (domyślnie). Pi 5 używa Cortex-A76, którego dedykowana optymalizacja nie jest jeszcze dostępna w flutterpi_tool.

## Co robi skrypt?

1. Sprawdza czy obraz Docker istnieje, jeśli nie - buduje go
2. Tworzy izolowany kontener Docker
3. **Kopiuje pliki źródłowe do kontenera** (lib/, assets/, pubspec.yaml, itp.)
4. Uruchamia budowanie wewnątrz kontenera:
   - Czyści poprzednie buildy (`flutter clean`)
   - Pobiera zależności Flutter (`flutter pub get`)
   - Buduje aplikację za pomocą `flutterpi_tool`
5. **Kopiuje wyniki z kontenera do `build/flutter_assets/`** na hoście
6. Usuwa kontener

**Ważne:** Skrypt NIE montuje katalogów hosta do kontenera (nie używa `-v`). Dzięki temu Docker działający jako root wewnątrz kontenera nie zmienia uprawnień Twoich plików. Zobacz [DOCKER_BUILD_CHANGES.md](DOCKER_BUILD_CHANGES.md) dla szczegółów technicznych.

## Pliki wyjściowe

Po zakończeniu budowania, pliki aplikacji znajdą się w:
```
build/flutter_assets/
```

**UWAGA:** Dla Flutter Pi wszystkie pliki znajdują się w `build/flutter_assets/`, **NIE** w `build/native_assets/`. To jest prawidłowe zachowanie. Folder `native_assets/linux` będzie pusty - jest to normalne dla Flutter Pi.

Struktura plików:
```
build/flutter_assets/
├── app.so                    # Twoja aplikacja (ARM64)
├── libflutter_engine.so      # Silnik Flutter (ARM64)
├── flutter-pi                # Runner
├── assets/                   # Zasoby aplikacji
├── fonts/                    # Czcionki
└── ...                       # Inne pliki
```

## Wgrywanie aplikacji na Raspberry Pi

### Metoda automatyczna (zalecana):

Użyj skryptu `deploy_to_pi.sh`, który automatycznie wgrywa aplikację:

```bash
# Podstawowe użycie (domyślne hasło: raspberry)
./deploy_to_pi.sh raspberrypi.local

# Z niestandardowym hasłem
./deploy_to_pi.sh raspberrypi.local /home/pi/dashboard pi mojehaslo
```

**Wymagania:**
- Zainstaluj `sshpass` dla automatycznego logowania (opcjonalnie, jeśli nie używasz kluczy SSH):
  ```bash
  sudo apt-get install sshpass
  ```

**Uwaga:** Domyślne hasło to `raspberry` - skrypt używa go automatycznie bez pytania!

### Metoda ręczna:

Jeśli wolisz skopiować pliki ręcznie:

```bash
# Z poziomu komputera
scp -r build/flutter_assets/ pi@raspberrypi.local:/home/pi/dashboard/
```

### 2. Zainstaluj flutter-pi na Raspberry Pi:

```bash
# Na Raspberry Pi
sudo apt update
sudo apt install -y cmake libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev \
    libdrm-dev libgbm-dev libsystemd-dev libinput-dev libudev-dev libxkbcommon-dev

git clone --recursive https://github.com/ardera/flutter-pi.git
cd flutter-pi
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### 3. Uruchom aplikację:

```bash
# Na Raspberry Pi (z poziomu konsoli, nie X11)

# Tryb RELEASE (zoptymalizowany, domyślnie budowany):
flutter-pi --release /home/pi/dashboard/flutter_assets

# Lub krócej (jeśli zbudowano release):
./flutter_assets/flutter-pi --release /home/pi/dashboard/flutter_assets

# Tryb DEBUG (tylko jeśli zbudowano z --debug):
flutter-pi /home/pi/dashboard/flutter_assets
```

**WAŻNE:** Jeśli zbudowałeś aplikację w trybie `release` (domyślnie), MUSISZ użyć flagi `--release` przy uruchamianiu!

## Rozwiązywanie problemów

### Błąd: "kernel_blob.bin does not exist, but is necessary for debug mode"

**Problem:** Flutter Pi próbuje uruchomić aplikację w trybie debug, ale zbudowałeś ją w trybie release.

**Rozwiązanie:** Dodaj flagę `--release` przy uruchamianiu:
```bash
flutter-pi --release /home/pi/dashboard/flutter_assets
```

Alternatywnie, zbuduj aplikację w trybie debug:
```bash
./build_flutter_pi.sh arm64 pi4 debug
```

### Raspberry Pi 5

Raspberry Pi 5 nie ma jeszcze dedykowanej optymalizacji w flutterpi_tool. Użyj budowania uniwersalnego (domyślnie):
```bash
./build_flutter_pi.sh arm64 generic release
# lub po prostu:
./build_flutter_pi.sh
```

Następnie uruchom z flagą `--release`:
```bash
flutter-pi --release /home/pi/dashboard/flutter_assets
```

Build `generic` działa doskonale na Pi 5!

### Błąd: "Cannot connect to the Docker daemon"
Upewnij się, że Docker jest uruchomiony:
```bash
sudo systemctl start docker
```

### Błąd podczas budowania obrazu Docker
Spróbuj wyczyścić cache Dockera:
```bash
docker system prune -a
```

### Aplikacja nie uruchamia się na Raspberry Pi
- Sprawdź czy wybrałeś odpowiednią architekturę i CPU (Pi 5 wymaga `pi5`)
- Upewnij się, że flutter-pi jest poprawnie zainstalowany
- Sprawdź logi: dodaj `-d` do komendy flutter-pi dla trybu debug
- **Zawsze używaj `--release` jeśli zbudowano w trybie release**

## Dodatkowe informacje

- Budowanie może zająć 10-30 minut za pierwszym razem (budowanie obrazu Docker)
- Kolejne budowania będą znacznie szybsze (5-10 minut)
- Obraz Docker ma około 3-4GB

## Przydatne linki

- [Flutter Pi GitHub](https://github.com/ardera/flutter-pi)
- [Flutter Pi Tool](https://pub.dev/packages/flutterpi_tool)
- [Flutter Documentation](https://flutter.dev/docs)

