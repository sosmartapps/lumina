import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../../core/services/expense_service.dart';
import '../../core/theme/app_theme.dart';

/// Detail view of a single expense with receipt photos, status timeline,
/// and role-gated approve / reject / mark-reimbursed actions.
class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  final _currency = NumberFormat.simpleCurrency();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final expenseService = ref.read(expenseServiceProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Expense Details'),
      ),
      body: StreamBuilder<Expense?>(
        stream: expenseService.watchExpense(widget.expenseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final expense = snapshot.data;
          if (expense == null) {
            return const Center(child: Text('Expense not found'));
          }
          return _buildBody(expense);
        },
      ),
    );
  }

  Widget _buildBody(Expense expense) {
    final provider = ref.read(caregiverNotifierProvider);
    final caregiver = provider.caregiver;
    final patient = provider.selectedUser;

    final canManage = caregiver != null &&
        patient != null &&
        ExpenseService.canManageFinances(caregiver, patient);
    final isSubmitter = caregiver != null && caregiver.id == expense.submittedBy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAmountCard(expense),
        const SizedBox(height: 16),
        _buildDetailsCard(expense),
        if (expense.receiptUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildReceiptsCard(expense),
        ],
        if (expense.reviewNote != null ||
            expense.reviewedByName != null ||
            expense.reimbursedAt != null) ...[
          const SizedBox(height: 16),
          _buildHistoryCard(expense),
        ],
        const SizedBox(height: 24),
        ..._buildActions(expense,
            canManage: canManage, isSubmitter: isSubmitter),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAmountCard(Expense expense) {
    final statusColor = _statusColor(expense.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _currency.format(expense.amount),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              expense.status.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _detailRow('Merchant', expense.merchant),
          _detailRow('Category', expense.category.displayName),
          _detailRow('Purchase Date',
              DateFormat('MMM d, yyyy').format(expense.expenseDate)),
          _detailRow('Paid By', expense.submittedByName),
          _detailRow('Submitted',
              DateFormat('MMM d, yyyy h:mm a').format(expense.createdAt)),
          if (expense.description != null)
            _detailRow('Notes', expense.description!),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsCard(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Receipts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: expense.receiptUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = expense.receiptUrls[index];
                return GestureDetector(
                  onTap: () => _showReceiptViewer(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 110,
                      height: 140,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 110,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 110,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptViewer(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: CachedNetworkImage(imageUrl: url),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white70,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (expense.reviewedByName != null && expense.reviewedAt != null)
            _detailRow(
              expense.status == ExpenseStatus.rejected
                  ? 'Rejected By'
                  : 'Approved By',
              '${expense.reviewedByName} · '
              '${DateFormat('MMM d, h:mm a').format(expense.reviewedAt!)}',
            ),
          if (expense.reviewNote != null)
            _detailRow('Note', expense.reviewNote!),
          if (expense.reimbursedAt != null)
            _detailRow(
              'Reimbursed',
              '${DateFormat('MMM d, yyyy').format(expense.reimbursedAt!)}'
              '${expense.reimbursementMethod != null ? ' · ${expense.reimbursementMethod!.displayName}' : ''}',
            ),
          if (expense.reimbursementNote != null)
            _detailRow('Payment Note', expense.reimbursementNote!),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    Expense expense, {
    required bool canManage,
    required bool isSubmitter,
  }) {
    final actions = <Widget>[];

    if (_busy) {
      return [const Center(child: CircularProgressIndicator())];
    }

    if (canManage && expense.status == ExpenseStatus.submitted) {
      actions.add(_actionButton(
        'Approve',
        Icons.check_circle,
        AppTheme.primaryGreen,
        () => _approve(expense),
      ));
      actions.add(const SizedBox(height: 12));
      actions.add(_actionButton(
        'Reject',
        Icons.cancel,
        AppTheme.primaryRed,
        () => _reject(expense),
        outlined: true,
      ));
    }

    if (canManage && expense.status == ExpenseStatus.approved) {
      actions.add(_actionButton(
        'Mark as Reimbursed',
        Icons.payments,
        AppTheme.primaryGreen,
        () => _markReimbursed(expense),
      ));
    }

    if (isSubmitter && expense.status == ExpenseStatus.rejected) {
      actions.add(_actionButton(
        'Resubmit',
        Icons.refresh,
        AppTheme.primaryBlue,
        () => _resubmit(expense),
      ));
    }

    if (isSubmitter && expense.status == ExpenseStatus.submitted) {
      actions.add(const SizedBox(height: 12));
      actions.add(_actionButton(
        'Delete Expense',
        Icons.delete_outline,
        AppTheme.primaryRed,
        () => _delete(expense),
        outlined: true,
      ));
    }

    return actions;
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
              ),
              icon: Icon(icon),
              label: Text(label),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(Expense expense) async {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    if (caregiver == null) return;
    await _runAction(() => ref.read(expenseServiceProvider).approveExpense(
          expense: expense,
          reviewerId: caregiver.id,
          reviewerName: caregiver.name,
        ));
  }

  Future<void> _reject(Expense expense) async {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    if (caregiver == null) return;

    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g., Receipt missing the total',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    await _runAction(() => ref.read(expenseServiceProvider).rejectExpense(
          expense: expense,
          reviewerId: caregiver.id,
          reviewerName: caregiver.name,
          reason: reason,
        ));
  }

  Future<void> _markReimbursed(Expense expense) async {
    ReimbursementMethod method = ReimbursementMethod.zelle;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Reimbursement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paying ${expense.submittedByName} '
                '${_currency.format(expense.amount)}',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReimbursementMethod>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: ReimbursementMethod.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => method = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g., Check #1042',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _runAction(() => ref.read(expenseServiceProvider).markReimbursed(
          expense: expense,
          method: method,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        ));
  }

  Future<void> _resubmit(Expense expense) async {
    await _runAction(
        () => ref.read(expenseServiceProvider).resubmitExpense(expense));
  }

  Future<void> _delete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
            'This removes the expense and its receipt photos. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(
        () => ref.read(expenseServiceProvider).deleteExpense(expense));
    if (mounted) Navigator.pop(context);
  }

  Color _statusColor(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.submitted:
        return AppTheme.primaryOrange;
      case ExpenseStatus.approved:
        return AppTheme.primaryBlue;
      case ExpenseStatus.rejected:
        return AppTheme.primaryRed;
      case ExpenseStatus.reimbursed:
        return AppTheme.primaryGreen;
    }
  }
}
