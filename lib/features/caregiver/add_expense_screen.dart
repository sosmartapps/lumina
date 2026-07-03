import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Screen for a family member/caregiver to submit an out-of-pocket
/// expense for reimbursement. Receipt photo -> OCR pre-fill -> editable
/// form -> submit.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<File> _receiptFiles = [];
  String? _ocrRawText;
  DateTime _expenseDate = DateTime.now();
  ExpenseCategory _category = ExpenseCategory.groceries;
  bool _scanning = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addReceipt({required bool fromCamera}) async {
    final expenseService = ref.read(expenseServiceProvider);
    final file = fromCamera
        ? await expenseService.captureReceiptPhoto()
        : await expenseService.pickReceiptFromGallery();
    if (file == null || !mounted) return;

    setState(() {
      _receiptFiles.add(file);
      _scanning = true;
    });

    // OCR only the first receipt to pre-fill the form.
    if (_receiptFiles.length == 1) {
      try {
        final scanService = ref.read(receiptScanServiceProvider);
        final result = await scanService.scanReceiptFile(file);
        if (!mounted) return;
        setState(() {
          _ocrRawText = result.rawText;
          if (result.totalAmount != null && _amountController.text.isEmpty) {
            _amountController.text =
                result.totalAmount!.toStringAsFixed(2);
          }
          if (result.merchant != null && _merchantController.text.isEmpty) {
            _merchantController.text = result.merchant!;
          }
          if (result.purchaseDate != null) {
            _expenseDate = result.purchaseDate!;
          }
        });
        if (result.foundAnything) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Receipt scanned — please review before submitting'),
            ),
          );
        }
      } catch (e) {
        // OCR failure is non-fatal — user fills the form manually.
        debugPrint('Receipt OCR failed: $e');
      }
    }

    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = ref.read(caregiverNotifierProvider);
    final user = provider.selectedUser;
    final caregiver = provider.caregiver;
    if (user == null || caregiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient selected')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final expenseService = ref.read(expenseServiceProvider);

      // Upload receipts first so the expense doc is complete on create.
      final receiptUrls = <String>[];
      for (final file in _receiptFiles) {
        final url = await expenseService.uploadReceipt(
          file: file,
          userId: user.id,
        );
        receiptUrls.add(url);
      }

      final expense = Expense(
        id: '',
        userId: user.id,
        submittedBy: caregiver.id,
        submittedByName: caregiver.name,
        amount: double.parse(_amountController.text.trim()),
        merchant: _merchantController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        expenseDate: _expenseDate,
        receiptUrls: receiptUrls,
        ocrRawText: _ocrRawText,
      );

      await expenseService.createExpense(expense);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense submitted for approval')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildReceiptSection(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = double.tryParse((value ?? '').trim());
                if (v == null || v <= 0) return 'Enter a valid amount';
                if (v > 99999) return 'Amount looks too large';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant / Store',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter the store or merchant'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: ExpenseCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Purchase Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('EEEE, MMM d, yyyy').format(_expenseDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., Weekly groceries for Mom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _submitting ? 'Submitting…' : 'Submit for Reimbursement',
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Receipt Photos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_scanning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_receiptFiles.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _receiptFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _receiptFiles[index],
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _receiptFiles.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning
                      ? null
                      : () => _addReceipt(fromCamera: true),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'Camera',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning
                      ? null
                      : () => _addReceipt(fromCamera: false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text(
                    'Gallery',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scanning a receipt auto-fills the amount, store, and date — '
            'double-check before submitting.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
