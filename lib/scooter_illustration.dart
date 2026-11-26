import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'saferide_ui.dart';

class ScooterIllustration extends StatelessWidget {
  const ScooterIllustration({
    super.key,
    this.showWordmark = false,
    this.maxHeight = 220,
  });

  final bool showWordmark;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: 1072 / 818.65033,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, 0.08, 0.92, 1],
            ).createShader(bounds),
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    SvgPicture.asset(
                      'assets/svg/main.svg',
                      colorMapper: _ScooterColors(
                        dark: dark,
                        showWordmark: showWordmark,
                      ),
                    ),
                    if (showWordmark)
                      Positioned(
                        left: constraints.maxWidth * 0.15,
                        top: constraints.maxHeight * 0.027,
                        child: Text(
                          saferideName,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: constraints.maxWidth * 0.073,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScooterColors extends ColorMapper {
  const _ScooterColors({required this.dark, required this.showWordmark});

  final bool dark;
  final bool showWordmark;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (attributeName != 'fill') return color;
    // The exported artwork has separate white canvas and ground paths.
    if (id == 'path1' || id == 'path4') return Colors.transparent;
    if (!showWordmark && (id == 'path152' || id == 'path153')) {
      return Colors.transparent;
    }
    if (!dark) return color;

    return switch (id) {
      'path32' || 'path151' => color,
      'path42' || 'path62' => const Color(0xFF2D7563),
      'path43' || 'path63' || 'path65' => const Color(0xFF286050),
      'path44' => const Color(0xFF205448),
      _ => switch (color.toARGB32()) {
        0xFFFFFFFF => const Color(0xFF416159),
        0xFFD3F4F6 => const Color(0xFF33544E),
        0xFFB7EAE8 => const Color(0xFF3C5F59),
        0xFFA1E0DB => const Color(0xFF3A665F),
        0xFFDBF5F7 => const Color(0xFF2B4945),
        _ => color,
      },
    };
  }
}
