import 'package:bug_reporter/bug_reporter.dart';
import 'package:flutter/material.dart';

/// Thin wrapper that exposes the shared bug_reporter package
/// as a Lumina feature screen accessible from settings/nav.
class BugReportScreen extends StatelessWidget {
  const BugReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Bug')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bug_report, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Found a problem or have a suggestion?',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap below to submit a report with screenshots, '
                'voice notes, and photos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => BugReportSheet.show(context),
                icon: const Icon(Icons.send),
                label: const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
