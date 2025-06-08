#!/bin/bash

# Ustawienia dla rozwiązania problemów XCB na Linuxie
export QT_X11_NO_MITSHM=1
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1

# Dodatkowe ustawienia dla Flutter
export DISPLAY=${DISPLAY:-:0}

echo "Uruchamianie Flutter Dashboard Demo na Linuxie..."
echo "Zmienne środowiskowe:"
echo "QT_X11_NO_MITSHM=$QT_X11_NO_MITSHM"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE" 
echo "GDK_BACKEND=$GDK_BACKEND"
echo "LIBGL_ALWAYS_SOFTWARE=$LIBGL_ALWAYS_SOFTWARE"
echo "DISPLAY=$DISPLAY"
echo ""

# Uruchom aplikację
flutter run -d linux --verbose 