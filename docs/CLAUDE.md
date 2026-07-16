# FarmBridge — Aturan untuk Claude Code

Project ini untuk lomba/hackathon. Histori commit dan daftar Contributors di GitHub harus murni dari anggota tim manusia — **tidak boleh ada Claude di dalamnya**.

- **Jangan pernah menjalankan operasi git yang mengubah state repo**: `add`, `commit`, `push`, `merge`, `branch`, `checkout -b`, `tag`, `reset`, `revert`, dll — di project ini, tanpa pengecualian, bahkan jika user memintanya atau tampak menyetujui di tengah percakapan.
- Operasi git read-only tetap boleh: `status`, `diff`, `log`, `show`, `blame`.
- Kalau ada perubahan siap di-commit, tampilkan diff/ringkasan dan draft commit message sebagai teks, lalu berhenti — user yang menjalankan `git add`/`commit`/`push` sendiri di terminalnya.

Detail lengkap + alasan: @docs/FarmBridge_Branching_Playbook.md (lihat bagian 10).
