> **Fork.** Ten CHANGELOG opisuje `github.com/gudaja/dashboard`, forka
> `Mehmetyaz/dashboard`. Wpisy do `0.0.3+1` włącznie pochodzą z upstreamu.
> Wpisy `0.0.4`–`0.0.5` zostały **odtworzone z historii commitów** przy okazji
> wydania `0.0.6` — plik nie był prowadzony na bieżąco, a `pubspec.yaml`
> deklarował `0.0.5` bez ani jednego wpisu za `0.0.3+1`.

## 0.0.6

Cykl życia kontrolera i cache delegata — zmiany wymuszone przez konsumenta,
który montuje drugą siatkę nad tym samym magazynem (edytor układu obok kokpitu).

* **`DashboardItemStorageDelegate.invalidateCache([int? slotCount])`** — publiczne
  porzucenie cache'u delegata. Dopóki dany `slotCount` ma wpis, `getAllItems`
  **nie jest wołane ponownie**, więc układ zapisany przez inną siatkę pozostawał
  niewidoczny aż do restartu procesu; przemontowanie widgetu nie pomagało, bo cache
  żyje na delegacie, nie na widgecie. `slotCount` jest normalizowany dokładnie tak
  jak w `getAllItems`, więc wywołanie nie może stać się cichym no-opem przy
  `layoutsBySlotCount == false`.
* **Odpięcie siatki od kontrolera** — `_attach` nie miał odpowiednika, więc
  odmontowana siatka zostawała podpięta na zawsze. Odpięcie czyści pole **tylko
  wtedy, gdy odchodząca siatka jest tą podpiętą**: Flutter montuje nowy widget
  ZANIM odmontuje stary, więc bezwarunkowe zerowanie odpinałoby siatkę żywą
  zamiast martwej.
* **`isEditing` powiadamia słuchaczy** `DashboardItemController`. Dotąd wszystkie
  `notifyListeners` siedziały na prywatnym kontrolerze układu, przez co
  `ListenableBuilder` nasłuchujący kontrolera elementów — ten, który ma wyłączać
  przesuwanie stron w trybie edycji — **nigdy nie dostawał powiadomienia**.
* **Setter `isEditing` nie rzuca**, gdy nic nie jest zamontowane. Po odpięciu jest
  to normalny stan cyklu życia, nie błąd; getter i tak degraduje się do `false`.
  `add`/`delete` nadal rzucają — tam ciche pominięcie gubi DANE.
* **Usunięte 27 wywołań `print()`** z produkcyjnego `lib/` (21 z nich logowało każdy
  gest) — realny koszt na Raspberry Pi. Jedno ostrzeżenie zostało jako `debugPrint`,
  bo odpala się wyłącznie na połkniętym wyjątku.
* **`test/resize_tests.dart` → `test/resize_test.dart`** — nazwa nie pasowała do globu
  `**_test.dart`, więc 256 linii testów **nigdy się nie uruchamiało**. Uwaga: po
  włączeniu okazały się atrapami — wykonują gesty i nie sprawdzają żadnego skutku.
* **`flutter_lints` rozszerzone do `>=5.0.0 <7.0.0`** — `^6.0.0` wymaga Dart `^3.8.0`,
  przez co własna suita testów paczki **nie dawała się uruchomić** na Flutterze 3.27.4.
  Zależność wyłącznie deweloperska.
* Metadane `homepage`/`repository` wskazują wreszcie ten fork, a nie upstream.

## 0.0.5

Odtworzone z historii. Wydajność i obsługa układów wielokolumnowych:
wirtualne kolumny-separatory, `MobileDashboardWrapper` z karuzelą sekcji,
`GridDimensions` i `onGridDimensionsChanged`, wsparcie dla Raspberry Pi
i widoku tabletu, poprawki przewijania w trybie edycji, migotania przy edycji,
skalowania i przeciągania nad kolumną-blokadą.

## 0.0.4

Odtworzone z historii. Optymalizacje przerysowań i pozycjonowania:
naprawa wyścigu przy aktualizacji pozycji, poprawki przy zmianie rozmiaru okna,
usuwaniu widgetu i cieniach.

## 0.0.3+1

* Fixed issue : ``At initial start or refresh dashboard not scrollable``
* Empty placeholder customizable for empty dashboard
* Added ``mountToTop`` parameter to DashboardItemController.add and addAll method. (if false controller trying to add item to given position)

## 0.0.2+5

* Mouse cursor bug fix

## 0.0.2+4

* Cursor don't show on desktop fixed.

## 0.0.2+3

* Switched to dart sdk 2.17.0
* Switched to linter 2.0.1
* Fix static analysis recommends


## 0.0.2+2

* Analysis error fixed 


## 0.0.2+1

* Flutter version specified


## 0.0.2

* Initial Release.

## 0.0.1

* TODO: Describe initial release.
