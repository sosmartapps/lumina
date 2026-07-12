import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/pet_feeding.dart';
import 'feeding_history_screen.dart';

/// Screen for setting up and managing pet feeding schedules.
///
/// Each pet has one or more feeding times per day and can repeat every day or
/// on specific weekdays. Caregivers (or the user themselves) can add/edit/
/// delete schedules, mark a pet as fed, and review feeding history.
class ManagePetFeedingScreen extends ConsumerStatefulWidget {
  const ManagePetFeedingScreen({super.key});

  @override
  ConsumerState<ManagePetFeedingScreen> createState() =>
      _ManagePetFeedingScreenState();
}

class _ManagePetFeedingScreenState
    extends ConsumerState<ManagePetFeedingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Text('Pet Feeding'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Feeding history',
            onPressed: () {
              final user = ref.read(caregiverNotifierProvider).selectedUser;
              if (user == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedingHistoryScreen(userId: user.id),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFeedingDialog(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Pet'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final service = ref.read(petFeedingServiceProvider);

          return StreamBuilder<List<PetFeeding>>(
            stream: service.getFeedings(user.id),
            builder: (context, snapshot) {
              final feedings = snapshot.data ?? [];
              if (feedings.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: feedings.length,
                itemBuilder: (context, index) =>
                    _buildFeedingCard(feedings[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No feeding schedules yet',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Pet" to set feeding times for Lily or any other pet.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedingCard(PetFeeding feeding) {
    final next = feeding.nextFeedingToday;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(feeding.petType.icon,
                      color: AppTheme.primaryGreen, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feeding.petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          feeding.petType.displayName,
                          if (feeding.amount != null &&
                              feeding.amount!.isNotEmpty)
                            feeding.amount!,
                          if (feeding.foodType != null &&
                              feeding.foodType!.isNotEmpty)
                            feeding.foodType!,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showFeedingDialog(existing: feeding);
                    } else if (value == 'delete') {
                      _confirmDelete(feeding);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Food photos — tap to view full-screen
            if (feeding.foodPhotoUrls.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: feeding.foodPhotoUrls
                      .map((url) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _showFoodPhoto(url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                    width: 72,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Feeding times
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: feeding.feedingTimes.map((t) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppTheme.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        t.label != null && t.label!.isNotEmpty
                            ? '${t.label} · ${t.timeString}'
                            : t.timeString,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    feeding.repeatDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.restaurant, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _lastFedLabel(feeding.lastFedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),

            if (next != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 16, color: AppTheme.primaryOrange),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Next feeding at ${DateFormat('h:mm a').format(next)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.primaryOrange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markFed(feeding),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Mark ${feeding.petName} Fed'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastFedLabel(DateTime? lastFedAt) {
    if (lastFedAt == null) return 'Not fed yet';
    final diff = DateTime.now().difference(lastFedAt);
    if (diff.inMinutes < 1) return 'Fed just now';
    if (diff.inMinutes < 60) return 'Fed ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Fed ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Fed yesterday';
    return 'Fed ${DateFormat('MMM d').format(lastFedAt)}';
  }

  Future<void> _markFed(PetFeeding feeding) async {
    final provider = ref.read(caregiverNotifierProvider);
    final service = ref.read(petFeedingServiceProvider);
    final fedByName = provider.caregiver?.name;

    // Attribute to the most recent scheduled slot that has already passed.
    final now = DateTime.now();
    DateTime? slot;
    for (final t in feeding.todayFeedingDateTimes()) {
      if (!t.isAfter(now)) slot = t;
    }

    await service.markFed(
      feeding: feeding,
      scheduledSlot: slot,
      fedByName: fedByName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${feeding.petName} marked as fed'),
        backgroundColor: AppTheme.primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(PetFeeding feeding) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
            'Remove the feeding schedule for "${feeding.petName}"? Feeding history is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final service = ref.read(petFeedingServiceProvider);
              await service.deleteFeeding(feeding);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Add (existing == null) or edit an existing feeding schedule.
  void _showFeedingDialog({PetFeeding? existing}) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.petName ?? '');
    final foodController = TextEditingController(text: existing?.foodType ?? '');
    final amountController =
        TextEditingController(text: existing?.amount ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    PetType petType = existing?.petType ?? PetType.dog;
    // Food photos: existing uploaded URLs + newly picked local files.
    final photoUrls = <String>[...(existing?.foodPhotoUrls ?? const [])];
    final newPhotoFiles = <File>[];
    final removedUrls = <String>[];
    bool saving = false;
    final times = <FeedingTime>[
      ...(existing?.feedingTimes ??
          [
            FeedingTime(
              id: _newTimeId(),
              hour: 7,
              minute: 0,
              label: 'Morning',
            ),
          ]),
    ];
    bool everyDay = existing?.isDaily ?? true;
    final selectedDays = <int>{...(existing?.repeatDays ?? const [])};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Pet' : 'Add Pet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Pet name *',
                      prefixIcon: Icon(Icons.pets),
                      hintText: 'e.g., Lily',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PetType>(
                    initialValue: petType,
                    decoration: const InputDecoration(
                      labelText: 'Pet type',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: PetType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text('${t.emoji}  ${t.displayName}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => petType = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: foodController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Food type (optional)',
                      prefixIcon: Icon(Icons.restaurant),
                      hintText: 'e.g., Kibble',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional)',
                      prefixIcon: Icon(Icons.straighten),
                      hintText: 'e.g., 1 cup',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Food photos — show exactly which cup/can to use
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Food photos',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: 'Take photo',
                        icon: const Icon(Icons.camera_alt,
                            color: AppTheme.primaryGreen),
                        onPressed: () async {
                          final file = await ref
                              .read(petFeedingServiceProvider)
                              .captureFoodPhoto();
                          if (file != null) {
                            setState(() => newPhotoFiles.add(file));
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'From gallery',
                        icon: const Icon(Icons.photo_library,
                            color: AppTheme.primaryGreen),
                        onPressed: () async {
                          final file = await ref
                              .read(petFeedingServiceProvider)
                              .pickFoodPhotoFromGallery();
                          if (file != null) {
                            setState(() => newPhotoFiles.add(file));
                          }
                        },
                      ),
                    ],
                  ),
                  if (photoUrls.isEmpty && newPhotoFiles.isEmpty)
                    Text(
                      'e.g., the measuring cup of dry food, the wet-food can',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    )
                  else
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...photoUrls.map((url) => _foodThumb(
                                image: Image.network(url,
                                    width: 72, height: 84, fit: BoxFit.cover),
                                onRemove: () => setState(() {
                                  photoUrls.remove(url);
                                  removedUrls.add(url);
                                }),
                              )),
                          ...newPhotoFiles.map((file) => _foodThumb(
                                image: Image.file(file,
                                    width: 72, height: 84, fit: BoxFit.cover),
                                onRemove: () => setState(
                                    () => newPhotoFiles.remove(file)),
                              )),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Feeding times
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Feeding times',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            times.add(FeedingTime(
                              id: _newTimeId(),
                              hour: 17,
                              minute: 0,
                              label: 'Evening',
                            ));
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add time'),
                      ),
                    ],
                  ),
                  ...times.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return _buildTimeRow(
                      context: context,
                      time: t,
                      canDelete: times.length > 1,
                      onPickTime: (picked) {
                        setState(() {
                          times[i] = FeedingTime(
                            id: t.id,
                            hour: picked.hour,
                            minute: picked.minute,
                            label: t.label,
                          );
                        });
                      },
                      onLabelChanged: (label) {
                        times[i] = FeedingTime(
                          id: t.id,
                          hour: t.hour,
                          minute: t.minute,
                          label: label,
                        );
                      },
                      onDelete: () => setState(() => times.removeAt(i)),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Recurrence
                  const Text('Repeat',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Every day'),
                    value: everyDay,
                    onChanged: (v) => setState(() => everyDay = v),
                  ),
                  if (!everyDay)
                    Wrap(
                      spacing: 6,
                      children: List.generate(7, (index) {
                        final weekday = index + 1; // 1=Mon..7=Sun
                        const labels = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        final selected = selectedDays.contains(weekday);
                        return FilterChip(
                          label: Text(labels[index]),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                selectedDays.add(weekday);
                              } else {
                                selectedDays.remove(weekday);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes),
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
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                onPressed: saving
                    ? null
                    : () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a pet name')),
                    );
                    return;
                  }
                  if (times.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Add at least one feeding time')),
                    );
                    return;
                  }
                  if (!everyDay && selectedDays.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pick at least one day, or "Every day"')),
                    );
                    return;
                  }

                  final provider = ref.read(caregiverNotifierProvider);
                  final service = ref.read(petFeedingServiceProvider);
                  final user = provider.selectedUser!;
                  final createdBy = provider.caregiver?.id ?? user.id;

                  final repeatDays =
                      everyDay ? null : (selectedDays.toList()..sort());
                  final foodType = foodController.text.trim();
                  final amount = amountController.text.trim();
                  final notes = notesController.text.trim();

                  setState(() => saving = true);
                  try {
                    // Upload any newly picked food photos first.
                    final uploadedUrls = <String>[];
                    for (final file in newPhotoFiles) {
                      uploadedUrls.add(await service.uploadFoodPhoto(
                        file: file,
                        userId: user.id,
                      ));
                    }
                    final allPhotoUrls = [...photoUrls, ...uploadedUrls];

                    if (isEdit) {
                      final updated = existing.copyWith(
                        petName: name,
                        petType: petType,
                        foodType: foodType.isEmpty ? null : foodType,
                        amount: amount.isEmpty ? null : amount,
                        foodPhotoUrls: allPhotoUrls,
                        feedingTimes: times,
                        repeatDays: repeatDays,
                        notes: notes.isEmpty ? null : notes,
                      );
                      await service.updateFeeding(updated);
                    } else {
                      final created = PetFeeding(
                        id: '',
                        userId: user.id,
                        petName: name,
                        petType: petType,
                        foodType: foodType.isEmpty ? null : foodType,
                        amount: amount.isEmpty ? null : amount,
                        foodPhotoUrls: allPhotoUrls,
                        feedingTimes: times,
                        repeatDays: repeatDays,
                        notes: notes.isEmpty ? null : notes,
                        createdBy: createdBy,
                      );
                      await service.createFeeding(created);
                    }

                    // Clean up photos the user removed from an existing pet.
                    for (final url in removedUrls) {
                      await service.deleteFoodPhoto(url);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save: $e')),
                    );
                    return;
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFoodPhoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Image.network(url),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(backgroundColor: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodThumb({
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required BuildContext context,
    required FeedingTime time,
    required bool canDelete,
    required ValueChanged<TimeOfDay> onPickTime,
    required ValueChanged<String?> onLabelChanged,
    required VoidCallback onDelete,
  }) {
    final labelController = TextEditingController(text: time.label ?? '');
    labelController.selection = TextSelection.fromPosition(
      TextPosition(offset: labelController.text.length),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time.timeOfDay,
              );
              if (picked != null) onPickTime(picked);
            },
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(time.timeString),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: labelController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Label (optional)',
              ),
              onChanged: (v) => onLabelChanged(v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  /// Unique-enough id for an embedded feeding time.
  String _newTimeId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
