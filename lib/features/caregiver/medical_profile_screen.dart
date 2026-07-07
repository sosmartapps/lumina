import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/health_profile.dart';
import '../../core/models/prescription.dart';
import '../../core/services/medical_info_service.dart';

/// Comprehensive medical profile management screen for caregivers
class MedicalProfileScreen extends ConsumerStatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  ConsumerState<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends ConsumerState<MedicalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.read(caregiverNotifierProvider);
    final user = provider.selectedUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medical Profile')),
        body: const Center(child: Text('No user selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareMedicalSummary(user.id),
            tooltip: 'Share Medical Summary',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.person)),
            Tab(text: 'Conditions', icon: Icon(Icons.medical_services)),
            Tab(text: 'Medications', icon: Icon(Icons.medication)),
            Tab(text: 'Allergies', icon: Icon(Icons.warning)),
            Tab(text: 'Providers', icon: Icon(Icons.local_hospital)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(userId: user.id),
          _ConditionsTab(userId: user.id),
          _MedicationsTab(userId: user.id),
          _AllergiesTab(userId: user.id),
          _ProvidersTab(userId: user.id),
        ],
      ),
    );
  }

  Future<void> _shareMedicalSummary(String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final summary = await MedicalInfoService.generateMedicalSummary(userId);
      if (!mounted) return;
      Navigator.pop(context);

      if (summary.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate medical summary')),
        );
        return;
      }

      // Format summary as readable text
      final text = _formatSummaryAsText(summary);

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Medical Summary - ${summary['patient']?['name'] ?? 'Patient'}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatSummaryAsText(Map<String, dynamic> summary) {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('        MEDICAL SUMMARY - LUMINA');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Generated: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln();

    // Patient Info
    final patient = summary['patient'] as Map<String, dynamic>?;
    if (patient != null) {
      buffer.writeln('▶ PATIENT INFORMATION');
      buffer.writeln('───────────────────────────────────────');
      if (patient['name'] != null) buffer.writeln('Name: ${patient['name']}');
      if (patient['bloodType'] != null) buffer.writeln('Blood Type: ${patient['bloodType']}');
      if (patient['insuranceProvider'] != null) {
        buffer.writeln('Insurance: ${patient['insuranceProvider']}');
        if (patient['insurancePolicyNumber'] != null) {
          buffer.writeln('Policy #: ${patient['insurancePolicyNumber']}');
        }
      }
      buffer.writeln();
    }

    // Emergency Notes
    if (summary['emergencyNotes'] != null) {
      buffer.writeln('▶ EMERGENCY NOTES');
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln(summary['emergencyNotes']);
      buffer.writeln();
    }

    // Allergies (first for safety)
    final allergies = summary['allergies'] as List?;
    if (allergies != null && allergies.isNotEmpty) {
      buffer.writeln('▶ ALLERGIES ⚠️');
      buffer.writeln('───────────────────────────────────────');
      for (final allergy in allergies) {
        buffer.writeln('• ${allergy['allergen']} (${allergy['severity']})');
        if (allergy['reaction'] != null) {
          buffer.writeln('  Reaction: ${allergy['reaction']}');
        }
      }
      buffer.writeln();
    }

    // Conditions
    final conditions = summary['conditions'] as List?;
    if (conditions != null && conditions.isNotEmpty) {
      buffer.writeln('▶ MEDICAL CONDITIONS');
      buffer.writeln('───────────────────────────────────────');
      for (final condition in conditions) {
        buffer.writeln('• ${condition['name']}');
        if (condition['severity'] != null) {
          buffer.writeln('  Severity: ${condition['severity']}');
        }
        if (condition['notes'] != null) {
          buffer.writeln('  Notes: ${condition['notes']}');
        }
      }
      buffer.writeln();
    }

    // Medications
    final medications = summary['medications'] as List?;
    if (medications != null && medications.isNotEmpty) {
      buffer.writeln('▶ CURRENT MEDICATIONS');
      buffer.writeln('───────────────────────────────────────');
      for (final med in medications) {
        buffer.writeln('• ${med['name']} ${med['dosage']}');
        buffer.writeln('  Frequency: ${med['frequency']}');
        if (med['instructions'] != null) {
          buffer.writeln('  Instructions: ${med['instructions']}');
        }
        if (med['reason'] != null) {
          buffer.writeln('  For: ${med['reason']}');
        }
      }
      buffer.writeln();
    }

    // Healthcare Providers
    final providers = summary['healthcareProviders'] as List?;
    if (providers != null && providers.isNotEmpty) {
      buffer.writeln('▶ HEALTHCARE PROVIDERS');
      buffer.writeln('───────────────────────────────────────');
      for (final provider in providers) {
        final isPrimary = provider['isPrimaryCare'] == true;
        buffer.writeln('• ${provider['name']}${isPrimary ? ' (Primary Care)' : ''}');
        if (provider['specialty'] != null) {
          buffer.writeln('  Specialty: ${provider['specialty']}');
        }
        if (provider['phone'] != null) {
          buffer.writeln('  Phone: ${provider['phone']}');
        }
      }
      buffer.writeln();
    }

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Generated by Lumina Care App');

    return buffer.toString();
  }
}

// ============================================================================
// OVERVIEW TAB
// ============================================================================

class _OverviewTab extends StatefulWidget {
  final String userId;

  const _OverviewTab({required this.userId});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  HealthProfile? _profile;
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _bloodTypeController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _policyNumberController = TextEditingController();
  final _groupNumberController = TextEditingController();
  final _emergencyNotesController = TextEditingController();
  final _advanceDirectivesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await MedicalInfoService.getHealthProfile(widget.userId);
    if (profile != null) {
      _bloodTypeController.text = profile.bloodType ?? '';
      _heightController.text = profile.height?.toString() ?? '';
      _weightController.text = profile.weight?.toString() ?? '';
      _insuranceProviderController.text = profile.insuranceProvider ?? '';
      _policyNumberController.text = profile.insurancePolicyNumber ?? '';
      _groupNumberController.text = profile.insuranceGroupNumber ?? '';
      _emergencyNotesController.text = profile.emergencyNotes ?? '';
      _advanceDirectivesController.text = profile.advanceDirectives ?? '';
    }
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = HealthProfile(
      id: _profile?.id ?? 'profile',
      userId: widget.userId,
      bloodType: _bloodTypeController.text.isNotEmpty
          ? _bloodTypeController.text
          : null,
      height: double.tryParse(_heightController.text),
      weight: double.tryParse(_weightController.text),
      insuranceProvider: _insuranceProviderController.text.isNotEmpty
          ? _insuranceProviderController.text
          : null,
      insurancePolicyNumber: _policyNumberController.text.isNotEmpty
          ? _policyNumberController.text
          : null,
      insuranceGroupNumber: _groupNumberController.text.isNotEmpty
          ? _groupNumberController.text
          : null,
      emergencyNotes: _emergencyNotesController.text.isNotEmpty
          ? _emergencyNotesController.text
          : null,
      advanceDirectives: _advanceDirectivesController.text.isNotEmpty
          ? _advanceDirectivesController.text
          : null,
      lastUpdated: DateTime.now(),
    );

    final success = await MedicalInfoService.saveHealthProfile(widget.userId, profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile saved' : 'Failed to save profile'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Section
            _buildSectionHeader('Basic Information'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _bloodTypeController,
                    label: 'Blood Type',
                    hint: 'e.g., A+, O-',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _heightController,
                    label: 'Height (cm)',
                    hint: 'e.g., 170',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _weightController,
                    label: 'Weight (kg)',
                    hint: 'e.g., 70',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Insurance Section
            _buildSectionHeader('Insurance Information'),
            _buildTextField(
              controller: _insuranceProviderController,
              label: 'Insurance Provider',
              hint: 'e.g., Blue Cross Blue Shield',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _policyNumberController,
                    label: 'Policy Number',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _groupNumberController,
                    label: 'Group Number',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Emergency Notes Section
            _buildSectionHeader('Emergency Notes'),
            Text(
              'Important information for emergency responders',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emergencyNotesController,
              label: 'Emergency Notes',
              hint: 'e.g., Has pacemaker, diabetic, etc.',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Advance Directives Section
            _buildSectionHeader('Advance Directives'),
            Text(
              'Living will, DNR orders, healthcare proxy, etc.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _advanceDirectivesController,
              label: 'Advance Directives',
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }
}

// ============================================================================
// CONDITIONS TAB
// ============================================================================

class _ConditionsTab extends StatelessWidget {
  final String userId;

  const _ConditionsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HealthCondition>>(
      stream: MedicalInfoService.getHealthConditions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final conditions = snapshot.data ?? [];

        return Scaffold(
          body: conditions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No health conditions recorded',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conditions.length,
                  itemBuilder: (context, index) {
                    final condition = conditions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: condition.isActive
                              ? Colors.blue[100]
                              : Colors.grey[200],
                          child: Icon(
                            Icons.medical_services,
                            color: condition.isActive ? Colors.blue : Colors.grey,
                          ),
                        ),
                        title: Text(condition.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (condition.severity != null)
                              Text('Severity: ${condition.severity}'),
                            if (condition.diagnosedBy != null)
                              Text('Diagnosed by: ${condition.diagnosedBy}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteCondition(context, condition),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addCondition(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _addCondition(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final diagnosedByController = TextEditingController();
    String? severity = 'moderate';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Health Condition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Condition Name *',
                  hintText: 'e.g., Alzheimer\'s Disease',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: ['mild', 'moderate', 'severe']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => severity = value,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: diagnosedByController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosed By',
                  hintText: 'Doctor name',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final condition = HealthCondition(
                id: '',
                name: nameController.text,
                description: descriptionController.text.isNotEmpty
                    ? descriptionController.text
                    : null,
                severity: severity,
                diagnosedBy: diagnosedByController.text.isNotEmpty
                    ? diagnosedByController.text
                    : null,
                diagnosisDate: DateTime.now(),
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await MedicalInfoService.addHealthCondition(userId, condition);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCondition(BuildContext context, HealthCondition condition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Condition'),
        content: Text('Delete "${condition.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await MedicalInfoService.deleteHealthCondition(userId, condition.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MEDICATIONS TAB
// ============================================================================

class _MedicationsTab extends StatelessWidget {
  final String userId;

  const _MedicationsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prescription>>(
      stream: MedicalInfoService.getPrescriptions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data ?? [];

        return Scaffold(
          body: prescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medication, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No medications recorded',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prescriptions.length,
                  itemBuilder: (context, index) {
                    final rx = prescriptions[index];
                    final needsRefill = rx.needsRefillSoon || rx.isRefillOverdue;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: needsRefill ? Colors.orange[50] : null,
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: rx.status == PrescriptionStatus.active
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                              child: Icon(
                                Icons.medication,
                                color: rx.status == PrescriptionStatus.active
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            if (needsRefill)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: rx.isRefillOverdue ? Colors.red : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(rx.medicationName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${rx.dosage} - ${rx.frequency}'),
                            if (rx.instructions != null)
                              Text(rx.instructions!, style: TextStyle(color: Colors.grey[600])),
                            if (needsRefill)
                              Text(
                                rx.isRefillOverdue ? '⚠️ Refill overdue!' : '⚠️ Refill needed soon',
                                style: TextStyle(
                                  color: rx.isRefillOverdue ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (rx.noRefillsRemaining)
                              const Text(
                                '📋 No refills remaining - contact doctor',
                                style: TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'refill',
                              child: Text('Record Refill'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'refill') {
                              _recordRefill(context, rx);
                            } else if (value == 'delete') {
                              _deletePrescription(context, rx);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addPrescription(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _addPrescription(BuildContext context) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final instructionsController = TextEditingController();
    final prescribedByController = TextEditingController();
    final reasonController = TextEditingController();
    final quantityController = TextEditingController();
    final daysSupplyController = TextEditingController();
    final refillsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'e.g., Donepezil',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage *',
                        hintText: 'e.g., 10mg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: frequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency *',
                        hintText: 'e.g., Once daily',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'e.g., Take with food',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prescribedByController,
                decoration: const InputDecoration(
                  labelText: 'Prescribed By',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason/Condition',
                  hintText: "e.g., Alzheimer's",
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Pills per refill',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: daysSupplyController,
                      decoration: const InputDecoration(
                        labelText: 'Days Supply',
                        hintText: 'e.g., 30',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refillsController,
                decoration: const InputDecoration(
                  labelText: 'Refills Remaining',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  dosageController.text.isEmpty ||
                  frequencyController.text.isEmpty) {
                return;
              }

              final now = DateTime.now();
              final daysSupply = int.tryParse(daysSupplyController.text);

              final prescription = Prescription(
                id: '',
                userId: userId,
                medicationName: nameController.text,
                dosage: dosageController.text,
                frequency: frequencyController.text,
                instructions: instructionsController.text.isNotEmpty
                    ? instructionsController.text
                    : null,
                prescribedBy: prescribedByController.text.isNotEmpty
                    ? prescribedByController.text
                    : null,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
                totalQuantity: int.tryParse(quantityController.text),
                remainingQuantity: int.tryParse(quantityController.text),
                daysSupply: daysSupply,
                refillsRemaining: int.tryParse(refillsController.text),
                startDate: now,
                lastFilledDate: now,
                nextRefillDate: daysSupply != null
                    ? now.add(Duration(days: daysSupply))
                    : null,
                status: PrescriptionStatus.active,
                refillReminderEnabled: true,
                refillReminderDaysBefore: 7,
                createdAt: now,
                updatedAt: now,
              );

              await MedicalInfoService.addPrescription(userId, prescription);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _recordRefill(BuildContext context, Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Refill'),
        content: Text('Mark ${rx.medicationName} as refilled today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final refill = RefillRecord(
                id: '',
                prescriptionId: rx.id,
                filledDate: DateTime.now(),
                quantity: rx.totalQuantity,
              );

              await MedicalInfoService.recordRefill(userId, rx.id, refill);
              if (!context.mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refill recorded')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _deletePrescription(BuildContext context, Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Delete "${rx.medicationName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await MedicalInfoService.deletePrescription(userId, rx.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ALLERGIES TAB
// ============================================================================

class _AllergiesTab extends StatelessWidget {
  final String userId;

  const _AllergiesTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Allergy>>(
      stream: MedicalInfoService.getAllergies(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allergies = snapshot.data ?? [];

        return Scaffold(
          body: allergies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No allergies recorded',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allergies.length,
                  itemBuilder: (context, index) {
                    final allergy = allergies[index];
                    final severityColor = _getSeverityColor(allergy.severity);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: severityColor.withValues(alpha: 0.2),
                          child: Icon(Icons.warning, color: severityColor),
                        ),
                        title: Text(allergy.allergen),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Severity: ${allergy.severity}'),
                            if (allergy.reaction != null)
                              Text('Reaction: ${allergy.reaction}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteAllergy(context, allergy),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addAllergy(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return Colors.yellow[700]!;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      case 'life-threatening':
        return Colors.red[900]!;
      default:
        return Colors.orange;
    }
  }

  void _addAllergy(BuildContext context) {
    final allergenController = TextEditingController();
    final reactionController = TextEditingController();
    String severity = 'moderate';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Allergy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: allergenController,
                decoration: const InputDecoration(
                  labelText: 'Allergen *',
                  hintText: 'e.g., Penicillin, Peanuts',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reactionController,
                decoration: const InputDecoration(
                  labelText: 'Reaction',
                  hintText: 'e.g., Hives, difficulty breathing',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: ['mild', 'moderate', 'severe', 'life-threatening']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => severity = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (allergenController.text.isEmpty) return;

              final allergy = Allergy(
                id: '',
                allergen: allergenController.text,
                reaction: reactionController.text.isNotEmpty
                    ? reactionController.text
                    : null,
                severity: severity,
                createdAt: DateTime.now(),
              );

              await MedicalInfoService.addAllergy(userId, allergy);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteAllergy(BuildContext context, Allergy allergy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Allergy'),
        content: Text('Delete "${allergy.allergen}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await MedicalInfoService.deleteAllergy(userId, allergy.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROVIDERS TAB
// ============================================================================

class _ProvidersTab extends StatelessWidget {
  final String userId;

  const _ProvidersTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HealthcareProvider>>(
      stream: MedicalInfoService.getHealthcareProviders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final providers = snapshot.data ?? [];

        return Scaffold(
          body: providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_hospital, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No healthcare providers recorded',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final provider = providers[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: provider.isPrimaryCare
                              ? Colors.blue[100]
                              : Colors.grey[200],
                          child: Icon(
                            Icons.person,
                            color: provider.isPrimaryCare ? Colors.blue : Colors.grey,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                provider.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.isPrimaryCare) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (provider.specialty != null)
                              Text(provider.specialty!),
                            if (provider.practice != null)
                              Text(provider.practice!),
                            if (provider.phone != null)
                              Text('📞 ${provider.phone}'),
                          ],
                        ),
                        isThreeLine: provider.specialty != null || provider.practice != null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteProvider(context, provider),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addProvider(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _addProvider(BuildContext context) {
    final nameController = TextEditingController();
    final specialtyController = TextEditingController();
    final practiceController = TextEditingController();
    final phoneController = TextEditingController();
    bool isPrimaryCare = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Healthcare Provider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Provider Name *',
                    hintText: 'e.g., Dr. John Smith',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    hintText: 'e.g., Neurologist',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practiceController,
                  decoration: const InputDecoration(
                    labelText: 'Practice/Hospital',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Primary Care Provider'),
                  value: isPrimaryCare,
                  onChanged: (value) => setState(() => isPrimaryCare = value!),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final provider = HealthcareProvider(
                  id: '',
                  name: nameController.text,
                  specialty: specialtyController.text.isNotEmpty
                      ? specialtyController.text
                      : null,
                  practice: practiceController.text.isNotEmpty
                      ? practiceController.text
                      : null,
                  phone: phoneController.text.isNotEmpty
                      ? phoneController.text
                      : null,
                  isPrimaryCare: isPrimaryCare,
                  createdAt: DateTime.now(),
                );

                await MedicalInfoService.addHealthcareProvider(userId, provider);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteProvider(BuildContext context, HealthcareProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Provider'),
        content: Text('Delete "${provider.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await MedicalInfoService.deleteHealthcareProvider(userId, provider.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
