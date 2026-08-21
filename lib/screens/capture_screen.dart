import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/capture_project.dart';
import '../services/project_store.dart';

enum CaptureMode { photo, video }

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CaptureMode _mode = CaptureMode.photo;
  bool _busy = false;
  bool _isRecording = false;
  Duration _recorded = Duration.zero;
  Timer? _timer;
  String? _error;

  /// 라이프사이클 전환이 연속으로 오는 동안 컨트롤러가 중복 생성되는 것을 막는다.
  bool _settingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    if (_settingUp) return;
    _settingUp = true;
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = '사용 가능한 카메라가 없습니다.');
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      // initialize() 대기 중 화면이 사라졌거나 다른 컨트롤러가 이미 붙었으면 폐기.
      if (!mounted || _controller != null) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '카메라 초기화 실패: $e');
    } finally {
      _settingUp = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      // 녹화 중에는 세션을 유지해 녹화가 끊기지 않게 한다.
      if (_isRecording) return;
      // setState로 지워야 폐기된 컨트롤러를 CameraPreview가 계속 참조하지 않는다.
      setState(() => _controller = null);
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) _setup();
    }
  }

  CaptureProject? get _project => ProjectStore.instance.byId(widget.projectId);

  Future<void> _takePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      final p = _project;
      if (p != null) await ProjectStore.instance.addPhoto(p, shot.path);
    } catch (e) {
      _snack('촬영 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    if (_isRecording) {
      try {
        final file = await c.stopVideoRecording();
        _timer?.cancel();
        final p = _project;
        if (p != null) await ProjectStore.instance.addVideo(p, file.path);
      } catch (e) {
        _snack('녹화 저장 실패: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recorded = Duration.zero;
          });
        }
      }
    } else {
      try {
        await c.startVideoRecording();
        setState(() {
          _isRecording = true;
          _recorded = Duration.zero;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recorded += const Duration(seconds: 1));
          }
        });
      } catch (e) {
        _snack('녹화 시작 실패: $e');
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _ErrorView(
                message: _error!,
                onRetry: () {
                  setState(() => _error = null);
                  _setup();
                },
              )
            : _controller == null
            ? const Center(child: CircularProgressIndicator())
            : _cameraUI(),
      ),
    );
  }

  Widget _cameraUI() {
    final c = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        _preview(c),
        Positioned(top: 0, left: 0, right: 0, child: _topBar()),
        Positioned(left: 0, right: 0, bottom: 0, child: _bottomControls()),
      ],
    );
  }

  Widget _preview(CameraController c) {
    final size = c.value.previewSize;
    if (size == null) return const ColoredBox(color: Colors.black);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _isRecording ? null : () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              _isRecording
                  ? '녹화 중 — 오브젝트 주위를 천천히 한 바퀴'
                  : '오브젝트를 60~80% 겹치게, 여러 각도에서',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (_isRecording) ...[
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(_fmt(_recorded), style: const TextStyle(color: Colors.white)),
          ],
        ],
      ),
    );
  }

  Widget _bottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: ProjectStore.instance,
            builder: (context, _) {
              final p = _project;
              return Text(
                '사진 ${p?.photoCount ?? 0} · 동영상 ${p?.videoCount ?? 0}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              );
            },
          ),
          const SizedBox(height: 14),
          _modeToggle(),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              _shutter(),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isRecording
                        ? null
                        : () => Navigator.maybePop(context),
                    child: const Text(
                      '완료',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return IgnorePointer(
      ignoring: _isRecording,
      child: Opacity(
        opacity: _isRecording ? 0.35 : 1,
        child: SegmentedButton<CaptureMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            selectedForegroundColor: Colors.black,
            selectedBackgroundColor: Colors.white,
          ),
          segments: const [
            ButtonSegment(
              value: CaptureMode.photo,
              icon: Icon(Icons.photo_camera_outlined),
              label: Text('사진'),
            ),
            ButtonSegment(
              value: CaptureMode.video,
              icon: Icon(Icons.videocam_outlined),
              label: Text('동영상'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
      ),
    );
  }

  Widget _shutter() {
    final isVideo = _mode == CaptureMode.video;
    return GestureDetector(
      onTap: isVideo ? _toggleRecording : _takePhoto,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: _busy
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isVideo ? (_isRecording ? 30 : 56) : 58,
                  height: isVideo ? (_isRecording ? 30 : 56) : 58,
                  decoration: BoxDecoration(
                    color: isVideo ? Colors.red : Colors.white,
                    shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _isRecording
                        ? BorderRadius.circular(6)
                        : null,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text(
                '돌아가기',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
