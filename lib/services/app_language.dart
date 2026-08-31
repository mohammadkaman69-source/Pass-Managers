import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();

  static const _storageKey = 'app_language';

  Locale _locale = const Locale('fa');
  bool _initialized = false;

  Locale get locale => _locale;
  bool get isPersian => _locale.languageCode == 'fa';

  Future<void> load() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code == 'en') {
      _locale = const Locale('en');
    } else if (code == 'fa') {
      _locale = const Locale('fa');
    }
    _initialized = true;
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'fa' && languageCode != 'en') return;
    final next = Locale(languageCode);
    if (_locale == next) return;
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, languageCode);
    notifyListeners();
  }
}

class AppStrings {
  AppStrings._();

  static bool fa(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fa';

  static String language(BuildContext context) => fa(context) ? 'زبان' : 'Language';
  static String persian(BuildContext context) => fa(context) ? 'فارسی' : 'Persian';
  static String english(BuildContext context) => fa(context) ? 'انگلیسی' : 'English';
  static String selectLanguage(BuildContext context) =>
      fa(context) ? 'انتخاب زبان' : 'Choose language';
  static String languageChanged(BuildContext context) =>
      fa(context) ? 'زبان برنامه تغییر کرد.' : 'App language changed.';

  static String mainPassword(BuildContext context) => fa(context) ? 'رمز اصلی' : 'Master Password';
  static String email(BuildContext context) => fa(context) ? 'آدرس ایمیل' : 'Email address';
  static String confirmPassword(BuildContext context) => fa(context) ? 'تکرار رمز اصلی' : 'Confirm Master Password';
  static String createAccount(BuildContext context) => fa(context) ? 'ساخت حساب' : 'Create account';
  static String login(BuildContext context) => fa(context) ? 'ورود' : 'Login';
  static String forgotPassword(BuildContext context) => fa(context) ? 'رمز را فراموش کرده‌اید؟' : 'Forgot your password?';
  static String recoverySoon(BuildContext context) => fa(context) ? 'بازیابی رمز به‌زودی فعال می‌شود.' : 'Password recovery will be available soon.';
  static String passwordRule(BuildContext context) => fa(context)
      ? 'رمز باید ترکیبی از حروف و عدد باشد و حداقل ۸ کاراکتر داشته باشد.'
      : 'Password must contain letters and numbers and be at least 8 characters long.';
  static String encryptionInfo(BuildContext context) => fa(context)
      ? 'رمز اصلی برای ساخت کلید رمزنگاری داده‌های شما استفاده می‌شود.'
      : 'The master password is used to derive the encryption key for your data.';
  static String biometricLogin(BuildContext context) => fa(context) ? 'ورود با بیومتریک' : 'Login with biometrics';
  static String invalidEmail(BuildContext context) => fa(context) ? 'ایمیل معتبر وارد کنید.' : 'Enter a valid email address.';
  static String enterEmail(BuildContext context) => fa(context) ? 'ایمیل را وارد کنید.' : 'Enter your email address.';
  static String enterPassword(BuildContext context) => fa(context) ? 'رمز اصلی را وارد کنید.' : 'Enter the master password.';
  static String weakPassword(BuildContext context) => fa(context)
      ? 'رمز باید حداقل ۸ کاراکتر و ترکیبی از حروف و عدد باشد.'
      : 'Password must be at least 8 characters and contain letters and numbers.';
  static String passwordsMismatch(BuildContext context) => fa(context) ? 'رمزها یکسان نیستند.' : 'Passwords do not match.';
  static String wrongPassword(BuildContext context) => fa(context) ? 'رمز اصلی اشتباه است.' : 'Incorrect master password.';
  static String securityOperationFailed(BuildContext context, Object error) =>
      fa(context) ? 'عملیات امنیتی ناموفق بود: $error' : 'Security operation failed: $error';
  static String biometricFailed(BuildContext context) => fa(context) ? 'احراز هویت بیومتریک انجام نشد.' : 'Biometric authentication failed.';

  static String exit(BuildContext context) => fa(context) ? 'خروج' : 'Exit';
  static String exitHint(BuildContext context) => fa(context) ? 'برای خروج دوباره دکمه Back را فشار دهید.' : 'Press Back again to exit.';
  static String cancel(BuildContext context) => fa(context) ? 'انصراف' : 'Cancel';
  static String close(BuildContext context) => fa(context) ? 'بستن' : 'Close';
  static String continueText(BuildContext context) => fa(context) ? 'ادامه' : 'Continue';
  static String save(BuildContext context) => fa(context) ? 'ذخیره' : 'Save';
  static String verify(BuildContext context) => fa(context) ? 'بررسی' : 'Verify';
  static String restore(BuildContext context) => fa(context) ? 'بازیابی' : 'Restore';
  static String backup(BuildContext context) => fa(context) ? 'نسخه پشتیبان' : 'Backup';
  static String createEncryptedBackup(BuildContext context) => fa(context) ? 'ایجاد نسخه پشتیبان رمزنگاری‌شده' : 'Create encrypted backup';
  static String restoreBackup(BuildContext context) => fa(context) ? 'بازیابی نسخه پشتیبان' : 'Restore backup';
  static String backupHealth(BuildContext context) => fa(context) ? 'بررسی سلامت Backup' : 'Backup health check';
  static String backupHealthSub(BuildContext context) => fa(context) ? 'Verify بدون تغییر Vault فعلی' : 'Verify without changing the current Vault';
  static String recoveryKey(BuildContext context) => fa(context) ? 'Recovery Key آخرین Backup' : 'Recovery Key of latest backup';
  static String biometricSettings(BuildContext context) => fa(context) ? 'تنظیم ورود بیومتریک' : 'Biometric login settings';
  static String settings(BuildContext context) => fa(context) ? 'تنظیمات' : 'Settings';
  static String securityMenu(BuildContext context) => fa(context) ? 'امنیت و تنظیمات' : 'Security & settings';
  static String noItems(BuildContext context) => fa(context) ? 'هنوز موردی ساخته نشده' : 'No items have been created yet';
  static String createFolder(BuildContext context) => fa(context) ? 'ساخت پوشه' : 'Create folder';
  static String createTable(BuildContext context) => fa(context) ? 'ساخت جدول' : 'Create table';
  static String folderName(BuildContext context) => fa(context) ? 'نام پوشه' : 'Folder name';
  static String tableName(BuildContext context) => fa(context) ? 'نام جدول' : 'Table name';
  static String recoveryKeySaved(BuildContext context) => fa(context) ? 'کلید را ذخیره کردم' : 'I saved the key';
  static String copy(BuildContext context) => fa(context) ? 'کپی' : 'Copy';
  static String copyKey(BuildContext context) => fa(context) ? 'کپی کلید' : 'Copy key';
  static String backupPasswordEncryption(BuildContext context) => fa(context) ? 'رمز عبور برای رمزنگاری Backup' : 'Password for backup encryption';
  static String backupPassword(BuildContext context) => fa(context) ? 'رمز عبور Backup را وارد کنید' : 'Enter the backup password';
  static String recoveryKeyTitle(BuildContext context) => fa(context) ? 'Recovery Key — حتماً ذخیره کنید' : 'Recovery Key — save it securely';
  static String recoveryKeyDescription(BuildContext context) => fa(context)
      ? 'این کلید برای بازیابی Backup در صورت از دست رفتن رمز اصلی لازم است.\nکلید داخل فایل Backup نیست؛ آن را در محل امن خارج از دستگاه نگه دارید.'
      : 'This key is required to recover a Backup if the master password is lost.\nThe key is not stored inside the Backup file; keep it securely outside the device.';
  static String recoveryKeyCopied(BuildContext context) => fa(context) ? 'Recovery Key کپی شد.' : 'Recovery Key copied.';
  static String noActiveRecoveryKey(BuildContext context) => fa(context)
      ? 'Recovery Key فعالی در این نشست نیست.\n\nاین کلید فقط هنگام ساخت موفق Backup جدید تولید می‌شود و بعد از بستن برنامه از حافظه پاک می‌شود. اگر کلید را ذخیره نکرده‌اید، یک Backup جدید بگیرید.'
      : 'There is no active Recovery Key in this session.\n\nThe key is generated only after a successful new Backup and is cleared from memory when the app closes. If you did not save it, create a new Backup.';
  static String restoreWarning(BuildContext context) => fa(context)
      ? 'با بازیابی، اطلاعات فعلی برنامه حذف و اطلاعات نسخه پشتیبان جایگزین می‌شود. ادامه می‌دهید؟'
      : 'Restoring will replace the current app data with the selected backup. Do you want to continue?';
  static String restoreSuccess(BuildContext context, int items, int rows, int values) => fa(context)
      ? 'بازیابی موفق: $items مورد، $rows رکورد، $values مقدار. در صورت نیاز بیومتریک را دوباره فعال کنید.'
      : 'Restore successful: $items items, $rows records, $values values. Re-enable biometrics if needed.';
  static String restoreCancelled(BuildContext context) => fa(context) ? 'انتخاب فایل پشتیبان لغو شد.' : 'Backup file selection was cancelled.';
  static String backupSaved(BuildContext context) => fa(context) ? 'نسخه پشتیبان با موفقیت ذخیره شد. Recovery Key را حتماً یادداشت کنید.' : 'Backup saved successfully. Be sure to record the Recovery Key.';
  static String backupCancelled(BuildContext context) => fa(context) ? 'ذخیره نسخه پشتیبان لغو شد.' : 'Backup save was cancelled.';
  static String backupCreateError(BuildContext context, Object error) => fa(context) ? 'خطا در ایجاد نسخه پشتیبان: $error' : 'Error creating backup: $error';
  static String backupRestoreError(BuildContext context, Object error) => fa(context) ? 'خطا در بازیابی نسخه پشتیبان: $error' : 'Error restoring backup: $error';
  static String biometricUnavailable(BuildContext context) => fa(context) ? 'بیومتریک روی این دستگاه در دسترس نیست.' : 'Biometrics are not available on this device.';
  static String biometricDisableQuestion(BuildContext context) => fa(context) ? 'ورود بیومتریک فعال است. غیرفعال شود؟' : 'Biometric login is enabled. Disable it?';
  static String disable(BuildContext context) => fa(context) ? 'غیرفعال کردن' : 'Disable';
  static String biometricDisabled(BuildContext context) => fa(context) ? 'ورود بیومتریک غیرفعال شد.' : 'Biometric login disabled.';
  static String biometricEnabled(BuildContext context) => fa(context) ? 'ورود بیومتریک فعال شد.' : 'Biometric login enabled.';
  static String biometricEnableFailed(BuildContext context) => fa(context) ? 'فعال‌سازی بیومتریک انجام نشد.' : 'Biometric activation failed.';
}
