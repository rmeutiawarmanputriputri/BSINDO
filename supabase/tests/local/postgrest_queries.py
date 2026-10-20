"""Menguji string select/filter repository Dart terhadap PostgREST 13 asli
+ PostgreSQL lokal (stub Supabase). Konstanta select DIBACA LANGSUNG dari
berkas Dart agar tidak ada salinan yang menyimpang."""
import json, re, sys, urllib.request, urllib.parse, os

import hmac, hashlib, base64, time
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'lib', 'features')
BASE = os.environ.get('PGRST_URL', 'http://127.0.0.1:3999')
SECRET = os.environ.get('PGRST_JWT_SECRET', 'uji-rahasia-lokal-yang-panjang-sekali-32b').encode()

def _b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b'=').decode()

def _token(sub):
    h = _b64(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
    p = _b64(json.dumps({'sub': sub, 'role': 'authenticated', 'exp': int(time.time()) + 3600}).encode())
    s = _b64(hmac.new(SECRET, f'{h}.{p}'.encode(), hashlib.sha256).digest())
    return f'{h}.{p}.{s}'

# Pengguna uji dibuat oleh run_postgrest_checks.sh
TA = _token('aaaaaaaa-0000-0000-0000-00000000000a')
TADM = _token('cccccccc-0000-0000-0000-00000000000c')
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def dart_const(path, name):
    src = open(os.path.join(ROOT, path)).read()
    m = re.search(r'static const ' + name + r'\s*=\s*((?:\s*\'[^\']*\'\s*)+);', src)
    if not m:
        raise SystemExit(f'const {name} tidak ditemukan di {path}')
    parts = re.findall(r"'([^']*)'", m.group(1))
    return ''.join(parts)

SIGN = dart_const('dictionary/domain/sign.dart', 'selectColumns')
def expand(s):
    return s.replace('${Sign.selectColumns}', SIGN)

results = []
def req(name, method, path, token, params=None, body=None, headers=None, expect=200):
    url = BASE + path
    if params:
        url += '?' + urllib.parse.urlencode(params, safe='*,().:!%')
    h = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    h.update(headers or {})
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with opener.open(r) as resp:
            code = resp.status
            text = resp.read().decode()
    except urllib.error.HTTPError as e:
        code = e.code
        text = e.read().decode()
    ok = code == expect if isinstance(expect, int) else code in expect
    results.append((name, ok, code, text[:160]))
    try:
        return json.loads(text) if text else None
    except Exception:
        return None

# ---- Kamus
signs = req('signs.search', 'GET', '/signs', TA, {
    'select': SIGN, 'status': 'eq.published', 'term_normalized': r'ilike.%contoh%',
    'order': 'term_normalized.asc.nullslast,id.asc.nullslast', 'offset': 0, 'limit': 20})
sid = signs[0]['id'] if signs else None
req('signs.search.escape', 'GET', '/signs', TA, {
    'select': SIGN, 'status': 'eq.published', 'term_normalized': r'ilike.%50\%\_x%'})
req('signs.byId.single', 'GET', '/signs', TA, {'select': SIGN, 'id': f'eq.{sid}'},
    headers={'Accept': 'application/vnd.pgrst.object+json'})
req('categories', 'GET', '/categories', TA, {'select': 'id,name,kind', 'kind': 'eq.sign',
    'is_active': 'eq.true', 'order': 'sort_order.asc.nullslast'})

# ---- Favorit (upsert ignore-duplicates, user_id default)
for i in range(2):
    req(f'favorites.upsert#{i}', 'POST', '/favorites', TA, {'on_conflict': 'user_id,sign_id'},
        body={'sign_id': sid}, headers={'Prefer': 'resolution=ignore-duplicates'}, expect=201)
fav = req('favorites.list', 'GET', '/favorites', TA, {
    'select': f'created_at,sign:signs({SIGN})', 'order': 'created_at.desc.nullslast'})
results.append(('favorites.count==1', fav is not None and len(fav) == 1, 0, str(len(fav or []))))
req('favorites.delete', 'DELETE', '/favorites', TA, {'sign_id': f'eq.{sid}'}, expect=204)

# ---- Kosakata sulit
DIFF = expand(dart_const('difficult_vocab/data/difficult_repository.dart', '_columns'))
for i in range(2):
    req(f'difficult.upsert#{i}', 'POST', '/difficult_vocabulary', TA, {'on_conflict': 'user_id,sign_id'},
        body={'sign_id': sid, 'status': 'learning', 'relearned_at': None, 'marked_at': '2026-10-20T00:00:00Z'},
        headers={'Prefer': 'resolution=merge-duplicates'}, expect=(200, 201))
dl = req('difficult.list', 'GET', '/difficult_vocabulary', TA, {
    'select': DIFF, 'status': 'eq.learning',
    'order': 'last_reviewed_at.asc.nullsfirst,marked_at.desc.nullslast', 'limit': 5})
results.append(('difficult.count==1', dl is not None and len(dl) == 1 and dl[0].get('sign') is not None, 0, str(dl)[:120]))
if dl:
    req('difficult.review', 'PATCH', '/difficult_vocabulary', TA, {'id': f"eq.{dl[0]['id']}"},
        body={'review_count': 1, 'last_reviewed_at': '2026-10-20T01:00:00Z', 'status': 'relearned',
              'relearned_at': '2026-10-20T01:00:00Z'}, expect=204)

# ---- Percakapan
CL = dart_const('conversation/domain/conversation.dart', 'listColumns')
CD = dart_const('conversation/domain/conversation.dart', 'detailColumns')
mods = req('conv.list', 'GET', '/conversation_modules', TA, {'select': CL, 'status': 'eq.published',
    'order': 'sort_order.asc.nullslast'})
mid = mods[0]['id'] if mods else None
md = req('conv.detail', 'GET', '/conversation_modules', TA, {'select': CD, 'id': f'eq.{mid}'},
    headers={'Accept': 'application/vnd.pgrst.object+json'})
results.append(('conv.detail.items==2', md is not None and len(md.get('items', [])) == 2, 0, str(md)[:140]))
req('categories.conversation', 'GET', '/categories', TA, {'select': 'id,name,kind', 'kind': 'eq.conversation'})

# ---- Progres
PROG = dart_const('learning/data/progress_repository.dart', '_columns')
req('rpc.touch_progress.module', 'POST', '/rpc/touch_progress', TA, body={
    'p_lesson_id': None, 'p_module_id': mid, 'p_progress_percent': None, 'p_last_position': 1,
    'p_completed': False}, expect=(200, 204))
pl = req('progress.latest', 'GET', '/user_progress', TA, {'select': PROG,
    'order': 'last_accessed_at.desc.nullslast', 'limit': 1})
results.append(('progress.latest.title', bool(pl) and (pl[0].get('module') or {}).get('title') is not None, 0, str(pl)[:140]))

# ---- Pelajaran & kuis
LL = dart_const('learning/domain/learning.dart', 'listColumns')
LD = dart_const('learning/domain/learning.dart', 'detailColumns')
QZ = dart_const('learning/domain/learning.dart', 'columns')
ls = req('lessons.list', 'GET', '/lessons', TA, {'select': LL, 'status': 'eq.published', 'order': 'sort_order.asc.nullslast'})
lid = ls[0]['id'] if ls else None
lesson = req('lessons.detail', 'GET', '/lessons', TA, {'select': LD, 'id': f'eq.{lid}'},
    headers={'Accept': 'application/vnd.pgrst.object+json'})
results.append(('lessons.detail.items==3+quiz', lesson is not None and len(lesson.get('items', [])) == 3 and lesson.get('quiz') is not None, 0, str(lesson)[:160]))
req('rpc.touch_progress.lesson', 'POST', '/rpc/touch_progress', TA, body={
    'p_lesson_id': lid, 'p_module_id': None, 'p_progress_percent': 33, 'p_last_position': None, 'p_completed': False}, expect=(200, 204))
quiz = req('quiz.forLesson', 'GET', '/quizzes', TA, {'select': QZ, 'lesson_id': f'eq.{lid}', 'is_active': 'eq.true'},
    headers={'Accept': 'application/vnd.pgrst.object+json'})
qs = (quiz or {}).get('questions', [])
results.append(('quiz.questions+options', len(qs) == 2 and all(len(q['options']) == 2 for q in qs), 0, str(quiz)[:160]))
results.append(('quiz.no_answer_key_leak', 'correct_option_id' not in json.dumps(quiz), 0, ''))
answers = [{'question_id': q['id'], 'option_id': sorted(q['options'], key=lambda o: o['position'])[0]['id']} for q in qs]
res = req('rpc.submit_quiz_attempt', 'POST', '/rpc/submit_quiz_attempt', TA, body={'p_quiz_id': quiz['id'] if quiz else None, 'p_answers': answers})
results.append(('quiz.score==100', bool(res) and res.get('score_percent') == 100 and res.get('passed') is True, 0, str(res)[:160]))
req('attempts', 'GET', '/quiz_attempts', TA, {'select': 'id,quiz_id,score_percent,passed,submitted_at,quiz:quizzes(title)',
    'order': 'submitted_at.desc.nullslast', 'limit': 50})
req('count.lessons', 'GET', '/lessons', TA, {'select': 'id', 'status': 'eq.published'},
    headers={'Prefer': 'count=exact'}, expect=(200, 206))

# ---- Laporan
REP = dart_const('reports/domain/report.dart', 'columns')
req('reports.insert', 'POST', '/content_reports', TA, body={'sign_id': sid, 'category': 'wrong_meaning', 'description': None},
    expect=201)
req('reports.duplicate→409', 'POST', '/content_reports', TA, body={'sign_id': sid, 'category': 'wrong_meaning', 'description': None},
    expect=409)
req('reports.mine', 'GET', '/content_reports', TA, {'select': REP, 'reporter_id': 'eq.aaaaaaaa-0000-0000-0000-00000000000a',
    'order': 'created_at.desc.nullslast'})

# ---- Profil
req('profile.single', 'GET', '/profiles', TA, {'select': 'id,full_name,role', 'id': 'eq.aaaaaaaa-0000-0000-0000-00000000000a'},
    headers={'Accept': 'application/vnd.pgrst.object+json'})
req('profile.updateName', 'PATCH', '/profiles', TA, {'id': 'eq.aaaaaaaa-0000-0000-0000-00000000000a'}, body={'full_name': 'Uji A2'}, expect=204)
req('profile.updateRole→ditolak', 'PATCH', '/profiles', TA, {'id': 'eq.aaaaaaaa-0000-0000-0000-00000000000a'}, body={'role': 'admin'}, expect=(401, 403))

# ---- Admin
req('admin.counts(nonadmin)→ditolak', 'POST', '/rpc/admin_dashboard_counts', TA, body={}, expect=(401, 403))
req('admin.counts', 'POST', '/rpc/admin_dashboard_counts', TADM, body={})
new = req('admin.insert.sign', 'POST', '/signs', TADM, {'select': 'id'}, body={'term': 'Entri Admin', 'entry_type': 'word', 'status': 'draft'},
    headers={'Prefer': 'return=representation', 'Accept': 'application/vnd.pgrst.object+json'}, expect=201)
nid = (new or {}).get('id')
r = req('admin.publish.tanpaValidasi→CHECK', 'PATCH', '/signs', TADM, {'id': f'eq.{nid}'}, body={'status': 'published'}, expect=400)
results.append(('admin.check.message', 'signs_validation_required' in json.dumps(r), 0, str(r)[:160]))
req('admin.list.signs', 'GET', '/signs', TADM, {'select': 'id,term,status,video_asset_id,thumbnail_asset_id,category:categories(name)',
    'status': 'eq.draft', 'order': 'created_at.desc.nullslast', 'limit': 200})
req('admin.reports.all', 'GET', '/content_reports', TADM, {'select': REP, 'order': 'created_at.desc.nullslast'})
req('admin.answer_key.maybeSingle', 'GET', '/question_answer_keys', TADM, {'select': 'question_id,correct_option_id,explanation',
    'question_id': f"eq.{qs[0]['id'] if qs else ''}"}, headers={'Accept': 'application/vnd.pgrst.object+json'})
req('user.insert.sign→ditolak', 'POST', '/signs', TA, body={'term': 'X'}, expect=(401, 403))

bad = [r for r in results if not r[1]]
for name, ok, code, text in results:
    print(('LULUS ' if ok else 'GAGAL ') + f'{name:38s} {code} {"" if ok else text}')
print(f'\n{len(results) - len(bad)}/{len(results)} lulus')
sys.exit(1 if bad else 0)
