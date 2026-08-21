# Photo3D

사진·동영상으로 3D 모델을 만드는 사진측량(photogrammetry) 앱.

대상 주위를 돌며 여러 각도에서 촬영하면, 겹쳐 찍힌 사진 속 같은 점을
삼각측량해 3차원 형상을 복원합니다. 촬영 → 포인트클라우드 → 메시 →
텍스처까지의 파이프라인을 앱 안에서 단계별로 보여줍니다.

세명대학교 재난안전학과(SMUDS) 프로젝트.

## 현재 상태

**촬영과 프로젝트 관리는 동작하고, 재구성 연산은 아직 시뮬레이션입니다.**

`ProjectStore.generateAll()`이 포인트클라우드 → 메시 → 텍스처 단계를
순서대로 전이시키지만, 실제 계산은 하지 않고 각 단계를 2초 지연으로
흉내냅니다. 무거운 재구성은 처리 백엔드(Apple Object Capture, COLMAP,
Meshroom 또는 클라우드)에 연동할 예정입니다.

| 기능 | 상태 |
|---|---|
| 사진·동영상 촬영 | 동작 |
| 프로젝트 생성·삭제, 디스크 영속화 | 동작 |
| 재구성 파이프라인 상태 전이 | 시뮬레이션 |
| 프레임 추출 · SfM · 메시 · 텍스처 | 미구현 |
| 포인트클라우드 뷰어 | 동작하지만 데모 점군을 렌더링 |

## 실행

```bash
flutter pub get
flutter run
```

Android 기기 또는 에뮬레이터를 권장합니다. 카메라가 핵심 기능이기
때문입니다.

스캐폴딩된 타깃은 `android`, `ios`, `macos`, `web`입니다 (Windows·Linux 없음).
웹에서는 `path_provider`가 동작하지 않아 저장이 메모리 전용으로 자동
강등됩니다 — 앱은 뜨지만 프로젝트가 디스크에 남지 않습니다
(`ProjectStore.persistent == false`).

## 구조

```text
lib/
  main.dart                        앱 진입점, 테마
  models/capture_project.dart      촬영 세션 모델, ReconStatus
  services/project_store.dart      프로젝트 영속화 + ChangeNotifier
  screens/
    home_screen.dart               프로젝트 목록
    capture_screen.dart            카메라 촬영(사진/동영상)
    project_detail_screen.dart     상세, 재구성 실행
    point_cloud_viewer_screen.dart 결과 뷰어
    about_screen.dart              사진측량 개념 설명
```

저장 구조는 앱 문서 디렉터리 아래에 만들어집니다.

```text
{appDocuments}/photo3d/
  projects.json        프로젝트 인덱스
  {projectId}/         프로젝트별 사진·동영상
```

## 촬영 가이드

좋은 재구성 결과를 위한 조건입니다. 앱 안의 "앱 소개" 화면에도 있습니다.

- 대상 주위를 한 바퀴 돌며 **60~80% 겹치게** 촬영 (높이를 바꿔 2~3바퀴 권장)
- 사진 **20장 이상**, 또는 천천히 도는 동영상 1개
- 밝고 균일한 조명, 짙은 그림자 없이
- 초점·노출 고정, 흔들림 최소화

피해야 할 대상: 반사(유리·금속)·투명·젖은 표면, 무늬 없는 단색 면,
움직이는 대상, 촬영 중 조명 변화.

## 개발

```bash
flutter analyze
dart format lib test
```
