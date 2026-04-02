import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _governorateCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _userId = '';
  String _email = '';
  String _role = 'patient';
  String? _avatarUrl;
  File? _avatarFile;
  bool _loading = true;
  bool _saving = false;
  bool _changingPass = false;
  bool _uploadingAvatar = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const _base = 'http://192.168.1.6:5000';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _governorateCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';
    _role = prefs.getString('user_role') ?? 'patient';
    if (_userId.isEmpty || _userId == 'guest') {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await ApiService.getUserProfile(_userId);
      if (mounted) {
        setState(() {
          _nameCtrl.text = data['name'] ?? '';
          _email = data['email'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _ageCtrl.text = data['age']?.toString() ?? '';
          _addressCtrl.text = data['address'] ?? '';
          _cityCtrl.text = data['city'] ?? '';
          _governorateCtrl.text = data['governorate'] ?? '';
          final rawUrl = data['avatar_url'] as String?;
          _avatarUrl = (rawUrl != null && rawUrl.isNotEmpty) ? '$_base$rawUrl' : null;
          _loading = false;
        });
      }
    } catch (_) {
      final name = prefs.getString('user_name') ?? '';
      if (mounted) {
        setState(() {
          _nameCtrl.text = name;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _avatarFile = File(picked.path);
      _uploadingAvatar = true;
    });

    try {
      final url = await ApiService.uploadAvatar(_userId, picked.path);
      if (!mounted) return;
      setState(() => _avatarUrl = url != null ? '$_base$url' : _avatarUrl);
      _showSnack('Profile picture updated');
    } catch (e) {
      if (mounted) _showSnack('Failed to upload: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Name cannot be empty', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ApiService.updateUserProfile(_userId, {
        'name': name,
        'phone': _phoneCtrl.text.trim(),
        'age': _ageCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'governorate': _governorateCtrl.text.trim(),
      });
      if (!mounted) return;
      if (result['error'] != null) {
        _showSnack(result['error'], isError: true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        _showSnack('Profile updated successfully');
      }
    } catch (_) {
      if (mounted) _showSnack('Connection error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty) {
      _showSnack('Please fill all password fields', isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnack('New passwords do not match', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _changingPass = true);
    try {
      final result = await ApiService.changePassword(_userId, current, newPass);
      if (!mounted) return;
      if (result['error'] != null) {
        _showSnack(result['error'], isError: true);
      } else {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _showSnack('Password changed successfully');
      }
    } catch (_) {
      if (mounted) _showSnack('Connection error', isError: true);
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, minimumSize: Size.zero),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : const Color(0xFF16A34A),
    ));
  }

  Widget _buildAvatar(bool isDark) {
    return GestureDetector(
      onTap: _userId == 'guest' ? null : _pickAndUploadAvatar,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: _avatarFile != null
                ? FileImage(_avatarFile!)
                : (_avatarUrl != null
                    ? NetworkImage(_avatarUrl!) as ImageProvider
                    : null),
            child: (_avatarFile == null && _avatarUrl == null)
                ? Icon(
                    _role == 'doctor'
                        ? Icons.medical_services_rounded
                        : Icons.person_rounded,
                    size: 52,
                    color: AppColors.primary,
                  )
                : null,
          ),
          if (_uploadingAvatar)
            Positioned.fill(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: Colors.black45,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                ),
              ),
            ),
          if (!_uploadingAvatar && _userId != 'guest')
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF0F0F1A) : Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + name header
                  Center(
                    child: Column(
                      children: [
                        _buildAvatar(isDark),
                        const SizedBox(height: 4),
                        if (_userId != 'guest')
                          TextButton(
                            onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Change Photo',
                                style: TextStyle(fontSize: 13, color: AppColors.secondary)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (_email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_email,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted)),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_role == 'doctor'
                                    ? AppColors.primary
                                    : AppColors.secondary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _role == 'doctor' ? 'Doctor' : 'Patient',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _role == 'doctor'
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Personal info
                  _SectionHeader(label: 'Personal Information', isDark: isDark),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _ProfileField(
                          controller: _nameCtrl,
                          label: 'Full Name',
                          icon: Icons.person_outline_rounded,
                        ),
                        _Divider(),
                        _ProfileField(
                          controller: null,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          enabled: false,
                          hint: _email.isEmpty ? 'Not set' : _email,
                        ),
                        _Divider(),
                        _ProfileField(
                          controller: _phoneCtrl,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                        ),
                        _Divider(),
                        _ProfileField(
                          controller: _ageCtrl,
                          label: 'Age',
                          icon: Icons.cake_outlined,
                          keyboard: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address info
                  _SectionHeader(label: 'Address', isDark: isDark),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _ProfileField(
                          controller: _addressCtrl,
                          label: 'Street Address',
                          icon: Icons.home_outlined,
                        ),
                        _Divider(),
                        _ProfileField(
                          controller: _cityCtrl,
                          label: 'City',
                          icon: Icons.location_city_outlined,
                        ),
                        _Divider(),
                        _ProfileField(
                          controller: _governorateCtrl,
                          label: 'Governorate',
                          icon: Icons.map_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Change password
                  _SectionHeader(label: 'Change Password', isDark: isDark),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _PassField(
                          controller: _currentPassCtrl,
                          label: 'Current Password',
                          obscure: _obscureCurrent,
                          onToggle: () => setState(
                              () => _obscureCurrent = !_obscureCurrent),
                        ),
                        _Divider(),
                        _PassField(
                          controller: _newPassCtrl,
                          label: 'New Password',
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                        _Divider(),
                        _PassField(
                          controller: _confirmPassCtrl,
                          label: 'Confirm New Password',
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _changingPass ? null : _changePassword,
                      icon: _changingPass
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.lock_reset_rounded, size: 18),
                      label: Text(
                          _changingPass ? 'Changing...' : 'Change Password'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.error),
                      label: const Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 0.5);
}

class _ProfileField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final bool enabled;
  final String? hint;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const UnderlineInputBorder(),
        disabledBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary));
  }
}

class _ProfileCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _ProfileCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PassField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const UnderlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
    );
  }
}
