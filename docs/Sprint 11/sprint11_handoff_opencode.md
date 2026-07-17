# Sprint 11 — Handoff untuk lanjut di opencode

> Paste bagian "PROMPT UNTUK OPENCODE" di bawah ke sesi baru opencode. Sisanya konteks referensi.

---

## PROMPT UNTUK OPENCODE (copy dari sini)

Kamu melanjutkan pekerjaan Sprint 11 di project Flutter **FarmBridge** (marketplace petani↔pembeli, hackathon). Tugas: **UI polish sesuai desain + fix logic semua flow**, cepat. Sesi sebelumnya sudah menyelesaikan sebagian besar golden-path buyer.

### ATURAN WAJIB
1. **JANGAN pernah jalankan git write** (`add`/`commit`/`push`/`merge`/`pull`/`branch`/`reset`/`revert`). `docs/CLAUDE.md` melarangnya — histori commit harus murni dari manusia. Kalau ada yang siap commit: tampilkan diff + draft commit message sebagai teks, user yang jalankan sendiri. Read-only git (status/diff/log) boleh.
2. **Jangan ketik password** ke field manapun. Verifikasi login harus dilakukan user.
3. Kerja lazy/minimal (YAGNI, reuse dulu), tapi baca kode & desain penuh sebelum edit.

### ACUAN DESAIN
- 15 PNG di `/Users/haimac/Downloads/FarmBridgeDesign/` (dinamai per sprint). Buka dengan tool baca gambar.
- **JANGAN pakai Figma MCP** — kena rate limit Starter plan.
- Design system: forest green `#14532D` (tombol/harga/emphasis), leaf `#2E7D46` (aksen), sage `#E7F2E9` (badge/banner), krem `#F3F2E9` (scaffold), kartu putih rounded ~16-20px. Tombol pill forest-green. Bottom nav mengambang + FAB "+" hijau di tengah.
- Token sudah dikunci di `lib/core/app_theme.dart` (`AppTheme.brandGreen/leaf/sage/cream/ink`). Format rupiah: `lib/core/format.dart` → `formatRupiah(num)`.

### CARA VERIFIKASI (PENTING)
- **Emulator network MATI** (DNS unknown host, ping korup) → app hang di splash. JANGAN pakai emulator.
- Pakai **device fisik Infinix** `147977056B001246` (punya internet + sesi buyer sudah login).
- adb: `~/Library/Android/sdk/platform-tools/adb`. Package app: `com.example.farmbridge`.
- Build+run: `flutter run -d 147977056B001246 --no-pub` di background (akan exit saat stdin EOF tapi APK terinstall). Lalu:
  - Launch: `adb -s 147977056B001246 shell monkey -p com.example.farmbridge -c android.intent.category.LAUNCHER 1`
  - Screenshot: `adb -s 147977056B001246 exec-out screencap -p > /tmp/s.png` lalu baca file-nya.
  - Tap: `adb -s 147977056B001246 shell input tap X Y` (koordinat REAL, layar 1080x2400).
- Supabase project id (untuk cek data via MCP): `rwxnjxmzkcfoddnzjosi`.
- Data test tipis: hanya ~4 listing aktif (kategori "Cabai Merah", "Kategori Uji FG48"), petani "Pak Tani Maju". Kebanyakan tanpa foto_url/lokasi (wajar tampil placeholder/"-").

### SUDAH SELESAI (jangan ulang; verified live = sudah dicek di Infinix)
- Theme global forest-green (`lib/core/app_theme.dart` + `main.dart`) — mengangkat semua layar. ✅ verified
- Buyer home feed rebuild: single-column rich cards + category chips dinamis dari data + badge VERIFIED (dari `farmer_profiles.verified`) + pill stok. ✅ verified live
- Listing detail: hero image, harga menonjol, kartu info, tombol pill. ✅ verified live
- Transaction detail: status chip berwarna, kartu info, total menonjol.
- Negotiation: pinned "Active Negotiation" card (price/qty/status) + ChatBubble (milikku=forest green teks putih, lawan=putih border) + tombol aksi pill. ⚠️ BELUM verified live (interrupt saat mau cek).
- Chat inbox + My listings: harga terformat + warna brand.
- Farmer profile: Trust Score card dengan progress bars. ⚠️ BELUM verified live.
- Login field fix (filled:false), router `/farmer` placeholder → redirect.
- `formatRupiah` + test. **`flutter analyze` bersih, `flutter test` 27/27 pass.**

### LOGIC AUDIT (sudah dilakukan — hasil: BERSIH)
Semua repository (listing/negotiation/buy-now/transaction/recurring) + edge functions sudah di-review, matang & E2E-tested di Sprint 10 (3 bug besar sudah fixed: race condition Buy Now, guard `.select()` hilang, EXPIRED case mismatch). `initialize()` tidak panggil network. **Yang selama ini terlihat "broken" = splash hang karena network mati + wart `/farmer` (sudah fix). Tidak ada bug flow baru.** Kalau user lapor flow spesifik patah, minta reproduksi konkret dulu.

### TODO — lanjutkan (urut prioritas demo)
1. **Verifikasi live** negotiation chat + farmer profile di Infinix (rebuild → Percakapan → buka negosiasi; tap nama petani → profil). Perbaiki kalau ada yang jelek.
2. **Farmer dashboard** (LAYAR BARU) sesuai `Sprint 5 ke-2.png`: Welcome + "Today's Summary" (3 stat card: Active Listings / Recurring Orders / Incoming Negotiations) + Recent Negotiations (list dgn Decline/Accept). Sekarang farmer home = `MyListingsScreen`. Bisa jadikan tab baru atau ganti landing `/farmer/listings`. Butuh endpoint hitung: jumlah listing aktif, recurring aktif, negosiasi masuk. Cek repo dulu apakah ada.
3. **Buyer profile** trust bars (samakan gaya `farmer_profile_screen.dart` yang sudah pakai `_MetricBar`) — lihat `buyer_profile_screen.dart`, jangan lupa test `test/profile_screens_test.dart` mengunci label ("Total Pembelian", "Reliability (Completion Rate)", dll).
4. **Fulfillment / Confirm Delivery** (`Sprint 2 ke-3.png`): stepper kuantitas, date picker, modal "Are you sure?", success screen. Sekarang di `transaction_detail_screen.dart` (`_openFulfillSheet`) — masih sheet sederhana.
5. **Recurring order** (`Sprint 4.png`): frequency picker cards (Weekly/Bi-Weekly/Monthly radio), "Recurring order active!" confirmation, Order Configuration card. Lihat `recurring_order/screens/*`.
6. **Create listing** (`Sprint 5 ke-1.png`): area upload foto besar, toggle unit (kg/head/flat), stepper qty, validasi inline. Lihat `create_listing_screen.dart`.
7. **Search + filter sheet** (`Sprint 2 ke-5.png`): search bar, hasil cards (reuse card feed), bottom sheet Filters (category chips, price range slider, location chips), empty "No results". Lihat `search_filter_screen.dart`.
8. **Chat inbox** rebuild lebih dekat ke `Sprint inbox.png` (kartu lebih besar, "Re: <produk>", waktu relatif).
9. **Buy Now sheet** + negotiation "Complete Your Request" sheet (`Sprint 3.png`): kartu order context, stepper, offer price, estimated total.
10. **Bottom nav** → floating pill + center FAB "+" hijau sesuai desain (`lib/core/widgets/main_shell.dart`, sekarang `BottomNavigationBar` standar).

Selalu `flutter analyze` + `flutter test` setelah edit. Kalau ubah copy/label yang di-assert test, update test-nya (intent tetap). Verifikasi visual di Infinix untuk layar yang disentuh.

---

## Konteks tambahan

### File yang diubah sesi ini (UNCOMMITTED)
Baru:
- `lib/core/app_theme.dart`, `lib/core/format.dart`, `test/format_test.dart`

Diubah:
- `lib/main.dart`, `lib/core/router/app_router.dart`
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/listing/data/listing_repository.dart`
- `lib/features/listing/screens/buyer_home_feed_screen.dart`
- `lib/features/listing/screens/listing_detail_screen.dart`
- `lib/features/listing/screens/my_listings_screen.dart`
- `lib/features/transaction/screens/transaction_detail_screen.dart`
- `lib/features/negotiation/widgets/negotiation_actions.dart`
- `lib/features/negotiation/widgets/chat_bubble.dart`
- `lib/features/negotiation/screens/negotiation_chat_screen.dart`
- `lib/features/negotiation/screens/chat_inbox_screen.dart`
- `lib/features/profile/screens/farmer_profile_screen.dart`
- `test/profile_screens_test.dart`

Plus fix Sprint 10 yang juga belum commit:
- `supabase/functions/_shared/inventory-locking.ts`, `supabase/functions/buy-now/index.ts`

### Draft commit (USER yang jalankan)
```bash
git add lib/ test/ supabase/
git commit -m "feat: Sprint 11 UI polish — theme forest-green + flow buyer sesuai desain

- Theme global forest-green + krem (app_theme.dart), semua layar konsisten
- Buyer feed rebuild: rich cards + category chips + badge VERIFIED
- Listing/transaction detail, negotiation pinned card + bubble, profile trust bars
- formatRupiah helper + test; buang placeholder /farmer; fix field login
- (termasuk fix Sprint 10 race condition + EXPIRED case yang belum ter-commit)"
```

### Struktur relevan
- `lib/features/<feature>/screens|data|widgets/`
- Router: `lib/core/router/app_router.dart` (GoRouter, ShellRoute + bottom nav via `main_shell.dart`)
- Auth/role: `lib/features/auth/providers/auth_provider.dart` (role 'farmer'/'buyer' di SharedPreferences)
- Semua write ke backend lewat Supabase Edge Functions (`_client.functions.invoke`), read lewat PostgREST. FK: `negotiations/transactions/recurring_orders.buyer_id/farmer_id -> users(id)`, TIDAK ada FK langsung ke profiles → repo lakukan manual lookup (pola sudah ada, ikuti).
