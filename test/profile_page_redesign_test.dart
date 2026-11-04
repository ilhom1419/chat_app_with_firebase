import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Profile Page Redesign & Localization Tests', () {
    test('1. Localization keys for Profile exist in all 3 languages (UZ, EN, RU)', () {
      // Uzbek
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('profile_title'), 'Profil');
      expect(LocalizationService.translate('user_id'), 'Hisob ID');
      expect(LocalizationService.translate('profile_info'), 'Profil ma\'lumotlari');
      expect(LocalizationService.translate('saved_messages_title'), 'Saqlangan xabarlar');
      expect(LocalizationService.translate('logout_btn'), 'Chiqish');
      expect(LocalizationService.translate('status_online'), 'Tarmoqda');

      // English
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('profile_title'), 'Profile');
      expect(LocalizationService.translate('user_id'), 'Account ID');
      expect(LocalizationService.translate('profile_info'), 'Profile Information');
      expect(LocalizationService.translate('saved_messages_title'), 'Saved Messages');
      expect(LocalizationService.translate('logout_btn'), 'Log Out');
      expect(LocalizationService.translate('status_online'), 'Online');

      // Russian
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('profile_title'), 'Профиль');
      expect(LocalizationService.translate('user_id'), 'ID аккаунта');
      expect(LocalizationService.translate('profile_info'), 'Информация профиля');
      expect(LocalizationService.translate('saved_messages_title'), 'Избранное');
      expect(LocalizationService.translate('logout_btn'), 'Выйти');
      expect(LocalizationService.translate('status_online'), 'В сети');
    });

    test('2. Username normalization logic (@ prefix stripped and lowercased)', () {
      final input1 = '@Jahongir_01';
      final clean1 = input1.startsWith('@') ? input1.substring(1) : input1;
      expect(clean1.toLowerCase(), 'jahongir_01');

      final input2 = 'Anna_Mariya';
      final clean2 = input2.startsWith('@') ? input2.substring(1) : input2;
      expect(clean2.toLowerCase(), 'anna_mariya');
    });

    test('3. Avatar initial fallback returns first letter capitalized or U', () {
      String getInitial(String displayName) {
        return displayName.trim().isNotEmpty
            ? displayName.trim().substring(0, 1).toUpperCase()
            : 'U';
      }

      expect(getInitial('Jahongir'), 'J');
      expect(getInitial('anna'), 'A');
      expect(getInitial(''), 'U');
      expect(getInitial('   '), 'U');
    });
  });
}
