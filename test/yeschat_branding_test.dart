import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/shared/widgets/yeschat_logo.dart';
import 'package:chat_app/features/auth/domain/entities/app_user.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepo implements AuthRepository {
  final Completer<AppUser?> _completer = Completer<AppUser?>();

  @override
  Stream<AppUser?> get onAuthStateChanged => const Stream.empty();
  @override
  Future<AppUser?> getCurrentUser() => _completer.future;
  @override
  Future<AppUser> signInWithEmailAndPassword(String email, String password) async => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  @override
  Future<AppUser> signUpWithEmailAndPassword(String email, String password, String displayName) async => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

void main() {
  group('YesChat! Branding & Identity Tests', () {
    test('1. Brand name is strictly YesChat! in all languages', () {
      for (final lang in ['en', 'ru', 'uz']) {
        LocalizationService.setLanguage(lang);
        expect(
          LocalizationService.translate('app_name'),
          'YesChat!',
          reason: 'Brand name must not be translated in $lang',
        );
      }
    });

    test('2. Supporting welcome text is properly localized per requirements', () {
      LocalizationService.setLanguage('en');
      expect(
        LocalizationService.translate('welcome_to_app'),
        'Welcome to YesChat!',
      );

      LocalizationService.setLanguage('ru');
      expect(
        LocalizationService.translate('welcome_to_app'),
        'Добро пожаловать в YesChat!',
      );

      LocalizationService.setLanguage('uz');
      expect(
        LocalizationService.translate('welcome_to_app'),
        'YesChat! ga xush kelibsiz',
      );
    });

    test('3. Tagline and About texts are localized across languages', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('app_tagline'), 'Fast & Secure Messenger');
      expect(LocalizationService.translate('about_app'), 'About YesChat!');
      expect(LocalizationService.translate('app_version'), 'Version');

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('app_tagline'), 'Быстрый и безопасный мессенджер');
      expect(LocalizationService.translate('about_app'), 'О приложении YesChat!');
      expect(LocalizationService.translate('app_version'), 'Версия');

      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('app_tagline'), 'Tez va xavfsiz messenjer');
      expect(LocalizationService.translate('about_app'), 'YesChat! haqida');
      expect(LocalizationService.translate('app_version'), 'Versiya');
    });

    testWidgets('4. YesChatLogo widget renders correctly with asset and styling',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: YesChatLogo(
                size: 80,
                borderRadius: 20,
                showShadow: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(YesChatLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/branding/yeschat_logo.png');
    });

    test('5. SplashPage code includes YesChatLogo and YesChat! branding', () {
      final splashSource = File('lib/features/auth/presentation/pages/splash_page.dart').readAsStringSync();
      expect(splashSource.contains('YesChatLogo('), isTrue);
      expect(splashSource.contains("'YesChat!'"), isTrue);
      expect(splashSource.contains("LocalizationService.translate('app_tagline')"), isTrue);
    });

    test('6. Android Manifest and iOS Info.plist labels are updated to YesChat!', () {
      final androidManifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        androidManifest.contains('android:label="YesChat!"'),
        isTrue,
        reason: 'AndroidManifest.xml must declare android:label="YesChat!"',
      );

      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        infoPlist.contains('<string>YesChat!</string>'),
        isTrue,
        reason: 'Info.plist must declare CFBundleDisplayName YesChat!',
      );

      final appDart = File('lib/app.dart').readAsStringSync();
      expect(
        appDart.contains("title: 'YesChat!'"),
        isTrue,
        reason: 'MaterialApp in lib/app.dart must have title: YesChat!',
      );
    });

    test('7. Branding assets exist in assets/branding and launcher mipmaps', () {
      expect(File('assets/branding/yeschat_logo.png').existsSync(), isTrue);
      expect(File('assets/branding/yeschat_logo.jpg').existsSync(), isTrue);

      final mipmapDirs = [
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ];
      for (final iconPath in mipmapDirs) {
        expect(File(iconPath).existsSync(), isTrue, reason: '$iconPath must exist');
      }
    });
  });
}
