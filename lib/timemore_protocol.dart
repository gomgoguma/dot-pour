import 'dart:typed_data';

/// TIMEMORE's framed FFF0 protocol. All multibyte fields are big endian.
/// See https://github.com/TIMEMORE-COFFEE/open-scale-protocol
class DotProtocol {
  static const service = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const notify = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const write = '0000fff2-0000-1000-8000-00805f9b34fb';

  static int crc16(List<int> bytes) {
    var crc = 0xffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xa001 : crc >> 1;
      }
    }
    return crc;
  }

  static Uint8List command(
    int opcode,
    int command, [
    List<int> data = const [],
  ]) {
    final bytes = Uint8List(8 + data.length);
    bytes.setAll(0, [0xa5, 0x5a, opcode, command]);
    ByteData.sublistView(bytes).setUint16(4, data.length);
    bytes.setAll(6, data);
    ByteData.sublistView(
      bytes,
    ).setUint16(bytes.length - 2, crc16(bytes.sublist(0, bytes.length - 2)));
    return bytes;
  }
}

class DotFrame {
  final int opcode;
  final int command;
  final Uint8List payload;
  final bool reservedCrc;
  const DotFrame(this.opcode, this.command, this.payload, this.reservedCrc);
}

/// Handles split notifications, several frames per notification and bad CRCs.
/// The specification also calls the CRC field reserved; zero CRC is accepted
/// for that firmware variant, while nonzero CRCs are always verified.
class DotFrameDecoder {
  final List<int> _buffer = [];
  int rejectedFrames = 0;
  int reservedCrcFrames = 0;

  void clear() => _buffer.clear();

  List<DotFrame> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <DotFrame>[];
    while (_buffer.length >= 2) {
      if (_buffer[0] != 0xa5 || _buffer[1] != 0x5a) {
        _buffer.removeAt(0);
        continue;
      }
      if (_buffer.length < 6) break;
      final length = (_buffer[4] << 8) | _buffer[5];
      if (length > 128 || ![1, 2, 3].contains(_buffer[2])) {
        rejectedFrames++;
        _buffer.removeAt(0);
        continue;
      }
      final size = length + 8;
      if (_buffer.length < size) break;
      final crc = (_buffer[size - 2] << 8) | _buffer[size - 1];
      if (crc != 0 && crc != DotProtocol.crc16(_buffer.sublist(0, size - 2))) {
        rejectedFrames++;
        _buffer.removeAt(0);
        continue;
      }
      if (crc == 0) reservedCrcFrames++;
      frames.add(
        DotFrame(
          _buffer[2],
          _buffer[3],
          Uint8List.fromList(_buffer.sublist(6, size - 2)),
          crc == 0,
        ),
      );
      _buffer.removeRange(0, size);
    }
    return frames;
  }
}

class ScaleReading {
  final double grams;
  final double flow;
  final int seconds;
  final bool overloaded;
  const ScaleReading(this.grams, this.flow, this.seconds, this.overloaded);

  static ScaleReading? fromFrame(DotFrame frame) {
    if (![1, 2].contains(frame.opcode) ||
        frame.command != 1 ||
        frame.payload.length != 9) {
      return null;
    }
    final data = ByteData.sublistView(frame.payload);
    // DOT's gram-mode weight and flow have 0.1 g / 0.1 g/s resolution.
    return ScaleReading(
      data.getInt32(0) / 10,
      data.getInt16(4) / 10,
      data.getUint16(6),
      data.getUint8(8) != 0,
    );
  }
}
