import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group('ItemLayout Model', () {
    test('should create with minimum required parameters', () {
      final layout = ItemLayout(width: 2, height: 3);

      expect(layout.width, 2);
      expect(layout.height, 3);
      expect(layout.startX, 0);
      expect(layout.startY, 0);
      expect(layout.minWidth, 1);
      expect(layout.minHeight, 1);
      expect(layout.maxWidth, isNull);
      expect(layout.maxHeight, isNull);
    });

    test('should create with all parameters', () {
      final layout = ItemLayout(
        width: 4,
        height: 3,
        startX: 2,
        startY: 1,
        minWidth: 2,
        minHeight: 1,
        maxWidth: 6,
        maxHeight: 5,
      );

      expect(layout.width, 4);
      expect(layout.height, 3);
      expect(layout.startX, 2);
      expect(layout.startY, 1);
      expect(layout.minWidth, 2);
      expect(layout.minHeight, 1);
      expect(layout.maxWidth, 6);
      expect(layout.maxHeight, 5);
    });

    test('should handle copyWithDimension correctly', () {
      final original = ItemLayout(
        width: 2,
        height: 2,
        startX: 1,
        startY: 1,
      );

      final copied = original.copyWithDimension(width: 3, height: 4);

      expect(copied.width, 3);
      expect(copied.height, 4);
      expect(copied.startX, 1); // nie zmienione
      expect(copied.startY, 1); // nie zmienione
    });

    test('should handle copyWithStarts correctly', () {
      final original = ItemLayout(
        width: 2,
        height: 2,
        startX: 1,
        startY: 1,
      );

      final copied = original.copyWithStarts(startX: 3, startY: 4);

      expect(copied.width, 2); // nie zmienione
      expect(copied.height, 2); // nie zmienione
      expect(copied.startX, 3);
      expect(copied.startY, 4);
    });

    test('should serialize to Map correctly', () {
      final layout = ItemLayout(
        width: 3,
        height: 2,
        startX: 1,
        startY: 2,
        minWidth: 1,
        minHeight: 1,
        maxWidth: 5,
        maxHeight: 4,
      );

      final map = layout.toMap();

      expect(map['w'], 3);
      expect(map['h'], 2);
      expect(map['s_X'], 1);
      expect(map['s_Y'], 2);
      expect(map['min_W'], 1);
      expect(map['min_H'], 1);
      expect(map['max_W'], 5);
      expect(map['max_H'], 4);
    });

    test('should deserialize from Map correctly', () {
      final map = {
        'w': 3,
        'h': 2,
        's_X': 1,
        's_Y': 2,
        'min_W': 1,
        'min_H': 1,
        'max_W': 5,
        'max_H': 4,
      };

      final layout = ItemLayout.fromMap(map);

      expect(layout.width, 3);
      expect(layout.height, 2);
      expect(layout.startX, 1);
      expect(layout.startY, 2);
      expect(layout.minWidth, 1);
      expect(layout.minHeight, 1);
      expect(layout.maxWidth, 5);
      expect(layout.maxHeight, 4);
    });

    test('should handle toString correctly', () {
      final layout = ItemLayout(
        width: 2,
        height: 3,
        startX: 1,
        startY: 4,
      );

      final string = layout.toString();
      expect(string, contains('startX: 1'));
      expect(string, contains('startY: 4'));
      expect(string, contains('width: 2'));
      expect(string, contains('height: 3'));
    });

    test('should enforce constraints', () {
      // minWidth <= width
      expect(
        () => ItemLayout(width: 1, height: 2, minWidth: 2),
        throwsAssertionError,
      );

      // minHeight <= height
      expect(
        () => ItemLayout(width: 2, height: 1, minHeight: 2),
        throwsAssertionError,
      );

      // maxWidth >= width
      expect(
        () => ItemLayout(width: 3, height: 2, maxWidth: 2),
        throwsAssertionError,
      );

      // maxHeight >= height
      expect(
        () => ItemLayout(width: 2, height: 3, maxHeight: 2),
        throwsAssertionError,
      );
    });
  });

  group('DashboardItem Model', () {
    test('should create item correctly', () {
      final item = DashboardItem(
        identifier: 'test-item',
        width: 2,
        height: 3,
        startX: 1,
        startY: 2,
      );

      expect(item.identifier, 'test-item');
      expect(item.layoutData.width, 2);
      expect(item.layoutData.height, 3);
      expect(item.layoutData.startX, 1);
      expect(item.layoutData.startY, 2);
    });

    test('should create item with layout', () {
      final layout = ItemLayout(width: 3, height: 2);
      final item = DashboardItem.withLayout('test-item', layout);

      expect(item.identifier, 'test-item');
      expect(item.layoutData, same(layout));
    });

    test('should handle min and max dimensions', () {
      final item = DashboardItem(
        identifier: 'test',
        width: 3,
        height: 3,
        minWidth: 2,
        minHeight: 2,
        maxWidth: 5,
        maxHeight: 5,
      );

      expect(item.layoutData.minWidth, 2);
      expect(item.layoutData.minHeight, 2);
      expect(item.layoutData.maxWidth, 5);
      expect(item.layoutData.maxHeight, 5);
    });

    test('should serialize and deserialize correctly', () {
      final originalItem = DashboardItem(
        identifier: 'serialize-test',
        width: 4,
        height: 2,
        startX: 3,
        startY: 1,
        minWidth: 2,
        minHeight: 1,
      );

      final map = originalItem.toMap();
      expect(map['item_id'], 'serialize-test');
      expect(map['layout'], isA<Map<String, dynamic>>());

      final recreatedItem = DashboardItem.fromMap(map);
      expect(recreatedItem.identifier, originalItem.identifier);
      expect(recreatedItem.layoutData.width, originalItem.layoutData.width);
      expect(recreatedItem.layoutData.height, originalItem.layoutData.height);
      expect(recreatedItem.layoutData.startX, originalItem.layoutData.startX);
      expect(recreatedItem.layoutData.startY, originalItem.layoutData.startY);
      expect(
          recreatedItem.layoutData.minWidth, originalItem.layoutData.minWidth);
      expect(recreatedItem.layoutData.minHeight,
          originalItem.layoutData.minHeight);
    });

    test('should maintain layout data integrity', () {
      final item = DashboardItem(
        identifier: 'integrity-test',
        width: 2,
        height: 2,
      );

      // Layout data powinno być dostępne
      expect(item.layoutData, isNotNull);
      expect(item.layoutData.width, 2);
      expect(item.layoutData.height, 2);

      // Możemy modyfikować layout data
      item.layoutData = ItemLayout(width: 3, height: 3);
      expect(item.layoutData.width, 3);
      expect(item.layoutData.height, 3);
    });
  });

  group('ItemStyle Model', () {
    test('should create ItemStyle with defaults', () {
      const style = ItemStyle();
      expect(style, isNotNull);
    });

    test('should handle ItemStyle parameters', () {
      // ItemStyle może mieć różne parametry w zależności od implementacji
      expect(() => const ItemStyle(), returnsNormally);
    });
  });

  group('VirtualColumnsConfig Model', () {
    test('should create config with disabled columns', () {
      const config = VirtualColumnsConfig(
        disabledColumns: [1, 3, 5],
        disabledColumnWidth: 0.1,
        showDisabledColumns: true,
      );

      expect(config.disabledColumns, [1, 3, 5]);
      expect(config.disabledColumnWidth, 0.1);
      expect(config.showDisabledColumns, true);
    });

    test('should create hidden config', () {
      const config = VirtualColumnsConfig.hidden(
        disabledColumns: [0, 2],
      );

      expect(config.disabledColumns, [0, 2]);
      expect(config.disabledColumnWidth, isNull);
      expect(config.showDisabledColumns, false);
    });

    test('should create visible config', () {
      const config = VirtualColumnsConfig.visible(
        disabledColumns: [1, 4],
        disabledColumnWidth: 0.05,
      );

      expect(config.disabledColumns, [1, 4]);
      expect(config.disabledColumnWidth, 0.05);
      expect(config.showDisabledColumns, true);
    });

    test('should check if column is disabled', () {
      const config = VirtualColumnsConfig(
        disabledColumns: [1, 3, 5],
      );

      expect(config.isColumnDisabled(1), true);
      expect(config.isColumnDisabled(3), true);
      expect(config.isColumnDisabled(5), true);
      expect(config.isColumnDisabled(0), false);
      expect(config.isColumnDisabled(2), false);
      expect(config.isColumnDisabled(4), false);
    });

    test('should calculate column width correctly', () {
      const config = VirtualColumnsConfig.visible(
        disabledColumns: [1],
        disabledColumnWidth: 0.1,
      );

      final normalWidth = 100.0;
      final totalGridWidth = 800.0;

      // Enabled column should have normal width
      expect(
          config.getColumnWidth(0, normalWidth, totalGridWidth), normalWidth);

      // Disabled column should have 10% of total grid width
      expect(config.getColumnWidth(1, normalWidth, totalGridWidth),
          80.0); // 0.1 * 800
    });

    test('should calculate column width for hidden columns', () {
      const config = VirtualColumnsConfig.hidden(
        disabledColumns: [1, 2],
      );

      final normalWidth = 100.0;
      final totalGridWidth = 800.0;

      // Hidden column should have zero width
      expect(config.getColumnWidth(1, normalWidth, totalGridWidth), 0.0);
      expect(config.getColumnWidth(2, normalWidth, totalGridWidth), 0.0);

      // Enabled column should have normal width
      expect(
          config.getColumnWidth(0, normalWidth, totalGridWidth), normalWidth);
    });

    test('should calculate column position correctly', () {
      const config = VirtualColumnsConfig.visible(
        disabledColumns: [1],
        disabledColumnWidth: 0.1,
      );

      final normalWidth = 100.0;
      final totalGridWidth = 800.0;

      // Column 0 should be at position 0
      expect(config.getColumnPosition(0, normalWidth, totalGridWidth), 0.0);

      // Column 1 should be at position 100 (after first normal column)
      expect(config.getColumnPosition(1, normalWidth, totalGridWidth), 100.0);

      // Column 2 should be at position 180 (100 + 80 for disabled column)
      expect(config.getColumnPosition(2, normalWidth, totalGridWidth), 180.0);
    });

    test('should find next enabled column', () {
      const config = VirtualColumnsConfig(
        disabledColumns: [1, 2, 4],
      );

      expect(config.getNextEnabledColumn(0, 6),
          3); // Next after 0 is 3 (1,2 disabled)
      expect(config.getNextEnabledColumn(1, 6),
          3); // Next after 1 is 3 (2 disabled)
      expect(config.getNextEnabledColumn(3, 6),
          5); // Next after 3 is 5 (4 disabled)
      expect(config.getNextEnabledColumn(5, 6), isNull); // No next after 5
    });

    test('should find previous enabled column', () {
      const config = VirtualColumnsConfig(
        disabledColumns: [1, 2, 4],
      );

      expect(config.getPreviousEnabledColumn(5),
          3); // Previous before 5 is 3 (4 disabled)
      expect(config.getPreviousEnabledColumn(3),
          0); // Previous before 3 is 0 (1,2 disabled)
      expect(
          config.getPreviousEnabledColumn(0), isNull); // No previous before 0
    });

    test('should validate disabledColumnWidth range', () {
      // Valid values
      expect(
          () => VirtualColumnsConfig(
              disabledColumns: const [1], disabledColumnWidth: 0.0),
          returnsNormally);
      expect(
          () => VirtualColumnsConfig(
              disabledColumns: const [1], disabledColumnWidth: 0.5),
          returnsNormally);
      expect(
          () => VirtualColumnsConfig(
              disabledColumns: const [1], disabledColumnWidth: 1.0),
          returnsNormally);

      // Invalid values should throw assertion error
      expect(
          () => VirtualColumnsConfig(
              disabledColumns: const [1], disabledColumnWidth: -0.1),
          throwsAssertionError);
      expect(
          () => VirtualColumnsConfig(
              disabledColumns: const [1], disabledColumnWidth: 1.1),
          throwsAssertionError);
    });

    test('should handle equality correctly', () {
      const config1 = VirtualColumnsConfig(
          disabledColumns: [1, 3], disabledColumnWidth: 0.1);
      const config2 = VirtualColumnsConfig(
          disabledColumns: [1, 3], disabledColumnWidth: 0.1);
      const config3 = VirtualColumnsConfig(
          disabledColumns: [1, 2], disabledColumnWidth: 0.1);

      expect(config1 == config2, true);
      expect(config1 == config3, false);
    });

    test('should generate correct toString', () {
      const config = VirtualColumnsConfig(
        disabledColumns: [1, 3],
        disabledColumnWidth: 0.05,
        showDisabledColumns: true,
      );

      final string = config.toString();
      expect(string, contains('VirtualColumnsConfig'));
      expect(string, contains('[1, 3]'));
      expect(string, contains('0.05'));
      expect(string, contains('true'));
    });
  });
}
