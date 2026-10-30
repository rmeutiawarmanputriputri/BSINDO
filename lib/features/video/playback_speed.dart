/// Kecepatan putar video isyarat (v1.1.0: 1× → 0,75× → 0,5×). Murni Dart.
const kPlaybackSpeeds = [1.0, 0.75, 0.5];

/// Kecepatan berikutnya dalam siklus 1× → 0,75× → 0,5× → 1×.
double nextPlaybackSpeed(double current) {
  final i = kPlaybackSpeeds.indexWhere((s) => (s - current).abs() < 0.01);
  return kPlaybackSpeeds[(i + 1) % kPlaybackSpeeds.length];
}

/// Label kecepatan berformat Indonesia, mis. "0,75×".
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed.toString().replaceAll('.', ',')}×';
