import 'package:flutter/material.dart';

class IOSInstallSheet extends StatelessWidget {
  const IOSInstallSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const IOSInstallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Install MOYD App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add to your home screen for the best experience',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildStep(
              number: 1,
              icon: Icons.ios_share,
              title: 'Tap the Share button',
              subtitle: 'At the bottom of Safari',
            ),
            const SizedBox(height: 16),
            _buildStep(
              number: 2,
              icon: Icons.add_box_outlined,
              title: 'Tap "Add to Home Screen"',
              subtitle: 'Scroll down in the share menu',
            ),
            const SizedBox(height: 16),
            _buildStep(
              number: 3,
              icon: Icons.check_circle_outline,
              title: 'Tap "Add"',
              subtitle: 'App will appear on your home screen',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
