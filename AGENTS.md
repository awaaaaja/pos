# 🤖 AGENTS.md — Aturan Eksekusi untuk OpenCode Agent

Dokumen ini adalah instruksi kerja untuk AI agent (OpenCode) yang mengerjakan KopiPOS. Baca `PLAN.md` dan `PRD.md` **sebelum** mulai coding di sprint manapun. Jangan improvisasi scope di luar dua dokumen itu — kalau ada gap, tanyakan lewat komentar `<!-- ASSUMPTION -->` di PR, jangan diam-diam menambah fitur.

---

## 1. Workflow Wajib (Stage-Gated)

Setiap task, sekecil apapun, mengikuti alur ini:

```
THINKING → BUILD → EKSEKUSI → REVIEW → PERBAIKI
```

1. **THINKING** — Baca requirement terkait di `PRD.md` + task di `SPRINTS.md`. Tulis rencana singkat: file yang akan dibuat/diubah, tabel yang terlibat, RLS policy yang dibutuhkan, edge case.
2. **BUILD** — Implementasi sesuai rencana. Ikuti struktur folder & konvensi di bawah.
3. **EKSEKUSI** — Jalankan: migration, seed (jika perlu), build, lint, unit test terkait.
4. **REVIEW** — Cek terhadap Definition of Done sprint tersebut (lihat `SPRINTS.md`) dan Security Checklist (`PRD.md` §8). Jangan tandai selesai kalau ada item yang belum terpenuhi.
5. **PERBAIKI** — Perbaiki temuan dari REVIEW sebelum lanjut ke task berikutnya.

Jangan lompat ke BUILD tanpa THINKING pada task yang menyentuh: state machine, RLS policy, atau transaksi finansial (order/payment/inventory).

---

## 2. Prinsip Non-Negosiabel

1. **RLS adalah security layer utama.** Jangan pernah mengandalkan hide-UI saja untuk operasi sensitif (void, refund, stock adjustment, discount override, user management).
2. **State machine, bukan string bebas.** Status order/PO/shift memakai enum Postgres atau constraint check, transisi lewat function terkontrol.
3. **Order completion + stock deduction = 1 transaction.** Gunakan Postgres function (`plpgsql`) atau Supabase RPC yang atomic. Tidak boleh ada race condition antara update order dan update inventory.
4. **Audit log itu wajib, bukan opsional.** Setiap CREATE/UPDATE/DELETE/VOID/REFUND/DISCOUNT/PAYMENT/STOCK_ADJUSTMENT/STOCK_OPNAME/SHIFT_OPEN/SHIFT_CLOSE/IMPORT/EXPORT menulis row ke `audit_logs`.
5. **Import selalu ada tahap preview + validasi.** Tidak ada "upload langsung masuk database".
6. **Jangan bangun halaman kosmetik duluan.** Ikuti golden flow di `PLAN.md` §11. Kalau diminta membuat fitur di luar urutan sprint aktif, konfirmasi dulu apakah ini scope creep.

---

## 3. Konvensi Teknis

### Struktur Folder
```
src/
├── modules/<domain>/        # logic per domain (pos, orders, kds, dst)
│   ├── components/
│   ├── composables/
│   ├── services/            # panggilan ke Supabase
│   ├── stores/               # Pinia store domain ini
│   └── types.ts
├── components/ui/            # shadcn-vue primitives
├── layouts/                  # OwnerLayout, CashierLayout, KdsLayout
├── router/
├── stores/                   # global store (auth, session)
├── composables/               # cross-domain composables
├── services/                  # supabase client, http, printer, barcode
├── types/                     # shared types
└── utils/
```

### Vue / TypeScript
- Composition API + `<script setup lang="ts">` — tidak pakai Options API.
- Props & emits selalu di-type eksplisit.
- State lokal kompleks → composable; state lintas komponen/domain → Pinia store.
- Semua form input divalidasi dengan **Zod schema** yang didefinisikan di `types/` atau co-located dengan modul, dipakai ulang untuk validasi server-side (edge function) juga bila memungkinkan.

### Service Layer
- Semua panggilan Supabase (query, mutation, RPC) lewat `modules/<domain>/services/*.ts` — komponen Vue **tidak** memanggil `supabase.from()` langsung.
- Fungsi service mengembalikan tipe hasil yang eksplisit (bukan `any`), termasuk error handling terstruktur (`{ data, error }`).

### Database
- Setiap tabel baru: migration SQL + RLS policy dalam PR yang sama, **tidak boleh terpisah sprint**.
- Kolom status pakai `enum` Postgres atau `check constraint`, sertakan komentar SQL yang menjelaskan transisi valid.
- Fungsi transaksional (order completion, stock deduction, stock opname confirm, PO receiving) ditulis sebagai `plpgsql function`/RPC, dipanggil dari service layer, bukan direkonstruksi step-by-step di frontend.

### Realtime
- Subscribe Realtime channel per outlet/table scope agar tidak over-fetch; unsubscribe saat komponen unmount (pakai composable `useRealtimeOrders` dsb).

### Naming
- Tabel: `snake_case` jamak (`order_items`).
- Komponen Vue: `PascalCase.vue`.
- Composable: `useXxx.ts`.
- Service function: verb-first (`createOrder`, `voidOrder`, `deductInventory`).

---

## 4. Definition of Done — Checklist Universal

Sebelum menandai task/sprint selesai, pastikan:

```
✓ Requirement PRD terkait terpenuhi (bukan cuma UI tampil)
✓ RLS policy dibuat & diuji untuk role yang relevan
✓ Validasi Zod di frontend, validasi ulang di server/DB
✓ Audit log ditulis untuk operasi sensitif
✓ Unit test untuk logic kalkulasi (jika ada)
✓ Error handling: user melihat pesan yang jelas, bukan crash diam
✓ Realtime update bekerja (untuk modul yang relevan: order/KDS)
✓ Tidak ada state string bebas untuk field yang seharusnya enum
```

DoD spesifik per sprint (lebih detail) ada di `SPRINTS.md` — checklist di atas adalah baseline minimum yang berlaku ke semua sprint.

---

## 5. Batasan Scope per Sprint

- Agent **hanya** mengerjakan task yang tercantum untuk sprint aktif di `SPRINTS.md`.
- Kalau menemukan dependency ke fase yang belum dikerjakan (mis. butuh tabel `suppliers` padahal masih sprint 4), buat stub minimal yang cukup untuk sprint aktif, catat sebagai `TODO(sprint-N)` di kode, jangan implementasi penuh fase lain.
- Fitur post-MVP (QR Ordering, Offline, Multi-outlet) **tidak dikerjakan** sebelum MVP v1 dinyatakan stabil oleh Owner (lihat `PLAN.md` §8).

---

## 6. Testing Wajib per Jenis Perubahan

| Jenis perubahan | Test wajib |
|---|---|
| Kalkulasi (discount, tax, recipe cost, loyalty) | Unit test |
| Order → Payment → KDS → Complete → Inventory | Integration test |
| Flow kasir end-to-end | E2E test (Playwright/Cypress) |
| RLS policy baru | Test query dengan role berbeda (positive + negative case) |

---

## 7. Komunikasi & Output

- Bahasa komentar kode & commit message: bahasa Inggris teknis standar (konvensi industri), tapi ringkasan/summary ke user dalam Bahasa Indonesia informal.
- Setiap sprint selesai, agent memberi ringkasan: apa yang dibangun, DoD yang terpenuhi, dan asumsi yang diambil (jika ada) — tanpa menunggu diminta.
- Jangan menandai fitur "selesai" kalau checklist DoD (§4) belum lengkap — laporkan sisanya secara eksplisit.
