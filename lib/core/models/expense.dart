import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle status of a caregiver expense.
enum ExpenseStatus {
  submitted('submitted'),
  approved('approved'),
  rejected('rejected'),
  reimbursed('reimbursed');

  final String value;
  const ExpenseStatus(this.value);

  static ExpenseStatus fromString(String value) {
    return ExpenseStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExpenseStatus.submitted,
    );
  }

  String get displayName {
    switch (this) {
      case ExpenseStatus.submitted:
        return 'Pending Approval';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.reimbursed:
        return 'Reimbursed';
    }
  }
}

/// Category of a caregiver expense.
enum ExpenseCategory {
  groceries('groceries'),
  medical('medical'),
  household('household'),
  transportation('transportation'),
  clothing('clothing'),
  utilities('utilities'),
  personalCare('personal_care'),
  other('other');

  final String value;
  const ExpenseCategory(this.value);

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExpenseCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.groceries:
        return 'Groceries';
      case ExpenseCategory.medical:
        return 'Medical';
      case ExpenseCategory.household:
        return 'Household';
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.clothing:
        return 'Clothing';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.personalCare:
        return 'Personal Care';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

/// How a reimbursement was paid out.
enum ReimbursementMethod {
  cash('cash'),
  check('check'),
  zelle('zelle'),
  venmo('venmo'),
  paypal('paypal'),
  bankTransfer('bank_transfer'),
  other('other');

  final String value;
  const ReimbursementMethod(this.value);

  static ReimbursementMethod fromString(String value) {
    return ReimbursementMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReimbursementMethod.other,
    );
  }

  String get displayName {
    switch (this) {
      case ReimbursementMethod.cash:
        return 'Cash';
      case ReimbursementMethod.check:
        return 'Check';
      case ReimbursementMethod.zelle:
        return 'Zelle';
      case ReimbursementMethod.venmo:
        return 'Venmo';
      case ReimbursementMethod.paypal:
        return 'PayPal';
      case ReimbursementMethod.bankTransfer:
        return 'Bank Transfer';
      case ReimbursementMethod.other:
        return 'Other';
    }
  }
}

/// An out-of-pocket expense a family member/caregiver paid on behalf of
/// the patient, tracked for reimbursement.
///
/// Lifecycle: submitted -> approved | rejected; approved -> reimbursed.
class Expense {
  final String id;

  /// The patient this expense was paid on behalf of.
  final String userId;

  /// Caregiver (Firebase Auth uid) who paid and submitted the expense.
  final String submittedBy;
  final String submittedByName;

  final double amount;
  final String merchant;
  final ExpenseCategory category;
  final String? description;

  /// Date the purchase was made (not the submission date).
  final DateTime expenseDate;

  /// Download URLs of receipt photos in Firebase Storage.
  final List<String> receiptUrls;

  /// Raw OCR text captured from the receipt scan (audit/debug aid).
  final String? ocrRawText;

  final ExpenseStatus status;

  // Approval audit trail
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  /// Approval note or rejection reason.
  final String? reviewNote;

  // Reimbursement audit trail
  final DateTime? reimbursedAt;
  final ReimbursementMethod? reimbursementMethod;
  final String? reimbursementNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.userId,
    required this.submittedBy,
    required this.submittedByName,
    required this.amount,
    required this.merchant,
    this.category = ExpenseCategory.other,
    this.description,
    required this.expenseDate,
    this.receiptUrls = const [],
    this.ocrRawText,
    this.status = ExpenseStatus.submitted,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
    this.reimbursedAt,
    this.reimbursementMethod,
    this.reimbursementNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPending => status == ExpenseStatus.submitted;
  bool get isSettled => status == ExpenseStatus.reimbursed;

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      userId: data['userId'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submittedByName: data['submittedByName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      merchant: data['merchant'] ?? '',
      category: ExpenseCategory.fromString(data['category'] ?? 'other'),
      description: data['description'],
      expenseDate:
          (data['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receiptUrls: List<String>.from(data['receiptUrls'] ?? []),
      ocrRawText: data['ocrRawText'],
      status: ExpenseStatus.fromString(data['status'] ?? 'submitted'),
      reviewedBy: data['reviewedBy'],
      reviewedByName: data['reviewedByName'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNote: data['reviewNote'],
      reimbursedAt: (data['reimbursedAt'] as Timestamp?)?.toDate(),
      reimbursementMethod: data['reimbursementMethod'] != null
          ? ReimbursementMethod.fromString(data['reimbursementMethod'])
          : null,
      reimbursementNote: data['reimbursementNote'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'amount': amount,
      'merchant': merchant,
      'category': category.value,
      'description': description,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'receiptUrls': receiptUrls,
      'ocrRawText': ocrRawText,
      'status': status.value,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewNote': reviewNote,
      'reimbursedAt':
          reimbursedAt != null ? Timestamp.fromDate(reimbursedAt!) : null,
      'reimbursementMethod': reimbursementMethod?.value,
      'reimbursementNote': reimbursementNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  Expense copyWith({
    double? amount,
    String? merchant,
    ExpenseCategory? category,
    String? description,
    DateTime? expenseDate,
    List<String>? receiptUrls,
    String? ocrRawText,
    ExpenseStatus? status,
    String? reviewedBy,
    String? reviewedByName,
    DateTime? reviewedAt,
    String? reviewNote,
    DateTime? reimbursedAt,
    ReimbursementMethod? reimbursementMethod,
    String? reimbursementNote,
  }) {
    return Expense(
      id: id,
      userId: userId,
      submittedBy: submittedBy,
      submittedByName: submittedByName,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      receiptUrls: receiptUrls ?? this.receiptUrls,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
      reimbursedAt: reimbursedAt ?? this.reimbursedAt,
      reimbursementMethod: reimbursementMethod ?? this.reimbursementMethod,
      reimbursementNote: reimbursementNote ?? this.reimbursementNote,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
