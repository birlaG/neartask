class WalletBalance {
  final double available;
  final double locked;

  WalletBalance({required this.available, required this.locked});

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        available: double.tryParse(json['available'].toString()) ?? 0,
        locked: double.tryParse(json['locked'].toString()) ?? 0,
      );
}

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String status;
  final String? note;
  final String createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'],
        type: json['type'],
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        status: json['status'] ?? 'COMPLETED',
        note: json['note'],
        createdAt: json['createdAt'],
      );
}
