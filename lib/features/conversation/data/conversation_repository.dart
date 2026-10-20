import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../dictionary/domain/sign.dart';
import '../domain/conversation.dart';

abstract interface class ConversationRepository {
  Future<List<ConversationModule>> modules({String? categoryId});
  Future<ConversationModule> module(String id);
  Future<List<Category>> categories();
}

class SupabaseConversationRepository implements ConversationRepository {
  SupabaseConversationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ConversationModule>> modules({String? categoryId}) =>
      guardRequest(() async {
        var filter = _client
            .from('conversation_modules')
            .select(ConversationModule.listColumns)
            .eq('status', 'published');
        if (categoryId != null) filter = filter.eq('category_id', categoryId);
        final data = await filter.order('sort_order', ascending: true);
        return rows(data).map(ConversationModule.fromJson).toList();
      });

  @override
  Future<ConversationModule> module(String id) => guardRequest(() async {
        final row = await _client
            .from('conversation_modules')
            .select(ConversationModule.detailColumns)
            .eq('id', id)
            .single();
        return ConversationModule.fromJson(row);
      });

  @override
  Future<List<Category>> categories() => guardRequest(() async {
        final data = await _client
            .from('categories')
            .select('id, name, kind')
            .eq('kind', 'conversation')
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        return rows(data).map(Category.fromJson).toList();
      });
}

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => SupabaseConversationRepository(ref.watch(supabaseClientProvider)),
);

final conversationCategoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(conversationRepositoryProvider).categories(),
);

final conversationModulesProvider = FutureProvider.autoDispose
    .family<List<ConversationModule>, String?>(
  (ref, categoryId) =>
      ref.watch(conversationRepositoryProvider).modules(categoryId: categoryId),
);

final conversationDetailProvider = FutureProvider.autoDispose
    .family<ConversationModule, String>(
  (ref, id) => ref.watch(conversationRepositoryProvider).module(id),
);
