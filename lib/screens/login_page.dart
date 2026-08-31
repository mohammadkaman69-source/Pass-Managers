import 'package:flutter/material.dart';

import '../security/security_manager.dart';
import '../security/biometric_service.dart';
import '../services/app_language.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoginSuccess});

  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _securityManager = SecurityManager();
  final _biometricService = BiometricService();

  bool _isSetup = false;
  bool _checking = true;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _obscure = true;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final configured = await _securityManager.isMasterPasswordConfigured();
      if (!mounted) return;
      setState(() {
        _isSetup = !configured;
        _checking = false;
      });
      if (configured) {
        _tryBiometric();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _isSetup = true;
      });
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final ok = await _biometricService.authenticate();
      if (ok && mounted) widget.onLoginSuccess();
    } catch (_) {}
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPasswordChanged(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value)) score++;
    if (value.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    setState(() => _strength = score.clamp(0, 3));
  }

  bool get _passwordValid {
    final p = _passwordController.text;
    return p.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p);
  }

  Future<void> _submitLogin() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      _showMessage(AppStrings.enterPassword(context));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await _securityManager.unlock(password);
      if (!mounted) return;
      if (ok) {
        widget.onLoginSuccess();
      } else {
        _showMessage(AppStrings.wrongPassword(context));
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppStrings.securityOperationFailed(context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSetup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (email.isEmpty) {
      _showMessage(AppStrings.enterEmail(context));
      return;
    }
    if (!email.contains('@')) {
      _showMessage(AppStrings.invalidEmail(context));
      return;
    }
    if (!_passwordValid) {
      _showMessage(AppStrings.weakPassword(context));
      return;
    }
    if (password != confirm) {
      _showMessage(AppStrings.passwordsMismatch(context));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _securityManager.setupMasterPassword(email: email, masterPassword: password);
      if (!mounted) return;
      widget.onLoginSuccess();
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppStrings.securityOperationFailed(context));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _chooseLanguage() async {
    final current = AppLanguage.instance.locale.languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.selectLanguage(ctx)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(AppStrings.persian(ctx)),
              value: 'fa',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: Text(AppStrings.english(ctx)),
              value: 'en',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await AppLanguage.instance.setLanguage(selected);
      if (mounted) {
        setState(() {});
        _showMessage(AppStrings.languageChanged(context));
      }
    }
  }

  Widget _strengthBar() {
    final labels = {
      0: '',
      1: AppStrings.strengthWeak(context),
      2: AppStrings.strengthMedium(context),
      3: AppStrings.strengthStrong(context),
    };
    final colors = {0: Colors.grey, 1: Colors.red, 2: Colors.orange, 3: Colors.green};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: _strength / 3,
          color: colors[_strength],
          backgroundColor: Colors.grey.shade300,
        ),
        if (_strength > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(labels[_strength]!, style: TextStyle(color: colors[_strength], fontSize: 12)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NexVault'),
        actions: [
          IconButton(
            tooltip: AppStrings.language(context),
            onPressed: _chooseLanguage,
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _isSetup ? AppStrings.createAccount(context) : AppStrings.login(context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(AppStrings.encryptionInfo(context)),
            const SizedBox(height: 24),
            if (_isSetup) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: AppStrings.email(context),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onChanged: _isSetup ? _onPasswordChanged : null,
              decoration: InputDecoration(
                labelText: AppStrings.mainPassword(context),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            if (_isSetup) ...[
              const SizedBox(height: 8),
              Text(AppStrings.passwordRule(context), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              _strengthBar(),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppStrings.confirmPassword(context),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isLoading || _isSubmitting)
                  ? null
                  : (_isSetup ? _submitSetup : _submitLogin),
              child: (_isLoading || _isSubmitting)
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isSetup ? AppStrings.createAccount(context) : AppStrings.login(context)),
            ),
            if (!_isSetup) ...[
              TextButton(
                onPressed: () => _showMessage(AppStrings.recoverySoon(context)),
                child: Text(AppStrings.forgotPassword(context)),
              ),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text(AppStrings.biometricLogin(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
