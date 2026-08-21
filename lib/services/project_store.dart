import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/capture_project.dart';

/// 촬영 프로젝트와 사진 파일을 관리하고 디스크에 영속화한다.
///
/// 저장 구조:
/// ```text
///   {appDocuments}/photo3d/
///     projects.json          (프로젝트 인덱스 메타데이터)
///     {projectId}/           (프로젝트별 사진 폴더)
///        photo_{ts}.jpg
/// ```
class ProjectStore extends ChangeNotifier {
  ProjectStore._();
  static final ProjectStore instance = ProjectStore._();

  static const _uuid = Uuid();

  /// 웹 등 파일 저장을 지원하지 않는 플랫폼에서는 null(메모리 전용 동작).
  Directory? _baseDir;
  final List<CaptureProject> _projects = <CaptureProject>[];
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get persistent => _baseDir != null;
  List<CaptureProject> get projects => List.unmodifiable(_projects);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final base = Directory('${docs.path}/photo3d');
      if (!await base.exists()) {
        await base.create(recursive: true);
      }
      _baseDir = base;
      await _load();
    } catch (e) {
      // 웹 등: 파일 저장 미지원 → 메모리 전용으로 계속 동작.
      _baseDir = null;
      debugPrint('ProjectStore: 파일 저장 비활성화 ($e)');
    }
    _initialized = true;
    notifyListeners();
  }

  File get _indexFile => File('${_baseDir!.path}/projects.json');
  Directory _projectDir(String id) => Directory('${_baseDir!.path}/$id');

  Future<void> _load() async {
    if (!persistent || !await _indexFile.exists()) return;
    try {
      final list = jsonDecode(await _indexFile.readAsString()) as List<dynamic>;
      _projects
        ..clear()
        ..addAll(
          list.map((e) => CaptureProject.fromJson(e as Map<String, dynamic>)),
        );
      _projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('ProjectStore: 인덱스 로드 실패, 새로 시작 ($e)');
    }
  }

  Future<void> _save() async {
    if (!persistent) return;
    final raw = jsonEncode(_projects.map((e) => e.toJson()).toList());
    await _indexFile.writeAsString(raw);
  }

  CaptureProject? byId(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<CaptureProject> createProject(String name) async {
    final project = CaptureProject(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    if (persistent) {
      await _projectDir(project.id).create(recursive: true);
    }
    _projects.insert(0, project);
    await _save();
    notifyListeners();
    return project;
  }

  /// 촬영된 임시 파일을 프로젝트 폴더로 복사해 영구 보관한다.
  Future<void> addPhoto(CaptureProject project, String sourcePath) async {
    if (!persistent) {
      // 메모리 전용: 경로만 기록(파일 영속 X).
      project.photoFileNames.add(sourcePath);
      notifyListeners();
      return;
    }
    final dir = _projectDir(project.id);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = 'photo_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(sourcePath).copy('${dir.path}/$fileName');
    project.photoFileNames.add(fileName);
    await _save();
    notifyListeners();
  }

  /// 프로젝트의 모든 사진을 File 목록으로 해석해 반환.
  List<File> photosOf(CaptureProject project) {
    if (!persistent) {
      return project.photoFileNames.map(File.new).toList();
    }
    final dirPath = _projectDir(project.id).path;
    return project.photoFileNames.map((f) => File('$dirPath/$f')).toList();
  }

  File? thumbnailOf(CaptureProject project) {
    final photos = photosOf(project);
    return photos.isEmpty ? null : photos.first;
  }

  /// 촬영된 임시 동영상을 프로젝트 폴더로 복사해 영구 보관한다.
  Future<void> addVideo(CaptureProject project, String sourcePath) async {
    if (!persistent) {
      project.videoFileNames.add(sourcePath);
      notifyListeners();
      return;
    }
    final dir = _projectDir(project.id);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = 'video_${DateTime.now().microsecondsSinceEpoch}.mp4';
    await File(sourcePath).copy('${dir.path}/$fileName');
    project.videoFileNames.add(fileName);
    await _save();
    notifyListeners();
  }

  List<File> videosOf(CaptureProject project) {
    if (!persistent) {
      return project.videoFileNames.map(File.new).toList();
    }
    final dirPath = _projectDir(project.id).path;
    return project.videoFileNames.map((f) => File('$dirPath/$f')).toList();
  }

  final Set<String> _processing = <String>{};

  /// 포인트클라우드 → 메시 → 텍스처를 순서대로 전부 자동 실행.
  /// 재진입/앱 재시작 시 현재 단계에서 이어서 진행한다.
  /// 실제 연산은 처리 백엔드 연동 전까지 각 단계를 시뮬레이션.
  Future<void> generateAll(CaptureProject project) async {
    if (_processing.contains(project.id)) return;
    if (!project.isReadyForReconstruction ||
        project.reconStatus == ReconStatus.done) {
      return;
    }
    _processing.add(project.id);
    try {
      Future<void> step(ReconStatus to) async {
        project.reconStatus = to;
        notifyListeners();
        await _save();
        await Future.delayed(const Duration(seconds: 2));
      }

      // TODO(backend): 프레임 추출 → SfM → 포인트클라우드 → 메시 → 텍스처
      if (project.reconStatus == ReconStatus.none) {
        await step(ReconStatus.cloud);
      }
      if (project.reconStatus == ReconStatus.cloud) {
        await step(ReconStatus.mesh);
      }
      if (project.reconStatus == ReconStatus.mesh) {
        await step(ReconStatus.texture);
      }
      if (project.reconStatus == ReconStatus.texture) {
        project.reconStatus = ReconStatus.done;
        notifyListeners();
        await _save();
      }
    } finally {
      _processing.remove(project.id);
    }
  }

  /// 재구성 결과를 지우고 다시 촬영/재생성할 수 있도록 초기화.
  Future<void> resetReconstruction(CaptureProject project) async {
    project.reconStatus = ReconStatus.none;
    await _save();
    notifyListeners();
  }

  Future<void> deleteProject(CaptureProject project) async {
    if (persistent) {
      final dir = _projectDir(project.id);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    _projects.removeWhere((p) => p.id == project.id);
    await _save();
    notifyListeners();
  }
}
