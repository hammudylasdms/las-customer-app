import 'package:flutter/material.dart';

/// Shared lettering: the handwritten My sits half a letter-height below LAS.
class LasWordmark extends StatelessWidget {
  const LasWordmark({super.key, this.size = 56, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'My LAS',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: Offset(0, size / 2),
          child: Text(
            'My ',
            style: TextStyle(
              color: color,
              fontSize: size,
              height: 1.2,
              fontFamily: 'Snell Roundhand',
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Text(
          'LAS',
          style: TextStyle(
            color: color,
            fontSize: size,
            height: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
