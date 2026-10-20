/// Definisi entitas konten yang dikelola admin.
class AdminEntity {
  const AdminEntity({
    required this.key,
    required this.table,
    required this.title,
    required this.listColumns,
    required this.titleColumn,
    this.hasStatus = true,
    this.orderBy = 'created_at',
    this.ascending = false,
  });

  final String key;
  final String table;
  final String title;
  final String listColumns;
  final String titleColumn;
  final bool hasStatus;
  final String orderBy;
  final bool ascending;

  static const signs = AdminEntity(
    key: 'signs',
    table: 'signs',
    title: 'Kosakata',
    listColumns: 'id, term, entry_type, status, validated_by, category:categories(name)',
    titleColumn: 'term',
  );

  static const categories = AdminEntity(
    key: 'categories',
    table: 'categories',
    title: 'Kategori',
    listColumns: 'id, name, slug, kind, sort_order, is_active',
    titleColumn: 'name',
    hasStatus: false,
    orderBy: 'sort_order',
    ascending: true,
  );

  static const modules = AdminEntity(
    key: 'modules',
    table: 'conversation_modules',
    title: 'Modul Percakapan',
    listColumns: 'id, title, slug, status, validated_by, category:categories(name)',
    titleColumn: 'title',
    orderBy: 'sort_order',
    ascending: true,
  );

  static const lessons = AdminEntity(
    key: 'lessons',
    table: 'lessons',
    title: 'Pelajaran',
    listColumns: 'id, title, slug, status, validated_by',
    titleColumn: 'title',
    orderBy: 'sort_order',
    ascending: true,
  );

  static const all = [signs, categories, modules, lessons];

  static AdminEntity? byKey(String key) {
    for (final e in all) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// Slug dari judul: huruf kecil, angka, tanda hubung (CHECK slug di DB).
String slugify(String input) {
  final lower = input.toLowerCase().trim();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

final _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
bool isValidSlug(String slug) => _slugPattern.hasMatch(slug);
