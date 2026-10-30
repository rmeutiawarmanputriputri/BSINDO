import 'package:flutter/material.dart';

import '../../study/presentation/sign_study_screen.dart';
import '../domain/sign.dart';

/// S09 Detail Kosakata. v1.1.0: memakai layar belajar terpadu (video
/// 0,5/0,75/1×, panduan visual, audio, tanda dipelajari, navigasi antar
/// materi dalam kategori yang sama, favorit, kosakata sulit, laporan).
class SignDetailScreen extends StatelessWidget {
  const SignDetailScreen({super.key, required this.signId});

  final String signId;

  @override
  Widget build(BuildContext context) =>
      SignStudyScreen(module: ContentModule.vocabulary, signId: signId);
}
