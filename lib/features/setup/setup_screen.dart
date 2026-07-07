import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/app_user.dart';
import '../../core/models/reminder.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/deep_link_service.dart';
import '../user_home/user_home_screen.dart';
import '../caregiver/caregiver_dashboard_screen.dart';

/// Initial setup screen for new users
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Caregiver auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // User info
  final _userNameController = TextEditingController();
  final _userPreferredNameController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _homeAddressController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _caregiverId;
  int _authMode = 0; // 0=new, 1=signIn, 2=invite
  final _inviteCodeController = TextEditingController();
  bool _joinedViaInvite = false;

  // Emergency contact fields
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _contactRelationship = 'Family';
  final List<EmergencyContact> _contacts = [];

  // Permissions state
  bool _locationGranted = false;
  bool _notificationsGranted = false;

  // Quick reminder fields
  final _reminderTitleController = TextEditingController();
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  ReminderType _reminderType = ReminderType.medication;

  static const _totalPages = 7;

  @override
  void initState() {
    super.initState();
    // Check if app was opened via an invite deep link
    final deepLinkService = DeepLinkService();
    if (deepLinkService.pendingInviteCode != null) {
      _authMode = 2;
      _inviteCodeController.text = deepLinkService.pendingInviteCode!;
      deepLinkService.clearPendingInviteCode();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _userNameController.dispose();
    _userPreferredNameController.dispose();
    _userPhoneController.dispose();
    _homeAddressController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _inviteCodeController.dispose();
    _reminderTitleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Release focus so the previous page's keyboard doesn't stay up and
    // cover the next page's content.
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: List.generate(_totalPages, (index) {
                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppTheme.primaryBlue
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildCaregiverAuthPage(),
                  _buildUserInfoPage(),
                  _buildEmergencyContactPage(),
                  _buildPermissionsPage(),
                  _buildQuickReminderPage(),
                  _buildCompletePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              size: 80,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Welcome to\nLumina',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'A caring assistant for daily life',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),

          // Features
          _buildFeatureRow(Icons.home, 'Easy navigation home'),
          _buildFeatureRow(Icons.phone, 'One-tap calling'),
          _buildFeatureRow(Icons.medication, 'Medication reminders'),
          _buildFeatureRow(Icons.location_on, 'Location tracking'),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'GET STARTED',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthToggle(String label, int mode) {
    final isSelected = _authMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _authMode = mode;
          _errorMessage = null;
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverAuthPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(height: 16),

          const Text(
            'Caregiver Setup',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _authMode == 2
                ? 'Enter your invite code and create an account'
                : 'Create or sign in to your caregiver account',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          // Toggle buttons
          Row(
            children: [
              _buildAuthToggle('New', 0),
              const SizedBox(width: 8),
              _buildAuthToggle('Sign In', 1),
              const SizedBox(width: 8),
              _buildAuthToggle('Have a Code', 2),
            ],
          ),
          const SizedBox(height: 24),

          // Invite code field
          if (_authMode == 2) ...[
            TextField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                prefixIcon: Icon(Icons.vpn_key),
                hintText: 'Enter 6-character code',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Form fields
          if (_authMode == 0 || _authMode == 2) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.primaryRed),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCaregiverAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _authMode == 2 ? 'JOIN' : (_authMode == 0 ? 'CREATE ACCOUNT' : 'SIGN IN'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade400)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 20),

          _buildOAuthButton(
            label: 'Continue with Apple',
            icon: Icons.apple,
            background: Colors.black,
            foreground: Colors.white,
            onPressed: _isLoading
                ? null
                : () => _handleOAuthAuth(() => ref
                    .read(authServiceProvider)
                    .signInWithApple(fallbackName: _nameController.text)),
          ),
          const SizedBox(height: 12),
          _buildOAuthButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata,
            background: Colors.white,
            foreground: Colors.black87,
            outlined: true,
            onPressed: _isLoading
                ? null
                : () => _handleOAuthAuth(() => ref
                    .read(authServiceProvider)
                    .signInWithGoogle(fallbackName: _nameController.text)),
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    bool outlined = false,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          side: outlined
              ? BorderSide(color: Colors.grey.shade400)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(height: 16),

          const Text(
            'User Information',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter details for the person who will use this app',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          TextField(
            controller: _userNameController,
            decoration: const InputDecoration(
              labelText: 'User\'s Full Name *',
              prefixIcon: Icon(Icons.person),
              hintText: 'e.g., Robert Smith',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _userPreferredNameController,
            decoration: const InputDecoration(
              labelText: 'Preferred Name',
              prefixIcon: Icon(Icons.favorite_border),
              hintText: 'What should the app call them? e.g., Bobby',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _userPhoneController,
            decoration: const InputDecoration(
              labelText: 'User\'s Phone (optional)',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _homeAddressController,
            decoration: const InputDecoration(
              labelText: 'Home Address *',
              prefixIcon: Icon(Icons.home),
              hintText: '123 Main St, City, State',
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The home address will be used for the "Go Home" button',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.primaryRed),
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(height: 16),

          const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add people the user can call for help',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Added contacts list
          if (_contacts.isNotEmpty) ...[
            ...List.generate(_contacts.length, (index) {
              final contact = _contacts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.tileColors[index % AppTheme.tileColors.length],
                    child: Text(
                      contact.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${contact.relationship ?? ''} - ${contact.phoneNumber}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _contacts.removeAt(index)),
                  ),
                ),
              );
            }),
            const Divider(height: 24),
          ],

          // Add contact form
          TextField(
            controller: _contactNameController,
            decoration: const InputDecoration(
              labelText: 'Contact Name',
              prefixIcon: Icon(Icons.person),
              hintText: 'e.g., Sarah (daughter)',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              hintText: '(520) 555-1234',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _contactRelationship,
            decoration: const InputDecoration(
              labelText: 'Relationship',
              prefixIcon: Icon(Icons.people),
            ),
            items: const [
              DropdownMenuItem(value: 'Family', child: Text('Family')),
              DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
              DropdownMenuItem(value: 'Child', child: Text('Son/Daughter')),
              DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
              DropdownMenuItem(value: 'Friend', child: Text('Friend')),
              DropdownMenuItem(value: 'Neighbor', child: Text('Neighbor')),
              DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _contactRelationship = v);
            },
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.add),
              label: const Text('ADD CONTACT', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.primaryRed)),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveContacts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _contacts.isEmpty ? 'SKIP FOR NOW' : 'CONTINUE',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _addContact() {
    if (_contactNameController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a name and phone number');
      return;
    }

    setState(() {
      _errorMessage = null;
      _contacts.add(EmergencyContact(
        id: const Uuid().v4(),
        name: _contactNameController.text.trim(),
        phoneNumber: _contactPhoneController.text.trim(),
        relationship: _contactRelationship,
        orderIndex: _contacts.length,
      ));
      _contactNameController.clear();
      _contactPhoneController.clear();
      _contactRelationship = 'Family';
    });
  }

  Future<void> _saveContacts() async {
    if (_contacts.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userProvider = ref.read(userNotifierProvider);
        final user = userProvider.user;
        if (user != null) {
          final authService = ref.read(authServiceProvider);
          await authService.updateUser(user.copyWith(
            emergencyContacts: _contacts,
          ));
          await userProvider.loadUser(user.id);
        }
      } catch (e) {
        setState(() => _errorMessage = e.toString());
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _isLoading = false);
    }

    _nextPage();
  }

  Widget _buildPermissionsPage() {
    // Scrollable (not Spacer-pinned) so CONTINUE stays reachable even if
    // a keyboard or large text shrinks the viewport.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(height: 16),

          const Text(
            'App Permissions',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lumina needs a few permissions to keep the user safe',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          // Location permission
          _buildPermissionCard(
            icon: Icons.location_on,
            title: 'Location (Always)',
            description: 'Tracks location so caregivers know where the user is, enables the "Go Home" button, and powers safe zone alerts.',
            granted: _locationGranted,
            onRequest: _requestLocationPermission,
          ),
          const SizedBox(height: 16),

          // Notifications permission
          _buildPermissionCard(
            icon: Icons.notifications_active,
            title: 'Notifications',
            description: 'Sends medication reminders, task alerts, and safety notifications even when the app is in the background.',
            granted: _notificationsGranted,
            onRequest: _requestNotificationPermission,
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data stays private. Location is only shared with caregivers you add.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onRequest,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: granted
                    ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                    : AppTheme.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: granted ? AppTheme.primaryGreen : AppTheme.primaryOrange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            granted
                ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 32)
                : ElevatedButton(
                    onPressed: onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Allow', style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _locationGranted = true);

      // Also try to get "always" if we only got "whileInUse"
      if (permission == LocationPermission.whileInUse) {
        final bg = await Geolocator.requestPermission();
        setState(() => _locationGranted = bg == LocationPermission.always || bg == LocationPermission.whileInUse);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    // iOS permissions are handled during NotificationService.initialize().
    // On Android 13+, request the POST_NOTIFICATIONS runtime permission.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    setState(() => _notificationsGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional);
  }

  Widget _buildQuickReminderPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _previousPage,
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(height: 16),

          const Text(
            'First Reminder',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up a daily reminder (you can add more later)',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          // Quick presets
          const Text('Quick presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Take Medicine', ReminderType.medication, const TimeOfDay(hour: 8, minute: 0)),
              _buildPresetChip('Feed the Dog', ReminderType.petCare, const TimeOfDay(hour: 7, minute: 0)),
              _buildPresetChip('Drink Water', ReminderType.hydration, const TimeOfDay(hour: 10, minute: 0)),
              _buildPresetChip('Take a Walk', ReminderType.exercise, const TimeOfDay(hour: 9, minute: 0)),
              _buildPresetChip('Eat Lunch', ReminderType.mealTime, const TimeOfDay(hour: 12, minute: 0)),
              _buildPresetChip('Check Water Bowl', ReminderType.petCare, const TimeOfDay(hour: 17, minute: 0)),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Or create your own:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          TextField(
            controller: _reminderTitleController,
            decoration: const InputDecoration(
              labelText: 'Reminder Title',
              prefixIcon: Icon(Icons.edit),
              hintText: 'e.g., Water the plants',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ReminderType>(
            initialValue: _reminderType,
            decoration: const InputDecoration(
              labelText: 'Type',
              prefixIcon: Icon(Icons.category),
            ),
            items: ReminderType.values.map((type) {
              return DropdownMenuItem(value: type, child: Text(type.displayName));
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _reminderType = v);
            },
          ),
          const SizedBox(height: 16),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: AppTheme.primaryBlue),
            title: Text(
              'Time: ${_reminderTime.format(context)}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _reminderTime,
              );
              if (time != null) setState(() => _reminderTime = time);
            },
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: _nextPage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'SKIP',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveQuickReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'ADD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String title, ReminderType type, TimeOfDay time) {
    return ActionChip(
      avatar: Icon(_getPresetIcon(type), size: 18),
      label: Text(title),
      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
      onPressed: () {
        setState(() {
          _reminderTitleController.text = title;
          _reminderType = type;
          _reminderTime = time;
        });
      },
    );
  }

  IconData _getPresetIcon(ReminderType type) {
    switch (type) {
      case ReminderType.medication:
        return Icons.medication;
      case ReminderType.petCare:
        return Icons.pets;
      case ReminderType.mealTime:
        return Icons.restaurant;
      case ReminderType.hydration:
        return Icons.water_drop;
      case ReminderType.exercise:
        return Icons.fitness_center;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _saveQuickReminder() async {
    if (_reminderTitleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a reminder title or pick a preset');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = ref.read(userNotifierProvider);
      final user = userProvider.user;
      if (user == null) return;

      final reminderService = ref.read(reminderServiceProvider);
      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year, now.month, now.day,
        _reminderTime.hour, _reminderTime.minute,
      );

      await reminderService.createReminder(Reminder(
        id: '',
        userId: user.id,
        title: _reminderTitleController.text.trim(),
        type: _reminderType,
        scheduledTime: scheduledTime,
        repeatFrequency: RepeatFrequency.daily,
        createdBy: _caregiverId ?? '',
      ));

      if (!mounted) return;
      _nextPage();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCompletePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 100,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'All Set!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Lumina is ready to help',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),

          // Tips
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Steps for Caregivers:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTipRow('Add emergency contacts'),
                _buildTipRow('Set up medications'),
                _buildTipRow('Create daily reminders'),
                _buildTipRow('Define safe zones'),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _completeSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'START USING APP',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCaregiverAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    if ((_authMode == 0 || _authMode == 2) && _nameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    if (_authMode == 2 && _inviteCodeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-character invite code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      if (_authMode == 0 || _authMode == 2) {
        final credential = await authService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );
        _caregiverId = credential.user!.uid;
      } else {
        final credential = await authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        _caregiverId = credential.user!.uid;
      }

      await _afterCaregiverAuthed();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Sign in / sign up with Apple or Google. Works in all three modes:
  /// New (account created from the provider profile), Sign In, and
  /// Have a Code (code redeemed after the OAuth sign-in).
  Future<void> _handleOAuthAuth(
    Future<UserCredential> Function() signIn,
  ) async {
    if (_authMode == 2 && _inviteCodeController.text.trim().length != 6) {
      setState(() =>
          _errorMessage = 'Please enter a valid 6-character invite code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await signIn();
      _caregiverId = credential.user!.uid;
      await _afterCaregiverAuthed();
    } catch (e) {
      // Don't show an error when the user simply dismissed the sheet.
      final msg = e.toString().toLowerCase();
      if (!msg.contains('cancel')) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shared continuation after a caregiver account is authenticated
  /// (email, Apple, or Google).
  Future<void> _afterCaregiverAuthed() async {
    // If invite mode, redeem code and skip patient creation
    if (_authMode == 2) {
      final inviteService = ref.read(inviteServiceProvider);
      final patient = await inviteService.redeemInviteCode(
        code: _inviteCodeController.text.trim(),
        caregiverId: _caregiverId!,
      );

      if (!mounted) return;

      final appState = ref.read(appStateNotifierProvider);
      await appState.setSetupComplete(
        userId: patient.id,
        caregiverId: _caregiverId,
      );

      final userProvider = ref.read(userNotifierProvider);
      await userProvider.loadUser(patient.id);

      final caregiverProvider = ref.read(caregiverNotifierProvider);
      await caregiverProvider.loadCaregiver(_caregiverId!);

      _joinedViaInvite = true;
      _pageController.jumpToPage(_totalPages - 1);
      return;
    }

    _nextPage();
  }

  Future<void> _handleCreateUser() async {
    if (_userNameController.text.isEmpty || _homeAddressController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final locationService = ref.read(locationServiceProvider);

      // Get home location from address
      final homeLocation =
          await locationService.getLocationFromAddress(_homeAddressController.text.trim());

      if (homeLocation == null) {
        setState(() =>
            _errorMessage = 'Could not find address. Please try a different format.');
        setState(() => _isLoading = false);
        return;
      }

      // Create user
      final preferredName = _userPreferredNameController.text.trim();
      final user = await authService.createUser(
        name: _userNameController.text.trim(),
        preferredName: preferredName.isEmpty ? null : preferredName,
        phoneNumber: _userPhoneController.text.trim(),
        primaryCaregiverId: _caregiverId!,
      );

      // Update with home location
      await authService.updateUser(user.copyWith(
        homeLocation: homeLocation,
        homeAddress: _homeAddressController.text.trim(),
      ));

      if (!mounted) return;

      // Save to app state
      final appState = ref.read(appStateNotifierProvider);
      await appState.setSetupComplete(
        userId: user.id,
        caregiverId: _caregiverId,
      );

      if (!mounted) return;

      // Load user data
      final userProvider = ref.read(userNotifierProvider);
      await userProvider.loadUser(user.id);

      _nextPage();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _completeSetup() async {
    if (!_joinedViaInvite) {
      // Request background location permission for safety monitoring
      final locationService = ref.read(locationServiceProvider);
      await locationService.requestBackgroundPermission();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => _joinedViaInvite
            ? const CaregiverDashboardScreen()
            : const UserHomeScreen(),
      ),
    );
  }
}
