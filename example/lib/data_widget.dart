import 'package:auto_size_text/auto_size_text.dart';
import 'package:dashboard/dashboard.dart';
import 'package:example/storage.dart';
import 'package:example/performance_optimizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

const Color blue = Color(0xFF4285F4);
const Color red = Color(0xFFEA4335);
const Color yellow = Color(0xFFFBBC05);
const Color green = Color(0xFF34A853);

class DataWidget extends StatelessWidget {
  DataWidget({super.key, required this.item});

  final ColoredDashboardItem item;

  final Map<String, Widget Function(ColoredDashboardItem i)> _map = {
    "welcome": (l) => const WelcomeWidget(),
    "resize": (l) => AdviceResize(size: l.layoutData.width),
    "description": (l) => const BasicDescription(),
    "transform": (l) => const TransformAdvice(),
    "add": (l) => const AddAdvice(),
    "buy_mee": (l) => const BuyMee(),
    "delete": (l) => const ClearAdvice(),
    "refresh": (l) => const DefaultAdvice(),
    "info": (l) => InfoAdvice(layout: l.layoutData),
    "github": (l) => const Github(),
    "twitter": (l) => const Twitter(),
    "linkedin": (l) => const LinkedIn(),
    "pub": (l) => const Pub(),
  };

  @override
  Widget build(BuildContext context) {
    return _map[item.data]!(item);
  }
}

class Pub extends StatelessWidget {
  const Pub({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrlString("https://pub.dev/packages/dashboard");
      },
      child: PerformantPaintedDashboardItem(
        color: Colors.white,
        child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                image: DecorationImage(
                    fit: BoxFit.contain,
                    image: AssetImage("assets/pub_dev.png")))),
      ),
    );
  }
}

class LinkedIn extends StatelessWidget {
  const LinkedIn({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrlString("https://www.linkedin.com/in/mehmetyaz/");
      },
      child: PerformantPaintedDashboardItem(
        color: const Color(0xFF0A66C2),
        child: Row(
          children: [
            const Expanded(
                child: Padding(
              padding: EdgeInsets.all(8.0),
              child: AutoSizeText("Connect Me!",
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  textAlign: TextAlign.center),
            )),
            Expanded(
              child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      image: DecorationImage(
                          fit: BoxFit.contain,
                          image: AssetImage("assets/linkedin.png")))),
            ),
          ],
        ),
      ),
    );
  }
}

class Twitter extends StatelessWidget {
  const Twitter({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrlString("https://twitter.com/smehmetyaz");
      },
      child: PerformantPaintedDashboardItem(
        color: const Color(0xFF1DA0F1),
        child: Row(
          children: [
            const Expanded(
                child: Padding(
              padding: EdgeInsets.all(8.0),
              child: AutoSizeText("Follow Me!",
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  textAlign: TextAlign.center),
            )),
            Expanded(
              child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      image: DecorationImage(
                          fit: BoxFit.contain,
                          image: AssetImage("assets/twitter.png")))),
            ),
          ],
        ),
      ),
    );
  }
}

class Github extends StatelessWidget {
  const Github({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrlString("https://github.com/Mehmetyaz/dashboard");
      },
      child: PerformantPaintedDashboardItem(
        color: Colors.white,
        child: Row(
          children: [
            const Expanded(
                child: Padding(
              padding: EdgeInsets.all(8.0),
              child: AutoSizeText(
                "Create Issue!",
                style: TextStyle(color: Colors.black),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            )),
            Expanded(
              child: Container(
                  margin: const EdgeInsets.all(5),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      image: DecorationImage(
                          fit: BoxFit.contain,
                          image: AssetImage("assets/github.png")))),
            ),
          ],
        ),
      ),
    );
  }
}

class BuyMee extends StatelessWidget {
  const BuyMee({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrlString("https://www.buymeacoffee.com/mehmetyaz");
      },
      child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              image: DecorationImage(
                  fit: BoxFit.cover, image: AssetImage("assets/img.png")))),
    );
  }
}

class InfoAdvice extends StatelessWidget {
  const InfoAdvice({super.key, required this.layout});

  final ItemLayout layout;

  @override
  Widget build(BuildContext context) {
    return Container(
        color: blue,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            const Flexible(
              child: AutoSizeText(
                  "Example dimensions and locations. (showing this)",
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  textAlign: TextAlign.center),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: DataTable(
                    headingRowHeight: 25,
                    border: const TableBorder(
                        horizontalInside: BorderSide(color: Colors.white)),
                    headingTextStyle: const TextStyle(color: Colors.white),
                    dataTextStyle: const TextStyle(color: Colors.white),
                    columns: const [
                      DataColumn(label: Text("startX")),
                      DataColumn(label: Text("startY")),
                      DataColumn(label: Text("width")),
                      DataColumn(label: Text("height"))
                    ],
                    rows: [
                      DataRow(cells: [
                        DataCell(Text(layout.startX.toString())),
                        DataCell(Text(layout.startY.toString())),
                        DataCell(Text(layout.width.toString())),
                        DataCell(Text(layout.height.toString())),
                      ])
                    ]),
              ),
            ),
          ],
        ));
  }
}

class DefaultAdvice extends StatelessWidget {
  const DefaultAdvice({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: yellow,
      text: "Your layout changes saved locally. Set default with this button.",
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      icon: Icons.refresh,
      iconColor: Colors.white,
    );
  }
}

class ClearAdvice extends StatelessWidget {
  const ClearAdvice({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: green,
      text: "Delete all widgets.",
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      icon: Icons.delete,
      iconColor: Colors.white,
    );
  }
}

class AddAdvice extends StatelessWidget {
  const AddAdvice({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: blue,
      text: "Add own colored widget with custom sizes.",
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      icon: Icons.add,
      iconColor: Colors.white,
    );
  }
}

class TransformAdvice extends StatelessWidget {
  const TransformAdvice({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: red,
      text: "Users can move widgets.\n\n"
          "To try moving, hold (or long press) the widget and move.\n\n"
          "While moving, it shrinks if possible according to the "
          "minimum width and height values.\n(This min w: 2 , h: 2)",
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
    );
  }
}

class WelcomeWidget extends StatelessWidget {
  const WelcomeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: blue,
      text: "Welcome to dashboard online demo!",
      textStyle: const TextStyle(color: Colors.white, fontSize: 18),
      icon: Icons.waving_hand,
      iconColor: Colors.white,
    );
  }
}

class BasicDescription extends StatelessWidget {
  const BasicDescription({super.key});

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: yellow,
      text:
          "Each widget is \"DashboardItem\" with location and dimensions by slots. Switch to edit mode to see slots.",
      textStyle: const TextStyle(color: Colors.white, fontSize: 10),
      icon: Icons.edit,
      iconColor: Colors.white,
    );
  }
}

class AdviceResize extends StatelessWidget {
  const AdviceResize({super.key, required this.size});

  final int size;

  @override
  Widget build(BuildContext context) {
    return UltraPerformantDashboardItem(
      color: green,
      text: "Users can resize widgets.\n\n"
          "To try resizing, hold (or long press) the widget and drag the edges.\n\n"
          "While resizing, it shrinks if possible according to the "
          "minimum width and height values.\n(This min w: 2 , h: 2)",
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
    );
  }
}
