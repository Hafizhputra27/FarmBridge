# Sprint 3 — Dokumentasi Fachri (FG-11)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `fachri_dev`

---

## Ringkasan

FG-11 Role Picker Flow — implementasi penuh entry point aplikasi FarmBridge. User memilih role (petani/pembeli), sign-in anonymous, isi nama, masuk ke dashboard sesuai role. App restart langsung skip role picker.

---

## Deliverables

| File | Aksi | Detail |
|---|---|---|
| `lib/features/auth/providers/auth_provider.dart` | File baru | AuthState, AuthNotifier (signInAnonymously, saveProfile, signOut), provider |
| `lib/features/auth/screens/role_picker_screen.dart` | File baru | 2 role card, glassmorphic, signIn saat tap |
| `lib/features/auth/screens/name_input_screen.dart` | File baru | Form validasi, insert DB, SharedPreferences |
| `lib/core/router/app_router.dart` | Edit | Wire real screens, hapus dummy provider, redirect aktif penuh |
| `test/widget_test.dart` | Edit | Update test untuk RolePickerScreen |

---

## Checklist FG-11

- [x] 2 screen sesuai desain FG-9: pilih role (farmer/buyer), isi nama
- [x] Validasi nama kosong ditolak dengan pesan jelas
- [x] `auth.signInAnonymously()` dipanggil saat role dipilih
- [x] Data tersimpan ke `users` + `farmer_profiles` / `buyer_profiles`
- [x] Role & nama di SharedPreferences → app restart skip role picker
- [x] GoRouter redirect logic penuh, provider tidak lagi dummy

---

## Flow (Sesuai JIRA)

```
/role-picker → tap "Saya Petani" → signInAnonymously()
                                    → push /name-input
                                    → isi nama → saveProfile()
                                    → insert users + farmer_profiles
                                    → SharedPreferences
                                    → context.go('/farmer')

App restart → SharedPreferences ada → GoRouter redirect → langsung /farmer
```

---

## Verifikasi

| Item | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | All tests passed |

---

## Catatan

- SignIn dilakukan di RolePickerScreen (saat tap role), sesuai JIRA/sprint3_fachri_dev.md
- Insert DB + SharedPreferences di NameInputScreen (saat submit nama)
- PlaceholderScreen tetap ada untuk /buyer dan /farmer (Dashboard belum diimplementasi di FG-11)
- FCM `_saveDeviceToken` sudah langsung berfungsi begitu user login (userId null → kini terisi)

---

## Referensi

- `docs/Sprint 3/sprint3_fachri_dev.md`
- `docs/Sprint 3/projek_plan_fachri_sprint3.md`
- `docs/Sprint 1/sprint0_alexander_design.md` (FG-9 desain)
- `docs/Sprint 2/sprint2_hasil_akhir.md` (FG-3 Auth)
