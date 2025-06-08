import 'dart:async';
import 'dart:convert';

import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColoredDashboardItem extends DashboardItem {
  ColoredDashboardItem(
      {this.color,
      required super.width,
      required super.height,
      required super.identifier,
      this.data,
      super.minWidth,
      super.minHeight,
      super.maxHeight,
      super.maxWidth,
      super.startX,
      super.startY});

  ColoredDashboardItem.fromMap(Map<String, dynamic> map)
      : color = map["color"] != null ? Color(map["color"]) : null,
        data = map["data"],
        super.withLayout(map["item_id"], ItemLayout.fromMap(map["layout"]));

  Color? color;

  String? data;

  @override
  Map<String, dynamic> toMap() {
    var sup = super.toMap();
    if (color != null) {
      sup["color"] = color?.toARGB32();
    }
    if (data != null) {
      sup["data"] = data;
    }
    return sup;
  }
}

class MyItemStorage extends DashboardItemStorageDelegate<ColoredDashboardItem> {
  late SharedPreferences _preferences;

  final int id = 0;

  final List<ColoredDashboardItem> _default = [
    ColoredDashboardItem(
      height: 2,
      width: 3,
      startX: 0,
      startY: 0,
      minHeight: 2,
      identifier: "1",
      data: "description",
    ),
    ColoredDashboardItem(
        startX: 3,
        startY: 0,
        minHeight: 2,
        height: 2,
        width: 2,
        identifier: "2",
        data: "resize"),
    ColoredDashboardItem(
        startX: 2,
        startY: 2,
        width: 4,
        height: 1,
        identifier: "3",
        minWidth: 3,
        data: "welcome"),
    ColoredDashboardItem(
        startX: 4,
        startY: 0,
        minWidth: 2,
        minHeight: 2,
        height: 2,
        width: 2,
        identifier: "4",
        data: "transform"),
    ColoredDashboardItem(
        startX: 7,
        startY: 0,
        minHeight: 2,
        height: 2,
        width: 1,
        identifier: "5",
        data: "add"),
    ColoredDashboardItem(
        minWidth: 2,
        maxWidth: 2,
        maxHeight: 1,
        height: 1,
        width: 2,
        startX: 2,
        startY: 4,
        identifier: "6",
        data: "buy_mee"),
    ColoredDashboardItem(
        minWidth: 2,
        height: 1,
        width: 2,
        startX: 0,
        startY: 2,
        identifier: "7",
        data: "delete"),
    ColoredDashboardItem(
        minWidth: 2,
        height: 1,
        width: 2,
        startX: 7,
        startY: 2,
        identifier: "8",
        data: "refresh"),
    ColoredDashboardItem(
        minWidth: 3,
        height: 1,
        width: 4,
        startX: 0,
        startY: 3,
        identifier: "9",
        data: "info"),
    ColoredDashboardItem(
        startX: 7,
        startY: 3,
        height: 2,
        width: 2,
        identifier: "13",
        data: "pub"),
    ColoredDashboardItem(
        startX: 9,
        startY: 0,
        height: 1, 
        width: 2, 
        identifier: "10", 
        data: "github"),
    ColoredDashboardItem(
        startX: 11,
        startY: 0,
        height: 1, 
        width: 2, 
        identifier: "11", 
        data: "twitter"),
    ColoredDashboardItem(
        startX: 14,
        startY: 0,
        height: 1, 
        width: 2, 
        identifier: "12", 
        data: "linkedin")
  ];

  Map<String, ColoredDashboardItem>? _localItems;

  @override
  FutureOr<List<ColoredDashboardItem>> getAllItems(int slotCount) {
    print("🔍 GET ALL ITEMS wywoływane dla slotCount: $slotCount");
    
    try {
      if (_localItems != null) {
        print("💾 Zwracam elementy z cache (${_localItems!.length} items)");
        final cachedItems = _localItems!.values.toList();
        
        // Wypisz pozycje z cache
        cachedItems.sort((a, b) {
          int yCompare = a.layoutData.startY.compareTo(b.layoutData.startY);
          if (yCompare != 0) return yCompare;
          return a.layoutData.startX.compareTo(b.layoutData.startX);
        });
        
        print("💭 POZYCJE Z CACHE:");
        for (var item in cachedItems) {
          print("  ${item.identifier}: (${item.layoutData.startX}, ${item.layoutData.startY}) ${item.layoutData.width}x${item.layoutData.height}");
        }
        
        return cachedItems;
      }

      return Future.microtask(() async {
        print("📱 ŁADUJĘ Z SHARED PREFERENCES...");
        _preferences = await SharedPreferences.getInstance();

        var init = _preferences.getBool("init") ?? false;
        print("🔧 Init flag: $init");

        if (!init) {
          print("🆕 PIERWSZY START - tworzę domyślny layout");
          _localItems = {for (var item in _default) item.identifier: item};

          await _preferences.setString(
              "${id}_layout_data_",
              json.encode(_default.asMap().map(
                  (key, value) => MapEntry(value.identifier, value.toMap()))));

          await _preferences.setBool("init", true);
          print("✅ Zapisano domyślny layout do SharedPreferences");
        } else {
          print("♻️ ŁADUJĘ ISTNIEJĄCY LAYOUT z SharedPreferences");
        }

        var js = json.decode(_preferences.getString("${id}_layout_data_")!);

        final items = js!.values
            .map<ColoredDashboardItem>(
                (value) => ColoredDashboardItem.fromMap(value))
            .toList();

        // Sort items by position to ensure consistent loading order
        // This prevents random positioning after restart
        items.sort((ColoredDashboardItem a, ColoredDashboardItem b) {
          // First sort by Y position (row)
          int yCompare = a.layoutData.startY.compareTo(b.layoutData.startY);
          if (yCompare != 0) return yCompare;
          
          // Then sort by X position (column) within the same row
          return a.layoutData.startX.compareTo(b.layoutData.startX);
        });
        
        print("📥 LOADING ${items.length} items from storage:");
        for (var item in items) {
          print("  ${item.identifier}: (${item.layoutData.startX}, ${item.layoutData.startY}) ${item.layoutData.width}x${item.layoutData.height}");
        }
        
        // Dodatkowa analiza pozycji
        print("📊 ANALIZA POZYCJI PO ZAŁADOWANIU:");
        final Map<int, List<String>> rowItems = {};
        for (var item in items) {
          final row = item.layoutData.startY;
          rowItems[row] ??= [];
          rowItems[row]!.add("${item.identifier}(${item.layoutData.startX},${item.layoutData.startY})");
        }
        
        final sortedRows = rowItems.keys.toList()..sort();
        for (var row in sortedRows) {
          print("  Rząd $row: ${rowItems[row]!.join(', ')}");
        }
        
        // Sprawdź kolizje z virtual columns (6, 13)
        print("🚫 SPRAWDZAM KOLIZJE Z VIRTUAL COLUMNS (6, 13):");
        final disabledCols = [6, 13];
        for (var item in items) {
          for (int x = item.layoutData.startX; x < item.layoutData.startX + item.layoutData.width; x++) {
            if (disabledCols.contains(x)) {
              print("  ⚠️ KOLIZJA: ${item.identifier} na kolumnie $x (disabled)");
            }
          }
        }
        
        return items;
      });
    } on Exception {
      rethrow;
    }
  }

  @override
  FutureOr<void> onItemsUpdated(
      List<ColoredDashboardItem> items, int slotCount) async {
    _setLocal();

    for (var item in items) {
      _localItems?[item.identifier] = item;
    }

    var js = json
        .encode(_localItems!.map((key, value) => MapEntry(key, value.toMap())));

    print("💾 SAVING ${items.length} updated items (pozycje po przemieszczeniu):");
    for (var item in items) {
      print("  ${item.identifier}: (${item.layoutData.startX}, ${item.layoutData.startY}) ${item.layoutData.width}x${item.layoutData.height}");
    }

    await _preferences.setString("${id}_layout_data_", js);
  }

  @override
  FutureOr<void> onItemsAdded(
      List<ColoredDashboardItem> items, int slotCount) async {
    print("➕ ADDING ${items.length} new items:");
    for (var item in items) {
      print("  ${item.identifier}: (${item.layoutData.startX}, ${item.layoutData.startY}) ${item.layoutData.width}x${item.layoutData.height}");
    }
    
    _setLocal();
    for (var i in items) {
      _localItems![i.identifier] = i;
    }

    await _preferences.setString(
        "${id}_layout_data_",
        json.encode(
            _localItems!.map((key, value) => MapEntry(key, value.toMap()))));
  }

  @override
  FutureOr<void> onItemsDeleted(
      List<ColoredDashboardItem> items, int slotCount) async {
    print("🗑️ DELETING ${items.length} items:");
    for (var item in items) {
      print("  ${item.identifier}: was at (${item.layoutData.startX}, ${item.layoutData.startY})");
    }
    
    _setLocal();
    for (var i in items) {
      _localItems?.remove(i.identifier);
    }

    await _preferences.setString(
        "${id}_layout_data_",
        json.encode(
            _localItems!.map((key, value) => MapEntry(key, value.toMap()))));
  }

  Future<void> clear() async {
    _localItems?.clear();
    await _preferences.remove("${id}_layout_data_");
    _localItems = null;
    await _preferences.setBool("init", false);
  }

  /// Resetuje cache żeby wymusić ponowne ładowanie z SharedPreferences
  void resetCache() {
    print("🔄 RESETTING CACHE - wymuszam ponowne ładowanie z SharedPreferences");
    if (_localItems != null) {
      print("🗑️ Usuwam ${_localItems!.length} elementów z cache:");
      
      // Wypisz pozycje elementów przed usunięciem z cache
      final sortedItems = _localItems!.values.toList();
      sortedItems.sort((a, b) {
        int yCompare = a.layoutData.startY.compareTo(b.layoutData.startY);
        if (yCompare != 0) return yCompare;
        return a.layoutData.startX.compareTo(b.layoutData.startX);
      });
      
      for (var item in sortedItems) {
        print("  💭 Cache miał: ${item.identifier} na (${item.layoutData.startX}, ${item.layoutData.startY})");
      }
    } else {
      print("ℹ️ Cache już był pusty");
    }
    _localItems = null;
  }

  /// Sprawdza czy cache jest pusty
  bool isCacheEmpty() {
    return _localItems == null;
  }

  void _setLocal() {
    _localItems = {for (var item in _default) item.identifier: item};
  }

  @override
  bool get layoutsBySlotCount => true;

  @override
  bool get cacheItems => true;
}
