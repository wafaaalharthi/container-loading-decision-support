/// Number formatting with thousands separators (Western digits).
String fmtNum(num v, [int decimals = 0]) {
  final s = v.toStringAsFixed(decimals);
  final parts = s.split('.');
  final neg = parts[0].startsWith('-');
  final digits = neg ? parts[0].substring(1) : parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final out = '${neg ? '-' : ''}$buf';
  return parts.length > 1 ? '$out.${parts[1]}' : out;
}

/// mm -> metres text, e.g. 5900 -> 5.90
String mmToM(int mm) => (mm / 1000).toStringAsFixed(2);

/// mm -> cm text without useless decimals, e.g. 800 -> 80, 805 -> 80.5
String mmToCm(int mm) => mm % 10 == 0 ? '${mm ~/ 10}' : (mm / 10).toStringAsFixed(1);

/// "L×W×H" in cm, kept left-to-right inside Arabic text.
String dimsCm(int l, int w, int h) => '\u2066${mmToCm(l)}×${mmToCm(w)}×${mmToCm(h)}\u2069';

/// Weight without useless decimals.
String fmtKg(double kg) => fmtNum(kg, kg % 1 == 0 ? 0 : 1);

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026/11/24 (Western digits in both languages)
String fmtDate(DateTime d) => '\u2066${d.year}/${_two(d.month)}/${_two(d.day)}\u2069';

/// 2026/11/24 17:48
String fmtDateTime(DateTime d) => '\u2066${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}\u2069';
