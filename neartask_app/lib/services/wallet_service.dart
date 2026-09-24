import '../models/wallet.dart';
import 'api_client.dart';

class WalletService {
  final ApiClient client;
  WalletService(this.client);

  Future<WalletBalance> getBalance() async {
    final res = await client.get('/wallet/balance');
    return WalletBalance.fromJson(res);
  }

  Future<List<WalletTransaction>> getTransactions() async {
    final res = await client.get('/wallet/transactions');
    return (res as List).map((t) => WalletTransaction.fromJson(t)).toList();
  }

  /// In production this is called only after the payment gateway SDK
  /// (Razorpay Checkout) confirms a successful payment — `gatewayRef` should
  /// be that payment's transaction ID, never a value the user can freely set.
  Future<void> topUp(double amount, String gatewayRef) =>
      client.post('/wallet/topup', body: {'amount': amount, 'gatewayRef': gatewayRef});

  Future<void> requestWithdrawal(double amount, String payoutDestination) => client.post(
        '/wallet/withdraw',
        body: {'amount': amount, 'payoutDestination': payoutDestination},
      );
}
