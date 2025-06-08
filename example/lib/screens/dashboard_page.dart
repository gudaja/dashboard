import 'dart:convert';
import 'dart:math';

import 'package:dashboard/dashboard.dart';
import 'package:example/add_dialog.dart';
import 'package:example/data_widget.dart';
import 'package:example/storage.dart';
import 'package:example/performance_optimizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MySlotBackground extends SlotBackgroundBuilder<ColoredDashboardItem> {
  @override
  Widget? buildBackground(BuildContext context, ColoredDashboardItem? item,
      int x, int y, bool editing) {
    if (item != null) {
      return CachedSlotBackground(
        cacheKey: '${item.identifier}_${x}_$y',
        child: Container(
          decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6)),
        ),
      );
    }

    return null;
  }
}

class ItemDisplayWidget extends StatelessWidget {
  const ItemDisplayWidget({
    super.key,
    required this.item,
    required this.isEditing,
    required this.onDelete,
    this.borderRadius = 10.0,
  });

  final ColoredDashboardItem item;
  final bool isEditing;
  final VoidCallback onDelete;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final layout = item.layoutData;

    final textContent = "ID: ${item.identifier}\n${[
      "x: ${layout.startX}",
      "y: ${layout.startY}",
      "w: ${layout.width}",
      "h: ${layout.height}",
      if (layout.minWidth != 1) "minW: ${layout.minWidth}",
      if (layout.minHeight != 1) "minH: ${layout.minHeight}",
      if (layout.maxWidth != null) "maxW: ${layout.maxWidth}",
      if (layout.maxHeight != null) "maxH : ${layout.maxHeight}"
    ].join("\n")}";

    return PerformantDashboardItem(
      child: OptimizedDashboardContainer(
        color: item.color ?? Colors.grey,
        borderRadius: borderRadius,
        child: Stack(
          children: [
            SizedBox(
                width: double.infinity,
                height: double.infinity,
                child:
                    DashboardPerformanceUtils.createOptimizedText(textContent)),
            if (isEditing)
              Positioned(
                  right: 5,
                  top: 5,
                  child: InkResponse(
                      radius: 20,
                      onTap: onDelete,
                      child: const Icon(
                        Icons.clear,
                        color: Colors.white,
                        size: 20,
                      )))
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController scrollController = ScrollController();

  late var _itemController =
      DashboardItemController<ColoredDashboardItem>.withDelegate(
          itemStorageDelegate: storage);

  bool refreshing = false;

  MyItemStorage storage = MyItemStorage();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //var dummyItemController =
  //    DashboardItemController<ColoredDashboardItem>(items: []);

  DashboardItemController<ColoredDashboardItem> get itemController =>
      _itemController;

  int? slot = 20;

  void setSlot() {
    setState(() {
      // slot = w > 600
      //     ? w > 900
      //         ? 10
      //         : 6
      //     : 4;
    });
  }

  List<String> d = [];

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;

    // Calculate dynamic border radius for items based on slot size
    final slotWidth = (w - 16) / slot!; // subtract padding
    final itemBorderRadius = (slotWidth * 0.08).clamp(4.0, 15.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4285F4),
        automaticallyImplyLeading: false,
                actions: [
          IconButton(
              onPressed: () async {
                await storage.clear();
                setState(() {
                  refreshing = true;
                });
                storage = MyItemStorage();
                _itemController = DashboardItemController.withDelegate(
                    itemStorageDelegate: storage);
                Future.delayed(const Duration(milliseconds: 150)).then((value) {
                  setState(() {
                    refreshing = false;
                  });
                });
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset do domyślnych'),
          IconButton(
              onPressed: () async {
                await reloadFromStorage();
              },
              icon: const Icon(Icons.download),
              tooltip: 'Przeładuj z storage'),
          IconButton(
              onPressed: () async {
                await printCurrentConfiguration();
              },
              icon: const Icon(Icons.info_outline),
              tooltip: 'Wypisz SharedPreferences'),
          IconButton(
              onPressed: () {
                itemController.clear();
              },
              icon: const Icon(Icons.delete),
              tooltip: 'Usuń wszystkie elementy'),
          IconButton(
              onPressed: () {
                add(context);
              },
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj nowy element'),
          IconButton(
              onPressed: () {
                print("✏️ TOGGLE EDIT MODE: ${!itemController.isEditing ? 'WŁĄCZAM' : 'WYŁĄCZAM'} edycję");
                itemController.isEditing = !itemController.isEditing;
                setState(() {});
              },
              icon: !itemController.isEditing
                  ? const Icon(Icons.edit)
                  : const Icon(Icons.check),
              tooltip: !itemController.isEditing
                  ? 'Włącz tryb edycji'
                  : 'Zakończ edycję'),
        ],
      ),
      body: SafeArea(
        child: refreshing
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Dashboard<ColoredDashboardItem>(
                scrollController: scrollController,
                shrinkToPlace: false,
                slideToTop: false,
                absorbPointer: false,
                slotBackgroundBuilder:
                    SlotBackgroundBuilder.withDimensionsFunction((context, item,
                        x, y, editing, slotWidth, slotHeight, virtualConfig) {
                  // Show disabled columns in red using config
                  final isDisabled =
                      virtualConfig?.isColumnDisabled(x) ?? false;

                  // Calculate dynamic border radius (5% of slot width, max 10px)
                  final borderRadius = (slotWidth * 0.05).clamp(2.0, 10.0);

                  return isDisabled
                      ? null
                      : Container(
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.black12, width: 0.5),
                            borderRadius: BorderRadius.circular(borderRadius),
                            color: null,
                          ),
                          child: null,
                        );
                }),
                padding: const EdgeInsets.all(8),
                horizontalSpace: 8,
                verticalSpace: 8,
                slotAspectRatio: 1,
                animateEverytime: false,
                cacheExtend: 250,
                dashboardItemController: itemController,
                slotCount: slot!,
                virtualColumnsConfig: const VirtualColumnsConfig.visible(
                  disabledColumns: [6, 13],
                  disabledColumnWidth: 0.03,
                ),
                errorPlaceholder: (e, s) {
                  return Text("$e , $s");
                },
                emptyPlaceholder: const Center(child: Text("Empty")),
                itemStyle: ItemStyle(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(itemBorderRadius))),
                physics: const RangeMaintainingScrollPhysics()
                    .applyTo(ClampingScrollPhysics()),
                editModeSettings: EditModeSettings(
                    draggableOutside: false,
                    paintBackgroundLines: false,
                    autoScroll: true,
                    resizeCursorSide: 40,
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 200),
                    resizeHandleBuilder: (context, item, isEditing) {
                      return Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: 3.14159 / 2, // 180 stopni
                          child: const Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      );
                    },
                    backgroundStyle: const EditModeBackgroundStyle(
                        lineColor: Colors.black38,
                        lineWidth: 0.5,
                        dualLineHorizontal: false,
                        dualLineVertical: false)),
                itemBuilder: (ColoredDashboardItem item) {
                  if (item.data != null) {
                    return DataWidget(
                      item: item,
                    );
                  }

                  return ItemDisplayWidget(
                    item: item,
                    isEditing: itemController.isEditing,
                    onDelete: () {
                      itemController.delete(item.identifier);
                    },
                    borderRadius: itemBorderRadius,
                  );
                },
              ),
      ),
    );
  }

    /// Przeładowuje konfigurację z storage bez czyszczenia
  Future<void> reloadFromStorage() async {
    print("🔄 RELOAD FROM STORAGE - START");
    
    setState(() {
      refreshing = true;
    });
    
    try {
      // Odśwież cache storage żeby wymusić ponowne załadowanie
      storage.resetCache();
      
      // Stwórz nowy controller który załaduje elementy z storage
      _itemController = DashboardItemController.withDelegate(
          itemStorageDelegate: storage);
      
      // Poczekaj chwilę na inicjalizację
      await Future.delayed(const Duration(milliseconds: 300));
      
      setState(() {
        refreshing = false;
      });
      
      print("🔄 RELOAD FROM STORAGE - COMPLETE");
      print("🔍 SPRAWDZAM AKTUALNY STAN KONTROLERA...");
      
      // Sprawdź czy kontroler ma elementy  
      try {
        final itemCount = _itemController.items.length;
        print("📋 KONTROLER MA $itemCount elementów");
      } catch (e) {
        print("⚠️ NIE MOŻNA SPRAWDZIĆ KONTROLERA: $e");
      }
      
    } catch (e) {
      print("❌ RELOAD ERROR: $e");
      setState(() {
        refreshing = false;
      });
    }
  }

  /// Wypisuje zawartość SharedPreferences
  Future<void> printCurrentConfiguration() async {
    print("🔍 ===== ZAWARTOŚĆ SHARED PREFERENCES =====");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final layoutData = prefs.getString("${storage.id}_layout_data_");
      final initFlag = prefs.getBool("init");
      
      
      
             if (layoutData != null) {
         try {
           final decoded = json.decode(layoutData);
           print("📥 SHARED PREFERENCES ${decoded.length} items:");
           
           // Konwertuj i posortuj dla czytelności
           final items = decoded.values
               .map<ColoredDashboardItem>((value) => ColoredDashboardItem.fromMap(value))
               .toList();
           
           items.sort((ColoredDashboardItem a, ColoredDashboardItem b) {
             int yCompare = a.layoutData.startY.compareTo(b.layoutData.startY);
             if (yCompare != 0) return yCompare;
             return a.layoutData.startX.compareTo(b.layoutData.startX);
           });
           
           for (var item in items) {
             print("  ${item.identifier}: (${item.layoutData.startX}, ${item.layoutData.startY})");
           }
           
         } catch (e) {
           print("  ❌ Error parsing layout data: $e");
         }
       } else {
         print("  ❌ No layout data found in SharedPreferences");
       }
      
      
      
    } catch (e) {
      print("❌ Error reading SharedPreferences: $e");
    }
    
    print("🔍 ===== KONIEC ZAWARTOŚCI =====");
  }

  Future<void> add(BuildContext context) async {
    var res = await showDialog(
        context: context,
        builder: (c) {
          return const AddDialog();
        });

    if (res != null) {
      final newId = (Random().nextInt(100000) + 4).toString();
      print("➕ ADDING NEW ITEM: $newId with size ${res[0]}x${res[1]}");
      
      itemController.add(
          ColoredDashboardItem(
              color: res[6],
              width: res[0],
              height: res[1],
              startX: 0,
              startY: 0,
              identifier: newId,
              minWidth: res[2],
              minHeight: res[3],
              maxWidth: res[4] == 0 ? null : res[4],
              maxHeight: res[5] == 0 ? null : res[5]),
          mountToTop: false);
    }
  }
}
