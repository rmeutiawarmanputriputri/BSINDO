import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/json.dart';
import '../data/admin_repository.dart';

/// Dialog memilih kosakata (semua status) untuk ditautkan ke item.
Future<({String id, String term})?> pickSign(BuildContext context, WidgetRef ref) {
  return showDialog<({String id, String term})>(
    context: context,
    builder: (context) => const _SignPickerDialog(),
  );
}

class _SignPickerDialog extends ConsumerStatefulWidget {
  const _SignPickerDialog();

  @override
  ConsumerState<_SignPickerDialog> createState() => _SignPickerDialogState();
}

class _SignPickerDialogState extends ConsumerState<_SignPickerDialog> {
  List<Json> _results = const [];
  bool _loading = false;

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final rows = await ref.read(adminRepositoryProvider).list(
            'signs',
            columns: 'id, term, status',
            orderBy: 'term',
            ascending: true,
            search: q,
            searchColumn: 'term',
          );
      if (mounted) setState(() => _results = rows);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih kosakata'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari kata',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  for (final r in _results)
                    ListTile(
                      title: Text(optString(r, 'term') ?? '-'),
                      subtitle: Text(optString(r, 'status') ?? ''),
                      onTap: () => Navigator.of(context).pop(
                        (id: reqString(r, 'id'), term: optString(r, 'term') ?? ''),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
