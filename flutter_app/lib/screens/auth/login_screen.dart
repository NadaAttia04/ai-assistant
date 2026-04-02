import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../patient/patient_home_screen.dart';
import '../doctor/doctor_dashboard_screen.dart';
import '../role_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isDoctor = false;
  bool _forgotLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final isRegister = _tab.index == 1;

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (isRegister) {
      if (name.isEmpty) {
        _showError('Full name is required.');
        return;
      }
      final confirm = _confirmPassCtrl.text.trim();
      if (password != confirm) {
        _showError('Passwords do not match.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final Map<String, dynamic> result;
      if (isRegister) {
        result = await ApiService.register(name, email, password);
      } else {
        result = await ApiService.login(email, password);
      }

      if (result['error'] != null) {
        _showError(_friendlyError(result['error'].toString()));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', result['user_id'].toString());
      await prefs.setString('user_name', result['name']?.toString() ?? email);

      if (!mounted) return;
      if (isRegister) {
        final role = _isDoctor ? 'doctor' : 'patient';
        await prefs.setString('user_role', role);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => role == 'doctor'
              ? const DoctorDashboardScreen()
              : const PatientHomeScreen(),
        ));
      } else {
        final savedRole = prefs.getString('user_role');
        Widget dest;
        if (savedRole == 'doctor') {
          dest = const DoctorDashboardScreen();
        } else if (savedRole == 'patient') {
          dest = const PatientHomeScreen();
        } else {
          dest = const RoleScreen();
        }
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => dest));
      }
    } catch (e) {
      _showError('Connection error. Check your network and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('not found') || r.contains('no account')) {
      return 'No account found with this email. Please register first.';
    }
    if (r.contains('invalid') || r.contains('incorrect') || r.contains('wrong')) {
      return 'Incorrect password. Please try again.';
    }
    if (r.contains('already') || r.contains('registered')) {
      return 'This email is already registered. Please sign in.';
    }
    return raw;
  }

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', 'guest');
    await prefs.setString('user_name', 'Guest');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleScreen()),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.lock_reset_rounded,
                color: AppColors.secondary, size: 22),
            SizedBox(width: 8),
            Text('Reset Password'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we\'ll send you instructions to reset your password.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _forgotLoading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => _forgotLoading = true);
                      try {
                        final result =
                            await ApiService.forgotPassword(email);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (result['error'] != null) {
                          _showError(
                              _friendlyError(result['error'].toString()));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ??
                                  'Instructions sent to $email'),
                              backgroundColor:
                                  const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          _showError('Connection error. Please try again.');
                        }
                      } finally {
                        if (mounted) {
                          setDialogState(() => _forgotLoading = false);
                        }
                      }
                    },
              style:
                  ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: _forgotLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRegister = _tab.index == 1;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Image.asset('assets/bot_icon.jpg',
                    fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Text(
                'Health AI',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your AI-powered medical companion',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2E)
                      : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.white54 : AppColors.textMuted,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Sign In'),
                    Tab(text: 'Register'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name field (register only)
              if (isRegister) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon:
                        Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // Role selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isDoctor = false),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isDoctor
                                  ? AppColors.secondary
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_rounded,
                                    size: 16,
                                    color: !_isDoctor
                                        ? Colors.white
                                        : AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text('Patient',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: !_isDoctor
                                            ? Colors.white
                                            : AppColors
                                                .textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isDoctor = true),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: _isDoctor
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons.medical_services_rounded,
                                    size: 16,
                                    color: _isDoctor
                                        ? Colors.white
                                        : AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text('Doctor',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: _isDoctor
                                            ? Colors.white
                                            : AppColors
                                                .textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: isRegister ? null : (_) => _submit(),
              ),

              // Confirm password (register only)
              if (isRegister) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon:
                        const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
              ],

              // Forgot password
              if (!isRegister) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : Text(isRegister
                          ? 'Create Account'
                          : 'Sign In'),
                ),
              ),
              const SizedBox(height: 12),

              // Guest button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _continueAsGuest,
                  icon: const Icon(
                      Icons.person_outline_rounded),
                  label: const Text('Continue as Guest'),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white30
                        : AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
