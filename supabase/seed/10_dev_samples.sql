-- ⚠️ HANYA UNTUK PROYEK DEV. DILARANG DIJALANKAN DI PRODUKSI.
-- Data contoh untuk menguji alur aplikasi. BUKAN materi BISINDO:
-- tidak ada gerakan, arti, deskripsi gerakan, atau video yang dikarang.
-- validated_by diawali 'DEV-SAMPLE' → aplikasi menampilkan lencana "Materi contoh".
-- Pemeriksaan pra-rilis: select count(*) from signs where validated_by like 'DEV-SAMPLE%';  -- harus 0 di produksi

do $$
declare
  v_cat uuid;
  v_conv_cat uuid;
  v_module uuid;
  v_lesson uuid;
  v_quiz uuid;
  v_q uuid;
  v_opt_a uuid;
  v_sign uuid;
  i int;
begin
  select id into v_cat from public.categories where slug = 'lainnya';
  select id into v_conv_cat from public.categories where slug = 'percakapan-lainnya';

  for i in 1..5 loop
    insert into public.signs (entry_type, category_id, term, meaning, usage_example,
                              source_note, validated_by, verified_at, status)
    values (case when i = 5 then 'phrase'::public.sign_entry_type else 'word' end,
            v_cat, 'Contoh ' || i,
            'Teks contoh pengembangan — bukan arti isyarat BISINDO.',
            null,
            'Contoh pengembangan', 'DEV-SAMPLE (BUKAN VERIFIKASI)', now(), 'published')
    returning id into v_sign;
  end loop;

  insert into public.conversation_modules (slug, category_id, title, description, context_note,
                                           source_note, validated_by, verified_at, status)
  values ('contoh-percakapan', v_conv_cat, 'Contoh Percakapan',
          'Modul contoh pengembangan.', 'Konteks contoh — bukan materi asli.',
          'Contoh pengembangan', 'DEV-SAMPLE (BUKAN VERIFIKASI)', now(), 'published')
  returning id into v_module;

  insert into public.conversation_items (module_id, position, speaker_label, text_id, sign_id)
  values (v_module, 0, 'A', 'Kalimat contoh pertama.', v_sign),
         (v_module, 1, 'B', 'Kalimat contoh kedua.', null);

  insert into public.lessons (slug, title, description, sort_order,
                              source_note, validated_by, verified_at, status)
  values ('contoh-pelajaran', 'Contoh Pelajaran', 'Pelajaran contoh pengembangan.', 1,
          'Contoh pengembangan', 'DEV-SAMPLE (BUKAN VERIFIKASI)', now(), 'published')
  returning id into v_lesson;

  insert into public.lesson_items (lesson_id, position, item_type, body_text)
  values (v_lesson, 0, 'text', 'Teks pengantar contoh.');
  insert into public.lesson_items (lesson_id, position, item_type, sign_id)
  values (v_lesson, 1, 'sign', v_sign);
  insert into public.lesson_items (lesson_id, position, item_type, conversation_module_id)
  values (v_lesson, 2, 'conversation_module', v_module);

  insert into public.quizzes (lesson_id, title, pass_score_percent)
  values (v_lesson, 'Kuis Contoh', 50) returning id into v_quiz;

  for i in 1..2 loop
    insert into public.questions (quiz_id, position, prompt)
    values (v_quiz, i - 1, 'Soal contoh ' || i || ' (bukan materi asli). Pilih "Pilihan A".')
    returning id into v_q;
    insert into public.question_options (question_id, position, label)
    values (v_q, 0, 'Pilihan A') returning id into v_opt_a;
    insert into public.question_options (question_id, position, label)
    values (v_q, 1, 'Pilihan B');
    insert into public.question_answer_keys (question_id, correct_option_id, explanation)
    values (v_q, v_opt_a, 'Penjelasan contoh.');
  end loop;
end $$;
