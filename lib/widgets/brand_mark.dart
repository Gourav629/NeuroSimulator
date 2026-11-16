
import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact || centered
          ? MainAxisSize.min
          : MainAxisSize.max,
      children: [
        Container(
          width: compact ? 30 : 44,
          height: compact ? 30 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFF18352D),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.monitor_heart_outlined,
            color: const Color(0xFF58D6B0),
            size: compact ? 18 : 24,
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        Text(
          'NEURO',
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        if (!compact)
          const Text(
            '  /  SIMULATOR',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFA4B0BC),
              letterSpacing: .8,
            ),
          ),
      ],
    );
  }
}
