import 'package:flutter/material.dart';

import '../security/security_manager.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SecurityManager _securityManager =
      SecurityManager();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  bool createMode = false;
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    checkPasswordStatus();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> checkPasswordStatus() async {
    try {
      final exists =
          await _securityManager.isMasterPasswordConfigured();

      if (!mounted) {
        return;
      }

      setState(() {
        createMode = !exists;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      showMessage(
        'Failed to check security status: $error',
      );
    }
  }

  bool validatePassword(String password) {
    if (password.length < 8) {
      return false;
    }

    final hasLetter =
        RegExp(r'[A-Za-z]').hasMatch(password);

    final hasNumber =
        RegExp(r'[0-9]').hasMatch(password);

    return hasLetter && hasNumber;
  }

  Future<void> submit() async {
    if (isSubmitting) {
      return;
    }

    final password =
        passwordController.text;

    if (password.isEmpty) {
      showMessage(
        createMode
            ? 'Enter a Master Password'
            : 'Enter Master Password',
      );
      return;
    }

    if (createMode) {
      if (!validatePassword(password)) {
        showMessage(
          'Master Password must be at least 8 characters and contain letters and numbers.',
        );
        return;
      }

      if (password != confirmController.text) {
        showMessage(
          'Passwords do not match.',
        );
        return;
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      if (createMode) {
        await _securityManager.setupMasterPassword(
          password,
        );

        openHome();
      } else {
        final result =
            await _securityManager.unlock(
          password,
        );

        if (result) {
          openHome();
        } else {
          showMessage(
            'Wrong Master Password.',
          );
        }
      }
    } catch (error) {
      showMessage(
        'Security operation failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void openHome() {
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
                  obscureText: true,
                  enabled: !isSubmitting,
                  decoration:
                      const InputDecoration(
                    labelText: 'Master Password',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (createMode) ...[
                  const SizedBox(height: 20),

                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    enabled: !isSubmitting,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Confirm Master Password',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Your Master Password is used to derive the encryption key for your password data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        isSubmitting ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            createMode
                                ? 'Create'
                                : 'Login',
                          ),
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
                    'Password recovery will be available soon.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
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
