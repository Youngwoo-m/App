/// 재구성 파이프라인 진행 상태.
/// 촬영이 충분하면 포인트클라우드 → 메시 → 텍스처를 순서대로 전부 자동 실행한다.
enum ReconStatus {
  none, // 촬영만 됨
  cloud, // 포인트클라우드 생성 중
  mesh, // 메시 생성 중
  texture, // 텍스처 생성 중
  done, // 완료(포인트클라우드+메시+텍스처)
}

/// 하나의 촬영 세션 = 한 오브젝트를 재구성하기 위해 찍은 사진/동영상 묶음.
class CaptureProject {
  /// 재구성 품질을 위해 권장하는 최소 사진 수.
  static const int recommendedMinPhotos = 20;

  final String id;
  String name;
  final DateTime createdAt;

  /// 프로젝트 폴더 안에 저장된 사진 파일 이름들(절대경로 X — 컨테이너 경로 변경에 견고).
  final List<String> photoFileNames;

  /// 프로젝트 폴더 안에 저장된 동영상 파일 이름들.
  final List<String> videoFileNames;

  /// 재구성 진행 상태(포인트클라우드 자동 / 메시·텍스처 수동).
  ReconStatus reconStatus;

  CaptureProject({
    required this.id,
    required this.name,
    required this.createdAt,
    List<String>? photoFileNames,
    List<String>? videoFileNames,
    this.reconStatus = ReconStatus.none,
  }) : photoFileNames = photoFileNames ?? <String>[],
       videoFileNames = videoFileNames ?? <String>[];

  int get photoCount => photoFileNames.length;
  int get videoCount => videoFileNames.length;

  /// 재구성 입력 충분 여부: 사진 20장 이상 또는 동영상 1개 이상.
  bool get isReadyForReconstruction =>
      photoCount >= recommendedMinPhotos || videoCount >= 1;

  String get formattedDate {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${createdAt.year}.${two(createdAt.month)}.${two(createdAt.day)} '
        '${two(createdAt.hour)}:${two(createdAt.minute)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'photoFileNames': photoFileNames,
    'videoFileNames': videoFileNames,
    'reconStatus': reconStatus.name,
  };

  factory CaptureProject.fromJson(Map<String, dynamic> json) => CaptureProject(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    photoFileNames: (json['photoFileNames'] as List<dynamic>? ?? [])
        .cast<String>(),
    videoFileNames: (json['videoFileNames'] as List<dynamic>? ?? [])
        .cast<String>(),
    reconStatus: ReconStatus.values.firstWhere(
      (s) => s.name == json['reconStatus'],
      orElse: () => ReconStatus.none,
    ),
  );
}
