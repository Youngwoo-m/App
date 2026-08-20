import 'dart:io';

import 'package:flutter/material.dart';

import '../models/capture_project.dart';
import '../services/project_store.dart';
import 'about_screen.dart';
import 'capture_screen.dart';
import 'project_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _createProject(BuildContext context) async {
    final now = DateTime.now();
    final controller = TextEditingController(
      text: '스캔 ${now.month}/${now.day}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 촬영 프로젝트'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '프로젝트 이름',
            hintText: '예: 도자기 화병',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final project = await ProjectStore.instance.createProject(name);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CaptureScreen(projectId: project.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo3D'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '앱 소개',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('새 촬영'),
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: ProjectStore.instance,
            builder: (context, _) {
              final projects = ProjectStore.instance.projects;
              if (projects.isEmpty) {
                return _EmptyState(onCreate: () => _createProject(context));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final project = projects[i];
                  return _ProjectCard(
                    project: project,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProjectDetailScreen(projectId: project.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // 좌측하단 SMUDS 로고
          Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12),
                child: Opacity(
                  opacity: 0.9,
                  child: Image.asset(
                    'assets/images/smuds_logo.png',
                    width: 150,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar_outlined, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('첫 촬영을 시작하세요', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '오브젝트 주위를 돌며 사진을 여러 장 찍거나\n동영상을 촬영하면 3D로 재구성합니다.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('새 촬영 프로젝트'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});
  final CaptureProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final File? thumb = ProjectStore.instance.thumbnailOf(project);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: (thumb != null && thumb.existsSync())
                      ? Image.file(thumb, fit: BoxFit.cover)
                      : Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CountChip(
                          icon: Icons.photo_outlined,
                          label: '사진 ${project.photoCount}',
                        ),
                        const SizedBox(width: 8),
                        _CountChip(
                          icon: Icons.videocam_outlined,
                          label: '동영상 ${project.videoCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
