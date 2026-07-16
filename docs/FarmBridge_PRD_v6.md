**PRODUCT REQUIREMENTS DOCUMENT**

**FarmBridge**

*Menjembatani Petani dan Buyer Institusional dengan Transparansi Harga dan Kepercayaan Berbasis Data*

(Detail & Objective Version) · Juli 2026

# Riwayat Versi

| **Versi** | **Tanggal** | **Perubahan Utama** |
| --- | --- | --- |
| 1.0 | Juli 2026 | PRD awal: fokus pada user flow Buyer, ERD dasar, API spec, breakdown pekerjaan tiga fitur utama. |
| 2.0 | Juli 2026 | Menambahkan User Flow Petani (Farmer) yang sebelumnya tidak ada; menambahkan Negotiation & Recurring Order State Machine untuk presisi status; memperjelas formula Trust Score dengan rolling window; menambahkan Personas, Glossary, Edge Cases, Assumptions & Risks; ERD diperbarui dengan tipe data eksplisit; breakdown pekerjaan diperluas mencakup sisi Petani. |
| 3.0 | Juli 2026 | Revisi hasil cross-check dengan Figma prototype: perjelas langkah manual buyer QC di Fulfillment (§4.1); tambah Search & Filter buyer (§3.1); jelaskan mekanisme inventory locking & endpoint filter (§9); perjelas prinsip "pihak penerima" pada Accept (§5.1); tambah edge case timeout Confirm Delivery & recurring order stok kurang (§11); nyatakan Auth/Onboarding in-scope minimal & Admin out-of-scope UI (§13.1, §14); tambah Lampiran pemetaan requirement ke screen Figma (§15). |
| 4.0 | Juli 2026 | Revisi lanjutan dari deep-dive kedua ke Figma: tambah fitur Buy Now sebagai jalur beli langsung tanpa negosiasi (§3.1, §5.1, §9, §8, §11) berdasarkan keputusan produk; ubah durasi expiry negotiation dari 48 jam menjadi 6 jam mengikuti desain Figma (§5.1, §10, §11, §15), sambil mempertahankan timeout Confirm Delivery terpisah di 48 jam; nyatakan likes/comments sebagai elemen dekoratif (out of scope, §14); nyatakan mekanisme aktivasi verified_badge (§14). |
| 5.0 | Juli 2026 | Revisi setelah cross-check ulang 42 screen Figma yang di-upload user: (1) BATALKAN sebagian revisi v4 §4.1 — fulfillment dikembalikan ke model satu-langkah (petani fulfill langsung final, buyer reject independen kapan saja) sesuai bukti desain (Transaction_Fulfilled, Tansation_detail), bukan model 2-langkah buyer-QC yang sebelumnya salah diasumsikan; hapus edge case timeout Confirm Delivery yang tidak relevan lagi. (2) Auth/Onboarding diubah total: hapus keputusan email+password v4, ganti jadi role picker tanpa login/registrasi sama sekali (landing screen → pilih role → isi nama → masuk aplikasi), teknis tetap pakai Supabase Anonymous Auth di balik layar supaya RLS tidak berubah (§3.1, §4, §7, §8, §13.1, §14). Catatan: screen role-picker ini belum ada di Figma, perlu didesain sebelum sprint 1. |
| 6.0 | Juli 2026 | Revisi final setelah verifikasi 42 screen Figma lengkap: (1) Tambah Chat inbox screen (Bagian 3.1, 4.1, 9 — endpoint baru GET /negotiations) yang sebelumnya tidak tercakup di PRD maupun JIRA meski selalu ada di bottom navigation. (2) Tambah Buyer Metrics/Buyer Profile sungguhan (Bagian 2.4 baru, 8, 9, 13) — tabel buyer_metrics baru (total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume) ditampilkan ke farmer, MEMBATALKAN keputusan v4 bahwa Trust Score sengaja satu arah. Endpoint baru GET /buyer-metrics/:buyer_id. Ini keputusan produk eksplisit dari user, bukan asumsi Claude. |

# Daftar Isi

1. Overview & Goals — 5
   1.1 Latar Belakang & Nama Produk — 5
   1.2 Problem Statement — 5
   1.3 Tujuan Produk — 5
   1.4 Metrik Sukses — 5
2. Personas & Glossary — 6
   2.1 Persona: Buyer Institusional — 6
   2.2 Persona: Petani (Farmer) — 6
   2.3 Glossary — Definisi Metrik Objektif — 6
   2.4 Buyer Metrics (revisi v6) — Definisi Formula
3. User Flow Buyer — 7
   3.1 Narasi Alur Buyer — 9
4. User Flow — Petani (Farmer) — 9
   4.1 Narasi Alur Petani — 10
5. State Machine: Negotiation & Transaction — 11
   5.1 Aturan Transisi — 11
6. State Machine: Recurring Order — 12
7. Tech Stack — 12
8. Entity Relationship Diagram (ERD) — 13
   8.1 Ringkasan Tabel — 13
9. API Spec — 14
10. Acceptance Criteria — 14
    10.1 Trust Score — 14
    10.2 Price Recommendation dalam Negosiasi — 15
    10.3 Negotiation Flow — 15
    10.4 Recurring Order — 15
    10.5 Fulfillment & Trust Metrics — 15
11. Edge Cases & Error Handling — 15
12. Non-Functional Requirements — 16
13. Assumptions, Constraints & Risks — 16
    13.1 Batasan Teknis — 17
14. Out of Scope (Non-Goals untuk MVP) — 17
15. Lampiran: Pemetaan Requirement ke Screen Figma

# 1. Overview & Goals

## 1.1 Latar Belakang & Nama Produk

FarmBridge adalah evolusi dari konsep awal "FarmBus" — marketplace B2B yang menghubungkan petani langsung dengan buyer institusional (restoran, kafe, hotel, katering) untuk memotong rantai tengkulak. Nama "FarmBridge" merepresentasikan tiga pilar yang membedakannya dari versi awal: menjembatani kepercayaan lewat data transaksi riil (bukan testimoni), menjembatani asimetri informasi harga lewat rekomendasi harga rule-based di titik keputusan, dan menjembatani hubungan jangka panjang lewat pesanan berulang.

## 1.2 Problem Statement

- Petani kehilangan margin signifikan karena bergantung pada tengkulak yang mengontrol akses ke buyer institusional.
- Buyer institusional kesulitan menilai kredibilitas petani baru — rating/testimoni konvensional tidak mencerminkan konsistensi operasional (ketepatan waktu, kesesuaian kuantitas/grade).
- Negosiasi harga terjadi manual dan tidak transparan (umumnya lewat WhatsApp), sehingga kedua pihak tidak punya acuan harga wajar saat transaksi berlangsung.
- Buyer dengan kebutuhan berulang harus bernegosiasi ulang setiap siklus, membebani kedua pihak dan membuka celah harga tidak konsisten antar siklus.
- Petani (bukan hanya buyer) tidak punya kanal terstruktur untuk mengelola listing, merespons banyak negosiasi masuk secara bersamaan, dan menjadwalkan pemenuhan recurring order — ini adalah gap yang secara eksplisit ditangani pada revisi dokumen ini.

## 1.3 Tujuan Produk

- Menghubungkan petani dan buyer institusional secara langsung, tanpa perantara.
- Menyediakan Trust Score berbasis data transaksi riil, dengan formula yang terbuka dan dapat diverifikasi kedua pihak (lihat Bagian 2.3).
- Menyisipkan rekomendasi harga rule-based langsung di dalam alur negosiasi, terlihat oleh buyer maupun petani secara simetris.
- Memungkinkan buyer & petani mengunci kesepakatan berulang (recurring order) untuk mengurangi friksi negosiasi repetitif.
- Memberi petani kanal operasional yang setara dengan buyer: mengelola listing, merespons negosiasi, menjadwalkan fulfillment, dan memantau dampaknya terhadap Trust Score miliknya sendiri.

## 1.4 Metrik Sukses

*Semua metrik di bawah didefinisikan dengan formula eksplisit pada Bagian 2.3 agar dapat diverifikasi secara objektif, bukan estimasi kualitatif.*

| **Metrik** | **Target MVP** | **Cara Ukur** |
| --- | --- | --- |
| Rata-rata margin petani per transaksi | Naik ≥ 15% dibanding estimasi harga ke tengkulak | (final_price − harga_tengkulak_referensi) / harga_tengkulak_referensi, dirata-ratakan per kategori produk |
| Waktu penyelesaian negosiasi | < 24 jam dari status OPEN ke ACCEPTED | AVG(negotiations.updated_at − negotiations.created_at) WHERE status = 'accepted' |
| Tingkat konversi ke recurring order | ≥ 20% dari transaksi fulfilled | COUNT(recurring_orders WHERE status='active') / COUNT(transactions WHERE status='fulfilled') |
| On-time delivery rate rata-rata petani | ≥ 85% (rolling 90 hari) | Lihat formula trust_metrics.on_time_delivery_rate, Bagian 2.3 |
| Adopsi sisi petani | ≥ 70% petani terdaftar membuat ≥ 1 listing dalam 14 hari pertama | COUNT(farmer_profiles dengan ≥ 1 listing) / COUNT(total farmer_profiles) |

# 2. Personas & Glossary

## 2.1 Persona: Buyer Institusional

- Peran: staf procurement/chef/pemilik restoran, kafe, hotel, atau katering.
- Tujuan utama: mendapatkan pasokan dengan harga wajar dan kepastian kualitas/jadwal, bukan sekadar harga termurah.
- Frekuensi penggunaan: tinggi untuk kebutuhan rutin (mingguan), rendah-sedang untuk kebutuhan insidental (event/lot besar).
- Kekhawatiran utama: risiko pasokan terlambat/tidak sesuai spesifikasi yang berdampak langsung pada operasional bisnis mereka. Entry point-nya sama seperti buyer (Bagian 3.1): landing screen → pilih "Saya Petani" → isi farm_name → langsung masuk Dashboard Petani, tanpa login/password.

## 2.2 Persona: Petani (Farmer)

- Peran: produsen hasil panen/ternak, mengelola satu atau lebih listing produk.
- Tujuan utama: mendapatkan harga jual yang lebih baik dibanding menjual ke tengkulak, dengan kepastian pembeli dan jadwal.
- Variasi tingkat literasi digital: dari petani yang terbiasa menggunakan smartphone untuk usaha, hingga yang baru pertama kali menggunakan aplikasi transaksi — desain UI wajib meminimalkan effort input manual (lihat catatan desain di Bagian 13).
- Kekhawatiran utama: negosiasi yang berlarut-larut, ketidakjelasan harga wajar, dan risiko reputasi (trust score) turun akibat faktor di luar kendali (mis. cuaca buruk saat pengiriman).

## 2.3 Glossary — Definisi Metrik Objektif

*Formula berikut adalah definisi final yang mengikat implementasi — bukan target aspirasional. Semua dihitung dengan rolling window 90 hari terakhir (window_days pada tabel trust_metrics) untuk menghindari skor yang membeku dari histori lama.*

**on_time_delivery_rate**

(Jumlah transaksi berstatus fulfilled dengan actual_delivery_date ≤ promised_delivery_date) ÷ (Total transaksi berstatus fulfilled) × 100%, dihitung dalam 90 hari terakhir.

**rejection_rate**

(Jumlah transaksi berstatus rejected) ÷ (Total transaksi yang pernah mencapai status pending untuk farmer tsb) × 100%, dihitung dalam 90 hari terakhir.

**fulfillment_consistency**

(Jumlah transaksi fulfilled dengan delivered_quantity = agreed_quantity, tanpa pengiriman partial) ÷ (Total transaksi fulfilled) × 100%, dihitung dalam 90 hari terakhir.

**recommended_price**

Nilai avg_price dari price_reference_data yang cocok dengan category & region listing terkait, disesuaikan dengan quantity yang diminta bila tersedia tier harga; bersifat rule-based (lookup + agregasi), bukan model machine learning.

**Trust Score (tampilan gabungan)**

Ditampilkan sebagai tiga angka terpisah (on-time delivery rate, rejection rate, fulfillment consistency) — bukan satu skor tunggal — supaya buyer bisa menilai berdasarkan dimensi yang relevan dengan kebutuhannya, dan tidak menyembunyikan trade-off di balik satu angka komposit.

## 2.4 Buyer Metrics (revisi v6) — Definisi Formula

**⚠ Perubahan keputusan v6:** Trust Score sebelumnya sengaja dibuat satu arah (lihat catatan di Bagian 13 Assumptions, sekarang direvisi). Berdasarkan konfirmasi Buyer Profile di Figma, buyer JUGA punya metrik yang dihitung sistem dan ditampilkan ke farmer — bukan hanya self-view. Empat metrik di bawah dihitung dengan rolling window 90 hari (window_days), sama seperti trust_metrics, disimpan di tabel baru buyer_metrics (FK ke buyer_profiles, lihat Bagian 8).

**total_procurement**

SUM(transactions.total_amount) untuk seluruh transaksi berstatus fulfilled milik buyer tsb, dihitung dalam 90 hari terakhir.

**active_orders_count**

COUNT(transactions.status = 'pending') + COUNT(recurring_orders.status = 'active') milik buyer tsb — dihitung real-time, bukan rolling window (beda dari 3 metrik lain di bawah).

**fulfillment_rate**

(Jumlah transaksi berstatus fulfilled) ÷ (Total transaksi yang pernah mencapai status pending untuk buyer tsb) × 100%, dihitung dalam 90 hari terakhir — analog rejection_rate farmer, tapi dari sisi konsistensi buyer menyelesaikan (bukan reject/abandon) transaksi yang dia mulai.

**avg_monthly_volume**

Rata-rata SUM(delivered_quantity) per bulan dari transaksi fulfilled milik buyer tsb, dihitung dalam 90 hari terakhir (3 bulan window).

*Catatan penamaan: label Figma "Payment Rate" sengaja TIDAK dipakai sebagai nama field/istilah — PRD ini tidak melacak pembayaran sungguhan (Bagian 14, payment gateway out of scope). fulfillment_rate mengukur konsistensi penyelesaian transaksi, bukan status bayar. Rekomendasikan label UI diubah jadi "Reliability" atau "Completion Rate" supaya tidak menyiratkan verifikasi pembayaran yang sebenarnya tidak ada.*

# 3. User Flow Buyer

Alur ini menggambarkan perjalanan buyer institusional dari menemukan listing hingga terbentuknya transaksi, termasuk titik masuk Trust Score, Price Recommendation, dan opsi Recurring Order.

*Gambar 1. User Flow Buyer*

## 3.1 Narasi Alur Buyer

- **Entry point (sebelum flow di bawah):** Buyer membuka aplikasi → landing screen menampilkan 2 pilihan role ("Saya Petani" / "Saya Pembeli") → pilih "Saya Pembeli" → isi satu field business_name → langsung masuk ke Buyer Home Feed. Tidak ada login/password (detail teknis di Bagian 13.1). Flow ini sama untuk Petani, hanya field-nya farm_name (lihat Bagian 4.1). Catatan: screen role-picker ini BELUM ada di Figma per revisi ini — perlu didesain (Alexander) sebelum masuk sprint pertama, karena ini entry point paling awal yang menentukan seluruh routing aplikasi.
- Buyer membuka feed listing (foto panen, harga per unit, lokasi petani).
- Buyer dapat mencari dan menyaring listing lewat halaman Search terpisah, dengan filter kategori produk, region/lokasi petani, dan rentang harga; hasil kosong menampilkan state "Tidak ada hasil" alih-alih layar kosong tanpa penjelasan.
- Sebelum menghubungi, buyer melihat profil petani lengkap dengan Trust Score tiga-dimensi (bukan rating bintang subjektif).
- **Jalur alternatif — Buy Now:** Sebagai alternatif dari negosiasi, buyer bisa menekan "Buy Now" di halaman detail listing untuk membeli langsung pada price_per_unit yang tertera, tanpa proses tawar-menawar. Buyer tetap mengisi kuantitas sebelum konfirmasi. Secara teknis, aksi ini membuat record negotiations dengan initial_price = current_offer_price = price_per_unit (tanpa opsi counter) yang langsung berstatus ACCEPTED oleh sistem, lalu transaction PENDING terbentuk — menggunakan state machine dan mekanisme inventory locking yang sama persis dengan jalur negosiasi (Bagian 5, 9), supaya tidak perlu skema data terpisah. Lihat detail endpoint di Bagian 9.
- Buyer memulai negosiasi lewat chat terstruktur dengan harga awal (initial_price).
- Sistem menampilkan recommended_price langsung di dalam thread chat, sebagai konteks sebelum buyer memutuskan.
- Buyer memilih salah satu aksi: Counter Offer, Decline, atau Accept (lihat state machine formal di Bagian 5).
- Jika deal terbentuk, sistem menawarkan opsi mengubah transaksi menjadi Recurring Order bila kebutuhan buyer bersifat rutin.
- **Chat inbox (revisi v6):** Tab Chat di bottom navigation membuka daftar seluruh negotiation aktif milik buyer (GET /negotiations, Bagian 9) — bukan cuma diakses lewat listing detail satu-satu. Tap salah satu item membuka NegotiationChatScreen yang sama seperti Bagian 3.1 sebelumnya.
- **Buyer Profile (revisi v6):** Buyer juga punya profil dengan buyer_metrics (Bagian 2.4): total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume. Ditampilkan ke farmer saat farmer meninjau negotiation dari buyer institusional besar, supaya farmer juga punya konteks kredibilitas sebelum accept (lihat Bagian 4.1).

# 4. User Flow — Petani (Farmer)

*Bagian ini secara eksplisit melengkapi gap pada versi PRD sebelumnya, yang hanya mendokumentasikan sisi buyer. Level detail flow petani dibuat setara dengan flow buyer.*

Alur ini menggambarkan seluruh aktivitas petani: mengelola listing, merespons negosiasi masuk, memenuhi pesanan, dan mengelola recurring order — termasuk percabangan akibat keterlambatan atau ketidaksesuaian kuantitas yang berdampak langsung ke Trust Score mereka sendiri.

*Gambar 2. User Flow Petani (Farmer)*

## 4.1 Narasi Alur Petani

### Kelola Listing

- Petani membuat/mengedit listing: foto produk, kategori, harga per unit, kuantitas tersedia.
- Listing yang dipublish langsung tampil di feed buyer tanpa proses approval manual pada MVP (lihat Bagian 14, Out of Scope, untuk moderasi konten).

### Merespons Negosiasi

- Petani menerima notifikasi setiap ada negotiation baru, dan melihat recommended_price yang identik dengan yang dilihat buyer — transparansi dua arah adalah prinsip desain, bukan opsional.
- Petani memilih Accept / Counter / Decline; setiap Counter mengembalikan bola ke pihak lain (lihat state machine, Bagian 5).
- **Buyer Profile (revisi v6):** Sebelum memutuskan, petani bisa tap nama buyer untuk lihat Buyer Profile (buyer_metrics, Bagian 2.4) — total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume — sebagai konteks kredibilitas buyer institusional, setara Trust Score yang dilihat buyer terhadap petani. Petani juga punya tab Chat inbox sendiri (GET /negotiations, Bagian 9) untuk lihat seluruh negotiation masuk sekaligus, terpisah dari daftar ringkas di Dashboard.

### Fulfillment

- Setelah accepted, petani menyiapkan pesanan sesuai promised_delivery_date yang disepakati saat negosiasi.
- Petani menandai pesanan sebagai terkirim dengan mengisi delivered_quantity dan actual_delivery_date, dikonfirmasi lewat modal "Anda yakin?" sebelum submit (aksi ini tidak bisa dibatalkan setelah tersimpan). Begitu disimpan, status transaction langsung berubah menjadi fulfilled — sistem otomatis membandingkan actual_delivery_date terhadap promised_delivery_date dan delivered_quantity terhadap agreed_quantity untuk memperbarui trust_metrics, tanpa langkah konfirmasi tambahan dari buyer. Secara independen, selama status transaction masih pending, buyer dapat menekan Reject dengan alasan (reason) kalau ada masalah — ini opsi yang tersedia kapan saja buyer mau, bukan langkah wajib setelah petani fulfill.

### Mengelola Recurring Order

- Petani menerima notifikasi H-1 sebelum next_order_date, dengan opsi konfirmasi kesiapan atau mengajukan reschedule/pause bila mis. hasil panen sedang tidak mencukupi.

# 5. State Machine: Negotiation & Transaction

Untuk menghindari ambiguitas pada deskripsi naratif "Accept/Counter/Decline", status negotiations dan transactions didefinisikan sebagai finite state machine berikut. Ini adalah spesifikasi yang mengikat untuk implementasi backend.

*Gambar 3. Negotiation & Transaction State Machine*

**⚠ Catatan revisi v4:** Gambar 3 di atas masih menampilkan angka "48 jam" pada label transisi expiry — ini nilai versi lama. Nilai yang berlaku (mengikuti keputusan tim & desain Figma) adalah **6 jam** (lihat tabel Aturan Transisi di Bagian 5.1, sudah diperbarui). Diagram gambar ini perlu digambar ulang oleh desainer sebelum dipakai sebagai referensi visual final — teks di Bagian 5.1 adalah yang mengikat untuk implementasi.

## 5.1 Aturan Transisi

*Prinsip umum: pada setiap transisi di bawah, "pihak penerima" adalah pihak yang TIDAK mengirim initial_price atau current_offer_price terakhir — mis. kalau buyer baru saja mengirim counter, maka farmer adalah pihak penerima yang berhak Accept/Decline/Counter berikutnya, bukan buyer itu sendiri. Ini mencegah satu pihak "menerima" tawarannya sendiri. Pengecualian: transaksi lewat Buy Now (Bagian 3.1) melompat langsung dari tidak-ada-record ke ACCEPTED secara sistem, tanpa melalui OPEN — karena tidak ada tawar-menawar yang perlu direspons pihak lain.*

| **Dari** | **Ke** | **Pemicu** | **Catatan** |
| --- | --- | --- | --- |
| OPEN | ACCEPTED | Pihak penerima (bukan pengirim initial_price/current_offer_price terakhir) menekan Accept | Memicu pembuatan transactions dengan status PENDING |
| OPEN | DECLINED | Buyer atau Farmer menekan Decline | Negosiasi ditutup permanen, tidak bisa dibuka ulang |
| OPEN | COUNTERED | Buyer atau Farmer mengirim harga baru | current_offer_price diperbarui, counter_count += 1 |
| COUNTERED | ACCEPTED / DECLINED / COUNTERED | Pihak yang menerima counter merespons | Tidak ada batas jumlah counter pada MVP, namun expires_at tetap berlaku (lihat baris berikut) |
| OPEN / COUNTERED | EXPIRED | 6 jam tanpa respons dari pihak yang dituju | Job terjadwal menutup otomatis; listing kembali berstatus tersedia untuk negosiasi baru |
| ACCEPTED → transactions.PENDING | transactions.FULFILLED | Farmer menandai terkirim DAN sistem memverifikasi delivered_quantity terisi | Memicu update trust_metrics |
| transactions.PENDING | transactions.REJECTED | Buyer menolak saat QC (kualitas/kuantitas tidak sesuai) | Memicu update rejection_rate farmer terkait |

# 6. State Machine: Recurring Order

*Gambar 4. Recurring Order State Machine*

Recurring order tidak pernah kembali ke status CREATED setelah aktif; siklus fulfillment berikutnya direpresentasikan sebagai transaction baru yang tertaut ke recurring_order_id yang sama, bukan sebagai entitas terpisah, untuk menjaga riwayat tetap dapat ditelusuri.

# 7. Tech Stack

Melanjutkan stack yang sudah digunakan pada FarmBus untuk menjaga kontinuitas development dan kecepatan iterasi.

| **Layer** | **Pilihan** | **Alasan** |
| --- | --- | --- |
| Frontend | Flutter (single codebase, role-based navigation) | Satu codebase untuk role farmer & buyer menghemat waktu build; role-based nav menghindari maintenance dua app terpisah. |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions) | Mengurangi effort setup infrastruktur; Edge Functions (Deno) menjalankan logic rule-based price recommendation & scheduled job recurring order tanpa server terpisah. |
| Realtime | Supabase Realtime | Dibutuhkan untuk sinkronisasi chat negosiasi & notifikasi recurring order secara live tanpa polling. |
| Database | PostgreSQL (dikelola Supabase) | Relational fit untuk data transaksional dengan banyak relasi antar entitas (lihat ERD, Bagian 8). |
| Scheduled Jobs | Supabase Cron (pg_cron) memicu Edge Function | Dibutuhkan untuk auto-expire negotiations (6 jam) dan trigger siklus recurring order (H-1 next_order_date). |
| Notifikasi | Supabase Realtime + Firebase Cloud Messaging (push) | Push notification untuk reminder recurring order & update negosiasi saat app di-background. |
| Auth | Supabase Anonymous Auth (role-based) | Role farmer/buyer/admin dikontrol lewat Row Level Security policy per tabel. Sesi dibuat via auth.signInAnonymously() saat role dipilih di landing screen (Bagian 13.1) — tanpa email/password, tapi auth.uid() tetap ada untuk RLS. |

# 8. Entity Relationship Diagram (ERD)

Skema berikut memperjelas tipe data setiap kolom secara eksplisit (dibanding versi 1.0 yang hanya mencantumkan nama kolom) untuk mengurangi ambiguitas saat implementasi database.

*Gambar 5. Entity Relationship Diagram (dengan tipe data)*

**⚠ Catatan revisi v4 — Buy Now:** fitur Buy Now (Bagian 3.1, 9) TIDAK menambah tabel/kolom baru pada ERD ini. Aksi Buy Now membuat satu record negotiations (status ACCEPTED, counter_count=0, tanpa entry negotiation_messages dari buyer) dan satu record transactions seperti biasa — dapat dibedakan dari negosiasi manual lewat query: negotiations yang statusnya langsung ACCEPTED tanpa negotiation_messages sebelumnya. Kalau nanti butuh analitik terpisah (mis. rasio Buy Now vs negosiasi), pertimbangkan kolom opsional negotiations.origin (enum: negotiated/buy_now) — sengaja tidak ditambahkan sekarang supaya migrasi skema tetap minimal untuk MVP.

**⚠ Catatan revisi v5 — users.email:** karena tidak ada lagi form signup/login (Bagian 13.1), kolom users.email pada Gambar 5 (bertanda unique) menjadi NULLABLE, bukan wajib diisi — identitas user cukup dari auth.uid() (anonymous) + name (farm_name/business_name). Kolom email tetap dipertahankan di skema untuk kemungkinan pemakaian masa depan, hanya tidak divalidasi wajib di MVP ini.

**⚠ Catatan revisi v6 — tabel baru buyer_metrics:** TIDAK tergambar di Gambar 5 (ERD dibuat sebelum keputusan ini) — perlu ditambahkan sebelum sprint 1. Struktur: id (PK uuid), buyer_id (FK → buyer_profiles, uuid), total_procurement (numeric 14,2), active_orders_count (int), fulfillment_rate (numeric 5,2), avg_monthly_volume (numeric 12,2), window_days (int default 90), updated_at (timestamptz). Formula tiap kolom di Bagian 2.4. Trigger update: sama seperti trust_metrics — dipicu Edge Function setelah transaction berubah fulfilled/rejected (Bagian 9), bukan input langsung dari client.

## 8.1 Ringkasan Tabel

| **Tabel** | **Fungsi** | **Relasi Kunci** |
| --- | --- | --- |
| users | Akun dasar semua peran | 1-1 ke farmer_profiles / buyer_profiles |
| farmer_profiles | Data & trust_score petani | 1-N ke listings, negotiations, recurring_orders; 1-1 ke trust_metrics |
| buyer_profiles | Data buyer institusional | 1-N ke negotiations, recurring_orders |
| listings | Produk yang dijual petani | 1-N ke negotiations, recurring_orders |
| price_reference_data | Basis perhitungan recommended_price | Direferensikan Edge Function price-recommendation |
| negotiations | Status & harga tawar-menawar | 1-N ke negotiation_messages; 1-1 ke transactions |
| negotiation_messages | Log percakapan & aksi negosiasi | N-1 ke negotiations |
| transactions | Realisasi transaksi & fulfillment | N-1 ke negotiations; sumber utama trust_metrics |
| recurring_orders | Kesepakatan berulang | N-1 ke buyer_profiles, farmer_profiles, listings |
| trust_metrics | Skor operasional petani (rolling 90 hari) | 1-1 ke farmer_profiles |

# 9. API Spec

Endpoint standar (CRUD dasar profil & listing) di-generate otomatis lewat Supabase PostgREST. Pencarian dan filter listing (kategori, region, rentang harga) dilakukan lewat query parameter PostgREST standar pada GET /listings (mis. category=eq.sayuran&price_per_unit=gte.10000&price_per_unit=lte.50000), bukan Edge Function terpisah, karena tidak ada logic tambahan di luar filtering kolom. Berikut endpoint custom sebagai Supabase Edge Functions, termasuk kode status error untuk presisi implementasi:

| **Method & Path** | **Request Body** | **Response 200** | **Error Response** |
| --- | --- | --- | --- |
| POST /negotiations | { listing_id, buyer_id, initial_price, quantity } | { negotiation_id, recommended_price, status:'open', expires_at } | 400 jika initial_price ≤ 0 atau quantity > listings.quantity_available |
| POST /negotiations/:id/messages | { sender_id, message_text?, offer_price?, action_type } | { message_id, negotiation_status } | 409 jika negotiation sudah berstatus accepted/declined/expired |
| GET /negotiations/:id | - | { negotiation detail + messages[] } | 403 jika requester bukan peserta negosiasi |
| POST /price-recommendation | { category, region, quantity } | { recommended_price, avg_price, min_price, max_price } | 200 dengan fallback message jika data referensi kosong (bukan error, lihat Bagian 11) |
| POST /recurring-orders | { buyer_id, farmer_id, listing_id, quantity, frequency, locked_price } | { recurring_order_id, next_order_date } | 400 jika listing_id sudah tidak berstatus active |
| PATCH /recurring-orders/:id | { status: 'paused'\|'cancelled'\|'active' } | { recurring_order_id, status } | 409 jika transisi status tidak valid (mis. cancelled → active) |
| GET /trust-metrics/:farmer_id | - | { on_time_delivery_rate, rejection_rate, fulfillment_consistency, total_transactions, window_days } | 404 jika farmer_id tidak ditemukan |
| POST /transactions/:id/fulfill | { delivered_quantity, actual_delivery_date } | { transaction_id, status, trust_metrics_updated:true } | 403 jika requester bukan farmer pemilik transaksi |
| POST /transactions/:id/reject | { reason } | { transaction_id, status:'rejected' } | 403 jika requester bukan buyer terkait; hanya bisa dilakukan saat status pending |
| POST /listings/:id/buy-now | { quantity, note? } | { negotiation_id, transaction_id, status:'pending', total_amount } | 400 jika quantity > listings.quantity_available atau listing.status != active; 404 jika listing tidak ditemukan; membuat negotiation ber-status ACCEPTED otomatis (initial_price=current_offer_price=price_per_unit) sebelum transaction dibuat |
| GET /buyer-metrics/:buyer_id | — (tanpa body) | { total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume, window_days } | 404 jika buyer_profiles tidak ditemukan; field bernilai 0/null bila buyer belum punya transaksi (bukan error) |
| GET /negotiations | query param opsional: status (mis. open,countered,accepted) | Array negotiation milik requester (buyer_id atau farmer_id = auth.uid()), terurut updated_at desc, untuk Chat inbox screen (Bagian 3.1/4.1) | Difilter otomatis via RLS — requester hanya lihat negotiation miliknya sendiri, tidak perlu parameter user_id manual |

**Mekanisme inventory locking:** listings.quantity_available TIDAK berkurang saat negotiation dibuat atau di-counter — baru berkurang saat negotiation berpindah ke ACCEPTED dan transactions.PENDING terbentuk (di dalam transaksi database yang sama, atomik). Jika transaction kemudian REJECTED, quantity_available dikembalikan (rollback) ke listing. Ini yang membuat validasi "quantity > listings.quantity_available" pada POST /negotiations (Bagian 9) tetap bisa gagal untuk dua negosiasi paralel pada listing yang sama — sesuai perilaku first-accepted-wins pada Bagian 11.

# 10. Acceptance Criteria

## 10.1 Trust Score

- Given buyer membuka profil petani, When halaman profil dimuat, Then sistem menampilkan on_time_delivery_rate, rejection_rate, fulfillment_consistency, dan total_transactions yang dihitung dari data transaksi 90 hari terakhir.
- Given seorang petani baru belum memiliki transaksi, When profil dibuka, Then sistem menampilkan state "Belum ada riwayat transaksi", bukan angka 0% yang menyesatkan (0% dapat disalahartikan sebagai skor buruk, bukan tidak ada data).

## 10.2 Price Recommendation dalam Negosiasi

- Given buyer mengirim initial_price pada negotiation baru, When negotiation dibuat, Then sistem menampilkan recommended_price di dalam thread chat sebelum pihak lain merespons.
- Given tidak ada price_reference_data untuk kategori/region terkait, When rekomendasi dihitung, Then sistem menampilkan pesan fallback "Data referensi belum tersedia untuk kategori ini" tanpa memblokir negosiasi berlanjut.

## 10.3 Negotiation Flow

- Given negotiation berstatus OPEN, When salah satu pihak mengirim counter offer, Then status berubah menjadi COUNTERED dan counter_count bertambah 1, sesuai state machine Bagian 5.
- Given negotiation berstatus OPEN atau COUNTERED tanpa respons selama 6 jam, When scheduled job berjalan, Then status otomatis berubah menjadi EXPIRED dan kedua pihak menerima notifikasi.

## 10.4 Recurring Order

- Given sebuah transaction berstatus fulfilled, When buyer memilih "Jadikan Recurring Order", Then sistem membuat record recurring_orders dengan locked_price dan next_order_date terhitung otomatis dari frequency.
- Given next_order_date sudah tercapai (H-1), When scheduled job berjalan, Then sistem mengirim notifikasi ke buyer & petani dan membuat transaction baru berstatus pending dengan locked_price yang sama.

## 10.5 Fulfillment & Trust Metrics

- Given transaction berstatus pending, When petani menandai delivered_quantity dan actual_delivery_date, Then sistem otomatis mengevaluasi ketepatan waktu & kesesuaian kuantitas dan memperbarui trust_metrics tanpa input manual tambahan.
- Given buyer menolak transaction saat QC, When status berubah menjadi rejected, Then rejection_rate farmer terkait diperbarui pada perhitungan berikutnya (rolling 90 hari).

# 11. Edge Cases & Error Handling

*Bagian ini eksplisit dibuat untuk mendukung permintaan spesifikasi "seobjective mungkin" — setiap kondisi ambigu didefinisikan perilaku sistemnya, bukan diserahkan ke asumsi implementasi.*

| **Kondisi** | **Perilaku Sistem yang Diharapkan** |
| --- | --- |
| Buyer mengirim counter offer dengan harga lebih tinggi dari initial_price milik buyer sendiri | Diizinkan (tidak ada validasi arah harga); sistem hanya memvalidasi harga > 0. |
| Listing kehabisan stok saat negotiation masih berjalan (quantity_available berubah karena transaksi lain) | Sistem menampilkan peringatan di thread chat "Stok tersedia berubah menjadi X", tidak otomatis membatalkan negotiation; keputusan lanjut/batal diserahkan ke kedua pihak. |
| Petani tidak merespons negotiation sama sekali dalam 6 jam | Status otomatis EXPIRED (lihat state machine Bagian 5); tidak memengaruhi trust_metrics karena tidak ada transaksi yang gagal dipenuhi. |
| Petani mengirim delivered_quantity lebih besar dari agreed_quantity | Sistem mencatat sebagai fulfilled namun menandai anomaly_flag = true untuk ditinjau admin; tidak otomatis dianggap pelanggaran fulfillment_consistency. |
| Dua buyer berbeda mengirim negotiation (termasuk lewat Buy Now) untuk listing dan quantity yang sama secara bersamaan (race condition stok) | Sistem memproses berbasis first-accepted-wins; negotiation kedua yang di-accept setelah stok habis akan gagal dengan pesan error 409 dan disarankan menghubungi petani untuk quantity tersisa. |
| price_reference_data belum pernah diisi untuk kategori produk baru | Endpoint price-recommendation mengembalikan response 200 dengan recommended_price: null dan pesan fallback, bukan error 404/500. |
| Buyer membatalkan recurring order di tengah siklus yang sudah masuk status pending (transaksi sudah terbentuk) | Transaksi yang sudah PENDING tetap berjalan sampai selesai; hanya siklus berikutnya yang dihentikan setelah status recurring_orders menjadi cancelled. |
| Farmer menghapus/mengarsipkan listing yang sedang terikat recurring_orders aktif | Sistem mencegah archive langsung; farmer diarahkan untuk pause/cancel seluruh recurring_orders terkait terlebih dahulu. |
| next_order_date recurring order tercapai (H-1), tapi farmer tidak konfirmasi kesiapan atau kuantitas listing tidak mencukupi | Siklus tersebut di-skip (transaction baru TIDAK dibuat untuk siklus ini); recurring_orders TETAP berstatus active untuk next_order_date berikutnya, tidak otomatis pause/cancel. Buyer & farmer menerima notifikasi bahwa siklus kali ini dilewati. |

# 12. Non-Functional Requirements

- Performance: pesan pada negotiation chat harus tersinkron ke seluruh peserta dalam < 2 detik menggunakan Supabase Realtime; endpoint POST /price-recommendation harus merespons < 500ms pada kondisi data tersedia.
- Security: setiap tabel menerapkan Row Level Security — buyer/petani hanya bisa mengakses negotiations & transactions di mana mereka menjadi peserta; service_role key tidak pernah diekspos ke client.
- Scalability: perhitungan price recommendation dan update trust_metrics dijalankan sebagai Edge Function stateless agar dapat di-scale horizontal saat volume negosiasi meningkat.
- Auditability: seluruh perubahan status negotiation (accept/decline/counter) tercatat di negotiation_messages sebagai log yang tidak bisa diedit/dihapus, termasuk oleh admin.
- Data Integrity: update trust_metrics hanya boleh dipicu oleh perubahan status transactions lewat Edge Function terkontrol, bukan input langsung dari user, untuk mencegah manipulasi skor.
- Observability: setiap eksekusi scheduled job (expire negotiation, trigger recurring cycle) mencatat log terpisah yang dapat ditinjau untuk debugging kegagalan job.
- Accessibility: UI Flutter mengikuti kontras warna minimum WCAG AA mengingat sebagian pengguna petani mengakses lewat perangkat dengan layar kecil di kondisi pencahayaan luar ruangan.

# 13. Assumptions, Constraints & Risks

*Disusun mengikuti kategori assumption-testing: user, problem, solution, business, feasibility, dan adoption — setiap asumsi diberi tingkat keyakinan dan mitigasi, bukan dianggap otomatis benar.*

| **Kategori** | **Asumsi** | **Tingkat Keyakinan** | **Mitigasi / Cara Validasi** |
| --- | --- | --- | --- |
| User | Buyer institusional bersedia menegosiasikan harga lewat chat in-app, bukan telepon/WhatsApp langsung | Sedang | Uji dengan 5–10 buyer pilot sebelum scale up; sediakan tombol "Hubungi via telepon" sebagai fallback di MVP |
| User | Petani dapat mengunggah foto listing dan mengoperasikan flow negosiasi tanpa pelatihan intensif | Rendah–Sedang | Sediakan onboarding tutorial singkat & UI dengan effort input minimal (lihat Bagian 4) |
| Problem | Ketidakpastian harga adalah hambatan utama, bukan hanya soal akses ke buyer | Sedang | Validasi lewat wawancara petani & buyer sebelum menambah kompleksitas fitur lanjutan |
| Solution | Trust score berbasis data transaksi lebih dipercaya buyer dibanding rating konvensional | Sedang | A/B test tampilan profil dengan & tanpa trust score pada cohort awal, ukur dampak ke conversion rate negotiation → accepted |
| Solution | DIBATALKAN per v6 (lihat Bagian 2.4): awalnya Trust Score dibuat satu arah, tapi setelah konfirmasi Buyer Profile di Figma menampilkan metrik buyer sungguhan ke farmer, keputusan ini direvisi — buyer_metrics ditambahkan dengan cakupan setara trust_metrics | Sedang | Revisit di v3 kalau ada keluhan farmer soal buyer yang sering batal/reneging tanpa akuntabilitas — pertimbangkan metrik ringan seperti buyer_cancellation_rate |
| Product | Buy Now (beli langsung tanpa negosiasi) dan timeout negotiation 6 jam adalah keputusan produk final per v4, mengikuti desain Figma — bukan lagi open question | Tinggi | Tidak perlu divalidasi lebih lanjut — cukup pastikan tim engineering sudah baca revisi §3.1, §5.1, §9 sebelum sprint fulfillment dimulai |
| Business | Volume transaksi berulang cukup untuk membuat recurring order bernilai (bukan fitur yang jarang dipakai) | Rendah–Sedang | Ukur % transaksi non-recurring yang berasal dari buyer sama & listing sama dalam 30 hari sebelum investasi penuh ke fitur ini |
| Feasibility | Rule-based price recommendation cukup akurat tanpa machine learning untuk MVP | Tinggi | Sudah menjadi keputusan tim untuk menjaga kredibilitas saat presentasi; revisit setelah data price_reference_data cukup besar |
| Adoption | Petani akan memperbarui status fulfillment tepat waktu tanpa insentif tambahan | Rendah | Pertimbangkan reminder otomatis H-0 pengiriman & dampak visibilitas trust_score sebagai insentif non-finansial |

## 13.1 Batasan Teknis

- MVP dibangun dalam kerangka waktu hackathon (30 jam) — sejumlah fitur yang disebut pada Bagian 14 sengaja tidak masuk scope awal.
- Tidak ada sistem pembayaran terintegrasi pada MVP; transaksi finansial diasumsikan terjadi di luar aplikasi (offline/transfer manual).
- Tidak ada sistem logistik/pengiriman terintegrasi; status pengiriman diinput manual oleh petani.
- Auth/Onboarding TANPA login dan registrasi tradisional (keputusan final untuk konteks lomba) — landing screen langsung menampilkan pilihan role "Saya Petani" / "Saya Pembeli", diikuti satu field nama (farm_name untuk petani, business_name untuk buyer) agar peserta lain/juri bisa membedakan akun satu sama lain saat demo multi-device. Tidak ada email, password, verifikasi, atau layar lupa password sama sekali. Secara teknis, tetap memakai Supabase Anonymous Auth (auth.signInAnonymously()) di baliknya begitu role dipilih — supaya auth.uid() tetap ada dan seluruh RLS policy yang sudah dirancang (Bagian 12, FR-Auth) tetap berfungsi tanpa perubahan, meski dari sisi pengguna terasa seperti "langsung masuk tanpa login". Pilihan role & nama disimpan lokal di device (mirip pola Wishlist) supaya sesi tidak hilang saat aplikasi ditutup-buka ulang.
- Admin role OUT-OF-SCOPE untuk UI aplikasi pada MVP: peninjauan anomaly_flag (Bagian 11) dan operasi admin lain dilakukan langsung lewat Supabase Studio oleh tim internal, bukan lewat layar admin di aplikasi Flutter. Role admin di RLS (Bagian 7, 12) tetap dipertahankan untuk membatasi akses data, meski tanpa UI khusus.

# 14. Out of Scope (Non-Goals untuk MVP)

- Payment gateway & escrow otomatis — transaksi finansial dilakukan di luar sistem.
- Sistem logistik/pelacakan pengiriman real-time — status delivery diinput manual.
- Moderasi konten listing otomatis (deteksi foto tidak sesuai, harga tidak wajar) — pada MVP listing tayang langsung tanpa approval.
- Rekomendasi harga berbasis machine learning — sengaja menggunakan pendekatan rule-based untuk menjaga transparansi dan kredibilitas.
- Multi-bahasa/lokalisasi di luar Bahasa Indonesia.
- Dispute resolution formal antara buyer & petani (mediasi admin) — pada MVP, rejected transaction hanya tercatat tanpa alur mediasi terstruktur.
- UI/panel admin di aplikasi — operasi admin (mis. peninjauan anomaly_flag) dilakukan langsung lewat Supabase Studio pada MVP, bukan lewat layar khusus di Flutter (lihat Bagian 13.1).
- Login/registrasi tradisional dalam bentuk apa pun (email/password, OTP, social login), termasuk flow lupa password dan verifikasi akun — MVP memakai role picker + nama tanpa kredensial sama sekali (lihat Bagian 13.1). Kalau nanti dilanjutkan di luar lomba, ini area pertama yang perlu ditambahkan sebelum rilis publik.
- Likes & comments count pada listing card (terlihat di prototipe Figma) — diputuskan sebagai elemen dekoratif mockup, bukan fitur yang dibangun untuk MVP; tidak ada tabel likes/comments di ERD (Bagian 8).
- Verifikasi dokumen/identitas farmer secara otomatis — farmer_profiles.verified_badge untuk MVP diaktifkan manual oleh tim internal lewat Supabase Studio (konsisten dengan keputusan admin di Bagian 13.1) setelah farmer melengkapi profil (foto, deskripsi, lokasi), bukan lewat proses verifikasi dokumen otomatis.

# 15. Lampiran: Pemetaan Requirement ke Screen Figma

*Ditambahkan setelah cross-check terhadap Figma file "BUZZER-Prototype" (fileKey b5Vmzd1KVKfodLMUnZGJ0K) — supaya breakdown tiket JIRA bisa langsung reference nama frame yang tepat, bukan cuma deskripsi tekstual. Sebagian frame ditandai (*) karena belum diverifikasi visual saat penyusunan lampiran ini; verifikasi ulang sebelum build.*

| **Requirement PRD** | **Screen/Frame Figma** |
| --- | --- |
| AC 10.1 — state "Belum ada riwayat transaksi" untuk petani baru | Farmer Public Profile (New Farmer) [90:927]; no transaction [129:779] |
| §11 Edge Case — Listing kehabisan stok saat negotiation berjalan | sold out [186:736] |
| §5 State Machine — negotiation EXPIRED (6 jam tanpa respons) | nego EXPIRED [155:2854] |
| §5 State Machine — negotiation ACCEPTED | nego ACCEPT [155:2244] |
| §5 State Machine — negotiation DECLINED | nego DECLINED (*belum diverifikasi visual) |
| §5 State Machine — negotiation COUNTERED | nego counter (*belum diverifikasi visual) |
| §4.1 — Petani input delivered_quantity/actual_delivery_date + modal konfirmasi "Anda yakin?" | confirm delivery [135:1746] |
| §10.5 AC — Petani input delivered_quantity & actual_delivery_date | Fulfillment Form [161:1155] |
| §3.1 (revisi) — Search & filter buyer, state hasil kosong | Buyer Search Page [90:252]; filter [147:2]; no results found (*belum diverifikasi visual) |
| Feed buyer kosong (belum ada listing di kategori tsb) | no listing (*belum diverifikasi visual) |
| §6 State Machine — Recurring Order ACTIVE/PAUSED/CANCELLED | My Recurring Orders [217:347]; Recurring Order Detail - Active/Paused, Pause/Cancel/Resume Confirmation (*belum diverifikasi visual) |
| §4.1 — Petani membuat/mengedit listing | Create / Edit Listing (Glassmorphic) [90:1175]; 3 varian Create Listing di Sprint 6 (*konfirmasi mana final) |
| §2.3 / AC 10.1 — Trust Score tiga-dimensi | trust score [129:525] |
| Form listing — validasi error input | form eror (*belum diverifikasi visual) |
| §3.1 — Buyer lihat profil petani dengan Trust Score | Buyer Public Profile [90:115]; Farmer Public Profile (Updated) [90:625] |
| §4.1 — Dashboard ringkasan farmer (listing aktif, negosiasi menunggu, recurring order) | Farmer Dashboard (Updated) [90:779] |
| §3.1 — Negosiasi chat + recommended_price | Negotiation / Chat Screen [90:405]; nego chat (*belum diverifikasi visual) |
| §2.4/§3.1/§4.1 (v6) — Buyer Profile dengan buyer_metrics sungguhan | Buyer Public Profile [90:115] — field UI sudah ada, backend BARU ditambahkan v6 |
| §3.1/§4.1 (v6) — Chat inbox (daftar semua negotiation aktif) | BELUM ada frame Figma — cuma ikon Chat di bottom nav semua screen, perlu didesain Alexander sebelum sprint 1 |
| §3.1/§9 (revisi v4) — Buy Now: beli langsung tanpa negosiasi | Deskripsi Produk [186:455]; order aktif [199:661]; tombol "Buy Now" di semua halaman detail listing |
| §9 — Modal buat initial_price/negosiasi ("Contact") | form [195:2] ("Complete Your Request", state kosong); form eror [196:304] (state validasi gagal) |
| §11 Edge Case (baru) — price_reference_data kosong untuk kategori/region | chat2 [133:1542] ("Price reference data not available") |
