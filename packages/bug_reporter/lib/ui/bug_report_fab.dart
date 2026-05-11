import 'package:flutter/material.dart';
import 'bug_report_sheet.dart';

/// Persistent draggable floating bug-report button.
/// Wrap your app's root widget with this overlay.
class BugReportFab extends StatefulWidget {
  final Widget child;

  const BugReportFab({super.key, required this.child});

  @override
  State<BugReportFab> createState() => _BugReportFabState();
}

class _BugReportFabState extends State<BugReportFab> {
  double _right = 4;
  double _bottom = 120;
  double _opacity = 0.5;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: _right,
          bottom: _bottom,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              _right = (_right - d.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - 44);
              _bottom = (_bottom - d.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 44);
              _opacity = 1.0;
            }),
            onPanEnd: (_) => setState(() => _opacity = 0.5),
            child: Opacity(
              opacity: _opacity,
              child: SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: 'bug_report_fab',
                  mini: true,
                  backgroundColor: Colors.red.shade700,
                  elevation: 2,
                  onPressed: () {
                    setState(() => _opacity = 1.0);
                    BugReportSheet.show(context);
                  },
                  child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
