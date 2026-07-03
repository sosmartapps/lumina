import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/caregiver.dart';
import '../models/expense.dart';

/// Service for tracking caregiver out-of-pocket expenses and reimbursements.
///
/// Family members submit expenses (with receipt photos); the patient's
/// designated Finance Manager (or primary caregiver) approves/rejects and
/// records reimbursement.
class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  CollectionReference get _expenses => _firestore.collection('expenses');

  // ---------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------

  /// Whether [caregiver] can approve/reject/reimburse expenses for [patient].
  ///
  /// True if the caregiver's effective role for the patient is
  /// financeManager, or (fallback so approvals are never orphaned) the
  /// caregiver is the patient's primary caregiver.
  static bool canManageFinances(Caregiver caregiver, AppUser patient) {
    final role = caregiver.roleForPatient(patient.id);
    return role == CaregiverRole.financeManager ||
        role == CaregiverRole.primaryCaregiver ||
        caregiver.id == patient.primaryCaregiverId;
  }

  // ---------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------

  Future<Expense> createExpense(Expense expense) async {
    final docRef = await _expenses.add(expense.toFirestore());
    final doc = await docRef.get();
    return Expense.fromFirestore(doc);
  }

  Future<void> updateExpense(Expense expense) async {
    await _expenses.doc(expense.id).update(expense.toFirestore());
  }

  /// Deletes an expense and its receipt photos. Only allowed while pending.
  Future<void> deleteExpense(Expense expense) async {
    for (final url in expense.receiptUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Receipt already gone — don't block the delete.
      }
    }
    await _expenses.doc(expense.id).delete();
  }

  // ---------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------

  /// All expenses for a patient, newest purchase first.
  Stream<List<Expense>> getExpenses(String userId) {
    return _expenses
        .where('userId', isEqualTo: userId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromFirestore).toList());
  }

  /// Expenses awaiting approval for a patient.
  Stream<List<Expense>> getPendingExpenses(String userId) {
    return _expenses
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: ExpenseStatus.submitted.value)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromFirestore).toList());
  }

  /// Single expense, live.
  Stream<Expense?> watchExpense(String expenseId) {
    return _expenses.doc(expenseId).snapshots().map(
        (doc) => doc.exists ? Expense.fromFirestore(doc) : null);
  }

  // ---------------------------------------------------------------------
  // Status transitions
  // ---------------------------------------------------------------------

  Future<void> approveExpense({
    required Expense expense,
    required String reviewerId,
    required String reviewerName,
    String? note,
  }) async {
    await _expenses.doc(expense.id).update({
      'status': ExpenseStatus.approved.value,
      'reviewedBy': reviewerId,
      'reviewedByName': reviewerName,
      'reviewedAt': Timestamp.now(),
      'reviewNote': note,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> rejectExpense({
    required Expense expense,
    required String reviewerId,
    required String reviewerName,
    required String reason,
  }) async {
    await _expenses.doc(expense.id).update({
      'status': ExpenseStatus.rejected.value,
      'reviewedBy': reviewerId,
      'reviewedByName': reviewerName,
      'reviewedAt': Timestamp.now(),
      'reviewNote': reason,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> markReimbursed({
    required Expense expense,
    required ReimbursementMethod method,
    String? note,
    DateTime? paidAt,
  }) async {
    await _expenses.doc(expense.id).update({
      'status': ExpenseStatus.reimbursed.value,
      'reimbursedAt': Timestamp.fromDate(paidAt ?? DateTime.now()),
      'reimbursementMethod': method.value,
      'reimbursementNote': note,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Resubmit a rejected expense (e.g., after fixing the amount/receipt).
  Future<void> resubmitExpense(Expense expense) async {
    await _expenses.doc(expense.id).update({
      'status': ExpenseStatus.submitted.value,
      'reviewedBy': null,
      'reviewedByName': null,
      'reviewedAt': null,
      'reviewNote': null,
      'updatedAt': Timestamp.now(),
    });
  }

  // ---------------------------------------------------------------------
  // Receipt photos
  // ---------------------------------------------------------------------

  Future<File?> captureReceiptPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return null;
    return File(image.path);
  }

  Future<File?> pickReceiptFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return null;
    return File(image.path);
  }

  /// Upload a receipt photo; returns the download URL.
  /// Storage path: expense_receipts/{patientUserId}/{timestamp}.jpg
  Future<String> uploadReceipt({
    required File file,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'expense_receipts/$userId/$timestamp.jpg';
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ---------------------------------------------------------------------
  // Balances
  // ---------------------------------------------------------------------

  /// Amount still owed (approved but not yet reimbursed) per submitter uid.
  static Map<String, double> owedBySubmitter(List<Expense> expenses) {
    final owed = <String, double>{};
    for (final e in expenses) {
      if (e.status == ExpenseStatus.approved) {
        owed[e.submittedBy] = (owed[e.submittedBy] ?? 0) + e.amount;
      }
    }
    return owed;
  }

  /// Total for a set of expenses matching [status].
  static double totalFor(List<Expense> expenses, ExpenseStatus status) {
    return expenses
        .where((e) => e.status == status)
        .fold(0.0, (acc, e) => acc + e.amount);
  }
}
