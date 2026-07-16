# Sprint 3 Kickoff — Hybrid Merge Strategy Active

**Strategy:** Merge per FASE (3 merge total), bukan per sprint (13 merge).

**Current Status:** Sprint 1-2 sudah di main (assumed), mulai Sprint 3 dari sini.

---

## Sebelum Mulai Sprint 3 (RIGHT NOW)

- [ ] Semua orang `git fetch origin` dan `git checkout` ke branch sendiri
  - Hafizh: `git checkout hafizh_dev`
  - Nevan: `git checkout nevan_dev`
  - Fachri: `git checkout fachri_dev`
  - Alexander: stay di Figma (no repo access)

- [ ] Hafizh buat local tags untuk Sprint 1-2 (jika belum):
  ```bash
  git tag sprint-1-done
  git tag sprint-2-done
  ```

- [ ] Verifikasi `main` branch = Demo-able state dari Sprint 1-2:
  ```bash
  git checkout main
  flutter run    # test app boots
  supabase db status  # DB reachable
  ```

- [ ] Cleanliness check: tidak ada uncommitted changes yang tertinggal
  ```bash
  git status    # should be clean
  ```

---

## Sprint 3 Execution (Fase 1, Part 3 of 3)

| Ticket | PIC | Sprint | Status |
|---|---|---|---|
| FG-7 | Hafizh | 3 | Seed price_reference_data |
| FG-11 | Fachri | 3 | Build Role Picker UI (blocked by FG-9) |

**Dependency:** FG-9 (Alexander's design) must be done before FG-11 starts.

---

## End of Sprint 3 → MERGE #1 (hafizh_dev → main)

**Trigger:** Semua 3 sprint (1-3) sudah di `hafizh_dev` dan green (no error di flutter analyze, migration dry-run hijau).

**Hafizh runs (copy-paste):**
```bash
git checkout hafizh_dev
git fetch origin

# Merge
git merge origin/nevan_dev
git merge origin/fachri_dev

# Verify
supabase db push --dry-run
flutter analyze

# Push & Tag
git push origin hafizh_dev
git checkout main
git merge --no-ff hafizh_dev
git tag phase-1-complete
git push origin main --tags

echo "✅ FASE 1 COMPLETE — MERGE #1 done"
```

---

## Selama Sprint 4-9 (Fase 2)

- **Jangan merge ke main dulu** — accumulate di hafizh_dev saja
- Local checkpoint tags: sprint-4-done, sprint-5-done, ... sprint-9-done (git tag saja, jangan push)
- Kalau perlu rollback salah satu sprint, reset ke local tag itu

**MERGE #2** baru di akhir Sprint 9 (sama command seperti di atas, tag: phase-2-complete)

---

## Selama Sprint 10-13 (Fase 3 + Demo)

- Same: accumulate di hafizh_dev
- **Code freeze last 2 hours** (dari 30 jam)
- **MERGE #3** di akhir Sprint 13 (tag: final-demo + release-garudahacks-7.0)

---

## Benefits of This Hybrid Strategy

| Aspek | Per-Sprint (13 merge) | Hybrid Per-Fase (3 merge) |
|---|---|---|
| Merge overhead | 65 min | 15 min |
| Git conflict risk | Higher (more cycles) | Lower (fewer cycles) |
| Rollback granularity | Per-sprint | Per-phase (wider range) |
| Demo checkpoints | 13 tags | 3 main tags + 13 local tags |
| Complexity | Higher | Lower |

---

## Questions?

- Hafizh: confirm merge commands clear?
- Nevan/Fachri: confirm checkpoint tagging makes sense?
- All: ready to start Sprint 3 dari sini?

**NEXT: Mulai Sprint 3 sekarang. GO!** 🚀
