// Renders the screenshots in `documentation/` that show what this fork adds
// on top of the upstream package. Not part of the test suite (`flutter test`
// only scans `test/`); regenerate the images after a visual change with:
//
//   flutter test tool/doc_screenshots_test.dart
//
// Every image is a real `Dashboard` / `MobileDashboardWrapper` from `lib/`,
// configured the way `example/` uses them, so it shows the package as it is.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = Color(0xFF4285F4);
const _pixelRatio = 1.5;

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

  testWidgets('virtual_columns.png', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    await _shoot(
      tester,
      const Size(900, 420),
      _app(title: 'VirtualColumnsConfig', body: _grid(controller, _slotCount)),
      'virtual_columns',
    );
  });

  testWidgets('mobile_carousel.png', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    await _shoot(
      tester,
      const Size(390, 520),
      _app(title: 'Telefon', body: _wrapper(controller)),
      'mobile_carousel',
    );
  });

  testWidgets('tablet_carousel.png', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: _layout());
    await _shoot(
      tester,
      const Size(780, 470),
      _app(title: 'Tablet', body: _wrapper(controller)),
      'tablet_carousel',
    );
  });

  testWidgets('edit_handles.png', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: [
      DashboardItem(identifier: '0', width: 2, height: 2, startX: 0, startY: 0),
      DashboardItem(identifier: '1', width: 2, height: 1, startX: 2, startY: 0),
      DashboardItem(identifier: '3', width: 1, height: 1, startX: 2, startY: 1),
    ]);
    await _shoot(
      tester,
      const Size(420, 330),
      _app(
        title: 'Tryb edycji',
        editing: true,
        body: _grid(controller, 4, virtual: false),
      ),
      'edit_handles',
      before: () async => controller.isEditing = true,
    );
  });

  testWidgets('compact_before.png / compact_after.png', (tester) async {
    final controller = DashboardItemController<DashboardItem>(items: [
      DashboardItem(identifier: '0', width: 2, height: 1, startX: 0, startY: 0),
      DashboardItem(identifier: '1', width: 1, height: 2, startX: 3, startY: 0),
      DashboardItem(identifier: '2', width: 1, height: 1, startX: 1, startY: 2),
      DashboardItem(identifier: '4', width: 2, height: 1, startX: 2, startY: 3),
      DashboardItem(identifier: '6', width: 1, height: 1, startX: 0, startY: 4),
    ]);
    final app = _app(
      title: 'compactToTop()',
      body: _grid(controller, 4, virtual: false),
    );
    await _shoot(tester, const Size(420, 560), app, 'compact_before');
    await _shoot(tester, const Size(420, 560), app, 'compact_after',
        before: () async => controller.compactToTop());
  });
}

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

Widget _app(
    {required String title, required Widget body, bool editing = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'Roboto', useMaterial3: false),
    home: Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: _blue,
        title: Text(title),
        actions: [
          const Icon(Icons.refresh),
          const SizedBox(width: 20),
          const Icon(Icons.delete),
          const SizedBox(width: 20),
          const Icon(Icons.add),
          const SizedBox(width: 20),
          Icon(editing ? Icons.check : Icons.edit),
          const SizedBox(width: 16),
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
    {bool virtual = true}) {
  return Dashboard<DashboardItem>(
    dashboardItemController: controller,
    slotCount: slotCount,
    slotAspectRatio: 1,
    padding: const EdgeInsets.all(8),
    horizontalSpace: 8,
    verticalSpace: 8,
    shrinkToPlace: false,
    slideToTop: false,
    animateEverytime: false,
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
      resizeHandleBuilder: (context, item, isEditing) =>
          _handle(Icons.open_in_full, Colors.red),
      deleteHandleBuilder: (context, item, isEditing, onDelete) =>
          _handle(Icons.delete, Colors.redAccent),
    ),
    itemBuilder: _tile,
  );
}

Widget _tile(DashboardItem item) {
  final l = item.layoutData;
  return Container(
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

Future<void> _shoot(WidgetTester tester, Size size, Widget app, String name,
    {Future<void> Function()? before}) async {
  // flutter_test replaces elevation shadows with a black outline by default;
  // the flag has to be back before the test body ends, not in a tearDown.
  debugDisableShadows = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(RepaintBoundary(key: _boundary, child: app));
  await tester.pumpAndSettle();
  if (before != null) {
    await before();
    await tester.pumpAndSettle();
  }

  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('documentation/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List(), flush: true);
  });
  debugDisableShadows = true;
}

String _flutterRoot() =>
    Platform.environment['FLUTTER_ROOT'] ??
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;

Future<ByteData> _font(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());
