// Records the animations in `documentation/` that show what this fork adds on
// top of the upstream package. Not part of the test suite (`flutter test`
// only scans `test/`); regenerate them after a visual change with:
//
//   flutter test tool/doc_screenshots_test.dart
//
// Needs `ffmpeg` on PATH. Every frame is a real `Dashboard` /
// `MobileDashboardWrapper` from `lib/`, driven by real gestures, so the
// animations show the package as it behaves. The circle is where the finger
// (or mouse button) is down.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = Color(0xFF4285F4);
const _pixelRatio = 1.5;
const _fps = 15;
const _frame = Duration(milliseconds: 1000 ~/ _fps);

/// Three sections of four columns, split by two separator columns.
const _slotCount = 14;
const _columns = VirtualColumnsConfig.visible(
  disabledColumns: [4, 9],
  disabledColumnWidth: 0.04,
);

const _palette = <Color>[
  Color(0xFF009688),
  Color(0xFF9C27B0),
  Color(0xFFCDDC39),
  Color(0xFF3F51B5),
  Color(0xFFFF7043),
  Color(0xFF26A69A),
  Color(0xFFEC407A),
  Color(0xFF5C6BC0),
  Color(0xFFFFA726),
  Color(0xFF66BB6A),
  Color(0xFF8D6E63),
  Color(0xFF29B6F6),
  Color(0xFFAB47BC),
];

void main() {
  setUpAll(() async {
    final fonts = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';
    await (FontLoader('Roboto')
          ..addFont(_font('$fonts/Roboto-Regular.ttf'))
          ..addFont(_font('$fonts/Roboto-Medium.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(_font('$fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('virtual_columns.gif', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    final r = await _Recorder.start(
      tester,
      'virtual_columns',
      const Size(800, 400),
      _app(
        title: 'VirtualColumnsConfig',
        controller: controller,
        body: _grid(controller, _slotCount),
      ),
    );

    await r.wait(const Duration(milliseconds: 600));
    await r.tap(tester.getCenter(find.byIcon(Icons.edit)));
    await r.wait(const Duration(milliseconds: 500));

    // Item 1 (section 1) goes under item 7 (section 2), across the separator.
    final item = tester.getRect(_tileOf('1'));
    final below = tester.getRect(_tileOf('7'));
    await r.drag(
      item.center,
      Offset(below.center.dx, below.bottom + item.height / 2 + 8),
      duration: const Duration(milliseconds: 1800),
    );
    await r.wait(const Duration(milliseconds: 600));
    await r.tap(tester.getCenter(find.byIcon(Icons.check)));
    await r.wait(const Duration(milliseconds: 1200));
    await r.finish();
  });

  testWidgets('mobile_carousel.gif', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    final r = await _Recorder.start(
      tester,
      'mobile_carousel',
      const Size(390, 560),
      _app(title: 'Telefon', body: _wrapper(controller)),
    );
    await _swipes(r, width: 390);
  });

  testWidgets('tablet_carousel.gif', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    final r = await _Recorder.start(
      tester,
      'tablet_carousel',
      const Size(780, 470),
      _app(title: 'Tablet', body: _wrapper(controller)),
    );
    await _swipes(r, width: 780, pages: 2);
  });

  testWidgets('edit_handles.gif', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: [
      DashboardItem(identifier: '0', width: 2, height: 2, startX: 0, startY: 0),
      DashboardItem(identifier: '1', width: 2, height: 1, startX: 2, startY: 0),
      DashboardItem(identifier: '3', width: 1, height: 1, startX: 2, startY: 1),
    ]);
    final r = await _Recorder.start(
      tester,
      'edit_handles',
      const Size(420, 420),
      _app(
        title: 'Tryb edycji',
        controller: controller,
        body: _grid(controller, 4, virtual: false, handles: true),
      ),
    );

    await r.wait(const Duration(milliseconds: 600));
    await r.tap(tester.getCenter(find.byIcon(Icons.edit)));
    await r.wait(const Duration(milliseconds: 600));

    // Grab the resize handle of item 3 and pull it one slot right and down.
    final small = tester.getRect(_tileOf('3'));
    final handle = small.bottomRight - const Offset(19, 19);
    await r.drag(handle, handle + Offset(small.width + 8, small.height + 8));
    await r.wait(const Duration(milliseconds: 400));

    // Delete item 1 with its button.
    final wide = tester.getRect(_tileOf('1'));
    await r.tap(wide.topRight + const Offset(-19, 19));
    await r.wait(const Duration(milliseconds: 600));
    await r.tap(tester.getCenter(find.byIcon(Icons.check)));
    await r.wait(const Duration(milliseconds: 1200));
    await r.finish();
  });

  testWidgets('compact_to_top.gif', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: [
      DashboardItem(identifier: '0', width: 2, height: 1, startX: 0, startY: 0),
      DashboardItem(identifier: '1', width: 1, height: 2, startX: 3, startY: 0),
      DashboardItem(identifier: '2', width: 1, height: 1, startX: 1, startY: 2),
      DashboardItem(identifier: '4', width: 2, height: 1, startX: 2, startY: 3),
      DashboardItem(identifier: '6', width: 1, height: 1, startX: 0, startY: 4),
    ]);
    final r = await _Recorder.start(
      tester,
      'compact_to_top',
      const Size(420, 560),
      _app(
        title: 'compactToTop()',
        controller: controller,
        onCompact: controller.compactToTop,
        // Outside edit mode a layout change animates only with
        // animateEverytime, which the other recordings leave off.
        body: _grid(controller, 4, virtual: false, animate: true),
      ),
    );

    await r.wait(const Duration(milliseconds: 1000));
    await r.tap(tester.getCenter(find.byIcon(Icons.vertical_align_top)));
    await r.wait(const Duration(milliseconds: 1800));
    await r.finish();
  });

  testWidgets('sections_relayout.gif', (tester) async {
    // The window narrows across both breakpoints of MobileCarouselConfig
    // (900 and 600): three sections side by side, then two, then one.
    const desktop = 960.0, tablet = 780.0, phone = 390.0;
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    final width = ValueNotifier<double>(desktop);
    final r = await _Recorder.start(
      tester,
      'sections_relayout',
      const Size(desktop, 470),
      ColoredBox(
        color: const Color(0xFF3C4043),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, w, child) => SizedBox(width: w, child: child),
            child: _app(
              title: 'MobileDashboardWrapper',
              body: _wrapper(controller),
            ),
          ),
        ),
      ),
      pixelRatio: 1,
    );

    await r.wait(const Duration(milliseconds: 1500));
    await r.tween(width, tablet);
    await r.wait(const Duration(milliseconds: 1500));
    await r.tween(width, phone);
    await r.wait(const Duration(milliseconds: 1500));
    await r.tween(width, desktop, duration: const Duration(milliseconds: 900));
    await r.wait(const Duration(milliseconds: 600));
    await r.finish();
  });
}

/// Left through every page, then back to the first.
Future<void> _swipes(_Recorder r,
    {required double width, int pages = 3}) async {
  await r.wait(const Duration(milliseconds: 800));
  final y = 330.0;
  for (var i = 1; i < pages; i++) {
    await r.drag(Offset(width * 0.8, y), Offset(width * 0.2, y),
        duration: const Duration(milliseconds: 500), hold: Duration.zero);
    await r.wait(const Duration(milliseconds: 700));
  }
  for (var i = 1; i < pages; i++) {
    await r.drag(Offset(width * 0.2, y), Offset(width * 0.8, y),
        duration: const Duration(milliseconds: 500), hold: Duration.zero);
    await r.wait(const Duration(milliseconds: 500));
  }
  await r.wait(const Duration(milliseconds: 600));
  await r.finish();
}

Finder _tileOf(String id) => find.byKey(ValueKey('tile_$id'));

List<DashboardItem> _layout() => [
      // Section 1 (columns 0-3)
      DashboardItem(identifier: '0', width: 2, height: 2, startX: 0, startY: 0),
      DashboardItem(identifier: '1', width: 2, height: 1, startX: 2, startY: 0),
      DashboardItem(identifier: '2', width: 1, height: 1, startX: 2, startY: 1),
      DashboardItem(identifier: '3', width: 1, height: 1, startX: 3, startY: 1),
      DashboardItem(identifier: '4', width: 4, height: 1, startX: 0, startY: 2),
      // Section 2 (columns 5-8)
      DashboardItem(identifier: '5', width: 1, height: 1, startX: 5, startY: 0),
      DashboardItem(identifier: '6', width: 3, height: 1, startX: 6, startY: 0),
      DashboardItem(identifier: '7', width: 2, height: 2, startX: 5, startY: 1),
      DashboardItem(identifier: '8', width: 2, height: 1, startX: 7, startY: 1),
      DashboardItem(identifier: '9', width: 2, height: 1, startX: 7, startY: 2),
      // Section 3 (columns 10-13)
      DashboardItem(
          identifier: '10', width: 4, height: 1, startX: 10, startY: 0),
      DashboardItem(
          identifier: '11', width: 1, height: 2, startX: 10, startY: 1),
      DashboardItem(
          identifier: '12', width: 3, height: 2, startX: 11, startY: 1),
    ];

Widget _app({
  required String title,
  required Widget body,
  DashboardItemController<DashboardItem>? controller,
  VoidCallback? onCompact,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'Roboto', useMaterial3: false),
    home: Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: _blue,
        title: Text(title),
        actions: [
          if (onCompact != null)
            IconButton(
                icon: const Icon(Icons.vertical_align_top),
                onPressed: onCompact),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
          if (controller != null)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => IconButton(
                icon: Icon(controller.isEditing ? Icons.check : Icons.edit),
                onPressed: () => controller.isEditing = !controller.isEditing,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    ),
  );
}

Widget _wrapper(DashboardItemController<DashboardItem> controller) {
  return MobileDashboardWrapper<DashboardItem>(
    dashboardItemController: controller,
    slotCount: _slotCount,
    columnsPerPage: 4,
    virtualColumnsConfig: _columns,
    mobileConfig: const MobileCarouselConfig(
      visibleSectionsOnMobile: 1,
      visibleSectionsOnTablet: 2,
      activeDotColor: _blue,
      arrowColor: _blue,
    ),
    dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) =>
        _grid(ctrl, slotCount),
  );
}

Widget _grid(DashboardItemController<DashboardItem> controller, int slotCount,
    {bool virtual = true, bool handles = false, bool animate = false}) {
  return Dashboard<DashboardItem>(
    dashboardItemController: controller,
    slotCount: slotCount,
    slotAspectRatio: 1,
    padding: const EdgeInsets.all(8),
    horizontalSpace: 8,
    verticalSpace: 8,
    shrinkToPlace: false,
    slideToTop: false,
    animateEverytime: animate,
    virtualColumnsConfig: virtual ? _columns : null,
    slotBackgroundBuilder: SlotBackgroundBuilder.withDimensionsFunction(
        (context, item, x, y, editing, slotWidth, slotHeight, config) {
      if (config?.isColumnDisabled(x) ?? false) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _blue.withAlpha(40),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }),
    itemStyle: ItemStyle(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    editModeSettings: EditModeSettings(
      paintBackgroundLines: false,
      // The handle's centre is ~19 px from the corner; a resize starts only
      // inside this band, so it must reach the handle.
      resizeCursorSide: 24,
      resizeHandleBuilder: handles
          ? (context, item, isEditing) =>
              _handle(Icons.open_in_full, Colors.red)
          : null,
      deleteHandleBuilder: handles
          ? (context, item, isEditing, onDelete) => GestureDetector(
              onTap: onDelete, child: _handle(Icons.delete, Colors.redAccent))
          : null,
    ),
    itemBuilder: _tile,
  );
}

Widget _tile(DashboardItem item) {
  final l = item.layoutData;
  return Container(
    key: ValueKey('tile_${item.identifier}'),
    color: _palette[int.parse(item.identifier) % _palette.length],
    padding: const EdgeInsets.all(8),
    child: Text(
      'x: ${l.startX}  y: ${l.startY}\n${l.width} × ${l.height}',
      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
    ),
  );
}

Widget _handle(IconData icon, Color color) => Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );

final _boundary = GlobalKey();

/// Pumps the app frame by frame, drives gestures and writes every frame to
/// `build/doc_frames/<name>/`, then encodes them into `documentation/<name>.gif`.
class _Recorder {
  _Recorder._(this.tester, this.name, this.frames, this.pixelRatio);

  final WidgetTester tester;
  final String name;
  final Directory frames;
  final double pixelRatio;
  final ValueNotifier<Offset?> _finger = ValueNotifier(null);
  int _count = 0;

  static Future<_Recorder> start(
      WidgetTester tester, String name, Size size, Widget app,
      {double pixelRatio = _pixelRatio}) async {
    // flutter_test replaces elevation shadows with a black outline by default;
    // the flag is put back in `finish`, before the test body ends.
    debugDisableShadows = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final frames = Directory('build/doc_frames/$name');
    if (frames.existsSync()) frames.deleteSync(recursive: true);
    frames.createSync(recursive: true);

    final r = _Recorder._(tester, name, frames, pixelRatio);
    await tester.pumpWidget(RepaintBoundary(
      key: _boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          app,
          ValueListenableBuilder<Offset?>(
            valueListenable: r._finger,
            builder: (context, at, _) => at == null
                ? const SizedBox.shrink()
                : Positioned(
                    left: at.dx - 18,
                    top: at.dy - 18,
                    child: IgnorePointer(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(50),
                          border: Border.all(
                              color: Colors.white.withAlpha(200), width: 2),
                        ),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return r;
  }

  Future<void> _capture() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${frames.path}/${(_count++).toString().padLeft(4, '0')}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> _step() async {
    await tester.pump(_frame);
    await _capture();
  }

  Future<void> wait(Duration duration) async {
    for (var t = Duration.zero; t < duration; t += _frame) {
      await _step();
    }
  }

  /// Moves [value] to [to] over [duration], one step per recorded frame.
  Future<void> tween(ValueNotifier<double> value, double to,
      {Duration duration = const Duration(milliseconds: 1200)}) async {
    final from = value.value;
    final steps = duration.inMilliseconds ~/ _frame.inMilliseconds;
    for (var i = 1; i <= steps; i++) {
      value.value =
          ui.lerpDouble(from, to, Curves.easeInOut.transform(i / steps))!;
      await _step();
    }
  }

  Future<void> tap(Offset at) async {
    _finger.value = at;
    await wait(const Duration(milliseconds: 300));
    await tester.tapAt(at);
    await wait(const Duration(milliseconds: 150));
    _finger.value = null;
  }

  Future<void> drag(Offset from, Offset to,
      {Duration duration = const Duration(milliseconds: 1200),
      Duration hold = const Duration(milliseconds: 300)}) async {
    _finger.value = from;
    final gesture = await tester.startGesture(from);
    await wait(hold);
    final steps = duration.inMilliseconds ~/ _frame.inMilliseconds;
    for (var i = 1; i <= steps; i++) {
      final at = Offset.lerp(from, to, Curves.easeInOut.transform(i / steps))!;
      await gesture.moveTo(at);
      _finger.value = at;
      await _step();
    }
    await wait(const Duration(milliseconds: 150));
    await gesture.up();
    _finger.value = null;
  }

  Future<void> finish() async {
    await tester.runAsync(() async {
      final result = await Process.run('ffmpeg', [
        '-v', 'error', '-y', //
        '-framerate', '$_fps',
        '-i', '${frames.path}/%04d.png',
        '-vf',
        'split[a][b];[a]palettegen=stats_mode=diff[p];'
            '[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
        '-loop', '0',
        'documentation/$name.gif',
      ]);
      if (result.exitCode != 0) throw Exception(result.stderr);
    });
    debugDisableShadows = true;
  }
}

String _flutterRoot() =>
    Platform.environment['FLUTTER_ROOT'] ??
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;

Future<ByteData> _font(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());
