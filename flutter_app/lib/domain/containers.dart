/// Container size. All lengths in mm (inside dimensions).
class ContainerDims {
  final String code; // 20GP, 40GP, 40HC or CUSTOM
  final int length;
  final int width;
  final int height;
  final int doorWidth;
  final int doorHeight;
  final double payloadKg;

  const ContainerDims({
    required this.code,
    required this.length,
    required this.width,
    required this.height,
    required this.doorWidth,
    required this.doorHeight,
    required this.payloadKg,
  });

  bool get isCustom => code == customCode;
  double get volumeM3 => length * width * height / 1e9;

  /// Translation key of the display name.
  String get titleKey => isCustom ? 'cont_custom' : 'cont_$code';

  static const customCode = 'CUSTOM';
}

// Inside dimensions and payload (same values as the prototype and engine data)
const List<ContainerDims> containerPresets = [
  ContainerDims(code: '20GP', length: 5900, width: 2352, height: 2395, doorWidth: 2340, doorHeight: 2292, payloadKg: 28130),
  ContainerDims(code: '40GP', length: 12032, width: 2352, height: 2395, doorWidth: 2340, doorHeight: 2292, payloadKg: 28750),
  ContainerDims(code: '40HC', length: 12032, width: 2350, height: 2700, doorWidth: 2340, doorHeight: 2597, payloadKg: 28600),
];

ContainerDims? presetByCode(String code) {
  for (final c in containerPresets) {
    if (c.code == code) return c;
  }
  return null;
}
