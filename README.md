# flutter_dashboard_grid

A fork of [dashboard](https://github.com/Mehmetyaz/dashboard) by Mehmet Yaz,
published as `flutter_dashboard_grid`.

Dynamic dashboard widget that allows your users to create their own layouts. Resize, move, indirect resize/move, auto re-layout are supported.

## Features

Dashboard can be thought of as a dynamic grid. Your users can create their own layouts, add new widgets or remove widgets.

Layout divides the screen into horizontal slots according to the entered value. The aspect ratio of the slots also determine their height. Widgets called DashboardItem are placed in these slots. This layout can be changed later.

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/slots.png" width="400"/>

### Resize

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/resize.gif" width="400"/>

Dashboard Items can be resized both by long pressing on mobile and by holding and moving on desktop/browser.

### Move

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/move.gif" width="400"/>

Dashboard Item locations can be changed by long pressing on mobile or by holding and pulling on desktop/browser.

### Slots Changes

With dynamic slot count, you can re-layout window size changes.

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/re-layout.gif" width="400"/>

### Storage Delegate

The layout information of the users can be stored in the database or on the local disk.

Define your storage delegate.

```dart
class MyItemStorage extends DashboardItemStorageDelegate {  

  @override  
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) {  
    // return items from db.
  }  
  
  @override  
  FutureOr<void> onItemsUpdated(  
      List<DashboardItem> items, int slotCount) {
      // save new layouts to db.
  }
  //[...]
}
```

And use it.

```dart
DashboardItemController.withDelegate(
    itemStorageDelegate: MyItemStorage())
```


## Added in this fork

The animations below are recorded from the package itself, with real gestures,
by `tool/doc_screenshots_test.dart`; regenerate them after a visual change with
`flutter test tool/doc_screenshots_test.dart` (needs `ffmpeg`).

### Column sections (virtual columns)

Disabled columns split the grid into sections. Items cannot be placed in or
across them, and they take a fixed share of the grid width (or none at all
with `VirtualColumnsConfig.hidden`).

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/virtual_columns.gif" width="600"/>

```dart
Dashboard(
  slotCount: 14,
  virtualColumnsConfig: const VirtualColumnsConfig.visible(
    disabledColumns: [4, 9],   // three sections of four columns
    disabledColumnWidth: 0.04, // 4% of the grid width each
  ),
  ...
)
```

### Sections on phones and tablets

`MobileDashboardWrapper` keeps the desktop layout and shows it section by
section below the breakpoints: one section on a phone, two on a tablet, with a
header, page dots and arrows. Changing pages does not rebuild the grid.

The mode follows the width the wrapper gets, so a window crossing the
breakpoints (900 and 600 by default) goes from three sections to two to one:

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/sections_relayout.gif" width="600"/>

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/mobile_carousel.gif" width="300"/> <img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/tablet_carousel.gif" width="500"/>

```dart
MobileDashboardWrapper(
  dashboardItemController: controller,
  slotCount: 14,
  columnsPerPage: 4,
  virtualColumnsConfig: columns,
  mobileConfig: const MobileCarouselConfig(
    visibleSectionsOnMobile: 1,
    visibleSectionsOnTablet: 2,
  ),
  dashboardBuilder: (controller, slotCount, startColumn, isMobile) =>
      Dashboard(dashboardItemController: controller, slotCount: slotCount, ...),
)
```


Sections are the column groups between disabled virtual columns; without a
`virtualColumnsConfig` every `columnsPerPage` columns make one. Page changes
are reported through `onPageChanged`. `MobileCarouselConfig`:

| Field | Default | |
|---|---|---|
| `mobileBreakpoint`, `tabletBreakpoint` | 600, 900 | below them the phone and the tablet layout |
| `visibleSectionsOnMobile`, `visibleSectionsOnTablet` | 1, 2 | sections side by side |
| `sectionStepOnTablet` | `null` (one section) | how far one tablet page moves |
| `showHeader`, `showDots`, `showArrows` | `true` | section header, page dots, arrows |
| `swipeEnabled` | `true` | paging by swipe |
| `swipeWhileEditing` | `false` | paging by swipe also in edit mode (see [Scrolling while editing](#scrolling-while-editing)) |
| `pageSnapping` | `true` | a swipe ends on a page; `false` leaves the grid where it was released (the dots follow the nearest page) |
| `dotColor`, `activeDotColor`, `arrowColor`, `dotSize`, `activeDotSize`, `dotsSpacing`, `arrowSize` | | looks of the dots and arrows |

With two sections visible and the default step, tablet pages overlap: page 0
shows sections 1+2, page 1 sections 2+3. `sectionStepOnTablet: 2` pages block
by block instead; the last page is clamped so it is never half empty (three
sections: 1+2, then 2+3; four sections: 1+2, then 3+4).

### Resize and delete handles

In edit mode every item can carry a resize handle (bottom right) and a delete
button (top right), both built by you.

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/edit_handles.gif" width="400"/>

```dart
EditModeSettings(
  resizeHandleBuilder: (context, item, isEditing) => const Icon(Icons.open_in_full),
  deleteHandleBuilder: (context, item, isEditing, onDelete) =>
      IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
)
```

### Scrolling while editing

By default a grid in edit mode does not scroll by hand: every drag on it moves
or resizes an item. With `scrollWhileEditing` it scrolls as usual, and an item
dragged to an edge takes the view along:

```dart
Dashboard(
  editModeSettings: EditModeSettings(scrollWhileEditing: true),
  ...
)

// In a carousel, also:
MobileCarouselConfig(swipeWhileEditing: true)
```

* A drag on an empty slot scrolls the grid (or swipes the section), and the
  mouse wheel scrolls it.
* A finger picks an item up after it is held still on it for
  `touchPickUpDelay` (350 ms); a finger that moves sooner scrolls instead. A
  mouse, stylus or trackpad picks it up as soon as it moves, and so does any
  pointer on the resize handle.
* An item dragged into the top or bottom edge zone (`autoScrollEdge`, by
  default 12% of the height, 40–80 px) scrolls the grid, faster the deeper it
  is, up to `autoScrollMaxSpeed` (1200 px/s), down to one row past the end. In
  the carousel, an item held at a side edge for `pageFlipDwell` (500 ms) moves
  to the next section, and on to the one after while it stays there. The view
  stays where the drag took it.
* `DashboardItemController.liftedItem` holds the identifier of the item being
  dragged, for drawing it picked up.

With the flag `panEnabled` and `longPressEnabled` are not used, except that
both `false` turn dragging off. Dragging an empty slot with a mouse scrolls
only if the dashboard's `scrollBehavior` lists the mouse in `dragDevices`,
which Flutter's default does not.

### Compact to top

`DashboardItemController.compactToTop()` closes the vertical gaps left after
moving or deleting items, and returns the identifiers it moved. The items
slide to their new rows in edit mode, or always with `animateEverytime` (the
default); with `animateEverytime: false` outside edit mode they jump, like
every other layout change.

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/compact_to_top.gif" width="400"/>


### Grid geometry

`onGridDimensionsChanged` reports the laid-out geometry (`slotWidth`,
`slotHeight`, `columns`, `totalWidth`, `totalHeight`, `padding`, the spacing),
so items can size their content to the slot. It is called during layout, on
every layout pass: compare, and `setState` after the frame.

```dart
Dashboard(
  onGridDimensionsChanged: (d) {
    if (d.slotWidth == _grid?.slotWidth && d.slotHeight == _grid?.slotHeight) {
      return;
    }
    _grid = d;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  },
  ...
)
```

`slotWidth` is the width of an enabled column; with virtual columns that is
wider than `totalWidth / columns`. `MobileDashboardWrapper` does not take the
callback: pass it to the `Dashboard` built in `dashboardBuilder`.

### Inside a NestedScrollView

With `primary: true` and no `scrollController`, the grid scrolls on the
`PrimaryScrollController` an enclosing `NestedScrollView` gives its body, so
dragging the grid also collapses and expands the header above it. The default
`false` keeps the grid on its own scroll position, which is what a carousel or
a second grid under the same header needs.

```dart
NestedScrollView(
  headerSliverBuilder: (context, innerBoxIsScrolled) => [
    const SliverAppBar(expandedHeight: 200, pinned: true),
  ],
  body: Dashboard(primary: true, ...),
)
```

## Getting started

### Install

```yaml
dependencies:
  flutter_dashboard_grid: ^1.0.0
```

```dart
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
```

Coming from the git dependency `dashboard` (up to `v0.0.13`): rename the
dependency and replace `package:dashboard/` with `package:flutter_dashboard_grid/`
in the imports; `package:flutter_dashboard_grid/dashboard.dart` still exists,
so the rest of each import can stay.

### Define Dashboard

```dart
Dashboard(  
  dashboardItemController: itemController,  
  itemBuilder: (item) {
	//return widget
  },  
);
```

### Define Items

Items can come from the database, or can be defined as fixed.

Fixed:
```dart
DashboardItemController(items: [
  DashboardItem(width: 2, height: 3, identifier: "id_1"),  
  DashboardItem(  
      startX: 3, startY: 4, width: 3, height: 1, identifier: "id_2"),  
]);
```

Or with delegate:

```dart
DashboardItemController<ADashboardItemImp>.withDelegate(  
    itemStorageDelegate: MyItemStorage())
```

[See example](https://github.com/gudaja/dashboard/blob/main/example/lib/storage.dart)


### Define Builder

The Builder is invoked with a DashboardItem and returns a widget.

```dart
Dashboard(  
  dashboardItemController: itemController,  
  itemBuilder: (item) {
	return Text(item.identifier);
  },  
);
```

## Parameters

### Item Style

Each item is wrapped with a Material widget. You can enter the parameters of the Material widget with item style.

All is optional.
```dart
ItemStyle(  
  color: Colors.red,  
  borderRadius: BorderRadius.circular(10),  
  shape: const RoundedRectangleBorder(),  
  shadowColor: Colors.black,  
  animationDuration: const Duration(milliseconds: 200),  
  borderOnForeground: false,  
  clipBehavior: Clip.antiAliasWithSaveLayer,  
  elevation: 10,  
  textStyle: const TextStyle(color: Colors.black),  
  type: MaterialType.card  
);
```

#### Slide

Slide to top items initially. Auto relayout places items to top as possible.

```slideToTop: true```

Before: 

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/before.png" width="400"/>

After: 

<img src="https://raw.githubusercontent.com/gudaja/dashboard/main/documentation/after.png" width="400"/>

#### Shrink

Shrink items when re-layout or editing is possible.


### Edit Mode Settings

EditModeSettings contains parameters related to gesture, animations, resizing.

```dart
EditModeSettings(
  resizeCursorSide: 10, // Resize side width
  resizeHysteresis: 0.05, // A resize steps at 50% + 5% of a slot, either way
  paintBackgroundLines: true, // Paint background lines
  fillEditingBackground: true, // Fill editing item background
  longPressEnabled: true, // Start resize or move with long press
  panEnabled: true, // Start resize or move with pan
  backgroundStyle: EditModeBackgroundStyle(), // Background style
  curve: Curves.easeOut, // Animation curve
  duration: Duration(milliseconds: 300), // Animation duration
  shrinkOnMove: true, // Shrink items on moving if necessary
  draggableOutside: true, // Items can be dragged outside the viewport
  autoScroll: true, // Viewport will scroll automatically when item is dragged outside
  scrollWhileEditing: false, // Scroll by hand in edit mode (see "Scrolling while editing")
  touchPickUpDelay: Duration(milliseconds: 350), // Hold to pick up, with scrollWhileEditing
  autoScrollMaxSpeed: 1200, // px/s at the edge, with scrollWhileEditing
  autoScrollEdge: null, // Edge zone depth; null = 12% of the extent, 40-80 px
  pageFlipDwell: Duration(milliseconds: 500), // Carousel section flip at a side edge
  resizeHandleBuilder: (context, item, isEditing) {
    // Custom resize handle widget displayed in bottom-right corner during edit mode
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.open_in_full, color: Colors.white, size: 12),
    );
  },
)
```

An edge changes the size by one slot once it is past the middle of the slot by
`resizeHysteresis` of it: with the default 0.05 an item grows when its edge is
55% into the next slot and shrinks when it is 55% back into its own last one.
A step is not undone until the edge goes back past 45%, so an edge held near
the middle does not flicker. While dragging, the item follows the pointer.

#### Custom Resize Handle

The `resizeHandleBuilder` parameter allows you to display a custom widget in the bottom-right corner of each dashboard item during edit mode. This provides a more visible and user-friendly way to resize items.

**Parameters:**
- `context`: The build context
- `item`: The dashboard item being edited
- `isEditing`: Whether the item is currently in edit mode

**Example:**
```dart
resizeHandleBuilder: (context, item, isEditing) {
  return Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.8),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 4,
          offset: Offset(2, 2),
        ),
      ],
    ),
    child: Icon(
      Icons.open_in_full,
      color: Colors.white,
      size: 14,
    ),
  );
}
```

If `resizeHandleBuilder` is null, no custom resize handle is displayed, and resizing works through the traditional edge detection method.

### Storage Delegate

[See example](https://github.com/gudaja/dashboard/blob/main/example/lib/storage.dart)

#### Caching

```dart
class MyItemStorage extends DashboardItemStorageDelegate<MyItem> {
  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => true;
  //[...]
}
```

With `cacheItems` the delegate keeps the layout in memory after the first
`getAllItems` and does not call it again for that slot count; additions,
layout changes and deletions made through the grid update the cache as they
are saved. With `layoutsBySlotCount` every slot count has a layout (and a
cache entry) of its own, otherwise all slot counts share one.

#### Invalidating the cache

The cache lives on the delegate, not on the widget, so re-mounting the
`Dashboard` keeps serving it. When the stored layout changed somewhere else —
a second grid over the same storage, an editor on another screen, a sync —
drop the cache and the next mount calls `getAllItems` again:

```dart
storage.invalidateCache(slotCount); // one slot count
storage.invalidateCache();          // all of them
```

The slot count is normalised the way `getAllItems` normalises it: with
`layoutsBySlotCount` false any value clears the one shared entry.
