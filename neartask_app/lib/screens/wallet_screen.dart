import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../state/auth_state.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletBalance? _balance;
  List<WalletTransaction> _transactions = [];
  bool _loading = true;
  late WalletService _walletService;

  @override
  void initState() {
    super.initState();
    _walletService = WalletService(context.read<AuthState>().client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final balance = await _walletService.getBalance();
    final txns = await _walletService.getTransactions();
    setState(() {
      _balance = balance;
      _transactions = txns;
      _loading = false;
    });
  }

  Future<void> _showTopUpDialog() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'In production this opens the Razorpay/Cashfree checkout SDK here. '
              'This dev build just simulates a successful top-up.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    await _walletService.topUp(amount, 'DEV-SIMULATED-${DateTime.now().millisecondsSinceEpoch}');
    _load();
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    final destinationController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(labelText: 'UPI ID or bank details'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Withdrawals are processed manually and typically take 24–48 hours.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request')),
        ],
      ),
    );
    if (result != true) return;
    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0 || destinationController.text.trim().isEmpty) return;
    await _walletService.requestWithdrawal(amount, destinationController.text.trim());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available balance', style: TextStyle(fontSize: 13)),
                          Text('₹${_balance?.available.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('₹${_balance?.locked.toStringAsFixed(2) ?? '0.00'} locked in active gigs',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: _showTopUpDialog, child: const Text('Add money')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(onPressed: _showWithdrawDialog, child: const Text('Withdraw')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Transaction history', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty) const Text('No transactions yet.'),
                  ..._transactions.map((t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_labelFor(t.type)),
                        subtitle: Text(t.note ?? ''),
                        trailing: Text('₹${t.amount.toStringAsFixed(2)}'),
                      )),
                ],
              ),
            ),
    );
  }

  String _labelFor(String type) {
    switch (type) {
      case 'TOPUP':
        return 'Added money';
      case 'LOCK':
        return 'Locked for a gig';
      case 'REFUND_UNLOCK':
        return 'Refund';
      case 'RELEASE_TO_DOER':
        return 'Gig payout';
      case 'COMMISSION':
        return 'Platform fee';
      case 'WITHDRAWAL_REQUEST':
        return 'Withdrawal requested';
      case 'WITHDRAWAL_PAID':
        return 'Withdrawal paid';
      default:
        return type;
    }
  }
}
