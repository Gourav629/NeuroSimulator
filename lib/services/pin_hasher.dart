
import 'dart:convert';

import 'package:crypto/crypto.dart';

String derivePinHash(String input) {
  final parts = input.split(':');

  List<int> value = utf8.encode(input);

  for (var i = 0; i < 100000; i++) {
    value = sha256.convert([
      ...value,
      ...utf8.encode(parts.first),
      i & 0xff,
    ]).bytes;
  }

  return value
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
