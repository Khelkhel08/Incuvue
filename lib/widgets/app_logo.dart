import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool circular;

  const AppLogo({
    super.key,
    required this.size,
    this.circular = true,
  });

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Image.asset(
        'assets/images/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (!circular) {
      return SizedBox(width: size, height: size, child: logo);
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: logo),
    );
  }
}
