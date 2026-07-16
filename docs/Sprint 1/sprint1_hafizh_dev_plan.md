# Sprint 1 (Hafizh) — FG-5 CI/CD + FG-6 FCM Implementation Plan

> **Catatan eksekusi:** Sebagian besar task di plan ini adalah aksi manual (Firebase Console, GitHub Secrets, `git push`) yang harus dijalankan langsung oleh Hafizh di terminal/browser — **bukan oleh Claude**, sesuai `CLAUDE.md` project ini (Claude tidak menjalankan operasi git yang mengubah state repo di project ini). Claude bisa membantu menulis/mengedit file kode (workflow YAML, Edge Function, Dart service) tapi commit/push/merge tetap dijalankan Hafizh sendiri.
>
> Kalau ingin Claude mengeksekusi bagian non-git dari plan ini task-by-task (menulis file, bukan git), gunakan superpowers:executing-plans secara inline di sesi ini.

**Goal:** Selesaikan FG-5 (CI/CD Pipeline) dan FG-6 (FCM Push Notification setup) Sprint 1, sampai siap ditarik ke `main` sebagai integration branch owner.

**Arsitektur:** CI/CD lewat GitHub Actions yang men-deploy migration + seluruh Edge Function di `supabase/functions/*` secara generik (tanpa hardcode nama function, supaya tidak perlu diedit lagi saat Nevan/Hafizh menambah function di sprint berikutnya). FCM diwujudkan sebagai satu shared function `sendPush()` (`supabase/functions/_shared/fcm.ts`) yang dipakai baik oleh endpoint HTTP `send-push` (untuk test manual) maupun diimport langsung oleh Edge Function lain mulai Sprint 6/8 — menghindari duplikasi logic FCM per use-case sesuai larangan eksplisit di task checklist FG-6.

**Tech Stack:** GitHub Actions, Supabase CLI, Supabase Edge Functions (Deno), Firebase Cloud Messaging HTTP v1 API via `google-auth-library` (npm, dipakai lewat `npm:` specifier Deno), FlutterFire CLI, `firebase_core` + `firebase_messaging` (Flutter).

## Global Constraints

- Kerja langsung di branch `hafizh_dev` (Playbook §1) — tidak ada branch pribadi terpisah untuk Hafizh.
- Format commit: `[FG-XX] deskripsi singkat` (Playbook §2 Aturan Dasar #4).
- Migration SQL (`supabase/migrations/*.sql`) **tidak pernah** ditulis Hafizh — itu murni domain Nevan (Playbook §2 #5).
- Kolom `device_token` harus disepakati dengan Nevan **sebelum** dia commit migration FG-2 (sprint1_hafizh_dev.md, sprint1_nevan_dev.md).
- Jangan hardcode secret apapun di kode/YAML — semua lewat GitHub Secrets atau Supabase Edge Function secrets (FG-5 checklist).
- Error dari `send-push` (token invalid/expired) **tidak boleh** membuat Edge Function crash (FG-6 checklist).
- CI job yang gagal (token salah/expired) harus gagal dengan pesan jelas, bukan silent fail (FG-5 checklist).
- Project Supabase **sudah ada dan aktif**: nama `FarmBridge`, ref `rwxnjxmzkcfoddnzjosi`, region `ap-southeast-1` (dikonfirmasi lewat `supabase projects list`, status `ACTIVE_HEALTHY`). Pakai ref ini langsung, tidak perlu membuat project baru.
- Repo GitHub: `Hafizhputra27/FarmBridge` (dikonfirmasi lewat `gh repo view`, `gh` sudah login dengan scope `repo`+`workflow`).

---

### Task 1: Sepakati skema `device_token` dengan Nevan (prasyarat, blocking)

**Files:** tidak ada file kode — ini keputusan yang harus disepakati sebelum Task-task lain yang menyentuh `users.device_token` (Task 9) dan sebelum Nevan menulis `supabase/migrations/*.sql` (FG-2).

**Interfaces:**
- Produces: keputusan final lokasi kolom `device_token`, dipakai oleh Task 9 (plan ini) dan oleh migration FG-2 (Nevan).

- [ ] **Step 1: Ajukan proposal ke Nevan**

Proposal (sesuai rekomendasi di `sprint1_README.md` baris 19 dan `sprint1_nevan_dev.md` baris 11): kolom nullable langsung di tabel `users`, bukan tabel terpisah.

```sql
-- bagian dari users table (ditulis Nevan di FG-2, BUKAN oleh Hafizh):
device_token text null
```

Alasan: satu user = satu device token aktif cukup untuk kebutuhan MVP (push reminder recurring order + update negosiasi), tabel terpisah (mis. `device_tokens` many-to-many) tidak dibutuhkan untuk 30 jam hackathon — YAGNI.

- [ ] **Step 2: Konfirmasi tertulis**

Begitu Nevan setuju, catat keputusannya di bagian **Decisions Log** di akhir file ini (Task 12) sebelum dia commit migration. Kalau Nevan minta bentuk lain (mis. tabel terpisah), update Task 9 di plan ini menyesuaikan sebelum dieksekusi.

---

### Task 2: Inisialisasi & link project Supabase

**Files:**
- Create: `supabase/config.toml` (hasil `supabase init`)
- Modify: `.gitignore` (root)

**Interfaces:**
- Produces: struktur folder `supabase/` yang jadi tempat Task 3 (CI workflow menunjuk ke sini), Task 8 (Edge Functions), dan folder `supabase/migrations/` milik Nevan nantinya.

- [ ] **Step 1: Inisialisasi struktur project Supabase**

```bash
cd /Users/haimac/AndroidStudioProjects/FarmBridge
supabase init
```

Expected: folder baru `supabase/` berisi `config.toml`, `.gitignore`, `functions/`, `seed.sql` kosong. Tidak ada folder `migrations/` — itu baru dibuat Nevan saat FG-2.

- [ ] **Step 2: Link ke project Supabase yang sudah ada**

```bash
supabase link --project-ref rwxnjxmzkcfoddnzjosi
```

Akan diminta memasukkan database password project (password yang diset saat project `FarmBridge` dibuat di dashboard). Kalau lupa, reset lewat Supabase Dashboard → Project Settings → Database → Reset Database Password.

Expected output: `Finished supabase link.` tanpa error.

- [ ] **Step 3: Tambahkan pengecualian secret ke `.gitignore` root**

Root `.gitignore` saat ini tidak punya entry untuk file kredensial. Tambahkan di akhir file:

```gitignore

# Firebase service account (secret — FG-6, jangan pernah commit)
**/serviceAccountKey.json
**/*firebase-adminsdk*.json

# Supabase local secrets
supabase/.env
```

- [ ] **Step 4: Commit (dijalankan Hafizh sendiri, bukan Claude)**

```bash
git add supabase/config.toml supabase/.gitignore supabase/seed.sql supabase/functions .gitignore
git commit -m "[FG-5] init supabase project scaffold + link ke project FarmBridge"
```

---

### Task 3: FG-5 — Tulis GitHub Actions CI/CD workflow

**Files:**
- Create: `.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: `supabase/functions/*` (dinamis, tidak hardcode nama — otomatis mencakup `send-push` dari Task 8 dan function apapun yang ditambah Nevan/Hafizh di sprint berikutnya).
- Produces: pipeline yang jadi syarat Definition of Done FG-5 ("push ke `main` → Edge Function ter-deploy otomatis").

- [ ] **Step 1: Tulis workflow file**

```yaml
name: Deploy Supabase

on:
  push:
    branches: [main]
  workflow_dispatch: {}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link Supabase project
        run: supabase link --project-ref "$SUPABASE_PROJECT_REF"
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}

      - name: Push database migrations
        run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}

      - name: Deploy Edge Functions
        run: |
          shopt -s nullglob
          for dir in supabase/functions/*/; do
            fn="$(basename "$dir")"
            if [ "$fn" = "_shared" ]; then
              continue
            fi
            echo "Deploying function: $fn"
            supabase functions deploy "$fn" --project-ref "$SUPABASE_PROJECT_REF"
          done
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}
```

Catatan desain (kenapa tidak perlu custom error handling tambahan): GitHub Actions menjalankan tiap `run:` step dengan `bash -eo pipefail` secara default — begitu satu perintah `supabase ...` exit non-zero, step langsung gagal dan step berikutnya tidak jalan, job jadi merah dengan log asli dari Supabase CLI. Ini sudah memenuhi checklist "job harus gagal dengan pesan jelas, jangan silent fail" tanpa script tambahan.

`_shared/` sengaja di-skip dari loop deploy karena itu folder shared module (dipakai Task 8, dan nanti `_shared/price-recommendation.ts` FG-23 Sprint 4) — bukan function yang bisa langsung di-deploy sendiri.

- [ ] **Step 2: Commit (dijalankan Hafizh sendiri)**

```bash
git add .github/workflows/deploy.yml
git commit -m "[FG-5] tambah CI/CD workflow deploy migration + edge functions"
```

---

### Task 4: FG-5 — Konfigurasi GitHub Secrets

**Files:** tidak ada file di repo — ini konfigurasi di sisi GitHub.

**Interfaces:**
- Consumes: `SUPABASE_PROJECT_REF` = `rwxnjxmzkcfoddnzjosi` (sudah diketahui dari Task 2).
- Produces: 3 secret yang dipakai workflow Task 3.

- [ ] **Step 1: Buat Supabase personal access token**

Buka `https://supabase.com/dashboard/account/tokens` → Generate new token → beri nama `farmbridge-ci` → copy token (hanya muncul sekali).

- [ ] **Step 2: Set secrets lewat `gh` CLI**

```bash
gh secret set SUPABASE_ACCESS_TOKEN --repo Hafizhputra27/FarmBridge
# paste token dari Step 1 saat diminta, lalu Enter, lalu Ctrl+D

gh secret set SUPABASE_PROJECT_REF --repo Hafizhputra27/FarmBridge --body "rwxnjxmzkcfoddnzjosi"

gh secret set SUPABASE_DB_PASSWORD --repo Hafizhputra27/FarmBridge
# paste database password project FarmBridge (sama seperti Task 2 Step 2)
```

- [ ] **Step 3: Verifikasi**

```bash
gh secret list --repo Hafizhputra27/FarmBridge
```

Expected: 3 baris — `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD` — dengan "Updated" hari ini.

**FG-5 selesai sampai di sini.** Verifikasi end-to-end penuh (push ke `main`, lihat Actions run hijau) baru bisa dilakukan setelah Task 11 (merge sprint), karena `workflow_dispatch`/push-triggered run baru terdaftar di GitHub setelah file workflow ada di branch default (`main`).

---

### Task 5: FG-6 — Buat Firebase project & registrasi Android app

**Files:**
- Create: `lib/firebase_options.dart` (auto-generate oleh FlutterFire CLI)
- Create: `android/app/google-services.json` (auto-generate)
- Modify: `android/settings.gradle.kts`, `android/app/build.gradle.kts` (auto-modify oleh FlutterFire CLI)

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` (dipakai Task 7, `main.dart`), dan Firebase project ID (dipakai Task 8, Edge Function).

- [ ] **Step 1: Aktifkan FlutterFire CLI**

```bash
dart pub global activate flutterfire_cli
```

- [ ] **Step 2: Buat Firebase project**

```bash
firebase projects:create farmbridge-hackathon --display-name "FarmBridge"
```

Kalau project ID `farmbridge-hackathon` sudah dipakai orang lain (ID Firebase bersifat global unik), Firebase CLI akan menolak dengan pesan jelas — coba varian lain, mis. `farmbridge-garudahacks7`, lalu sesuaikan project ID di step berikutnya.

- [ ] **Step 3: Jalankan FlutterFire configure**

```bash
cd /Users/haimac/AndroidStudioProjects/FarmBridge
flutterfire configure --project=farmbridge-hackathon --platforms=android
```

Saat diminta pilih Android app, pilih `com.example.farmbridge` (applicationId saat ini di `android/app/build.gradle.kts` — scaffold Fachri FG-57 belum mengubahnya). **Kalau Fachri sudah mengubah `applicationId`** sebelum kamu menjalankan step ini, jalankan ulang `flutterfire configure` supaya package name yang terdaftar di Firebase tetap sinkron — jangan biarkan berbeda, FCM registration akan gagal diam-diam kalau package name tidak cocok.

Expected: CLI menampilkan ringkasan file yang dibuat/diubah, lalu keluar tanpa error.

- [ ] **Step 4: Verifikasi hasil**

```bash
git status
```

Expected: file baru `lib/firebase_options.dart`, `android/app/google-services.json`, dan perubahan di `android/settings.gradle.kts` / `android/app/build.gradle.kts` (FlutterFire CLI menambahkan Google Services Gradle plugin otomatis).

- [ ] **Step 5: Commit**

Commit `google-services.json` dan `firebase_options.dart` bersama kode — keduanya bukan secret sungguhan (proteksi datang dari Firebase Security Rules & API key restriction, bukan dari kerahasiaan file ini), dan ke-4 anggota tim butuh file yang sama supaya build Android jalan tanpa perlu tiap orang generate ulang.

```bash
git add lib/firebase_options.dart android/app/google-services.json android/settings.gradle.kts android/app/build.gradle.kts pubspec.yaml
git commit -m "[FG-6] setup firebase project + registrasi android app (flutterfire configure)"
```

---

### Task 6: FG-6 — Tambah dependencies Firebase/FCM & `FcmService`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/services/fcm_service.dart`

**Interfaces:**
- Consumes: `DefaultFirebaseOptions.currentPlatform` (Task 5), `Supabase.instance.client` (disediakan Fachri FG-57/Nevan FG-3 — sudah ada sejak scaffold awal karena `supabase_flutter` termasuk dependency dasar FG-57).
- Produces: `FcmService().initialize()` — dipanggil Task 7 dari `main.dart`.

- [ ] **Step 1: Tambah dependencies**

```bash
flutter pub add firebase_core firebase_messaging
```

Ini otomatis resolve versi terbaru yang kompatibel dengan Flutter SDK project ini — jangan hardcode nomor versi manual di `pubspec.yaml`.

- [ ] **Step 2: Tulis `FcmService`**

```dart
// lib/core/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ponytail: sengaja kosong — FCM sudah menampilkan notifikasi system tray
  // otomatis untuk payload `notification` saat app di background/terminated,
  // tidak perlu handling manual untuk MVP.
}

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveDeviceToken(token);
    }
    _messaging.onTokenRefresh.listen(_saveDeviceToken);
  }

  Future<void> _saveDeviceToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // Belum ada user login (role picker FG-11 baru Sprint 3) — token
      // akan tersimpan otomatis lewat onTokenRefresh atau initialize()
      // berikutnya begitu user sudah punya sesi.
      return;
    }
    await Supabase.instance.client
        .from('users')
        .update({'device_token': token}).eq('id', userId);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/fcm_service.dart
git commit -m "[FG-6] tambah firebase_core + firebase_messaging, FcmService"
```

---

### Task 7: FG-6 — Wiring `main.dart` (koordinasi dengan Fachri)

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `DefaultFirebaseOptions.currentPlatform` (Task 5), `FcmService` (Task 6).

⚠️ **Sync point:** `lib/main.dart` juga disentuh Fachri (FG-57, `Supabase.initialize()`) di waktu yang sama. Untuk minimalkan conflict, tambahkan baris seminimal mungkin (import + 1 baris init) dan **kabari Fachri sebelum push** supaya urutan `Firebase.initializeApp()` vs `Supabase.initialize()` disepakati (keduanya harus sebelum `runApp()`, urutan antar-keduanya sendiri tidak masalah).

- [ ] **Step 1: Tambahkan Firebase + FCM init**

Tambahkan ke `lib/main.dart` (sesuaikan posisi persis dengan apa yang sudah ada dari Fachri saat kamu mengedit — jangan timpa `Supabase.initialize()` miliknya):

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService().initialize();
  // Supabase.initialize(...) — punya Fachri, biarkan tetap ada di sini
  runApp(const MyApp());
}
```

- [ ] **Step 2: Verifikasi app masih jalan**

```bash
flutter run
```

Expected: app build & run tanpa error, muncul prompt izin notifikasi Android saat pertama kali dibuka (dari `requestPermission()`).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "[FG-6] init firebase + fcm service di app entry point"
```

---

### Task 8: FG-6 — Edge Function `send-push` generic + shared `sendPush()`

**Files:**
- Create: `supabase/functions/_shared/fcm.ts`
- Create: `supabase/functions/send-push/index.ts`

**Interfaces:**
- Produces: `sendPush({ deviceToken, title, body, deepLink })` — signature ini yang akan diimport Nevan/Hafizh sendiri di Sprint 6 (FG-24 expire-negotiations) dan Sprint 8 (FG-42, negotiations accept/decline/counter), sesuai larangan bikin fungsi terpisah per use-case di task checklist FG-6.

- [ ] **Step 1: Set Firebase service account sebagai Supabase secret**

Buka Firebase Console → Project Settings → Service Accounts → tab "Firebase Admin SDK" → "Generate new private key" → simpan file JSON, mis. ke `~/Downloads/serviceAccountKey.json` (di luar folder repo supaya tidak tergoda commit).

```bash
supabase secrets set FIREBASE_PROJECT_ID=farmbridge-hackathon --project-ref rwxnjxmzkcfoddnzjosi
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/serviceAccountKey.json)" --project-ref rwxnjxmzkcfoddnzjosi
```

Expected: `Finished supabase secrets set.` Verifikasi dengan `supabase secrets list --project-ref rwxnjxmzkcfoddnzjosi` — muncul 2 nama secret (value-nya disembunyikan, itu normal).

- [ ] **Step 2: Tulis shared FCM module**

```typescript
// supabase/functions/_shared/fcm.ts
import { GoogleAuth } from "npm:google-auth-library@9";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!,
);

async function getAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: FIREBASE_SERVICE_ACCOUNT,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("Failed to obtain FCM access token");
  return token.token;
}

export interface SendPushParams {
  deviceToken: string;
  title: string;
  body: string;
  deepLink?: string;
}

export interface SendPushResult {
  ok: boolean;
  error?: string;
}

export async function sendPush(
  { deviceToken, title, body, deepLink }: SendPushParams,
): Promise<SendPushResult> {
  if (!deviceToken) {
    return { ok: false, error: "missing device_token" };
  }

  const accessToken = await getAccessToken();

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          data: deepLink ? { deep_link: deepLink } : undefined,
        },
      }),
    },
  );

  if (!res.ok) {
    const errText = await res.text();
    // Token invalid/expired atau request salah tidak boleh crash pemanggil.
    return { ok: false, error: `FCM ${res.status}: ${errText}` };
  }

  return { ok: true };
}
```

- [ ] **Step 3: Tulis thin HTTP wrapper untuk test manual**

```typescript
// supabase/functions/send-push/index.ts
import { sendPush } from "../_shared/fcm.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: {
    device_token?: string;
    title?: string;
    body?: string;
    deep_link?: string;
  };

  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ ok: false, error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const { device_token, title, body, deep_link } = payload;
  if (!device_token || !title || !body) {
    return new Response(
      JSON.stringify({
        ok: false,
        error: "device_token, title, body are required",
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const result = await sendPush({
    deviceToken: device_token,
    title,
    body,
    deepLink: deep_link,
  });

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 4: Deploy manual untuk test cepat (sebelum nunggu CI)**

```bash
supabase functions deploy send-push --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/fcm.ts supabase/functions/send-push/index.ts
git commit -m "[FG-6] edge function send-push + shared sendPush() helper"
```

---

### Task 9: FG-6 — Wiring `device_token` ke kolom `users` (setelah FG-2 merge)

**Prasyarat:** Task 1 sudah disepakati DAN Nevan sudah commit + kamu sudah merge `nevan_dev` (FG-2) ke `hafizh_dev` — kolom `users.device_token` harus benar-benar ada di database sebelum task ini, jangan dikerjakan lebih awal (lihat checklist FG-6 asli: "jangan mulai bagian ini sebelum dapat konfirmasi dari Nevan").

**Files:** tidak ada file baru — verifikasi bahwa `_saveDeviceToken()` di Task 6 (`lib/core/services/fcm_service.dart`) sudah menunjuk ke kolom yang benar.

- [ ] **Step 1: Tarik migration Nevan**

```bash
git checkout hafizh_dev
git fetch origin
git merge origin/nevan_dev
```

- [ ] **Step 2: Cek kolom ada**

```bash
supabase db push --dry-run
```

Expected: hijau, tidak ada error. Buka Supabase Studio → Table Editor → `users` → pastikan kolom `device_token` (type `text`, nullable) muncul.

- [ ] **Step 3: Verifikasi `_saveDeviceToken()` cocok**

Buka `lib/core/services/fcm_service.dart` (Task 6) — pastikan nama tabel `'users'` dan kolom `'device_token'` di method `_saveDeviceToken()` **sama persis** dengan yang ditulis Nevan di migration. Kalau Nevan pakai nama berbeda (mis. `fcm_token`), update `fcm_service.dart` menyesuaikan — jangan minta Nevan mengganti nama migration di titik ini.

Tidak ada commit terpisah untuk task ini kalau nama kolom sudah cocok sejak Task 6 (kemungkinan besar, karena skema sudah disepakati Task 1 sebelum Nevan menulis migration).

---

### Task 10: FG-6 — Verifikasi end-to-end manual

**Files:** tidak ada file baru — ini task verifikasi murni.

**Interfaces:**
- Consumes: `send-push` (Task 8, sudah dideploy), tabel `users` (Task 9).

- [ ] **Step 1: Insert dummy user dengan device token asli**

Jalankan app di device/emulator fisik (Task 7 sudah membuat `FcmService` mencetak token lewat `getToken()` — tambahkan `print(token)` sementara di `_saveDeviceToken` kalau perlu lihat nilainya di console, hapus lagi setelah dapat).

Di Supabase Studio → SQL Editor:

```sql
insert into users (id, role, device_token)
values (gen_random_uuid(), 'farmer', '<device-token-dari-console>')
returning id;
```

- [ ] **Step 2: Invoke `send-push` manual**

```bash
curl -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/send-push" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_token":"<device-token-dari-console>","title":"Test FG-6","body":"Halo dari send-push","deep_link":"farmbridge://test"}'
```

`$SUPABASE_ANON_KEY` didapat dari Supabase Dashboard → Project Settings → API → `anon` `public` key.

Expected: response `{"ok":true}`, dan notifikasi push muncul di device/emulator dalam beberapa detik.

- [ ] **Step 3: Test error handling (token invalid)**

```bash
curl -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/send-push" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_token":"token-tidak-valid","title":"Test","body":"Test"}'
```

Expected: response `{"ok":false,"error":"FCM 400: ..."}` dengan **HTTP status 200** (bukan 500) — membuktikan Edge Function tidak crash untuk token invalid, sesuai checklist FG-6.

- [ ] **Step 4: Hapus dummy user**

```sql
delete from users where id = '<id-dari-step-1>';
```

---

### Task 11: Merge sprint ke `main` (integration branch owner)

**Prasyarat:** Task 1–10 selesai, `nevan_dev` (FG-2) sudah masuk `hafizh_dev` di Task 9 Step 1, dan `fachri_dev` (FG-57) juga sudah ditarik kalau siap.

Jalankan urutan ini **sendiri di terminal** (bukan lewat Claude, sesuai `CLAUDE.md`):

- [ ] **Step 1: Pastikan hafizh_dev up to date & bersih**

```bash
git checkout hafizh_dev
git fetch origin
git status
```

- [ ] **Step 2: Tarik branch teammate yang sudah siap**

```bash
git merge origin/nevan_dev    # kalau belum ditarik di Task 9
git merge origin/fachri_dev   # kalau FG-57 sudah siap
```

- [ ] **Step 3: Dry-run migration**

```bash
supabase db push --dry-run
```

Wajib hijau. Kalau merah, **jangan lanjut** — kembalikan ke Nevan (Playbook §4).

- [ ] **Step 4: Push hafizh_dev**

```bash
git push origin hafizh_dev
```

- [ ] **Step 5: Merge ke main**

```bash
git checkout main
git merge hafizh_dev
git push origin main
```

- [ ] **Step 6: Verifikasi CI/CD live (DoD FG-5)**

Buka tab **Actions** di `https://github.com/Hafizhputra27/FarmBridge/actions` — pastikan run terbaru (trigger dari push ke `main`) hijau. Cek juga di Supabase Dashboard → Edge Functions → `send-push` menunjukkan timestamp deploy ter-update.

Kalau merah: baca log step yang gagal (biasanya `SUPABASE_ACCESS_TOKEN` salah/expired atau `SUPABASE_DB_PASSWORD` salah) — perbaiki secret di Task 4, lalu re-run lewat tab Actions → "Re-run all jobs", **jangan** push commit baru cuma untuk retry.

---

## Decisions Log

*(Isi setelah disepakati — jangan biarkan kosong sebelum Nevan commit FG-2)*

- **`device_token` location:** Terverifikasi 2026-07-16 lewat migration Nevan (`origin/nevan_dev`, `supabase/migrations/20260716080000_initial_schema.sql`): `device_token text NULL` langsung di tabel `users`, persis sesuai proposal — cocok dengan `fcm_service.dart` tanpa perlu penyesuaian nama kolom.
- **Firebase project ID final:** `farmbridge-d7fe8` (dibuat manual oleh Hafizh 2026-07-16, `farmbridge-hackathon` sudah dipakai)

---

## Self-Check Coverage (FG-5 & FG-6 checklist asli → task di plan ini)

| Item checklist asli (`sprint1_hafizh_dev.md`) | Task di plan ini |
|---|---|
| CI/CD: lint → deploy migration → deploy Edge Functions | Task 3 |
| CI/CD: GitHub Secrets, jangan hardcode | Task 4 |
| CI/CD: trigger push ke `main` | Task 3 (Step 1), Task 11 |
| CI/CD: gagal jelas kalau token salah | Task 3 (catatan desain) |
| FCM: project Firebase + hubungkan ke Flutter | Task 5 |
| FCM: Edge Function generik `send-push` | Task 8 |
| FCM: simpan device token, tunggu konfirmasi Nevan | Task 1, Task 9 |
| FCM: error handling token invalid tidak crash | Task 8 (Step 3 desain), Task 10 (Step 3 verifikasi) |
