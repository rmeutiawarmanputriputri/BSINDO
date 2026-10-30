-- 0120_v110_import.sql — BISINDO v1.1.0
-- Impor massal dari CMS (CSV/JSON yang sudah di-parse menjadi array objek).
-- SEMUA baris masuk sebagai DRAFT. Media dirujuk dengan nama berkas yang
-- SUDAH diunggah di menu Media (original_filename / judul / path).
-- p_dry_run = true → validasi saja, tidak ada yang disimpan (pratinjau).

create or replace function public.resolve_media(p_name text, p_kind public.media_kind)
returns uuid language sql stable security definer set search_path = '' as $$
  select m.id from public.media_assets m
  where nullif(btrim(p_name), '') is not null and m.kind = p_kind
    and (lower(m.original_filename) = lower(btrim(p_name)) or m.path = btrim(p_name)
         or lower(m.title) = lower(btrim(p_name)))
  order by m.created_at desc limit 1;
$$;
revoke all on function public.resolve_media(text, public.media_kind) from public, anon, authenticated;

create or replace function public.slugify(p text)
returns text language sql immutable set search_path = '' as $$
  select nullif(trim(both '-' from regexp_replace(lower(coalesce(p, '')), '[^a-z0-9]+', '-', 'g')), '');
$$;

create or replace function public.admin_import(p_kind text, p_rows jsonb, p_dry_run boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r        jsonb;
  n        int := 0;
  v_ok     int := 0;
  v_fail   int := 0;
  v_results jsonb := '[]'::jsonb;
  v_err    text[];
  v_warn   text[];
  v_id     uuid;
  v_cat    uuid;
  v_vid uuid; v_img uuid; v_aud uuid; v_thumb uuid;
  v_module uuid;
  v_slug   text;
  v_pos    int;
  v_opts   text[];
  v_correct text;
  v_cidx   int;
  v_q      jsonb;
  v_pairs  jsonb;
  v_left   text; v_right text;
  v_k      int;
  v_type   text;
  c_dry    constant text := 'BISINDO_DRY_RUN';
begin
  perform public.assert_admin();
  if p_kind not in ('vocabulary', 'alphabet', 'number', 'conversation', 'quiz') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'invalid_rows' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 2000 then
    raise exception 'too_many_rows: maksimum 2000 baris per impor' using errcode = '22023';
  end if;

  begin  -- blok luar: dibatalkan seluruhnya bila dry run
    for r in select * from jsonb_array_elements(p_rows) loop
      n := n + 1;
      v_err := '{}'; v_warn := '{}'; v_id := null;
      v_vid := null; v_img := null; v_aud := null; v_thumb := null; v_cat := null;

      begin  -- savepoint per baris
        if jsonb_typeof(r) <> 'object' then
          raise exception 'Baris bukan objek';
        end if;

        -- media (peringatan bila nama ada tetapi berkas belum diunggah)
        if nullif(btrim(r ->> 'video_file'), '') is not null then
          v_vid := public.resolve_media(r ->> 'video_file', 'video');
          if v_vid is null then v_warn := v_warn || format('Video "%s" belum ada di Media', r ->> 'video_file'); end if;
        end if;
        if nullif(btrim(r ->> 'image_file'), '') is not null then
          v_img := public.resolve_media(r ->> 'image_file', 'image');
          if v_img is null then v_warn := v_warn || format('Gambar "%s" belum ada di Media', r ->> 'image_file'); end if;
        end if;
        if nullif(btrim(r ->> 'audio_file'), '') is not null then
          v_aud := public.resolve_media(r ->> 'audio_file', 'audio');
          if v_aud is null then v_warn := v_warn || format('Audio "%s" belum ada di Media', r ->> 'audio_file'); end if;
        end if;
        if nullif(btrim(r ->> 'thumbnail_file'), '') is not null then
          v_thumb := public.resolve_media(r ->> 'thumbnail_file', 'image');
          if v_thumb is null then v_warn := v_warn || format('Thumbnail "%s" belum ada di Media', r ->> 'thumbnail_file'); end if;
        end if;

        if p_kind in ('vocabulary', 'alphabet', 'number') then
          if nullif(btrim(r ->> 'category'), '') is not null then
            select id into v_cat from public.categories
             where kind = 'sign' and (slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category')))
             order by (slug = lower(btrim(r ->> 'category'))) desc limit 1;
            if v_cat is null then raise exception 'Kategori "%" tidak ditemukan', r ->> 'category'; end if;
          elsif p_kind = 'vocabulary' then
            raise exception 'Kolom category wajib diisi';
          end if;
          if p_kind = 'vocabulary' and nullif(btrim(r ->> 'term'), '') is null then
            raise exception 'Kolom term wajib diisi';
          end if;
          if p_kind in ('alphabet', 'number') and nullif(btrim(r ->> 'symbol'), '') is null then
            raise exception 'Kolom symbol wajib diisi';
          end if;
          if p_kind = 'number' and coalesce(r ->> 'number_group', '') not in ('0-9', '10-20', 'tens', '100+') then
            raise exception 'number_group harus salah satu: 0-9, 10-20, tens, 100+';
          end if;

          insert into public.signs (entry_type, content_module, category_id, term, symbol, number_group,
                                    meaning, movement_description, usage_example, video_asset_id,
                                    thumbnail_asset_id, image_asset_id, audio_asset_id, source_note,
                                    validated_by, verified_at, sort_order, is_premium, status)
          values (coalesce(nullif(r ->> 'entry_type', ''), 'word')::public.sign_entry_type, p_kind, v_cat,
                  btrim(coalesce(nullif(r ->> 'term', ''), r ->> 'symbol')),
                  case when p_kind <> 'vocabulary' then btrim(r ->> 'symbol') end,
                  case when p_kind = 'number' then r ->> 'number_group' end,
                  nullif(btrim(r ->> 'meaning'), ''), nullif(btrim(r ->> 'movement_description'), ''),
                  nullif(btrim(r ->> 'usage_example'), ''), v_vid, v_thumb, v_img, v_aud,
                  nullif(btrim(r ->> 'source_note'), ''), nullif(btrim(r ->> 'validated_by'), ''),
                  (nullif(btrim(r ->> 'verified_at'), ''))::date,
                  coalesce((nullif(r ->> 'sort_order', ''))::int, 0),
                  coalesce((nullif(lower(r ->> 'is_premium'), ''))::boolean, false), 'draft')
          returning id into v_id;

        elsif p_kind = 'conversation' then
          if nullif(btrim(r ->> 'topic'), '') is null then raise exception 'Kolom topic wajib diisi'; end if;
          if nullif(btrim(r ->> 'text'), '') is null then raise exception 'Kolom text wajib diisi'; end if;
          select id into v_module from public.conversation_modules
            where lower(title) = lower(btrim(r ->> 'topic')) order by created_at limit 1;
          if v_module is null then
            if nullif(btrim(r ->> 'category'), '') is not null then
              select id into v_cat from public.categories
               where kind = 'conversation' and (slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category')))
               limit 1;
              if v_cat is null then raise exception 'Kategori percakapan "%" tidak ditemukan', r ->> 'category'; end if;
            end if;
            v_slug := coalesce(public.slugify(r ->> 'topic'), 'topik');
            if exists (select 1 from public.conversation_modules where slug = v_slug) then
              v_slug := v_slug || '-' || substr(md5(random()::text), 1, 6);
            end if;
            insert into public.conversation_modules (slug, category_id, title, description, status)
            values (v_slug, v_cat, btrim(r ->> 'topic'), nullif(btrim(r ->> 'topic_description'), ''), 'draft')
            returning id into v_module;
            v_warn := v_warn || format('Topik baru dibuat: %s', btrim(r ->> 'topic'));
          elsif (select status from public.conversation_modules where id = v_module) = 'published' then
            raise exception 'Topik "%" sudah Published; ubah ke Draft dulu sebelum menambah kalimat lewat impor', r ->> 'topic';
          end if;
          v_pos := coalesce((nullif(r ->> 'position', ''))::int - 1,
                            (select coalesce(max(position) + 1, 0) from public.conversation_items where module_id = v_module));
          if v_pos < 0 then raise exception 'position dimulai dari 1'; end if;
          if exists (select 1 from public.conversation_items where module_id = v_module and position = v_pos) then
            raise exception 'Posisi % sudah terisi di topik "%"', v_pos + 1, r ->> 'topic';
          end if;
          insert into public.conversation_items (module_id, position, speaker_label, text_id, translation,
                                                 explanation, video_asset_id, audio_asset_id)
          values (v_module, v_pos, coalesce(nullif(btrim(r ->> 'speaker'), ''), 'A'), btrim(r ->> 'text'),
                  nullif(btrim(r ->> 'translation'), ''), nullif(btrim(r ->> 'explanation'), ''), v_vid, v_aud)
          returning id into v_id;

        elsif p_kind = 'quiz' then
          v_type := coalesce(nullif(btrim(r ->> 'question_type'), ''), 'multiple_choice');
          if v_type not in ('multiple_choice', 'guess_letter', 'guess_number', 'guess_sign', 'match_image', 'arrange_word') then
            raise exception 'question_type tidak dikenal: %', v_type;
          end if;
          if coalesce(r ->> 'module', '') not in ('alphabet', 'number', 'vocabulary', 'conversation', 'general') then
            raise exception 'module harus salah satu: alphabet, number, vocabulary, conversation, general';
          end if;
          if nullif(btrim(r ->> 'prompt'), '') is null then raise exception 'Kolom prompt wajib diisi'; end if;
          if nullif(btrim(r ->> 'category'), '') is not null then
            select id into v_cat from public.categories
             where slug = lower(btrim(r ->> 'category')) or lower(name) = lower(btrim(r ->> 'category'))
             order by (slug = lower(btrim(r ->> 'category'))) desc limit 1;
            if v_cat is null then raise exception 'Kategori "%" tidak ditemukan', r ->> 'category'; end if;
          end if;

          v_q := jsonb_build_object('module', r ->> 'module', 'category_id', v_cat, 'question_type', v_type,
                   'prompt', btrim(r ->> 'prompt'), 'difficulty', coalesce(nullif(r ->> 'difficulty', ''), 'medium'),
                   'sort_order', coalesce((nullif(r ->> 'sort_order', ''))::int, 0),
                   'is_premium', coalesce((nullif(lower(r ->> 'is_premium'), ''))::boolean, false),
                   'video_asset_id', v_vid, 'image_asset_id', v_img,
                   'explanation', r ->> 'explanation', 'status', 'draft');

          if v_type = 'arrange_word' then
            -- correct: urutan benar dipisah "|" (mis. "M|A|K|A|N"). Ubin = isi urutan itu.
            v_opts := string_to_array(btrim(coalesce(r ->> 'correct', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'correct untuk arrange_word minimal 2 ubin dipisah "|"'; end if;
            v_q := v_q || jsonb_build_object(
              'options', (select jsonb_agg(jsonb_build_object('label', btrim(x)) order by o) from unnest(v_opts) with ordinality u(x, o)),
              'correct_sequence', (select jsonb_agg(o - 1 order by o) from unnest(v_opts) with ordinality u(x, o)));
          elsif v_type = 'match_image' then
            -- pairs: "gambar1.png=Arti 1|gambar2.png=Arti 2"
            v_opts := string_to_array(btrim(coalesce(r ->> 'pairs', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'pairs minimal 2 pasangan "berkas.png=Arti" dipisah "|"'; end if;
            v_pairs := '[]'::jsonb; v_q := v_q || jsonb_build_object('options', '[]'::jsonb);
            v_k := 0;
            foreach v_correct in array v_opts loop
              v_left := btrim(split_part(v_correct, '=', 1)); v_right := btrim(split_part(v_correct, '=', 2));
              if v_left = '' or v_right = '' then raise exception 'Format pasangan salah: "%"', v_correct; end if;
              v_img := public.resolve_media(v_left, 'image');
              if v_img is null then v_warn := v_warn || format('Gambar "%s" belum ada di Media', v_left); end if;
              v_q := jsonb_set(v_q, '{options}', (v_q -> 'options')
                       || jsonb_build_object('label', 'Gambar ' || (v_k + 1), 'side', 'left', 'image_asset_id', v_img)
                       || jsonb_build_object('label', v_right, 'side', 'right'));
              v_pairs := v_pairs || jsonb_build_object('left', v_k * 2, 'right', v_k * 2 + 1);
              v_k := v_k + 1;
            end loop;
            v_q := v_q || jsonb_build_object('pairs', v_pairs);
          else
            v_opts := string_to_array(btrim(coalesce(r ->> 'options', '')), '|');
            if cardinality(v_opts) < 2 then raise exception 'options minimal 2 pilihan dipisah "|"'; end if;
            v_correct := btrim(coalesce(r ->> 'correct', ''));
            v_cidx := null;
            if v_correct ~ '^[0-9]+$' and v_correct::int between 1 and cardinality(v_opts) then
              v_cidx := v_correct::int - 1;
            else
              select o - 1 into v_cidx from unnest(v_opts) with ordinality u(x, o) where lower(btrim(x)) = lower(v_correct) limit 1;
            end if;
            if v_cidx is null then raise exception 'correct "%" tidak cocok dengan pilihan mana pun', v_correct; end if;
            v_q := v_q || jsonb_build_object(
              'options', (select jsonb_agg(jsonb_build_object('label', btrim(x)) order by o) from unnest(v_opts) with ordinality u(x, o)),
              'correct_index', v_cidx);
          end if;
          v_id := public.admin_save_question(v_q);
        end if;

        v_ok := v_ok + 1;
        v_results := v_results || jsonb_build_object('row', n, 'ok', true, 'id', v_id, 'warnings', to_jsonb(v_warn));
      exception when others then
        v_fail := v_fail + 1;
        v_results := v_results || jsonb_build_object('row', n, 'ok', false,
                                                     'errors', to_jsonb(array[sqlerrm]), 'warnings', to_jsonb(v_warn));
      end;
    end loop;

    if p_dry_run then
      raise exception using message = c_dry;
    end if;
  exception when others then
    if sqlerrm <> c_dry then raise; end if;
  end;

  return jsonb_build_object('kind', p_kind, 'dry_run', p_dry_run, 'total', n,
                            'ok', v_ok, 'failed', v_fail, 'results', v_results);
end $$;
revoke all on function public.admin_import(text, jsonb, boolean) from public, anon;
grant execute on function public.admin_import(text, jsonb, boolean) to authenticated;
