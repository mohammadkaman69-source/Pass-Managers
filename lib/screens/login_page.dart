import 'package:flutter/material.dart';

import '../security/security_manager.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  final TextEditingController recoveryEmailController =
      TextEditingController();

  final SecurityManager _securityManager =
      SecurityManager();

  bool createMode = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    recoveryEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    try {
      final exists =
          await _securityManager
              .isMasterPasswordConfigured();

      if (!mounted) {
        return;
      }

      setState(() {
        createMode = !exists;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Failed to check security status: $error',
      );
    }
  }

  bool _validatePassword(
    String password,
  ) {
    if (password.length < 8) {
      return false;
    }

    final hasLetter =
        RegExp(r'[A-Za-z]').hasMatch(password);

    final hasNumber =
        RegExp(r'[0-9]').hasMatch(password);

    return hasLetter && hasNumber;
  }

  bool _validateEmail(
    String email,
  ) {
    final value = email.trim();

    if (value.isEmpty) {
      return false;
    }

    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value);
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final password =
        passwordController.text;

    if (password.isEmpty) {
      _showMessage(
        createMode
            ? 'Enter a Master Password'
            : 'Enter Master Password',
      );
      return;
    }

    if (createMode) {
      if (!_validatePassword(password)) {
        _showMessage(
          'Master Password must be at least 8 characters and contain letters and numbers.',
        );
        return;
      }

      if (password !=
          confirmController.text) {
        _showMessage(
          'Passwords do not match.',
        );
        return;
      }

      final recoveryEmail =
          recoveryEmailController.text.trim();

      if (!_validateEmail(recoveryEmail)) {
        _showMessage(
          'Enter a valid Recovery Email.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (createMode) {
        await _securityManager
            .setupMasterPassword(
          password,
          recoveryEmail:
              recoveryEmailController.text
                  .trim(),
        );

        _openHome();
        return;
      }

      final unlocked =
          await _securityManager.unlock(
        password,
      );

      if (!unlocked) {
        _showMessage(
          'Wrong Master Password.',
        );
        return;
      }

      _openHome();
    } catch (error) {
      _showMessage(
        'Security operation failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
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
        builder: (_) =>
            const HomePage(),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'Pass Managers',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller:
                      passwordController,
                  obscureText:
                      _obscurePassword,
                  enabled:
                      !_isSubmitting,
                  textInputAction:
                      createMode
                          ? TextInputAction
                              .next
                          : TextInputAction
                              .done,
                  onSubmitted: (_) {
                    if (!createMode) {
                      _submit();
                    }
                  },
                  decoration:
                      InputDecoration(
                    labelText:
                        'Master Password',
                    border:
                        const OutlineInputBorder(),
                    suffixIcon:
                        IconButton(
                      onPressed:
                          _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),

                if (createMode) ...[
                  const SizedBox(height: 20),

                  TextField(
                    controller:
                        confirmController,
                    obscureText:
                        _obscureConfirmPassword,
                    enabled:
                        !_isSubmitting,
                    textInputAction:
                        TextInputAction
                            .next,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Confirm Master Password',
                      border:
                          const OutlineInputBorder(),
                      suffixIcon:
                          IconButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller:
                        recoveryEmailController,
                    enabled:
                        !_isSubmitting,
                    keyboardType:
                        TextInputType
                            .emailAddress,
                    textInputAction:
                        TextInputAction.done,
                    onSubmitted: (_) {
                      _submit();
                    },
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Recovery Email',
                      hintText:
                          'example@email.com',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'This email will be used later for password recovery and verification.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Your Master Password is used to derive the encryption key for your password data.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 25),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : _submit,
                    child:
                        _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
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
                    style:
                        TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Password recovery will be available soon.',
                    style:
                        TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign:
                        TextAlign.center,
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
