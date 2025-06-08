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
    try {
      if (_localItems != null) {
        return _localItems!.values.toList();
      }

      return Future.microtask(() async {
        _preferences = await SharedPreferences.getInstance();

        var init = _preferences.getBool("init") ?? false;

        if (!init) {
          _localItems = {for (var item in _default) item.identifier: item};

          await _preferences.setString(
              "${id}_layout_data_",
              json.encode(_default.asMap().map(
                  (key, value) => MapEntry(value.identifier, value.toMap()))));

          await _preferences.setBool("init", true);
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

    await _preferences.setString("${id}_layout_data_", js);
  }

  @override
  FutureOr<void> onItemsAdded(
      List<ColoredDashboardItem> items, int slotCount) async {
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
    _localItems = null;
  }

  /// Sprawdza czy cache jest pusty
  bool isCacheEmpty() {
    return _localItems == null;
  }

  void _setLocal() {
    // Only initialize if _localItems is null, don't reset existing data
    _localItems ??= {for (var item in _default) item.identifier: item};
  }

  @override
  bool get layoutsBySlotCount => true;

  @override
  bool get cacheItems => true;
}
