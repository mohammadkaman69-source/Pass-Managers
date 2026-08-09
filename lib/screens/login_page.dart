import 'package:flutter/material.dart';

import '../security/master_password_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final MasterPasswordService _masterPasswordService =
      MasterPasswordService();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  bool createMode = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkPasswordStatus();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> checkPasswordStatus() async {
    try {
      final exists =
          await _masterPasswordService.isMasterPasswordConfigured();

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
        'Failed to check password status: $error',
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

  bool validateEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  Future<void> submit() async {
    if (isLoading) {
      return;
    }

    final password = passwordController.text;

    if (createMode) {
      if (!validatePassword(password)) {
        showMessage(
          'Password must be at least 8 characters and contain letters and numbers',
        );
        return;
      }

      if (password != confirmController.text) {
        showMessage(
          'Passwords do not match',
        );
        return;
      }

      if (!validateEmail(emailController.text)) {
        showMessage(
          'Invalid email format',
        );
        return;
      }

      try {
        setState(() {
          isLoading = true;
        });

        await _masterPasswordService.setupMasterPassword(
          password,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        openHome();
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        showMessage(
          'Failed to create Master Password: $error',
        );
      }
    } else {
      if (password.isEmpty) {
        showMessage(
          'Enter Master Password',
        );
        return;
      }

      try {
        setState(() {
          isLoading = true;
        });

        final result =
            await _masterPasswordService.verifyMasterPassword(
          password,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        if (result) {
          openHome();
        } else {
          showMessage(
            'Wrong Master Password',
          );
        }
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });

        showMessage(
          'Login failed: $error',
        );
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
        builder: (context) => const HomePage(),
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
                  decoration: const InputDecoration(
                    labelText: 'Master Password',
                  ),
                ),
                if (createMode) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Master Password',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Recovery Email',
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: isLoading ? null : submit,
                  child: Text(
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
                    'Password recovery will be available soon',
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
