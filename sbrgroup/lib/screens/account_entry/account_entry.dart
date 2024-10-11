import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ajna/screens/account_entry/custom_date_picker1.dart';
import 'package:ajna/screens/api_endpoints.dart';

class Transaction {
  final int id;
  final String projectName;
  final DateTime date;
  final String remiterName;
  final String transactionType;
  final String remiterBankName;
  final String status;
  final double creditAmount;
  final double debitAmount;
  final String formattedCreditAmount;
  final String formattedDebitAmount;
  final String crDr;
  final String beneficiaryName;
  final String beneficiaryBankName;
  final String chequeNo;
  final String formattedAmount;

  Transaction({
    required this.id,
    required this.projectName,
    required this.date,
    required this.remiterName,
    required this.transactionType,
    required this.remiterBankName,
    required this.status,
    required this.creditAmount,
    required this.debitAmount,
    required this.formattedCreditAmount,
    required this.formattedDebitAmount,
    required this.crDr,
    required this.beneficiaryName,
    required this.beneficiaryBankName,
    required this.chequeNo,
    required this.formattedAmount,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      projectName: json['projectName'] ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      remiterName: json['remiterName'] ?? '',
      transactionType: json['transactionType'] ?? '',
      remiterBankName: json['remiterBankName'] ?? '',
      status: json['status'] ?? '',
      creditAmount: (json['creditAmount'] ?? 0.0).toDouble(),
      debitAmount: (json['debitAmount'] ?? 0.0).toDouble(),
      formattedCreditAmount: json['formattedCreditAmount'] != null
          ? utf8.decode(json['formattedCreditAmount'].toString().codeUnits)
          : '0.00',
      formattedDebitAmount: json['formattedDebitAmount'] != null
          ? utf8.decode(json['formattedDebitAmount'].toString().codeUnits)
          : '0.00',
      crDr: json['crDr'] ?? '',
      beneficiaryName: json['beneficiaryName'] ?? '',
      beneficiaryBankName: json['beneficiaryBankName'] ?? '',
      chequeNo: json['chequeNo'] ?? '',
      formattedAmount: json['formattedAmount'] != null
          ? utf8.decode(json['formattedAmount'].toString().codeUnits)
          : '0.00',
    );
  }
}

class AmountsDto {
  final String formattedCreditTotal;
  final String formattedDebitTotal;
  final String formattedGrandTotal;

  AmountsDto({
    required this.formattedCreditTotal,
    required this.formattedDebitTotal,
    required this.formattedGrandTotal,
  });

  factory AmountsDto.fromJson(Map<String, dynamic> json) {
    return AmountsDto(
      formattedCreditTotal: json['formattedCreditTotal'] != null
          ? utf8.decode(json['formattedCreditTotal'].toString().codeUnits)
          : '0.00',
      formattedDebitTotal: json['formattedDebitTotal'] != null
          ? utf8.decode(json['formattedDebitTotal'].toString().codeUnits)
          : '0.00',
      formattedGrandTotal: json['formattedGrandTotal'] != null
          ? utf8.decode(json['formattedGrandTotal'].toString().codeUnits)
          : '0.00',
    );
  }
}

class TransactionResponse {
  List<Transaction>? transactions;
  AmountsDto? amounts;
  final int pageNo;
  final int pageSize;
  final bool last;
  final bool first;
  final int totalPages;
  final int totalRecords;

  TransactionResponse({
    this.transactions,
    this.amounts,
    required this.pageNo,
    required this.pageSize,
    required this.last,
    required this.first,
    required this.totalPages,
    required this.totalRecords,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      transactions: (json['records'] as List)
          .map((item) => Transaction.fromJson(item))
          .toList(),
      amounts:
          json['amounts'] != null ? AmountsDto.fromJson(json['amounts']) : null,
      pageNo: json['pageNo'] ?? 0,
      pageSize: json['pageSize'] ?? 10,
      last: json['last'] ?? false,
      first: json['first'] ?? true,
      totalPages: json['totalPages'] ?? 0,
      totalRecords: json['totalRecords'] ?? 0,
    );
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  @override
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedRange = '0';
  String _selectedTotalType = '';
  TransactionResponse? transactions;
  bool _isLoading = false; // Loading state

  bool isLoadingMore = false; // To track if more data is being loaded

  // ScrollController to detect scroll events
  final ScrollController _scrollController = ScrollController();

  final int _currentPage = 0;
  int _pageSize = 10; // Define your page size

  Future<void> _fetchTransactionData({bool isLoadingMore = false}) async {
    try {
      final transactionsResponse = await ApiService.fetchAccountEntries(
        searchQuery: _searchQuery,
        beneficiaryName: '',
        transactionType: '',
        amount: '',
        minAmount: '',
        maxAmount: '',
        selectedAmountType: '',
        rangeOfDays: _selectedRange,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
        page: _currentPage,
        size: _pageSize,
      );

      final amountsResponse = await ApiService.fetchAccountEntryAmounts(
        searchQuery: _searchQuery,
        remiterName: '',
        beneficiaryName: '',
        transactionType: '',
        amount: '',
        minAmount: '',
        maxAmount: '',
        selectedAmountType: '',
        rangeOfDays: _selectedRange,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );

      if (transactionsResponse.statusCode == 200 &&
          amountsResponse.statusCode == 200) {
        final transactionsData = json.decode(transactionsResponse.body);
        final amountsData = json.decode(amountsResponse.body);

        setState(() {
          if (!isLoadingMore) {
            transactions = TransactionResponse.fromJson(transactionsData);
          } else {
            final newTransactions =
                TransactionResponse.fromJson(transactionsData);
            transactions!.transactions!.addAll(newTransactions.transactions!);
          }
          transactions!.amounts = AmountsDto.fromJson(amountsData);
        });
      } else {
        throw Exception('Failed to load transactions or amounts');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactionData(); // Call to fetch both transactions and amounts
    _scrollController.addListener(_scrollListener); // Add the scroll listener
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Don't forget to dispose the controller
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !isLoadingMore) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
      _pageSize += 10;
    });

    try {
      await _fetchTransactionData(isLoadingMore: true);
    } catch (e) {
      print('Error loading more transactions: $e');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  List<Transaction> getFilteredTransactions() {
    return transactions?.transactions?.where((transaction) {
          if (_selectedTotalType.isNotEmpty &&
              transaction.crDr != _selectedTotalType) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final searchQueryLower = _searchQuery.trim().toLowerCase();
            final remiterName = transaction.remiterName.toLowerCase().trim();
            if (!remiterName.contains(searchQueryLower)) {
              return false;
            }
          }
          return true;
        }).toList() ??
        [];
  }

  // List<Transaction> getFilteredTransactions() {
  //   return transactions?.transactions?.where((transaction) {
  //         // Filter by selected total type
  //         if (_selectedTotalType.isNotEmpty &&
  //             transaction.crDr != _selectedTotalType) {
  //           return false;
  //         }
  //         // Filter by search query
  //         if (_searchQuery.isNotEmpty) {
  //           final searchQueryLower = _searchQuery.trim().toLowerCase();
  //           final remiterName = transaction.remiterName.toLowerCase().trim();
  //           if (!remiterName.contains(searchQueryLower)) {
  //             return false;
  //           }
  //         }
  //         return true;
  //       }).toList() ??
  //       [];
  // }

  @override
  Widget build(BuildContext context) {
    List<Transaction> filteredTransactions = getFilteredTransactions();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Account Entry',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Aligns the heading to the start
          children: [
            // Search Field
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _fetchTransactionData();
                  });
                },
              ),
            ),
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(5.0),
              child: CustomDateRangePicker1(
                onDateRangeSelected: (start, end, range) {
                  setState(() {
                    _selectedStartDate = start;
                    _selectedEndDate = end;
                    _selectedRange = range;
                    _fetchTransactionData();
                  });
                },
                selectedDateRange: _selectedRange,
              ),
            ),

            SizedBox(height: 14.0),
            Column(
              children: [
                // Block for 'Cr'
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTotalType = 'Cr';
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedTotalType == 'Cr'
                          ? Colors.teal[50]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType == 'Cr'
                                    ? Colors.teal
                                    : Colors.black)),
                        Text(
                            transactions?.amounts?.formattedCreditTotal ??
                                '₹0.00',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType == 'Cr'
                                    ? Colors.teal
                                    : Colors.green)),
                      ],
                    ),
                  ),
                ),
                // Block for 'Dr'
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTotalType = 'Dr';
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedTotalType == 'Dr'
                          ? Colors.teal[50]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Debit',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType == 'Dr'
                                    ? Colors.teal
                                    : Colors.black)),
                        Text(
                            transactions?.amounts?.formattedDebitTotal ??
                                '₹0.00',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType == 'Dr'
                                    ? Colors.teal
                                    : Colors.red)),
                      ],
                    ),
                  ),
                ),
                // Block for 'Gross Total'
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTotalType = '';
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedTotalType.isEmpty
                          ? Colors.teal[50]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gross Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType.isEmpty
                                    ? Colors.teal
                                    : Colors.black)),
                        Text(
                            transactions?.amounts?.formattedGrandTotal ??
                                '₹0.00',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTotalType.isEmpty
                                    ? Colors.teal
                                    : Colors.black)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Add "Transaction Details" heading
            const Padding(
              padding: EdgeInsets.symmetric(
                  vertical: 8.0), // Adjust padding as needed
              child: Center(
                child: Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0, // Adjust the font size for the heading
                  ),
                ),
              ),
            ),
            SizedBox(height: 8), // Spacing between the heading and the list
            // Show loading indicator or transaction details
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions == null || transactions!.transactions!.isEmpty
                    ? Center(child: Text('No transactions found.'))
                    : Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredTransactions.length +
                              (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the end of the list when loading more data
                            if (isLoadingMore &&
                                index == filteredTransactions.length) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final transaction = filteredTransactions[index];
                            final screenWidth =
                                MediaQuery.of(context).size.width;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: 8.0), // Smaller margin
                              elevation:
                                  2.0, // Lower elevation for a flatter look
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    8.0), // Smaller corner radius
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    8.0), // Reduced padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row for Remitter Name and Transaction Date
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Remitter: ${transaction.remiterName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  14.0, // Smaller font size
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(
                                            width: 4.0), // Reduced space
                                        Text(
                                          '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                          style: const TextStyle(
                                            fontSize:
                                                12.0, // Smaller font size for date
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 4.0), // Reduced space

                                    // Beneficiary Name
                                    Text(
                                      'Beneficiary: ${transaction.beneficiaryName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.0, // Smaller font size
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(
                                        height: 2.0), // Reduced space

                                    // Beneficiary Bank Name
                                    Text(
                                      'Bank: ${transaction.beneficiaryBankName}',
                                      style: const TextStyle(
                                        fontSize: 12.0, // Smaller font size
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(
                                        height: 2.0), // Reduced space

                                    // Cheque Number
                                    Text(
                                      'Cheque No: ${transaction.chequeNo}',
                                      style: const TextStyle(
                                        fontSize: 12.0, // Smaller font size
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(
                                        height: 4.0), // Reduced space

                                    // Transaction Type and Remitter Bank
                                    Text(
                                      'Trns Type: ${transaction.transactionType}, Remitter Bank: ${transaction.remiterBankName}',
                                      style: const TextStyle(
                                        fontSize: 12.0, // Smaller font size
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(
                                        height: 8.0), // Reduced space

                                    // Credit and Debit amounts aligned properly
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (transaction.crDr == "Dr")
                                          Expanded(
                                            child: Text(
                                              'Debit:',
                                              style: TextStyle(
                                                fontSize: screenWidth *
                                                    0.035, // Smaller size
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        if (transaction.crDr == "Cr")
                                          Expanded(
                                            child: Text(
                                              'Credit:',
                                              style: TextStyle(
                                                fontSize: screenWidth *
                                                    0.035, // Smaller size
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          transaction.crDr == "Dr"
                                              ? transaction.formattedDebitAmount
                                              : transaction
                                                  .formattedCreditAmount,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.035,
                                            fontWeight: FontWeight.bold,
                                            color: transaction.crDr == "Dr"
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
          ],
        ),
      ),
    );
  }
}
