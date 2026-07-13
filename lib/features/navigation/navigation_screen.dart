import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/large_action_tile.dart';
import '../../core/models/app_user.dart';

/// Screen for navigating to saved locations
class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text(
          'GO TO',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: ref.read(userNotifierProvider),
        builder: (context, child) {
          final userProvider = ref.read(userNotifierProvider);
          final user = userProvider.user;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Home button (large and prominent)
                if (user.homeLocation != null) ...[
                  _buildLargeLocationTile(
                    ref: ref,
                    name: 'HOME',
                    address: user.homeAddress,
                    icon: Icons.home,
                    color: AppTheme.tileColors[0],
                    location: user.homeLocation!,
                    isLarge: true,
                  ),
                  const SizedBox(height: 24),
                ],

                // Saved locations
                if (user.savedLocations.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'SAVED PLACES',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: user.savedLocations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final location = user.savedLocations[index];
                      return _buildLocationTile(
                        ref: ref,
                        savedLocation: location,
                        index: index,
                      );
                    },
                  ),
                ],

                // Empty state
                if (user.homeLocation == null && user.savedLocations.isEmpty)
                  _buildEmptyState(),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeLocationTile({
    required WidgetRef ref,
    required String name,
    String? address,
    required IconData icon,
    required Color color,
    required dynamic location,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: () => _navigateToLocation(ref, name, location),
      child: Container(
        // min-height instead of fixed height: 2-line addresses at large
        // text scale overflowed 11px (2026-07-13)
        constraints:
            isLarge ? const BoxConstraints(minHeight: 160) : null,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: isLarge ? 48 : 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),

              // Name and address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isLarge ? 32 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isLarge ? 16 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Navigate icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions,
                  size: isLarge ? 36 : 28,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile({
    required WidgetRef ref,
    required SavedLocation savedLocation,
    required int index,
  }) {
    final color = AppTheme.tileColors[(index + 1) % AppTheme.tileColors.length];
    final icon = _getLocationIcon(savedLocation.iconName);

    return LocationTile(
      name: savedLocation.name,
      address: savedLocation.address,
      icon: icon,
      color: color,
      onTap: () => _navigateToLocation(
        ref,
        savedLocation.name,
        savedLocation.location,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_location_alt,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No places saved yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your caregiver to add\nyour favorite places',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLocationIcon(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'medical':
        return Icons.local_hospital;
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
        return Icons.store;
      case 'church':
        return Icons.church;
      case 'park':
        return Icons.park;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.place;
    }
  }

  Future<void> _navigateToLocation(
    WidgetRef ref,
    String name,
    dynamic location,
  ) async {
    HapticFeedback.heavyImpact();

    final tts = ref.read(ttsServiceProvider);
    final locationService = ref.read(locationServiceProvider);

    await tts.speak('Getting directions to $name');
    final url = await locationService.getGoogleMapsDirectionsUrl(
      destination: location,
      destinationName: name,
    );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
