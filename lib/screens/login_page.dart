import 'package:flutter/material.dart';

import '../security/security_manager.dart';
import '../security/biometric_service.dart';
import '../services/app_language.dart';
import '../widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SecurityManager _securityManager = SecurityManager();
  final BiometricService _biometricService = BiometricService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool createMode = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onFieldsChanged);
    confirmController.addListener(_onFieldsChanged);
    emailController.addListener(_onFieldsChanged);
    _checkPasswordStatus();
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    emailController.removeListener(_onFieldsChanged);
    passwordController.removeListener(_onFieldsChanged);
    confirmController.removeListener(_onFieldsChanged);
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    try {
      final exists = await _securityManager.isMasterPasswordConfigured();
      if (!mounted) return;
      final biometricAvailable = await _biometricService.isSupported();
      final biometricEnabled = await _biometricService.isEnabled();
      if (!mounted) return;
      setState(() {
        createMode = !exists;
        _biometricEnabled = biometricEnabled && biometricAvailable;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(AppStrings.securityOperationFailed(context, error));
    }
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    return hasLetter && hasNumber;
  }

  bool _validateEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

  int _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/]').hasMatch(password)) score++;
    if (score <= 2) return 1;
    if (score <= 4) return 2;
    return 3;
  }

  bool get _canCreateAccount {
    if (!createMode) return true;
    return _validateEmail(emailController.text.trim()) &&
        _validatePassword(passwordController.text) &&
        passwordController.text == confirmController.text;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (createMode) {
      if (email.isEmpty) {
        _showMessage(AppStrings.enterEmail(context));
        return;
      }
      if (!_validateEmail(email)) {
        _showMessage(AppStrings.invalidEmail(context));
        return;
      }
    }
    if (password.isEmpty) {
      _showMessage(AppStrings.enterPassword(context));
      return;
    }
    if (createMode) {
      if (!_validatePassword(password)) {
        _showMessage(AppStrings.weakPassword(context));
        return;
      }
      if (password != confirmController.text) {
        _showMessage(AppStrings.passwordsMismatch(context));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      if (createMode) {
        await _securityManager.setupMasterPassword(email: email, masterPassword: password);
        if (!mounted) return;
        _openHome();
        return;
      }
      final unlocked = await _securityManager.unlock(password);
      if (!mounted) return;
      if (!unlocked) {
        _showMessage(AppStrings.wrongPassword(context));
        return;
      }
      _openHome();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppStrings.securityOperationFailed(context, error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_isSubmitting || !_biometricEnabled) return;
    setState(() => _isSubmitting = true);
    try {
      final unlocked = await _biometricService.authenticateAndUnlock();
      if (!mounted) return;
      if (unlocked) {
        _openHome();
      } else {
        _showMessage(AppStrings.biometricFailed(context));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _chooseLanguage() async {
    final current = AppLanguage.instance.locale.languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.selectLanguage(context)),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) Navigator.pop(dialogContext, value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: 'fa', title: Text(AppStrings.persian(context))),
              RadioListTile<String>(value: 'en', title: Text(AppStrings.english(context))),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await AppLanguage.instance.setLanguage(selected);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openHome() {
    if (mounted) widget.onLoginSuccess?.call();
  }

  Widget _buildStrengthBar(String password) {
    final level = _passwordStrength(password);
    final colors = {0: Colors.grey.shade300, 1: Colors.red, 2: Colors.orange, 3: Colors.green};
    final labels = {0: '', 1: AppLanguage.instance.isPersian ? 'ضعیف' : 'Weak', 2: AppLanguage.instance.isPersian ? 'متوسط' : 'Medium', 3: AppLanguage.instance.isPersian ? 'قوی' : 'Strong'};
    final color = colors[level]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: level == 0 ? 0 : level / 3, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
        if (level > 0) ...[
          const SizedBox(height: 6),
          Text(labels[level]!, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final password = passwordController.text;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(height: 110, showShadow: true),
                const SizedBox(height: 16),
                const Text('NexVault', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _isSubmitting ? null : _chooseLanguage,
                    icon: const Icon(Icons.language),
                    label: Text(AppStrings.language(context)),
                  ),
                ),
                const SizedBox(height: 10),
                if (createMode) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(labelText: AppStrings.email(context), hintText: 'example@email.com', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !_isSubmitting,
                  textInputAction: createMode ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: (_) { if (!createMode) _submit(); },
                  decoration: InputDecoration(labelText: AppStrings.mainPassword(context), border: const OutlineInputBorder()),
                ),
                if (createMode) ...[
                  _buildStrengthBar(password),
                  const SizedBox(height: 8),
                  Text(AppStrings.passwordRule(context), textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) { if (_canCreateAccount) _submit(); },
                    decoration: InputDecoration(labelText: AppStrings.confirmPassword(context), border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Text(AppStrings.encryptionInfo(context), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : (createMode && !_canCreateAccount ? null : _submit),
                    child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(createMode ? AppStrings.createAccount(context) : AppStrings.login(context)),
                  ),
                ),
                if (!createMode && _biometricEnabled) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _isSubmitting ? null : _loginWithBiometric, icon: const Icon(Icons.fingerprint), label: Text(AppStrings.biometricLogin(context)))),
                ],
                if (!createMode) ...[
                  const SizedBox(height: 25),
                  Text(AppStrings.forgotPassword(context), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(AppStrings.recoverySoon(context), style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
