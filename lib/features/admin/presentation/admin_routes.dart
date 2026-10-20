import 'package:flutter/material.dart';

import '../../../core/utils/uuid.dart';
import '../../../core/widgets/state_views.dart';
import 'admin_entities.dart';
import 'admin_lesson_form.dart';
import 'admin_list_screen.dart';
import 'admin_module_form.dart';
import 'admin_reports_screen.dart';
import 'admin_sign_form.dart';

/// `/admin/:entity`
Widget adminEntityPage(String entity) {
  if (entity == 'reports') return const AdminReportsScreen();
  final e = AdminEntity.byKey(entity);
  if (e == null) return const _NotFound();
  return AdminListScreen(entity: e);
}

/// `/admin/:entity/:id` (id = 'new' untuk entri baru).
Widget adminEditPage(String entity, String id) {
  if (id != 'new' && !isUuid(id)) return const _NotFound();
  return switch (entity) {
    'signs' => AdminSignFormScreen(id: id),
    'modules' => AdminModuleFormScreen(id: id),
    'lessons' => AdminLessonFormScreen(id: id),
    _ => const _NotFound(),
  };
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const EmptyView(icon: Icons.help_outline, title: 'Halaman tidak ditemukan'),
      );
}
