-- Rollback 0119. Aman: hanya menghapus fungsi (data tidak tersentuh).
drop function if exists public.admin_save_question(jsonb);
drop function if exists public.admin_save_conversation_items(uuid, jsonb);
drop function if exists public.admin_reorder(text, uuid[]);
drop function if exists public.admin_set_premium(uuid, boolean, text, timestamptz, text);
drop function if exists public.admin_set_user_active(uuid, boolean);
drop function if exists public.admin_set_user_role(uuid, public.app_role);
drop function if exists public.admin_user_detail(uuid);
drop function if exists public.admin_list_users(text, int, int, text);
drop function if exists public.admin_replace_media_file(uuid, text, text, bigint, text, int, int, int);
drop function if exists public.admin_delete_media(uuid, boolean);
drop function if exists public.media_usage(uuid);
drop function if exists public.admin_dashboard_stats();
drop function if exists public.assert_admin();
