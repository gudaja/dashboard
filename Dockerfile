# Environemnt to install flutter and build web
FROM ubuntu:22.04 AS build-env

# install all needed stuff
RUN apt-get update

# Ustaw tryb nieinteraktywny
ENV DEBIAN_FRONTEND=noninteractive

# Automatycznie zaakceptuj licencję EULA dla ttf-mscorefonts-installer
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections


RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    # Zależności flutter-pi
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    libdrm-dev \
    libgbm-dev \
    ttf-mscorefonts-installer \
    fontconfig \
    libsystemd-dev \
    libinput-dev \
    libudev-dev \
    libxkbcommon-dev \
    # Zależności dla gstreamer (opcjonalne, ale przydatne)
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-alsa \
    sudo 

# define variables
ARG FLUTTER_SDK=/usr/local/flutter
ARG FLUTTER_VERSION=3.27.1
ARG APP=/app/

#clone flutter
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_SDK
# change dir to current flutter folder and make a checkout to the specific version
RUN cd $FLUTTER_SDK && git fetch && git checkout $FLUTTER_VERSION

# setup the flutter path as an enviromental variable
ENV PATH="$FLUTTER_SDK/bin:$FLUTTER_SDK/bin/cache/dart-sdk/bin:${PATH}"

# Aktualizujemy czcionki systemowe
RUN fc-cache

# Start to run Flutter commands
# doctor to see if all was installes ok
# Akceptujemy licencje i wstępnie pobieramy komponenty Flutter
RUN flutter doctor --android-licenses || true && \
    flutter doctor -v

# Pobieramy i kompilujemy flutter-pi
RUN git clone --recursive https://github.com/ardera/flutter-pi.git /flutter-pi && \
    cd /flutter-pi && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    sudo make install && \
    cd /

RUN flutter pub global activate flutterpi_tool

# create folder to copy source code
RUN mkdir $APP
# create folder for dashboard library (used when building from parent project)
RUN mkdir -p /dashboard_lib
# # copy source code to folder
# COPY . $APP
# stup new folder as the working directory
WORKDIR $APP

RUN export PATH="$PATH":"$HOME/.pub-cache/bin"

# # Run build: 1 - clean, 2 - pub get, 3 - build web
# RUN flutter clean
# RUN flutter pub get
# RUN flutter build web

# # once heare the app will be compiled and ready to deploy

#flutter pub global activate flutterpi_tool

#flutterpi_tool build --arch=arm64 --cpu=pi4 --release

CMD ["/bin/bash"]