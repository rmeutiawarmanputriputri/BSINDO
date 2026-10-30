import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/sanitize_search.dart';
import '../domain/sign.dart';

/// Ukuran halaman daftar (UI_UX §2).
const kPageSize = 20;

class DictionaryQuery {
  const DictionaryQuery({this.text = '', this.categoryId, this.entryType});

  final String text;
  final String? categoryId;
  final SignEntryType? entryType;

  bool get isEmpty =>
      normalizeSearch(text).isEmpty && categoryId == null && entryType == null;

  DictionaryQuery copyWith({
    String? text,
    String? Function()? categoryId,
    SignEntryType? Function()? entryType,
  }) => DictionaryQuery(
    text: text ?? this.text,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    entryType: entryType != null ? entryType() : this.entryType,
  );

  @override
  bool operator ==(Object other) =>
      other is DictionaryQuery &&
      normalizeSearch(other.text) == normalizeSearch(text) &&
      other.categoryId == categoryId &&
      other.entryType == entryType;

  @override
  int get hashCode => Object.hash(normalizeSearch(text), categoryId, entryType);
}

abstract interface class SignRepository {
  Future<List<Sign>> search(DictionaryQuery query, {int page = 0});
  Future<Sign> getById(String id);
  Future<List<Category>> categories({String kind = 'sign'});
}

class SupabaseSignRepository implements SignRepository {
  SupabaseSignRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Sign>> search(DictionaryQuery query, {int page = 0}) =>
      guardRequest(() async {
        var filter = _client
            .from('signs')
            .select(Sign.selectColumns)
            // Filter eksplisit sisi pengguna (RLS juga membatasi).
            .eq('status', 'published')
            // v1.1.0: Kamus = kosakata; huruf & angka punya halaman sendiri.
            .eq('content_module', ContentModule.vocabulary.value);
        final text = normalizeSearch(query.text);
        if (text.isNotEmpty) {
          filter = filter.ilike('term_normalized', containsPattern(text));
        }
        if (query.categoryId != null) {
          filter = filter.eq('category_id', query.categoryId!);
        }
        if (query.entryType != null) {
          filter = filter.eq('entry_type', query.entryType!.value);
        }
        final from = page * kPageSize;
        final data = await filter
            .order('term_normalized', ascending: true)
            .order('id', ascending: true)
            .range(from, from + kPageSize - 1);
        return rows(data).map(Sign.fromJson).toList();
      });

  @override
  Future<Sign> getById(String id) => guardRequest(() async {
    final row = await _client
        .from('signs')
        .select(Sign.selectColumns)
        .eq('id', id)
        .single();
    return Sign.fromJson(row);
  });

  @override
  Future<List<Category>> categories({String kind = 'sign'}) =>
      guardRequest(() async {
        final data = await _client
            .from('categories')
            .select('id, name, kind')
            .eq('kind', kind)
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        return rows(data).map(Category.fromJson).toList();
      });
}

final signRepositoryProvider = Provider<SignRepository>(
  (ref) => SupabaseSignRepository(ref.watch(supabaseClientProvider)),
);

final signCategoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(signRepositoryProvider).categories(),
);

final signDetailProvider = FutureProvider.autoDispose.family<Sign, String>(
  (ref, id) => ref.watch(signRepositoryProvider).getById(id),
);
