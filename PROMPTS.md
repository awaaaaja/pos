# 💬 PROMPTS.md — Prompt Library untuk OpenCode Agent

Dokumen ini beda fungsi dari `SPRINTS.md`. `SPRINTS.md` berisi prompt **spesifik per sprint** (scope tetap, sekali pakai per sprint). `PROMPTS.md` ini berisi prompt **reusable** yang dipakai berulang kali sepanjang project — buka sesi baru, lanjut kerjaan, review, debug, refactor, sampai pre-deploy. Pakai yang sesuai situasi, jangan campur dengan prompt sprint.

---

## 1. Master Kickoff Prompt

Dipakai **di awal setiap sesi baru** dengan OpenCode, sebelum minta agent kerjakan apapun. Memastikan agent selalu punya context penuh sebelum bertindak.

```
Kamu mengerjakan project KopiPOS. Sebelum melakukan apapun, baca dokumen
berikut secara berurutan dari root project:

1. PLAN.md    — arsitektur, tech stack, golden flow, roadmap
2. PRD.md     — requirement fungsional & non-fungsional tiap modul, skema database
3. DESIGN.md  — design tokens, komponen, motion system, aturan per role
4. AGENTS.md  — aturan eksekusi: workflow THINKING→BUILD→EKSEKUSI→REVIEW→PERBAIKI,
                konvensi kode, prinsip non-negosiabel (RLS-first, atomic
                transaction, audit log wajib)
5. SPRINTS.md — breakdown sprint, cek sprint mana yang sedang berjalan dan
                task apa yang sudah/belum selesai

Setelah membaca, konfirmasi ke saya secara singkat:
- Sprint keberapa yang sedang aktif berdasarkan progres kode saat ini
- Task dari sprint itu yang sudah terlihat selesai vs belum
- Ada tidak inkonsistensi antara kode yang ada dengan dokumen (kalau ada,
  laporkan sebelum lanjut, jangan langsung diperbaiki sendiri)

Jangan mulai coding di kickoff ini — tunggu instruksi task berikutnya.
```

---

## 2. Continue Sprint Prompt

Dipakai untuk melanjutkan sprint yang sedang berjalan (bukan mulai sprint baru — untuk itu pakai prompt di `SPRINTS.md`).

```
Lanjutkan Sprint [N] — [nama sprint] sesuai SPRINTS.md.
Cek dulu task mana dari scope sprint ini yang sudah diimplementasikan di
kode saat ini, lalu lanjutkan dari task berikutnya yang belum selesai.

Tetap ikuti workflow THINKING→BUILD→EKSEKUSI→REVIEW→PERBAIKI (AGENTS.md §1)
dan prinsip non-negosiabel di AGENTS.md §2 (RLS-first, atomic transaction,
audit log, state machine, import dengan preview).

Setelah task ini selesai, verifikasi terhadap DoD Sprint [N] di SPRINTS.md
dan laporkan checklist mana yang terpenuhi vs belum.
```

---

## 3. Review / Audit Prompt

Dipakai untuk minta agent mengaudit kode yang sudah ada terhadap dokumen — baik setelah sprint selesai, atau kapan saja mau spot-check.

```
Lakukan review menyeluruh terhadap [modul/sprint tertentu, atau "seluruh
codebase" kalau full audit] dengan membandingkan implementasi saat ini
terhadap:

1. PRD.md   — apakah requirement fungsional modul ini benar-benar terpenuhi,
              bukan cuma UI yang tampil
2. DESIGN.md — apakah token warna/tipografi, density per role, dan motion
               system diikuti (bukan nilai ad-hoc)
3. AGENTS.md §2 — cek satu per satu: RLS ada & benar, state machine bukan
                  string bebas, transaksi order+stok atomic, audit log
                  tertulis untuk operasi sensitif, import ada preview
4. AGENTS.md §8 (Security Checklist di PRD.md §8) — validasi lengkap

Laporkan temuan sebagai daftar concern dengan tingkat urutan prioritas
(critical/major/minor), file/lokasi terkait, dan rekomendasi perbaikan.
JANGAN langsung memperbaiki tanpa saya approve temuannya dulu, kecuali saya
minta eksplisit "langsung perbaiki".
```

---

## 4. Bug Fix Prompt

```
Ada bug: [deskripsikan gejala, langkah reproduksi, expected vs actual behavior]

Sebelum memperbaiki:
1. Cari root cause-nya, bukan cuma gejala di permukaan.
2. Cek apakah bug ini melanggar salah satu prinsip di AGENTS.md §2 (mis.
   ada race condition karena deduksi stok tidak atomic, atau RLS bocor).
3. Kalau perbaikan menyentuh state machine/transaksi finansial, lakukan
   tahap THINKING dulu (AGENTS.md §1) sebelum ubah kode.

Setelah fix, jelaskan singkat: apa root cause-nya, apa yang diubah, dan
apakah ada area lain di codebase yang berpotensi punya bug serupa (jangan
diperbaiki sekarang, cukup ditandai).
```

---

## 5. Refactor Prompt

```
Refactor [area/modul tertentu] dengan tujuan: [alasan — mis. duplikasi
service layer, komponen tidak reusable, dsb].

Batasan:
- Tidak boleh mengubah behavior yang terlihat user (functional requirement
  di PRD.md tetap sama persis).
- Ikuti konvensi struktur folder & naming di AGENTS.md §3.
- Kalau menyentuh komponen UI, pastikan tetap sesuai DESIGN.md (token,
  komponen dari design system, bukan reimplementasi lokal).
- Jalankan test yang relevan (AGENTS.md §6) setelah refactor untuk pastikan
  tidak ada regresi.

Laporkan file yang diubah dan alasan tiap perubahan.
```

---

## 6. New Feature / Post-MVP Prompt

Dipakai setelah MVP v1 stabil, untuk mulai fase v1.1 ke atas (`PLAN.md` §8). **Jangan dipakai sebelum Owner menyatakan MVP stabil.**

```
MVP v1 sudah dinyatakan stabil. Kita masuk fase [v1.1/v1.2/v1.3/v1.4/v2.0]
— [nama fitur, mis. "Supplier, Purchasing, Goods Receiving, Stock Opname,
Waste, Expense"].

Sebelum mulai:
1. Konfirmasi requirement fitur ini di PRD.md — kalau belum cukup detail
   untuk fase post-MVP ini, tanyakan dulu ke saya sebelum berasumsi.
2. Buat breakdown task ala SPRINTS.md untuk fase ini (boleh diusulkan
   sebagai file baru SPRINTS-V2.md, jangan campur ke SPRINTS.md yang sudah ada).
3. Ikuti workflow dan prinsip yang sama seperti MVP (AGENTS.md tetap berlaku
   penuh untuk fase post-MVP).

Tunggu saya approve breakdown task sebelum mulai coding.
```

---

## 7. Pre-Deploy / Production Readiness Prompt

Dipakai menjelang deploy ke production (biasanya di penghujung Sprint 12, atau tiap kali mau deploy rilis baru).

```
Lakukan pre-deploy check untuk KopiPOS sebelum deploy ke production.

Verifikasi satu per satu:
1. Security Checklist penuh (PRD.md §8) — semua item tercentang, bukan
   sebagian.
2. Golden Flow end-to-end (PLAN.md §11) berjalan tanpa error: Customer/
   Cashier → POS → Order → Payment + KDS → Completed → Recipe Engine →
   Inventory → Report.
3. RLS diuji ulang untuk ketiga role (Owner/Cashier/Barista) — tidak ada
   akses yang bocor.
4. Environment variable production terpisah dari staging, tidak ada secret
   ter-commit di repo.
5. Backup & audit log berfungsi (PRD.md §3.21, §3.24).
6. Test suite (unit/integration/E2E dari AGENTS.md §6) hijau semua.

Laporkan hasil sebagai checklist pass/fail. Kalau ada yang fail, JANGAN
deploy — laporkan dulu ke saya.
```

---

## 8. Context Refresh Prompt (sesi panjang / lupa konteks)

Dipakai kalau di tengah sesi panjang agent mulai terasa kehilangan konteks project atau mulai menyimpang dari dokumen.

```
Sebelum lanjut, baca ulang PLAN.md §11 (Golden Flow) dan AGENTS.md §2
(Prinsip Non-Negosiabel). Konfirmasi kamu masih berpegang pada urutan
build: Product → Order → Payment → KDS → Completed → Recipe → Inventory →
Report, dan tidak menambah scope di luar sprint aktif tanpa konfirmasi.

Lanjutkan task sebelumnya dengan konteks ini.
```

---

## Catatan Pemakaian

- Prompt di sini **tidak** menggantikan prompt sprint spesifik di `SPRINTS.md` — pakai `SPRINTS.md` untuk memulai sprint baru, pakai file ini untuk aktivitas rutin di luar/di dalam sprint (lanjut kerja, review, bug fix, refactor, deploy).
- Semua prompt di atas mengasumsikan agent sudah pernah menjalankan **Master Kickoff Prompt (§1)** di sesi tersebut — kalau sesi baru, selalu mulai dari situ dulu.
