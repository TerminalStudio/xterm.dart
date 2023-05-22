import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          SizedBox(
            height: 500,
          ),
          OverlayDemo(),
          SizedBox(
            height: 2500,
          ),
        ],
      ),
    );
  }
}

class OverlayDemo extends StatefulWidget {
  const OverlayDemo({super.key});

  @override
  State<OverlayDemo> createState() => OverlayDemoState();
}

class OverlayDemoState extends State<OverlayDemo> {
  final overlay = OverlayPortalController();
  final link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: overlay,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: link,
          child: Stack(
            children: [
              Container(
                color: Colors.yellow,
                width: 100,
                height: 100,
              ),
            ],
          ),
        );
      },
      child: MouseRegion(
        onHover: (event) {
          setState(() {
            overlay.show();
          });
        },
        onExit: (event) {
          setState(() {
            overlay.hide();
          });
        },
        child: CompositedTransformTarget(
          link: link,
          child: GestureDetector(
            onTap: () {
              debugDumpLayerTree();
            },
            child: Container(
              color: Colors.red,
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),
    );
  }
}
