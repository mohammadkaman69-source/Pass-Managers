import 'package:flutter/material.dart';

import '../security/security_manager.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  final SecurityManager _securityManager = SecurityManager();

  bool createMode = false;
  bool isLoading = true;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _checkSecurityStatus();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurityStatus() async {
    try {
      final configured =
          await _securityManager.isMasterPasswordConfigured();

      if (!mounted) {
        return;
      }

      setState(() {
        createMode = !configured;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Failed to check security status: $error',
      );
    }
  }

  bool _validatePassword(String password) {
    if (password.length < 8) {
      return false;
    }

    final hasLetter =
        RegExp(r'[A-Za-z]').hasMatch(password);

    final hasNumber =
        RegExp(r'[0-9]').hasMatch(password);

    return hasLetter && hasNumber;
  }

  Future<void> _submit() async {
    if (isLoading) {
      return;
    }

    final password = passwordController.text;

    if (password.isEmpty) {
      _showMessage(
        createMode
            ? 'Enter a Master Password'
            : 'Enter Master Password',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (createMode) {
        await _createMasterPassword(password);
      } else {
        await _unlock(password);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Security operation failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _createMasterPassword(
    String password,
  ) async {
    if (!_validatePassword(password)) {
      _showMessage(
        'Master Password must be at least 8 characters '
        'and contain letters and numbers.',
      );
      return;
    }

    if (password != confirmController.text) {
      _showMessage(
        'Master Passwords do not match.',
      );
      return;
    }

    await _securityManager.setupMasterPassword(
      password,
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Master Password created successfully.',
    );

    _openHome();
  }

  Future<void> _unlock(String password) async {
    final unlocked =
        await _securityManager.unlock(password);

    if (!unlocked) {
      _showMessage(
        'Wrong Master Password.',
      );
      return;
    }

    _openHome();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _openHome() {
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && !createMode) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pass Managers',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    suffixIcon: IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                obscurePassword =
                                    !obscurePassword;
                              });
                            },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                if (createMode) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirmPassword,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText:
                          'Confirm Master Password',
                      suffixIcon: IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Master Password must be at least 8 characters '
                    'and contain letters and numbers.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          createMode ? 'Create' : 'Login',
                        ),
                ),
                if (!createMode) ...[
                  const SizedBox(height: 25),
                  const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Password recovery is not available yet.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
