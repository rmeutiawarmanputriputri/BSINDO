// Tes logika fitur tambahan v1.1.0 sesuai daftar fitur A–L (data uji TEST_,
// bukan materi BISINDO).
import 'package:bisindo_app/app/router/routes.dart';
import 'package:bisindo_app/core/utils/media_type.dart';
import 'package:bisindo_app/features/conversation/domain/conversation.dart';
import 'package:bisindo_app/features/dictionary/domain/sign.dart';
import 'package:bisindo_app/features/home_content/domain/home_content.dart';
import 'package:bisindo_app/features/quiz/domain/quiz_bank.dart';
import 'package:bisindo_app/features/reminders/reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const _topic = '11111111-2222-4333-8444-555555555555';

void main() {
  group('Animasi GIF', () {
    test('dikenali dari ekstensi path', () {
      expect(isGifPath('library/video/2026/10/a.gif'), true);
      expect(isGifPath('library/video/2026/10/A.GIF'), true);
      expect(isGifPath('library/video/2026/10/a.mp4'), false);
      expect(isGifPath(null), false);
    });
  });

  group('Sign offline (toJson ↔ fromJson)', () {
    test('semua kolom kembali sama; mediaPaths hanya yang ada', () {
      final s = Sign.fromJson({
        'id': 'TEST_id',
        'term': 'TEST_HURUF',
        'entry_type': 'word',
        'content_module': 'alphabet',
        'symbol': 'Q',
        'meaning': 'TEST keterangan',
        'movement_description': 'TEST penjelasan',
        'video': {'path': 'library/video/x.gif'},
        'audio': {'path': 'library/audio/x.mp3'},
        'category': {'name': 'TEST kategori'},
        'validated_by': 'TEST',
        'verified_at': '2026-10-30T00:00:00Z',
        'is_premium': true,
        'number_group': null,
        'sort_order': 3,
      });
      final r = Sign.fromJson(s.toJson());
      expect(r.id, s.id);
      expect(r.displayTitle, 'Q');
      expect(r.contentModule, ContentModule.alphabet);
      expect(r.movementDescription, 'TEST penjelasan');
      expect(r.categoryName, 'TEST kategori');
      expect(r.videoPath, 'library/video/x.gif');
      expect(r.isGifAnimation, true);
      expect(r.isPremium, true);
      expect(r.sortOrder, 3);
      expect(r.verifiedAt, s.verifiedAt);
      expect(r.mediaPaths, ['library/video/x.gif', 'library/audio/x.mp3']);
    });
  });

  group('Bagian kalimat percakapan', () {
    test('urut menurut posisi; label & arti dari CMS atau kamus', () {
      final item = ConversationItem.fromJson({
        'id': 'i1',
        'position': 0,
        'text_id': 'TEST kalimat',
        'parts': [
          {
            'position': 1,
            'part_text': 'TEST bagian',
            'meaning': 'TEST arti bagian',
          },
          {
            'position': 0,
            'part_text': null,
            'meaning': null,
            'part_sign': {
              'id': 's1',
              'term': 'TEST_KATA',
              'meaning': 'TEST arti kamus',
              'content_module': 'vocabulary',
            },
          },
          // kosakata Draft tidak terbaca (RLS) & tanpa teks → tidak ditampilkan
          {'position': 2, 'part_text': null, 'part_sign': null},
        ],
      });
      expect(item.parts.map((p) => p.position), [0, 1, 2]);
      expect(item.parts[0].label, 'TEST_KATA');
      expect(item.parts[0].displayMeaning, 'TEST arti kamus');
      expect(item.parts[0].signId, 's1');
      expect(item.parts[1].label, 'TEST bagian');
      expect(item.parts[1].displayMeaning, 'TEST arti bagian');
      expect(item.parts[1].signId, isNull);
      expect(item.parts[2].isVisible, false);
    });

    test('data lama tanpa parts tetap terbaca', () {
      final item = ConversationItem.fromJson({'id': 'i', 'text_id': 'TEST'});
      expect(item.parts, isEmpty);
    });
  });

  group('Latihan per topik percakapan', () {
    test('parameter RPC hanya dikirim bila ada topik', () {
      const base = QuizConfig(
        mode: QuizMode.category,
        module: QuizModule.conversation,
      );
      expect(base.toRpcParams().containsKey('p_conversation_module_id'), false);
      const withTopic = QuizConfig(
        mode: QuizMode.category,
        module: QuizModule.conversation,
        conversationModuleId: _topic,
      );
      expect(withTopic.toRpcParams()['p_conversation_module_id'], _topic);
      expect(withTopic == base, false);
    });

    test('rute kuis membawa topik; topik bukan UUID diabaikan', () {
      const c = QuizConfig(
        mode: QuizMode.category,
        module: QuizModule.conversation,
        categoryName: 'TEST Topik',
        conversationModuleId: _topic,
      );
      final uri = Uri.parse(AppRoutes.quizPlay(c));
      final parsed = AppRoutes.parseQuizConfig(uri.queryParameters);
      expect(parsed, c);
      expect(
        AppRoutes.parseQuizConfig({
          'mode': 'category',
          'topic': 'bukan-uuid',
        }).conversationModuleId,
        isNull,
      );
    });
  });

  group('Konten beranda (home_layout)', () {
    test('bagian tidak disebut = tampil; teks kosong = teks bawaan', () {
      final l = HomeLayout.fromJson({
        'intro_title': '  ',
        'intro_text': null,
        'sections': {'recommendations': false, 'modules': true, 'x': 'ya'},
      });
      expect(l.show('recommendations'), false);
      expect(l.show('modules'), true);
      expect(l.show('premium'), true);
      expect(l.show('x'), true);
      expect(l.title, HomeLayout.defaultIntroTitle);
      expect(l.text, HomeLayout.defaultIntroText);
      final custom = HomeLayout.fromJson({'intro_title': 'TEST judul'});
      expect(custom.title, 'TEST judul');
    });
  });

  group('Pengingat belajar', () {
    test('parse, batas nilai, label jam', () {
      expect(const ReminderSettings().enabled, false);
      final s = ReminderSettings.fromJson({
        'reminder': {'enabled': true, 'hour': 7, 'minute': 5},
      });
      expect(s.enabled, true);
      expect(s.label, '07.05');
      final bad = ReminderSettings.fromJson({
        'reminder': {'enabled': 'ya', 'hour': 30, 'minute': -1},
      });
      expect(bad.enabled, false);
      expect(bad.hour, 19);
      expect(bad.minute, 0);
      expect(ReminderSettings.fromJson(s.toJson()), s);
      expect(s.copyWith(enabled: false).enabled, false);
    });

    test('zona waktu Indonesia dari offset perangkat', () {
      expect(guessTimeZoneName(const Duration(hours: 7), []), 'Asia/Jakarta');
      expect(guessTimeZoneName(const Duration(hours: 8), []), 'Asia/Makassar');
      expect(guessTimeZoneName(const Duration(hours: 9), []), 'Asia/Jayapura');
      expect(
        guessTimeZoneName(const Duration(hours: 1), ['Europe/Paris']),
        'Europe/Paris',
      );
      expect(guessTimeZoneName(const Duration(hours: 1), []), 'UTC');
    });
  });
}
