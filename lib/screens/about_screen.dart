import 'package:flutter/material.dart';

/// 앱 소개: 사진측량·3D 모델링 개념, 재구성 파이프라인 인포그래픽, 촬영 방법.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 소개')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _Hero(),
          SizedBox(height: 24),
          _SectionTitle('사진측량(Photogrammetry)이란?'),
          SizedBox(height: 8),
          Text(
            '여러 각도에서 찍은 2D 사진들에서 각 지점의 3차원 위치를 계산해 '
            '실제 형상을 복원하는 기술입니다. 겹쳐 찍힌 사진 속 같은 점을 여러 장에서 '
            '찾아내 삼각측량으로 깊이를 구하고, 그 점들을 모아 3D로 만듭니다.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 24),
          _SectionTitle('재구성 파이프라인'),
          SizedBox(height: 4),
          Text(
            '촬영부터 3D 모델까지의 단계입니다.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          SizedBox(height: 12),
          _PipelineInfographic(),
          SizedBox(height: 24),
          _SectionTitle('핵심 개념'),
          SizedBox(height: 12),
          _ConceptCard(
            icon: Icons.blur_on,
            title: '포인트클라우드',
            body:
                '대상 표면 위 수많은 점들의 3D 좌표 집합. 가볍고 빠르게 형상을 확인할 수 있어 '
                '이 앱에서는 자동으로 생성합니다.',
          ),
          SizedBox(height: 10),
          _ConceptCard(
            icon: Icons.grid_3x3,
            title: '메시(Mesh)',
            body: '점들을 삼각형 면으로 연결해 만든 연속된 표면. 포인트클라우드에 이어 자동으로 생성됩니다.',
          ),
          SizedBox(height: 10),
          _ConceptCard(
            icon: Icons.texture,
            title: '텍스처(Texture)',
            body: '메시 표면에 실제 사진의 색·무늬를 입혀 사실적으로 보이게 하는 과정입니다.',
          ),
          SizedBox(height: 24),
          _SectionTitle('촬영 방법'),
          SizedBox(height: 12),
          _HowToShoot(),
          SizedBox(height: 24),
          _BackendNote(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.30), cs.surfaceContainerHigh],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.view_in_ar, color: cs.onPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo3D',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('사진·동영상으로 만드는 3D 모델'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

/// 인포그래픽: 세로 흐름의 재구성 파이프라인.
class _PipelineInfographic extends StatelessWidget {
  const _PipelineInfographic();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stages = <_StageData>[
      _StageData(
        Icons.photo_camera,
        '촬영',
        '사진·동영상으로 대상을 여러 각도에서',
        null,
        cs.primary,
      ),
      _StageData(
        Icons.movie_filter_outlined,
        '프레임 추출',
        '동영상을 이미지 프레임으로 분해',
        '자동',
        cs.primary,
      ),
      _StageData(
        Icons.hub_outlined,
        '특징점 매칭 (SfM)',
        '여러 사진 속 같은 점을 대응',
        '자동',
        cs.primary,
      ),
      _StageData(Icons.blur_on, '포인트클라우드', '점들의 3D 좌표 집합', '자동', cs.primary),
      _StageData(Icons.grid_3x3, '메시', '점을 삼각형 면으로 연결', '자동', cs.tertiary),
      _StageData(Icons.texture, '텍스처', '사진 색을 표면에 입힘', '자동', cs.tertiary),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < stages.length; i++)
            _StageRow(
              data: stages[i],
              index: i + 1,
              isLast: i == stages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StageData {
  const _StageData(this.icon, this.title, this.desc, this.badge, this.color);
  final IconData icon;
  final String title;
  final String desc;
  final String? badge;
  final Color color;
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.data,
    required this.index,
    required this.isLast,
  });
  final _StageData data;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: data.color, width: 1.5),
                ),
                child: Icon(data.icon, size: 20, color: data.color),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: cs.outlineVariant)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$index. ${data.title}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (data.badge != null)
                        _Badge(text: data.badge!, color: data.color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.desc,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToShoot extends StatelessWidget {
  const _HowToShoot();

  @override
  Widget build(BuildContext context) {
    const dos = [
      '대상 주위를 한 바퀴 돌며 60~80% 겹치게 촬영 (높이를 바꿔 2~3바퀴 권장)',
      '사진은 20장 이상, 또는 천천히 도는 동영상 1개',
      '밝고 균일한 조명에서, 짙은 그림자 없이',
      '초점·노출을 고정하고 흔들리지 않게',
      '대상이 화면을 충분히 채우도록 가까이',
    ];
    const donts = [
      '반사(유리·금속)·투명·젖은 표면',
      '무늬 없는 단색 면 (특징점이 안 잡힘)',
      '움직이는 대상, 촬영 중 조명 변화',
    ];
    return Column(
      children: [
        _TipBlock(
          title: '이렇게 촬영하세요',
          icon: Icons.check_circle,
          color: Colors.green,
          items: dos,
        ),
        const SizedBox(height: 12),
        _TipBlock(
          title: '이런 대상·상황은 피하세요',
          icon: Icons.cancel,
          color: Colors.redAccent,
          items: donts,
        ),
      ],
    );
  }
}

class _TipBlock extends StatelessWidget {
  const _TipBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: cs.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BackendNote extends StatelessWidget {
  const _BackendNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dns_outlined, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '무거운 재구성 연산은 처리 백엔드가 담당합니다 '
              '(예: Apple Object Capture · 클라우드 · COLMAP/Meshroom). '
              '현재는 파이프라인 흐름을 미리 보여주는 단계입니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
