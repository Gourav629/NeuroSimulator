
import 'package:flutter/material.dart';

class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF15252A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 17,
            color: Color(0xFF58D6B0),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB1C0C9),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
