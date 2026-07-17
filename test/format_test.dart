import 'package:flutter_test/flutter_test.dart';
import 'package:farmbridge/core/format.dart';

void main() {
  test('formatRupiah pemisah ribuan', () {
    expect(formatRupiah(0), 'Rp0');
    expect(formatRupiah(5000), 'Rp5.000');
    expect(formatRupiah(35000), 'Rp35.000');
    expect(formatRupiah(1200000), 'Rp1.200.000');
    expect(formatRupiah(65000000), 'Rp65.000.000');
    expect(formatRupiah(999), 'Rp999');
    expect(formatRupiah(8000.7), 'Rp8.001'); // dibulatkan
  });
}
