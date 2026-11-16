
import 'dart:typed_data';

class BlePacketCodec {
  static const int txPacketLength = 19;

  static int calculateCrc(List<int> data) {
    int crc = 0xFFFF;

    for (final byte in data) {
      crc ^= (byte & 0xFF) << 8;

      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc;
  }

  static bool get crcTestPassed {
    return calculateCrc([
          0x31,
          0x32,
          0x33,
          0x34,
          0x35,
          0x36,
          0x37,
          0x38,
          0x39,
        ]) ==
        0x29B1;
  }

  static Uint8List buildTxPacket({
    required int days,
    required int hours,
    required int minutes,
    required int seconds,
    required int milliseconds,
    required bool start,
    required int channel,
    required int current,
    required int frequency,
    required int pulseWidth,
    required int gap,
  }) {
    if (days < 0 ||
        days > 65535 ||
        hours < 0 ||
        hours > 255 ||
        minutes < 0 ||
        minutes > 255 ||
        seconds < 0 ||
        seconds > 255 ||
        milliseconds < 0 ||
        milliseconds > 65535 ||
        current < 0 ||
        current > 255 ||
        frequency < 0 ||
        frequency > 255 ||
        pulseWidth < 0 ||
        pulseWidth > 65535 ||
        gap < 0 ||
        gap > 65535 ||
        channel < 1 ||
        channel > 4) {
      throw RangeError(
        'One or more BLE packet values are out of range.',
      );
    }

    final packet = Uint8List(txPacketLength);

    packet[0] = 0x4E;

    packet[1] = days & 0xFF;
    packet[2] = (days >> 8) & 0xFF;

    packet[3] = hours;
    packet[4] = minutes;
    packet[5] = seconds;

    packet[6] = milliseconds & 0xFF;
    packet[7] = (milliseconds >> 8) & 0xFF;

    final commandBits = start ? 0x01 : 0x02;
    final channelBits = 1 << (channel + 1);

    packet[8] = commandBits | channelBits;

    packet[9] = current;
    packet[10] = frequency;

    packet[11] = pulseWidth & 0xFF;
    packet[12] = (pulseWidth >> 8) & 0xFF;

    packet[13] = gap & 0xFF;
    packet[14] = (gap >> 8) & 0xFF;

    packet[15] = 0x4F;
    packet[16] = 0x4F;

    // CRC over bytes 0–16.
    final crc = calculateCrc(
      packet.sublist(0, 17),
    );

    // CRC1 = LSB, CRC2 = MSB.
    packet[17] = crc & 0xFF;
    packet[18] = (crc >> 8) & 0xFF;

    return packet;
  }

  static bool verifyTxPacket(List<int> packet) {
    if (packet.length != txPacketLength) {
      return false;
    }

    if (packet[0] != 0x4E ||
        packet[15] != 0x4F ||
        packet[16] != 0x4F) {
      return false;
    }

    final receivedCrc =
        (packet[17] & 0xFF) |
        ((packet[18] & 0xFF) << 8);

    final calculatedCrc = calculateCrc(
      packet.sublist(0, 17),
    );

    return receivedCrc == calculatedCrc;
  }
}
