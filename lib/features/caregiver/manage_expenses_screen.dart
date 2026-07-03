import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../../core/services/expense_service.dart';
import '../../core/theme/app_theme.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';

/// Caregiver screen listing all reimbursement expenses for the selected
/// patient, with status filtering and outstanding-balance summary.
class ManageExpensesScreen extends ConsumerStatefulWidget {
  const ManageExpensesScreen({super.key});

  @override
  ConsumerState<ManageExpensesScreen> createState() =>
      _ManageExpensesScreenState();
}

class _ManageExpensesScreenState extends ConsumerState<ManageExpensesScreen> {
  ExpenseStatus? _filter; // null = all
  final _currency = NumberFormat.simpleCurrency();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Expenses & Reimbursements'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
        ),
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Expense'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final expenseService = ref.read(expenseServiceProvider);

          return StreamBuilder<List<Expense>>(
            stream: expenseService.getExpenses(user.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load expenses.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }

              final all = snapshot.data ?? [];
              final expenses = _filter == null
                  ? all
                  : all.where((e) => e.status == _filter).toList();

              return Column(
                children: [
                  _buildSummaryHeader(all),
                  _buildFilterChips(),
                  Expanded(
                    child: expenses.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: expenses.length,
                            itemBuilder: (context, index) =>
                                _buildExpenseCard(expenses[index]),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(List<Expense> all) {
    final pendingTotal =
        ExpenseService.totalFor(all, ExpenseStatus.submitted);
    final owedTotal = ExpenseService.totalFor(all, ExpenseStatus.approved);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryTile(
              'Awaiting Approval',
              _currency.format(pendingTotal),
              AppTheme.primaryOrange,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _buildSummaryTile(
              'Owed (Approved)',
              _currency.format(owedTotal),
              AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = <(String, ExpenseStatus?)>[
      ('All', null),
      ('Pending', ExpenseStatus.submitted),
      ('Approved', ExpenseStatus.approved),
      ('Reimbursed', ExpenseStatus.reimbursed),
      ('Rejected', ExpenseStatus.rejected),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, status) = filters[index];
          return FilterChip(
            label: Text(label),
            selected: _filter == status,
            selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
            onSelected: (_) => setState(() => _filter = status),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _filter == null
                ? 'No expenses yet'
                : 'No ${_filter!.displayName.toLowerCase()} expenses',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Snap a receipt to request reimbursement',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final statusColor = _statusColor(expense.status);
    final dateStr = DateFormat('MMM d, yyyy').format(expense.expenseDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_categoryIcon(expense.category), color: statusColor),
        ),
        title: Text(
          expense.merchant,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$dateStr · ${expense.submittedByName}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                expense.status.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          _currency.format(expense.amount),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpenseDetailScreen(expenseId: expense.id),
          ),
        ),
      ),
    );
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

  IconData _categoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return Icons.shopping_cart;
      case ExpenseCategory.medical:
        return Icons.medical_services;
      case ExpenseCategory.household:
        return Icons.home;
      case ExpenseCategory.transportation:
        return Icons.directions_car;
      case ExpenseCategory.clothing:
        return Icons.checkroom;
      case ExpenseCategory.utilities:
        return Icons.bolt;
      case ExpenseCategory.personalCare:
        return Icons.spa;
      case ExpenseCategory.other:
        return Icons.receipt;
    }
  }
}
