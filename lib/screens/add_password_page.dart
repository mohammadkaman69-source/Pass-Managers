import 'dart:math';

import 'package:flutter/material.dart';

import '../services/app_language.dart';

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

  String _t(String fa, String en) => AppStrings.fa(context) ? fa : en;

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
    var available = '';
    if (useLowercase) available += lower;
    if (useUppercase) available += upper;
    if (useNumbers) available += numbers;
    if (useSymbols) available += symbols;
    if (available.isEmpty) return '';
    final random = Random.secure();
    return List.generate(passwordLength, (_) => available[random.nextInt(available.length)]).join();
  }

  void createPassword() {
    final password = generatePassword();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('حداقل یک نوع کاراکتر برای رمز انتخاب کنید.', 'Select at least one password character type.'))));
      return;
    }
    passwordController.text = password;
    setState(() => obscurePassword = false);
  }

  void savePassword() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('عنوان را وارد کنید.', 'Please enter a title.'))));
      return;
    }
    if (passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('رمز را وارد یا تولید کنید.', 'Please enter or generate a password.'))));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('ذخیره‌سازی در مرحله بعد اضافه می‌شود.', 'Save will be added later.'))));
  }

  Widget buildPasswordOption({required String title, required bool value, required ValueChanged<bool?> onChanged}) {
    return CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(title), value: value, onChanged: onChanged, dense: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('افزودن رمز', 'Add Password'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: titleController, decoration: InputDecoration(labelText: _t('عنوان', 'Title'), hintText: _t('مثال: Nextcloud', 'Example: Nextcloud'), border: const OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: usernameController, decoration: InputDecoration(labelText: _t('نام کاربری', 'Username'), border: const OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: _t('ایمیل', 'Email'), border: const OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: passwordController, obscureText: obscurePassword, decoration: InputDecoration(labelText: _t('رمز عبور', 'Password'), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off)))),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: createPassword, icon: const Icon(Icons.auto_fix_high), label: Text(_t('تولید رمز', 'Generate Password')))),
          const SizedBox(height: 25),
          Text(_t('تنظیمات رمز عبور', 'Password Configuration'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_t('طول رمز: $passwordLength', 'Password Length: $passwordLength'), style: const TextStyle(fontSize: 16)),
          Slider(min: 8, max: 64, divisions: 56, value: passwordLength.toDouble(), label: passwordLength.toString(), onChanged: (value) => setState(() => passwordLength = value.round())),
          buildPasswordOption(title: _t('حروف کوچک (a-z)', 'Lowercase letters (a-z)'), value: useLowercase, onChanged: (value) => setState(() => useLowercase = value ?? false)),
          buildPasswordOption(title: _t('حروف بزرگ (A-Z)', 'Uppercase letters (A-Z)'), value: useUppercase, onChanged: (value) => setState(() => useUppercase = value ?? false)),
          buildPasswordOption(title: _t('اعداد (0-9)', 'Numbers (0-9)'), value: useNumbers, onChanged: (value) => setState(() => useNumbers = value ?? false)),
          buildPasswordOption(title: _t('نمادها (!@#...)', 'Symbols (!@#...)'), value: useSymbols, onChanged: (value) => setState(() => useSymbols = value ?? false)),
          const SizedBox(height: 15),
          TextField(controller: websiteController, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: _t('وب‌سایت', 'Website'), hintText: 'https://example.com', border: const OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: noteController, maxLines: 4, decoration: InputDecoration(labelText: _t('یادداشت', 'Notes'), border: const OutlineInputBorder())),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: savePassword, icon: const Icon(Icons.save), label: Text(_t('ذخیره', 'Save')))),
        ]),
      ),
    );
  }
}
