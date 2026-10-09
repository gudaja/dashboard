> **Fork.** Ten CHANGELOG opisuje `github.com/gudaja/dashboard`, forka
> `Mehmetyaz/dashboard`. Wpisy do `0.0.3+1` włącznie pochodzą z upstreamu.
> Wpisy `0.0.4`–`0.0.5` zostały **odtworzone z historii commitów** przy okazji
> wydania `0.0.6` — plik nie był prowadzony na bieżąco, a `pubspec.yaml`
> deklarował `0.0.5` bez ani jednego wpisu za `0.0.3+1`.
>
> **`0.0.8` and `0.0.9` are the same kind of catch-up.** Both tags already exist
> and both point at the commit that carries the work — but those commits still
> declared `version: 0.0.7`, because the consumer resolves this package by `ref:`
> and the tag was what it needed. The entries below were written afterwards,
> together with the version bump, in a commit that touches no `lib/` file and
> therefore gets NO tag of its own: `v0.0.8` and `v0.0.9` keep pointing where
> they pointed.

## 0.0.13

**Toggling edit mode keeps the scroll offset, and the layout can be compacted.**

* `Dashboard` keyed its `Scrollable` by `isEditing`, so every toggle remounted
  it and the fresh `ScrollPosition` started at 0 — the consumer's layout editor
  jumped back to the top each time its lock was flipped (owner's report,
  2026-10-09). The key is gone; `Scrollable.didUpdateWidget` swaps the physics
  and the position is rebuilt FROM the old one, keeping `pixels`.
* Why the key existed: this grid applies its scroll dimensions from
  `viewportBuilder`, i.e. inside `Scrollable.build`, so `setCanDrag` of the new
  position runs after `build` captured the old gesture recognizers and a drag
  still scrolled the pinned grid. `dashboardWidget` now schedules ONE more build
  after the frame whenever the physics flips between dragging and
  `NeverScrollableScrollPhysics` (edit mode and the item-drag `scrollable` flag
  alike).
* New `DashboardItemController.compactToTop()`: every item slides straight up
  until it meets another item or the top edge. `startX`, width and height never
  change (sections and virtual columns stay intact), items move in reading
  order, the moved ones reach `onItemsUpdated` in ONE call (none when nothing
  moved), and the call is a no-op during an edit session or with no grid
  mounted.
* Tests: `test/compact_and_edit_toggle_test.dart` (`T-CT-01…06`).

## 0.0.12

**The layout-time correction moves the items too when the VIEWPORT grows.**

* `0.0.11` replaced `jumpTo` with `correctBy` in `_setNewOffset`. `correctBy`
  notifies no one, and the items position themselves with their own
  `AnimatedBuilder` over the offset. A content change rebuilds the stack's item
  list anyway, so that case was right; a viewport that GROWS while the grid is
  scrolled to the end, with no new key entering the cache band, hands the stack
  its cached item list, and the items stayed at the old offset. Measured by the
  consumer (wave KB, phase B, anomaly A3): layout editor 1400×600 → 900 left a
  ~300 px empty strip at the bottom, a phone cockpit under the band 390×600 →
  844 ~100 px, until the next scroll event; `0.0.10` showed no strip.
* Fix, in the correction block only: the stack's cached item list is dropped
  right after `correctBy`, so the stack build that follows in the SAME frame
  places every item at the corrected offset (no notification, no `itemBuilder`
  call), and the controller's listeners are notified once, in a post-frame
  callback — outside layout, never through `jumpTo`. A post-frame notification
  alone was measured as well: the first frame still showed the strip (304 px in
  the test), the items were right one frame later.
* Tests `T-KB2-07` (bare grid, 400×600 → 900) and `T-KB2-08` (under a
  `NestedScrollView`, band offset unchanged): after ONE frame `pixels ==
  maxScrollExtent`, the bottom item sits at the bottom edge, zero layout-phase
  notifications, exactly one notification after the frame. Five items, not ten:
  with ten the growth pulls a new key into the cache band, the rebuilt list
  repositions the items by accident, and the test was green on `0.0.11`.

## 0.0.11

Wave **KB** of the consumer: **the grid can be the inner position of a One UI
band**, and the layout-time scroll correction no longer calls `jumpTo`.

* **`Dashboard.primary`** (opt-in, default `false`). With `true` and no
  `scrollController`, the grid's `Scrollable` scrolls on
  `PrimaryScrollController.maybeOf(context)` — the inner controller an enclosing
  `NestedScrollView` hands its body — so dragging the grid collapses and expands
  the band above it. A bare `Scrollable` never adopts the primary controller on
  its own (`scrollable.dart:590-591`, Flutter 3.47), and the default stays that
  way because every other grid of the consumer (carousel, layout editor,
  device-tile tabs) must keep scrolling on its own position under a band. With
  `true` and no `PrimaryScrollController` above, the grid behaves as before.
* **`correctBy` instead of `jumpTo` when the content shrinks under the
  offset.** `_setNewOffset` runs during layout (the grid is built from a
  `LayoutBuilder`), and `jumpTo` there notified every scroll listener in the
  middle of layout; on a nested position it was `coordinator.jumpTo` — `goIdle`,
  a jump of the band and `goBallistic(0)`, all inside layout. `correctBy` is the
  API made for that moment and notifies no one; the `applyContentDimensions`
  that follows publishes the new range. Measured: after deleting the bottom row
  of a grid scrolled to the end, `pixels` sits on the new `maxScrollExtent` in
  the same frame and the items are drawn at the corrected offset (the layout
  controller's rebuild repositions them, so no extra notification is needed).
* Tests `T-KB2-01…06` (`test/band_inner_position_test.dart`): adoption under a
  `NestedScrollView` (band expands and collapses, then the grid scrolls), the
  correction with zero layout-phase notifications both bare and nested (band
  offset unchanged), a viewport height oscillating 440↔720 builds neither the
  slot-background layer nor an item, the default does not adopt, and `primary:
  true` without a primary controller scrolls exactly like `false`.

## 0.0.10

**An empty slot-background layer no longer collapses the grid.**

* `0.0.8` returned a bare, NON-positioned `SizedBox.shrink()` from the
  slot-background layer when the builder answered `null` for every slot. A
  non-positioned child sizes a `Stack`, so under loose constraints the grid's
  `Stack` became 0×0 and its `Clip.hardEdge` cut every item away — the items
  stayed in the tree with their render boxes at the right coordinates, which is
  why no test that looked for them noticed. Seen by the consumer as a read-only
  cockpit on a wallpaper (no slot frames there by design) showing the wallpaper
  and not a single tile on a desktop window; the carousel below 900 px hands the
  grid tight constraints and was not affected.
* The empty layer is now `Positioned.fill(child: SizedBox.shrink())`: two
  widgets instead of one (`T-PV2-05` updated), and the stack sizes itself as it
  does with no background builder at all. `T-PV2-12` pins the size under loose
  constraints.

## 0.0.9

Wave **PV**, stage e of the consumer's plan: **paging the carousel no longer
rebuilds the grid.**

* **The page offset travels through a `ValueNotifier`** to a
  `ValueListenableBuilder` around `Transform.translate`, so a finger drag and the
  300 ms page animation MOVE the grid instead of rebuilding it. Until now both
  called `setState` on the wrapper, and that rebuild reached all the way down:
  `dashboardBuilder` was invoked again, its fresh `itemBuilder` closure made the
  stack drop its item map, and every item on screen was rebuilt. Measured on a
  phone-sized frame: five frames of a drag cost **5 `dashboardBuilder` and 120
  `itemBuilder` calls for 24 items**, 12–28 ms of build per frame — while the
  `Dashboard` element survived all of it, so the work was pure waste.
* **The grid subtree is remembered between builds.** `Element.updateChild`
  short-circuits on an identical widget instance, so a rebuild of the wrapper
  that hands back the same grid does not visit it at all: the dots, the header
  and the page may rebuild as often as they like. The cache is keyed by what the
  subtree is built from — the consumer's `dashboardBuilder` and controller by
  IDENTITY, plus `slotCount` and the device class.
* **Every notification of the item controller drops that cache**, because a
  consumer is allowed to READ live controller state inside its
  `dashboardBuilder` (one takes edit mode off in there). A swipe notifies
  nothing, which is why the cache is safe.
* The drag-offset arithmetic moved out of `build` into one place, which the
  drag-end handler now shares instead of keeping a literal copy of it, and the
  dots get an explicit `setState` where the page changes — the animation no
  longer redraws them as a side effect.

## 0.0.8

Wave **PV**, stages a–b: **the vertical band virtualises for real, and the slot
background is built when the band moves instead of on every frame.**

* **The static layer's cache is valid for the KEY SET it was built from.** It
  used to be keyed by the editing id alone, and outside edit mode that is `null`
  on both sides — so a scroll that pulled new items into the map (paying for
  `itemBuilder`) still handed the `Stack` the OLD list. Below the first band the
  grid went empty and never filled again: measured on a phone as 5 → 2 → 0 items
  on screen after three screen-height scrolls, with the stale ones coming back on
  the way up. A revision counter, bumped by the ONE helper every mutation of the
  map goes through, is now part of the key; the item being dragged is exempt,
  because the static layer never renders it and a drag takes it out and puts it
  back on every frame.
* **The slot background is ONE subtree that is moved, not rebuilt.** The slots
  are positioned in content space and the whole layer is offset by a single
  `AnimatedBuilder` over the viewport offset — the trick every item already used.
  `pixels` is gone from the cache key, and the layer is rebuilt only when the
  viewport LEAVES its band (`cacheExtend` of travel), not when the band's rounded
  edges move. Measured on a phone: 600 slot subtrees per scroll frame, **56,6 %
  of the frame's build time (7,0 ms of 12,4 ms)**, down to zero. `Clip.none` on
  the inner `Stack` is mandatory — its box is a coordinate frame, not a viewport,
  and the visible boundary stays the outer `Stack`.
* **A slot whose builder answers `null` costs nothing.** `null` used to become an
  empty `Container()` wrapped in `Positioned` > `RepaintBoundary` > `Builder`, so
  a consumer that draws no grid paid the full price of an invisible layer. The
  user's builder is also asked ONCE per band now, not once per frame.
* **An item is built once at mount, not twice.** `didUpdateWidget` cleared the
  item map on EVERY rebuild of the stack, including the ones where not a single
  field had changed (`Dashboard` rebuilds itself from its own `setState`), which
  cost a second `itemBuilder` call for every item on screen — measured 48 calls
  for 24 items. It now clears only when a parameter the map is BUILT FROM
  changed, and a deleted item is swept out of the map explicitly, since the
  blanket clear was what used to remove it.

## 0.0.7

* **`MobileCarouselConfig.sectionStepOnTablet`** — how many sections one page of
  the tablet carousel advances by. The wrapper has always stepped one section at
  a time, so with `visibleSectionsOnTablet: 2` page 0 showed S1+S2 and page 1
  showed S2+S3: the middle section appeared on both pages, and a three-section
  layout needed two swipes to reveal one new section. Setting the step to the
  number of visible sections pages the viewport block by block instead, with the
  last page clamped to the last full viewport so it is never half empty (3
  sections, 2 visible, step 2 → pages S1+S2 and S2+S3; 4 sections → the disjoint
  S1+S2 and S3+S4).
* The field is **`int?` and defaults to `null` = 1**, which is exactly the old
  arithmetic, so a consumer that does not set it sees no change. Page count and
  first-section-of-page are now `MobileCarouselConfig.totalPagesFor` /
  `sectionForPage` (`@visibleForTesting`), and the carousel header is written
  from the section index rather than from the page index — with a step of 1 the
  two are the same number, which is why nothing moved before.

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
