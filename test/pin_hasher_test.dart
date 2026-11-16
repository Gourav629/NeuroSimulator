import 'package:flutter_test/flutter_test.dart';

import 'package:neurosim/services/pin_hasher.dart';

void main() {
  group('PIN hashing tests', () {
    test('Same PIN and salt should generate same hash', () {
      final hash1 = derivePinHash('salt123:123456');
      final hash2 = derivePinHash('salt123:123456');

      expect(hash1, hash2);
    });

    test('Different PINs should generate different hashes', () {
      final hash1 = derivePinHash('salt123:123456');
      final hash2 = derivePinHash('salt123:654321');

      expect(hash1, isNot(hash2));
    });

    test('Different salts should generate different hashes', () {
      final hash1 = derivePinHash('salt123:123456');
      final hash2 = derivePinHash('salt456:123456');

      expect(hash1, isNot(hash2));
    });

    test('Generated hash should be a hexadecimal string', () {
      final hash = derivePinHash('salt123:123456');

      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('Generated hash should contain 64 hexadecimal characters', () {
      final hash = derivePinHash('salt123:123456');

      expect(hash.length, 64);
    });
  });
}
