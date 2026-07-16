# FarmBridge — Claude Code Guide for 30-Hour Hackathon

**Tujuan:** Gunakan Claude Code (CLI tool) untuk automate, assist, dan track progress selama 30 jam build.

---

## Apa itu Claude Code?

Claude Code adalah command-line tool yang memungkinkan kamu interact dengan Claude secara programmatic:
- Run AI-assisted tasks dari terminal
- Automate code generation, refactoring, testing
- Delegate complex tasks ke Claude tanpa buka browser
- Ideal untuk hackathon environment (headless/CLI-only setup)

**Install:** `npm install -g @anthropic-ai/claude-code` (atau gunakan existing installation)

---

## Setup: Siapkan Repo untuk Claude Code

**1. Create `.claude/config.json` di root repo:**

```json
{
  "project_name": "FarmBridge (GarudaHacks 7.0)",
  "description": "30-hour agritech hackathon build",
  "tech_stack": ["Flutter", "Supabase", "Firebase", "PostgreSQL"],
  "team": {
    "hafizh": "Integration owner + backend/PM",
    "nevan": "Backend (DB, state machine, edge functions)",
    "fachri": "Flutter frontend",
    "alexander": "Figma design"
  },
  "merge_strategy": "hybrid_per_fase",
  "phases": [
    {"number": 1, "sprints": "1-3", "hours": 6, "merge_tag": "phase-1-complete"},
    {"number": 2, "sprints": "4-9", "hours": 12, "merge_tag": "phase-2-complete"},
    {"number": 3, "sprints": "10-13", "hours": 10, "merge_tag": "final-demo"}
  ]
}
```

**2. Create `.claude/.gitignore` untuk skip file besar:**

```
# Skip during Claude analysis
*.apk
*.ipa
build/
.dart_tool/
node_modules/
.supabase/
*.log
```

---

## Common Claude Code Workflows

### 1️⃣ **Sprint Kickoff: Breakdown Sprint Tickets**

```bash
claude-code prompt \
  --file "Sprint 3/sprint3_README.md" \
  --file "Sprint 3/sprint3_nevan_dev.md" \
  --file "Sprint 3/sprint3_fachri_dev.md" \
  "Summarize ticket dependencies for Sprint 3. List blockers first. Estimate effort for each PIC."
```

**Output:** Dependency report → share ke tim sebelum start.

---

### 2️⃣ **Mid-Sprint: Generate PR Description Template**

```bash
claude-code generate \
  --file "lib/features/role_picker/role_picker_screen.dart" \
  --jira-ticket "FG-11" \
  --type "pr_description"
```

**Output:** PR template dengan AC checklist, testing evidence, link ke Figma.

---

### 3️⃣ **Feature Implementation: Generate Boilerplate**

Misal Fachri mau buat Transaction Detail screen (FG-59):

```bash
claude-code generate \
  --lang "flutter" \
  --template "supabase_crud_screen" \
  --table "transactions" \
  --fields "id,farmer_id,buyer_id,status,total_amount,promised_delivery_date" \
  --output "lib/features/transaction/transaction_detail_screen.dart"
```

**Output:** Scaffold screen + Supabase query + error handling (boilerplate siap diisi logic).

---

### 4️⃣ **Code Review: Check Acceptance Criteria**

```bash
claude-code review \
  --file "supabase/functions/price_recommendation/index.ts" \
  --jira-ticket "FG-23" \
  --checklist "AC_10.2"
```

**Output:** AC verification report → evidence untuk demo.

---

### 5️⃣ **Testing: Generate E2E Test Case**

```bash
claude-code test:generate \
  --feature "negotiation_flow" \
  --scenario "buy_now_race_condition" \
  --output "test/e2e/buy_now_race_condition_test.dart"
```

**Output:** Integration test code → paste ke Flutter test suite.

---

### 6️⃣ **Merge Prep: Verify State**

Run sebelum MERGE #1 (end of Fase 1):

```bash
claude-code verify \
  --phase 1 \
  --check "migration_status" \
  --check "flutter_analyze" \
  --check "dependency_links" \
  --output "MERGE_READINESS_PHASE1.txt"
```

**Output:** Checklist apakah semua green untuk merge.

---

### 7️⃣ **Evidence Collection: Prepare Demo Script**

```bash
claude-code demo:script \
  --phase 3 \
  --flow "role_picker_to_negotiation_complete" \
  --output "DEMO_SCRIPT_FINAL.md"
```

**Output:** Step-by-step demo script dengan screenshot markers.

---

## Advanced: Custom Hooks untuk Automation

**`.claude/hooks/pre-merge.sh`** — Run sebelum Hafizh merge fase:

```bash
#!/bin/bash
# Pre-merge verification

echo "🔍 Running pre-merge checks..."

# Dry-run migration
supabase db push --dry-run || exit 1

# Analyze Flutter
flutter analyze || exit 1

# Run unit tests (if exist)
flutter test test/ || echo "⚠️ No tests found"

# Verify JIRA AC
claude-code verify --phase ${PHASE} || exit 1

echo "✅ All pre-merge checks passed"
```

**Usage (saat MERGE #1):**
```bash
PHASE=1 bash .claude/hooks/pre-merge.sh
# Kalau hijau → proceed merge
# Kalau merah → fix dulu, rerun hook
```

---

## Sprint Template: Use Claude Code untuk Track Progress

**End of sprint, Hafizh runs:**

```bash
claude-code report:sprint \
  --sprint 3 \
  --team hafizh,nevan,fachri \
  --include "completed_tickets" \
  --include "blockers" \
  --include "effort_variance" \
  --output "SPRINT_3_REPORT.md"
```

**Output:** Sprint summary → share ke juri/lead (jika ada).

---

## Full Hackathon Workflow: Timeline dengan Claude Code

```
T+0 (Kickoff)
├─ claude-code prompt: "Break down Sprint 1 blockers"
└─ Share output → tim memahami dependencies

T+2 (Mid Sprint 1)
├─ claude-code generate: Scaffold FG-57 Flutter project
└─ Fachri tinggal isi logic

T+4 (End Sprint 2)
├─ claude-code verify --phase 1: Checklist pre-merge
├─ Hafizh runs merge hook
└─ MERGE #1 → main

T+8 (Mid Fase 2)
├─ claude-code test:generate: E2E test untuk buy now
└─ Fachri/Nevan run test

T+18 (Start Fase 3)
├─ claude-code review: Verify AC per feature
└─ List gap untuk testing

T+28 (Code Freeze)
├─ claude-code demo:script: Generate demo walkthrough
└─ Rehearsal dengan script

T+30 (Demo)
├─ Follow script → Juri happy
└─ Done!
```

---

## Command Reference (Quick Copy-Paste)

```bash
# Breakdown tickets
claude-code prompt --file "path/to/sprint_README.md" "Summarize blockers"

# Generate code
claude-code generate --lang flutter --template supabase_crud_screen --table users --output lib/features/user/user_screen.dart

# Review AC
claude-code review --file path/to/file.dart --jira-ticket FG-11 --checklist AC_3.1

# Pre-merge check
claude-code verify --phase 1 --check migration_status --check flutter_analyze

# Generate demo script
claude-code demo:script --phase 3 --flow complete_user_journey --output DEMO_FINAL.md

# Sprint report
claude-code report:sprint --sprint 3 --team hafizh,nevan,fachri --output SPRINT_3_REPORT.md
```

---

## Tips: Maksimalkan Claude Code Selama 30 Jam

1. **Keep config.json updated** — Setiap sprint, update completed_sprints & next_blockers
2. **Use hooks untuk automation** — Pre-merge checks run otomatis
3. **Generate evidence early** — Jangan tunggu Sprint 13, evidence collect per-feature
4. **Create standar templates** — PR template, test template, demo script template
5. **Leverage async** — Biarkan Claude Code run report/analysis saat team lanjut code

---

## Troubleshooting

**"Claude Code command not found"**
- Check: `which claude-code` (or `npm -g list | grep claude`)
- Install: `npm install -g @anthropic-ai/claude-code` (may need sudo)

**"File not found in context"**
- Use absolute paths: `--file /full/path/to/file.md`
- Or cd ke repo root dulu: `cd /path/to/farmbridge && claude-code ...`

**"Output too verbose"**
- Add flag: `--output-format brief`
- Or pipe to file: `> OUTPUT.txt`

---

## Next Steps

1. **Hafizh:** Create `.claude/config.json` di repo root
2. **Hafizh:** Create `.claude/hooks/pre-merge.sh` + chmod +x
3. **Nevan:** Test `claude-code generate` untuk FG-3 (Auth setup)
4. **Fachri:** Test `claude-code generate` untuk FG-11 (Role picker scaffold)

**Ready?** Start Sprint 3 dengan Claude Code support! 🚀

