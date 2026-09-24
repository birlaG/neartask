import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import 'login_screen.dart';
import 'kyc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _saving = false;

  Future<void> _updateVisibility(String visibility) async {
    setState(() => _saving = true);
    try {
      await context.read<AuthState>().authService.updateProfile({'profileVisibility': visibility});
      await context.read<AuthState>().refreshUser();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 32, child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
          const SizedBox(height: 12),
          Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user.phone, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          Row(
            children: [
              _statTile('Completed', user.completedTasks.toString()),
              _statTile('Trust score', user.trustScore.toStringAsFixed(1)),
              _statTile('No-shows', user.noShowCount.toString()),
            ],
          ),
          const SizedBox(height: 24),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Verification tier'),
            subtitle: Text(user.verificationTier),
            trailing: user.kycStatus != 'VERIFIED'
                ? OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KycScreen()));
                      if (mounted) context.read<AuthState>().refreshUser();
                    },
                    child: const Text('Verify'),
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
          const Divider(),

          const Text('Profile visibility to other users', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Controls what applicants/creators see about you — the platform always knows your verified identity regardless of this setting.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          _visibilityOption('FULL', 'Full — name & photo visible', user.profileVisibility),
          _visibilityOption('PARTIAL', 'Partial — first name & blurred photo', user.profileVisibility),
          _visibilityOption('HIDDEN', 'Hidden — anonymized until confirmed', user.profileVisibility),

          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () async {
              await context.read<AuthState>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _visibilityOption(String value, String label, String current) => RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        value: value,
        groupValue: current,
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onChanged: _saving ? null : (v) => _updateVisibility(v!),
      );
}
