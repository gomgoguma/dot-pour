import 'dart:convert';
import 'dart:typed_data';
import 'package:dot_pour/timemore_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRC matches the standard reflected IBM/MODBUS check vector', () {
    expect(DotProtocol.crc16(ascii.encode('123456789')), 0x4b37);
  });
  // Fixed gram-mode example: 160.0g, 6.5g/s, 30 seconds, no overload.
  final weight = [
    0xa5,
    0x5a,
    1,
    1,
    0,
    9,
    0,
    0,
    6,
    0x40,
    0,
    0x41,
    0,
    30,
    0,
    0,
    0,
  ];
  test(
    'decode a split zero-CRC firmware frame with signed weight and flow',
    () {
      final decoder = DotFrameDecoder();
      expect(decoder.add(weight.sublist(0, 7)), isEmpty);
      final reading =
          ScaleReading.fromFrame(decoder.add(weight.sublist(7)).single)!;
      expect(reading.grams, 160);
      expect(reading.flow, 6.5);
      expect(reading.seconds, 30);
      expect(reading.overloaded, false);
      expect(decoder.reservedCrcFrames, 1);
      final negative = Uint8List.fromList(weight);
      ByteData.sublistView(negative).setInt32(6, -123);
      ByteData.sublistView(negative).setInt16(10, -15);
      final signed = ScaleReading.fromFrame(decoder.add(negative).single)!;
      expect(signed.grams, -12.3);
      expect(signed.flow, -1.5);
    },
  );
  test('recover after junk or bad CRC and decode combined frames', () {
    final bad = [...weight]..[15] = 0xff;
    final decoder = DotFrameDecoder();
    final frames = decoder.add([4, 5, ...bad, ...weight, ...weight]);
    expect(frames.length, 2);
    expect(decoder.rejectedFrames, 1);
  });
  test('do not parse acknowledgements or short payloads as weight', () {
    expect(ScaleReading.fromFrame(DotFrame(3, 1, Uint8List(9), false)), isNull);
    expect(ScaleReading.fromFrame(DotFrame(1, 1, Uint8List(8), false)), isNull);
  });
  test('commands have big-endian payload length and CRC', () {
    final bytes = DotProtocol.command(3, 6, [0]);
    expect(bytes.sublist(0, 7), [0xa5, 0x5a, 3, 6, 0, 1, 0]);
    expect(
      ByteData.sublistView(bytes).getUint16(7),
      DotProtocol.crc16(bytes.sublist(0, 7)),
    );
    expect(DotFrameDecoder().add(bytes).single.command, 6);
  });
}
