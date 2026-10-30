import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/features/dictionary/domain/sign.dart';
import 'package:bisindo_app/features/home_content/domain/home_content.dart';
import 'package:bisindo_app/features/quiz/domain/quiz_bank.dart';
import 'package:bisindo_app/features/video/playback_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PremiumInfo: paket tanpa nama diabaikan', () {
    final i = PremiumInfo.fromJson({
      'enabled': true,
      'title': 'TEST',
      'plans': [
        {'name': 'TEST bulanan', 'price_label': 'TEST'},
        {'name': ''},
      ],
    });
    expect(i.enabled, true);
    expect(i.plans.length, 1);
    expect(const PremiumInfo().enabled, false);
  });

  test('HomeBanner dapat diketuk hanya bila punya tujuan', () {
    expect(HomeBanner.fromJson({'id': 'b', 'title': 'T'}).isTappable, false);
    final b = HomeBanner.fromJson({
      'id': 'b',
      'title': 'T',
      'target_type': 'route',
      'target_value': '/alphabet',
      'image': {'path': 'x.png'},
    });
    expect(b.isTappable, true);
    expect(b.imagePath, 'x.png');
  });

  test('PremiumStatus & Announcement', () {
    expect(
      PremiumStatus.fromJson({'is_premium': true, 'plan': 'P'}).isPremium,
      true,
    );
    final a = Announcement.fromJson({
      'id': 'a',
      'title': 'T',
      'body': 'B',
      'published_at': '2026-10-30T00:00:00Z',
    }, isRead: true);
    expect(a.isRead, true);
  });

  group('Rute v1.1.0', () {
    test('rute belajar & mode belajar', () {
      expect(
        AppRoutes.study(ContentModule.alphabet, 'abc'),
        '/study/alphabet/abc',
      );
      expect(
        AppRoutes.study(ContentModule.number, 'abc', learnMode: true),
        '/study/number/abc?mode=learn',
      );
    });

    test('konfigurasi kuis bolak-balik lewat query', () {
      const c = QuizConfig(
        mode: QuizMode.category,
        module: QuizModule.vocabulary,
        categoryId: 'c1',
        categoryName: 'TEST Kategori',
        difficulty: QuizDifficulty.easy,
        limit: 20,
      );
      final uri = Uri.parse(AppRoutes.quizPlay(c));
      expect(uri.path, '/quiz/play');
      final back = AppRoutes.parseQuizConfig(uri.queryParameters);
      expect(back == c, true);
      expect(back.categoryName, 'TEST Kategori');
      expect(AppRoutes.parseQuizConfig({'limit': '999'}).limit, 50);
    });

    test('banner hanya boleh ke rute yang dikenal', () {
      expect(AppRoutes.bannerRoute('/vocabulary'), AppRoutes.dictionary);
      expect(AppRoutes.bannerRoute('/admin'), null);
    });
  });

  test('kecepatan video 1× → 0,75× → 0,5× → 1×', () {
    expect(nextPlaybackSpeed(1.0), 0.75);
    expect(nextPlaybackSpeed(0.75), 0.5);
    expect(nextPlaybackSpeed(0.5), 1.0);
    expect(nextPlaybackSpeed(2.0), 1.0);
    expect(speedLabel(0.75), '0,75×');
    expect(speedLabel(1.0), '1×');
  });
}
