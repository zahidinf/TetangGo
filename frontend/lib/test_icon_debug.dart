import 'package:flutter/material.dart';

/// Test page untuk mendiagnosis masalah Material Icons
class TestIconDebug extends StatelessWidget {
  const TestIconDebug({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Icon Debug Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Material Icons Standard Test',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildIconTest(
                'holiday_village_rounded', Icons.holiday_village_rounded),
            _buildIconTest('account_balance_wallet_outlined',
                Icons.account_balance_wallet_outlined),
            _buildIconTest('shield_outlined', Icons.shield_outlined),
            _buildIconTest(
                'person_outline_rounded', Icons.person_outline_rounded),
            _buildIconTest('lock_outline_rounded', Icons.lock_outline_rounded),
            _buildIconTest('visibility_outlined', Icons.visibility_outlined),
            _buildIconTest(
                'visibility_off_outlined', Icons.visibility_off_outlined),
            _buildIconTest('info_outline_rounded', Icons.info_outline_rounded),
            _buildIconTest('error_outline', Icons.error_outline),
            const SizedBox(height: 32),
            const Text('Rendered Result: Check if icons display or show X box',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTest(String name, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 32, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Code: Icons.$name',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
