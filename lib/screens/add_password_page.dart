import 'dart:math';

import 'package:flutter/material.dart';

class AddPasswordPage extends StatefulWidget {
  const AddPasswordPage({super.key});

  @override
  State<AddPasswordPage> createState() => _AddPasswordPageState();
}

class _AddPasswordPageState extends State<AddPasswordPage> {
  final titleController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final websiteController = TextEditingController();
  final noteController = TextEditingController();

  bool obscurePassword = true;

  int passwordLength = 16;

  bool useLowercase = true;
  bool useUppercase = true;
  bool useNumbers = true;
  bool useSymbols = true;

  @override
  void dispose() {
    titleController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    websiteController.dispose();
    noteController.dispose();

    super.dispose();
  }

  String generatePassword() {
    final lower = 'abcdefghijklmnopqrstuvwxyz';
    final upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final numbers = '0123456789';
    final symbols = r'!@#$%^&*()-_=+[]{};:,.?/';

    String available = '';

    if (useLowercase) {
      available += lower;
    }

    if (useUppercase) {
      available += upper;
    }

    if (useNumbers) {
      available += numbers;
    }

    if (useSymbols) {
      available += symbols;
    }

    if (available.isEmpty) {
      return '';
    }

    final random = Random();

    return List.generate(
      passwordLength,
      (_) => available[random.nextInt(available.length)],
    ).join();
  }

  void createPassword() {
    final password = generatePassword();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select at least one password character type.',
          ),
        ),
      );

      return;
    }

    passwordController.text = password;

    setState(() {
      obscurePassword = false;
    });
  }

  void savePassword() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a title.',
          ),
        ),
      );

      return;
    }

    if (passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter or generate a password.',
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Save will be added later.',
        ),
      ),
    );
  }

  Widget buildPasswordOption({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Password',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Example: Nextcloud',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
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

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: createPassword,
                icon: const Icon(
                  Icons.auto_fix_high,
                ),
                label: const Text(
                  'Generate Password',
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Password Configuration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Password Length: $passwordLength',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            Slider(
              min: 8,
              max: 64,
              divisions: 56,
              value: passwordLength.toDouble(),
              label: passwordLength.toString(),
              onChanged: (value) {
                setState(() {
                  passwordLength = value.round();
                });
              },
            ),

            buildPasswordOption(
              title: 'Lowercase letters (a-z)',
              value: useLowercase,
              onChanged: (value) {
                setState(() {
                  useLowercase = value ?? false;
                });
              },
            ),

            buildPasswordOption(
              title: 'Uppercase letters (A-Z)',
              value: useUppercase,
              onChanged: (value) {
                setState(() {
                  useUppercase = value ?? false;
                });
              },
            ),

            buildPasswordOption(
              title: 'Numbers (0-9)',
              value: useNumbers,
              onChanged: (value) {
                setState(() {
                  useNumbers = value ?? false;
                });
              },
            ),

            buildPasswordOption(
              title: 'Symbols (!@#...)',
              value: useSymbols,
              onChanged: (value) {
                setState(() {
                  useSymbols = value ?? false;
                });
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: websiteController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: savePassword,
                icon: const Icon(
                  Icons.save,
                ),
                label: const Text(
                  'Save',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
