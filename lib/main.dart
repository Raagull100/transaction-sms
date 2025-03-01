import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:core';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SmsQuery _query = SmsQuery();
  List<Transaction> _transactions = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Transaction SMS Reader')),
        body: _transactions.isNotEmpty
            ? ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  var txn = _transactions[index];
                  return ListTile(
                    title: Text("${txn.type} - ₹${txn.amount}"),
                    subtitle: Text("Bank: ${txn.bank}\nRef: ${txn.referenceId}"),
                    trailing: Text(txn.date),
                  );
                })
            : const Center(child: Text('No transaction SMS found. Tap refresh.')),
        floatingActionButton: FloatingActionButton(
          onPressed: _readSms,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Future<void> _readSms() async {
    var status = await Permission.sms.status;
    if (status.isGranted) {
      List<SmsMessage> messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50, // Fetch last 50 messages
      );
      
      List<Transaction> transactions = messages.map((msg) => detectTransaction(msg.body ?? "")).whereType<Transaction>().toList();
      
      setState(() => _transactions = transactions);
    } else {
      await Permission.sms.request();
    }
  }
}

Transaction? detectTransaction(String message) {
  final debitPattern = RegExp(r"(debited|withdrawn|spent|paid|purchase|transferred).*?₹?\s?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)", caseSensitive: false);
  final creditPattern = RegExp(r"(credited|received|added|deposited|refund|reversal).*?₹?\s?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)", caseSensitive: false);
  final bankPattern = RegExp(r"(?:from|to|via|at|using|through) (HDFC|SBI|ICICI|Paytm|GPay|PhonePe|Amazon Pay|Bank of America)", caseSensitive: false);
  final balancePattern = RegExp(r"(?:Available balance|Bal|Balance)[:\s]*₹?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)", caseSensitive: false);
  final refPattern = RegExp(r"(?:Ref|Ref No|Transaction ID|Txn ID)[:\s]*([A-Za-z0-9]+)", caseSensitive: false);

  Match? debitMatch = debitPattern.firstMatch(message);
  Match? creditMatch = creditPattern.firstMatch(message);
  Match? bankMatch = bankPattern.firstMatch(message);
  Match? balanceMatch = balancePattern.firstMatch(message);
  Match? refMatch = refPattern.firstMatch(message);

  String? type;
  double? amount;

  if (debitMatch != null) {
    type = "Debit";
    amount = double.parse(debitMatch.group(2)!.replaceAll(",", ""));
  } else if (creditMatch != null) {
    type = "Credit";
    amount = double.parse(creditMatch.group(2)!.replaceAll(",", ""));
  }

  if (type != null && amount != null) {
    return Transaction(
      type: type,
      amount: amount,
      bank: bankMatch?.group(1) ?? "Unknown Bank",
      date: DateTime.now().toString(),
      referenceId: refMatch?.group(1) ?? "N/A",
      balance: balanceMatch != null ? double.parse(balanceMatch.group(1)!.replaceAll(",", "")) : null,
    );
  }
  return null;
}

class Transaction {
  final String type;
  final double amount;
  final String bank;
  final String date;
  final String referenceId;
  final double? balance;

  Transaction({
    required this.type,
    required this.amount,
    required this.bank,
    required this.date,
    required this.referenceId,
    this.balance,
  });
}
