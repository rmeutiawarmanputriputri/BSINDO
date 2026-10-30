import 'package:bisindo_app/core/errors/app_failure.dart';
import 'package:bisindo_app/core/utils/debouncer.dart';
import 'package:bisindo_app/features/dictionary/data/sign_repository.dart';
import 'package:bisindo_app/features/dictionary/domain/sign.dart';
import 'package:bisindo_app/features/dictionary/presentation/dictionary_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSignRepository implements SignRepository {
  final List<DictionaryQuery> queries = [];
  final List<int> pages = [];
  bool fail = false;

  @override
  Future<List<Sign>> search(DictionaryQuery query, {int page = 0}) async {
    queries.add(query);
    pages.add(page);
    if (fail) throw const NetworkFailure();
    final count = page == 0 ? kPageSize : 3;
    return [
      for (var i = 0; i < count; i++)
        Sign(
          id: 'p$page-$i',
          term: 'Kata $page-$i',
          entryType: SignEntryType.word,
        ),
    ];
  }

  @override
  Future<Sign> getById(String id) => throw UnimplementedError();

  @override
  Future<List<Category>> categories({String kind = 'sign'}) async => const [];
}

void main() {
  late FakeSignRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSignRepository();
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [signRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(dictionaryControllerProvider, (prev, next) {});
  });
  tearDown(() => container.dispose());

  DictionaryController c() =>
      container.read(dictionaryControllerProvider.notifier);
  DictionaryState s() => container.read(dictionaryControllerProvider);

  test('query kosong → tidak memanggil server (empty awal)', () async {
    c().setText('   ');
    await Future<void>.delayed(Duration.zero);
    expect(repo.queries, isEmpty);
    expect(s().query.isEmpty, isTrue);
  });

  test('DICT-02/04: hasil, pagination tanpa duplikat, akhir daftar', () async {
    c().setText('kata');
    await Future<void>.delayed(Duration.zero);
    expect(s().items, hasLength(kPageSize));
    expect(s().hasMore, isTrue);

    await c().loadMore();
    expect(s().items, hasLength(kPageSize + 3));
    expect(s().hasMore, isFalse);
    expect(repo.pages, [0, 1]);
    expect(s().items.map((e) => e.id).toSet().length, s().items.length);
  });

  test('filter kategori + jenis diteruskan ke repository', () async {
    c().setCategory('cat-1');
    await Future<void>.delayed(Duration.zero);
    c().setEntryType(SignEntryType.phrase);
    await Future<void>.delayed(Duration.zero);
    expect(repo.queries.last.categoryId, 'cat-1');
    expect(repo.queries.last.entryType, SignEntryType.phrase);
  });

  test('error → state error; reload mencoba lagi', () async {
    repo.fail = true;
    c().setText('x');
    await Future<void>.delayed(Duration.zero);
    expect(s().error, isA<NetworkFailure>());
    repo.fail = false;
    await c().reload();
    expect(s().error, isNull);
    expect(s().items, isNotEmpty);
  });

  testWidgets('DICT-03: 5 ketikan cepat → 1 aksi (debounce 350 ms)', (
    tester,
  ) async {
    final debouncer = Debouncer();
    var calls = 0;
    for (var i = 0; i < 5; i++) {
      debouncer.run(() => calls++);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, 1);
    debouncer.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
