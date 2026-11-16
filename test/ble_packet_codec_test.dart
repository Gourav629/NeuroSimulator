import 'package:flutter_test/flutter_test.dart';

import 'package:neurosim/protocol/ble_packet_codec.dart';

void main() {
  group('BlePacketCodec CRC tests', () {
    test('CRC16-CCITT test vector should return 0x29B1', () {
      final crc = BlePacketCodec.calculateCrc([
        0x31,
        0x32,
        0x33,
        0x34,
        0x35,
        0x36,
        0x37,
        0x38,
        0x39,
      ]);

      expect(crc, 0x29B1);
    });

    test('CRC test property should pass', () {
      expect(BlePacketCodec.crcTestPassed, isTrue);
    });
  });

  group('BLE packet generation tests', () {
    late List<int> packet;

    setUp(() {
      packet = BlePacketCodec.buildTxPacket(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        milliseconds: 0,
        start: true,
        channel: 1,
        current: 0,
        frequency: 20,
        pulseWidth: 200,
        gap: 100,
      );
    });

    test('Generated packet should contain 19 bytes', () {
      expect(packet.length, 19);
    });

    test('Packet should contain correct header', () {
      expect(packet[0], 0x4E);
    });

    test('Packet should contain correct footer', () {
      expect(packet[15], 0x4F);
      expect(packet[16], 0x4F);
    });

    test('Packet should contain correct frequency', () {
      expect(packet[10], 20);
    });

    test('Packet should contain correct pulse width', () {
      expect(packet[11], 200);
      expect(packet[12], 0);
    });

    test('Packet should contain correct gap', () {
      expect(packet[13], 100);
      expect(packet[14], 0);
    });

    test('Generated packet should pass CRC validation', () {
      expect(BlePacketCodec.verifyTxPacket(packet), isTrue);
    });

    test('Modified packet should fail CRC validation', () {
      packet[9] = 1;

      expect(BlePacketCodec.verifyTxPacket(packet), isFalse);
    });

    test('Incorrect packet length should fail validation', () {
      expect(BlePacketCodec.verifyTxPacket([0x4E, 0x4F]), isFalse);
    });
  });

  group('BLE channel and command tests', () {
    test('Channel 1 start command should produce correct bits', () {
      final packet = BlePacketCodec.buildTxPacket(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        milliseconds: 0,
        start: true,
        channel: 1,
        current: 0,
        frequency: 20,
        pulseWidth: 200,
        gap: 100,
      );

      expect(packet[8], 0x05);
    });

    test('Channel 4 start command should produce correct bits', () {
      final packet = BlePacketCodec.buildTxPacket(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        milliseconds: 0,
        start: true,
        channel: 4,
        current: 0,
        frequency: 20,
        pulseWidth: 200,
        gap: 100,
      );

      expect(packet[8], 0x21);
    });

    test('Stop command should use stop bit', () {
      final packet = BlePacketCodec.buildTxPacket(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        milliseconds: 0,
        start: false,
        channel: 1,
        current: 0,
        frequency: 20,
        pulseWidth: 200,
        gap: 100,
      );

      expect(packet[8], 0x06);
    });
  });

  group('BLE packet range tests', () {
    test('Invalid channel should throw RangeError', () {
      expect(
        () => BlePacketCodec.buildTxPacket(
          days: 0,
          hours: 0,
          minutes: 0,
          seconds: 0,
          milliseconds: 0,
          start: true,
          channel: 5,
          current: 0,
          frequency: 20,
          pulseWidth: 200,
          gap: 100,
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });
}
