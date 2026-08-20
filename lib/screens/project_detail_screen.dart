import 'dart:io';

import 'package:flutter/material.dart';

import '../models/capture_project.dart';
import '../services/project_store.dart';
import 'capture_screen.dart';
import 'point_cloud_viewer_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAutoReconstruct(),
    );
  }

  /// 촬영이 충분하면 포인트클라우드→메시→텍스처를 자동 실행(진행 중이면 이어서).
  void _maybeAutoReconstruct() {
    final p = ProjectStore.instance.byId(widget.projectId);
    if (p == null) return;
    if (p.isReadyForReconstruction && p.reconStatus != ReconStatus.done) {
      ProjectStore.instance.generateAll(p);
    }
  }

  Future<void> _openCapture() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(projectId: widget.projectId),
      ),
    );
    _maybeAutoReconstruct();
  }

  Future<void> _confirmDelete(CaptureProject project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프로젝트 삭제'),
        content: Text('"${project.name}" 와(과) 모든 사진·동영상을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ProjectStore.instance.deleteProject(project);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProjectStore.instance,
      builder: (context, _) {
        final project = ProjectStore.instance.byId(widget.projectId);
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('프로젝트를 찾을 수 없습니다.')),
          );
        }
        final photos = ProjectStore.instance.photosOf(project);
        final videos = ProjectStore.instance.videosOf(project);
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(project);
                  if (v == 'reset') {
                    ProjectStore.instance.resetReconstruction(project);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reset', child: Text('재구성 초기화')),
                  PopupMenuItem(value: 'delete', child: Text('프로젝트 삭제')),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _ReconPanel(project: project)),
              if (videos.isNotEmpty)
                SliverToBoxAdapter(child: _VideoStrip(videos: videos)),
              if (photos.isEmpty && videos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCapture(onCapture: _openCapture),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '사진 ${photos.length}장',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _PhotoTile(file: photos[i]),
                      childCount: photos.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCapture,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('촬영 계속'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 재구성 진행 상황 패널. 포인트클라우드는 자동, 메시·텍스처는 버튼 실행.
class _ReconPanel extends StatelessWidget {
  const _ReconPanel({required this.project});
  final CaptureProject project;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: _content(context, cs),
    );
  }

  Widget _content(BuildContext context, ColorScheme cs) {
    switch (project.reconStatus) {
      case ReconStatus.none:
        if (!project.isReadyForReconstruction) {
          final need = CaptureProject.recommendedMinPhotos - project.photoCount;
          return _row(
            icon: Icons.info_outline,
            color: cs.onSurfaceVariant,
            title: '재구성 준비 중',
            subtitle:
                '사진 ${need > 0 ? need : 0}장 더 찍거나 동영상 1개를 추가하면 자동으로 재구성이 시작됩니다.',
          );
        }
        return _row(
          icon: Icons.auto_awesome,
          color: cs.primary,
          title: '재구성 대기',
          subtitle: '잠시 후 포인트클라우드 → 메시 → 텍스처가 자동 생성됩니다…',
        );
      case ReconStatus.cloud:
        return _progress(
          context,
          title: '포인트클라우드 생성 중… (1/3)',
          subtitle: '프레임 추출 → 특징점 매칭(SfM) → 점 좌표 계산',
        );
      case ReconStatus.mesh:
        return _progress(
          context,
          title: '메시 생성 중… (2/3)',
          subtitle: '포인트클라우드 → 삼각형 면으로 연결',
        );
      case ReconStatus.texture:
        return _progress(
          context,
          title: '텍스처 생성 중… (3/3)',
          subtitle: '사진 색을 표면에 매핑',
        );
      case ReconStatus.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              icon: Icons.view_in_ar,
              color: cs.tertiary,
              title: '3D 모델 완료',
              subtitle: '포인트클라우드 + 메시 + 텍스처가 자동 생성되었습니다.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PointCloudViewerScreen(projectName: project.name),
                  ),
                ),
                icon: const Icon(Icons.threed_rotation),
                label: const Text('3D 모델 보기'),
              ),
            ),
          ],
        );
    }
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progress(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _VideoStrip extends StatelessWidget {
  const _VideoStrip({required this.videos});
  final List<File> videos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '동영상 ${videos.length}개',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Container(
                width: 120,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: cs.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '클립 ${i + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PhotoViewer(file: file)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(maxScale: 5, child: Image.file(file)),
      ),
    );
  }
}

class _EmptyCapture extends StatelessWidget {
  const _EmptyCapture({required this.onCapture});
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_back_outlined,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text('아직 촬영이 없습니다'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('촬영 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
