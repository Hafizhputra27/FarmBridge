/// Format angka jadi Rupiah dengan pemisah ribuan: 35000 -> "Rp35.000".
/// Dipakai di listing card, listing detail, transaction detail.
/// ponytail: positif saja (harga tidak pernah negatif); tambah handling
/// tanda kalau suatu saat perlu.
String formatRupiah(num value) {
  final digits = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return 'Rp$buf';
}
