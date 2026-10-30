import 'package:bisindo_app/features/dictionary/domain/sign.dart';
import 'package:bisindo_app/features/study/domain/study.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressSummary', () {
    test('membaca hasil my_progress_summary', () {
      final s = ProgressSummary.fromJson({
        'modules': {
          'alphabet': {'total': 26, 'learned': 13},
          'vocabulary': {'total': 4, 'learned': 0},
        },
        'categories': [
          {'category_id': 'c', 'name': 'TEST', 'total': 2, 'learned': 1},
        ],
        'conversations': {'total': 3, 'completed': 1},
        'quizzes': {
          'sessions': 2,
          'average_score': 75,
          'best_score': 90,
          'last_at': null,
        },
        'total_learned': 13,
      });
      expect(s.module('alphabet').ratio, 0.5);
      expect(s.module('number').total, 0);
      expect(s.totalMaterials, 30);
      expect(s.overallPercent, 43);
      expect(s.categories.single.ratio, 0.5);
      expect(s.conversationsCompleted, 1);
      expect(s.quizAverage, 75);
    });

    test('kosong / materi belum ada → 0% tanpa pembagian nol', () {
      final s = ProgressSummary.fromJson({});
      expect(s.overallPercent, 0);
      expect(const ModuleProgress().ratio, 0.0);
    });
  });

  test('HistoryEntry: label modul & waktu lokal', () {
    final e = HistoryEntry.fromJson({
      'item_type': 'sign',
      'module': 'alphabet',
      'item_id': 'id1',
      'title': 'TEST',
      'symbol': 'A',
      'completed': true,
      'last_accessed_at': '2026-10-30T03:00:00Z',
    });
    expect(e.moduleLabel, 'Alfabet');
    expect(e.completed, true);
    expect(e.lastAccessedAt.isUtc, false);
  });

  test('SignProgress: learned dari learned_at atau flag RPC', () {
    expect(
      SignProgress.fromJson({
        'sign_id': 'a',
        'learned_at': '2026-10-30',
      }).learned,
      true,
    );
    expect(
      SignProgress.fromJson({'sign_id': 'a', 'learned': true}).learned,
      true,
    );
    expect(
      SignProgress.fromJson({'sign_id': 'a', 'learned_at': null}).learned,
      false,
    );
  });

  test('mode belajar mulai dari materi pertama yang belum dipelajari', () {
    expect(nextUnlearnedIndex(['a', 'b', 'c'], {'a'}), 1);
    expect(nextUnlearnedIndex(['a', 'b', 'c'], {'a', 'b', 'c'}), 0);
    expect(nextUnlearnedIndex([], {}), 0);
  });

  group('Sign v1.1.0', () {
    test('kolom baru: modul, simbol, kelompok angka, media, Premium', () {
      final s = Sign.fromJson({
        'id': 'x',
        'term': 'TEST tujuh',
        'content_module': 'number',
        'symbol': '7',
        'number_group': '0-9',
        'sort_order': 3,
        'is_premium': true,
        'image': {'path': 'i.png'},
        'audio': {'path': 'a.mp3'},
        'video': {'path': 'v.mp4'},
      });
      expect(s.contentModule, ContentModule.number);
      expect(s.numberGroup, NumberGroup.zeroToNine);
      expect(s.displayTitle, '7');
      expect(s.imagePath, 'i.png');
      expect(s.audioPath, 'a.mp3');
      expect(s.isPremium, true);
      expect(s.sortOrder, 3);
    });

    test('JSON lama (tanpa kolom v1.1.0) tetap terbaca sebagai kosakata', () {
      final s = Sign.fromJson({
        'id': 'x',
        'term': 'TEST kata',
        'entry_type': 'phrase',
      });
      expect(s.contentModule, ContentModule.vocabulary);
      expect(s.displayTitle, 'TEST kata');
      expect(s.isPremium, false);
      expect(s.numberGroup, null);
      expect(s.entryType, SignEntryType.phrase);
    });

    test('kolom select memuat relasi media baru', () {
      expect(
        Sign.selectColumns.contains('image:media_assets!image_asset_id(path)'),
        true,
      );
      expect(
        Sign.selectColumns.contains('audio:media_assets!audio_asset_id(path)'),
        true,
      );
      expect(Sign.selectColumns.contains('content_module'), true);
    });
  });
}
