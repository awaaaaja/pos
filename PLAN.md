# ☕ PLAN.md — KopiPOS Master Development Plan

> Dokumen ini adalah source of truth untuk arah project. Dibaca bersama `PRD.md`, `AGENTS.md`, dan `SPRINTS.md` sebelum eksekusi sprint apapun.

---

## 1. Identitas Project

| Item | Detail |
|---|---|
| Nama | KopiPOS |
| Jenis | Coffee Shop Point of Sale & Management System |
| Target user | Owner/Admin, Cashier, Barista/Kitchen |
| Platform | Web (PWA), Desktop, Tablet, Mobile (monitoring) |
| Repo strategi | Trunk-based, 1 repo, modular folder per domain |

---

## 2. Arsitektur

```
Vue 3 + TypeScript
        │
        ▼
   Supabase Client
        │
 ┌──────┼──────────────┐
 ▼      ▼              ▼
Auth  PostgreSQL    Realtime
        │
        ▼
       RLS
```

**Prinsip arsitektur:**
- RLS adalah security layer **utama**, bukan sekadar route guard di frontend.
- Operasi sensitif (void, refund, stock adjustment, discount override) divalidasi di **database function / edge function**, bukan hanya di UI.
- Stock deduction dan order completion terjadi dalam **satu transaction/database function** — tidak boleh terpisah.
- Status order/PO memakai **enum/state machine**, bukan string bebas.

---

## 3. Tech Stack Final

**Frontend:** Vue 3, TypeScript, Vite, Vue Router, Pinia, Tailwind CSS, shadcn-vue, Lucide Icons, Zod, VueUse, ECharts

**Backend:** Supabase (PostgreSQL, Auth, RLS, Realtime, Storage, Edge Functions)

**PWA:** vite-plugin-pwa

**Export:** PapaParse (CSV), SheetJS (Excel), jsPDF/pdfmake (PDF)

**Barcode:** Scanner (USB keyboard-wedge + camera), Generator, Label printing

**Printing:** ESC/POS, Thermal 58mm/80mm

**Deployment:** GitHub → Vercel → Supabase

---

## 4. Development Principle

Jangan bangun semua halaman lebih dulu. Bangun mengikuti **business flow**:

```
PRODUCT → ORDER → PAYMENT → KDS → COMPLETED → RECIPE → INVENTORY → REPORT
```

Kalau golden flow ini benar end-to-end, sistem sudah punya core yang kuat. Fitur lain (purchasing, loyalty, promo, QR ordering, offline, multi-outlet) ditambahkan **setelah** golden flow stabil.

**Prioritas implementasi:** Database + RBAC → Product/Barcode → POS → Order → Payment → KDS → Recipe/Inventory → baru sisanya.

---

## 5. Role & Access Control (ringkas — detail di PRD)

- **Owner**: full access ke semua modul.
- **Cashier**: POS, Orders, Tables, Customers, Payment, Shift, limited reports. Void/refund butuh Owner PIN approval.
- **Barista/Kitchen**: KDS, order detail, order history saja.

---

## 6. Fase Pengembangan (26+ fase, dipetakan ke 12 sprint)

| # | Fase | Sprint |
|---|---|---|
| 01 | Foundation | 1 |
| 02 | Database Foundation | 2 |
| 03 | Auth + RBAC | 2 |
| 04 | Product Management | 3 |
| 05 | Barcode System | 3 |
| 06–07 | POS + Table Management | 4–5 |
| 08 | Order Engine (state machine) | 5 |
| 09 | KDS + Realtime | 6 |
| 10 | Payment | 5 |
| 11 | Receipt & Printer | 12 |
| 12 | Shift Management | 8 |
| 13–14 | Inventory + Recipe Engine | 7 |
| 15 | Stock Opname | 9 |
| 16–17 | Purchasing + Barcode Receiving | 9 |
| 18 | Customer & Loyalty | 10 |
| 19 | Promo | 10 |
| 20 | Expense | 9 |
| 21–22 | Import/Export | 11 |
| 23 | Backup | 12 |
| 24–25 | Dashboard + Reporting | 11 |
| 26 | Audit Log | 8 |
| 27 | QR Ordering | v1.3 (post-MVP) |
| 28 | Notification | rolling, tiap sprint terkait |
| 29 | Settings | rolling |
| 30 | Offline | v1.4 (post-MVP) |

Detail task per fase ada di dokumen asli requirement (referensi lengkap 43 bagian) — `PRD.md` merangkum requirement fungsionalnya per modul, `SPRINTS.md` memecah jadi task per sprint.

---

## 7. Struktur Folder

```
src/
├── modules/
│   ├── auth/ pos/ orders/ kds/ products/ barcode/ inventory/
│   ├── recipes/ purchasing/ customers/ loyalty/ payments/
│   ├── shifts/ expenses/ reports/ exports/ imports/
├── components/
│   ├── ui/ pos/ tables/ barcode/ charts/
├── layouts/
│   ├── OwnerLayout.vue CashierLayout.vue KdsLayout.vue
├── stores/ composables/ services/ types/ utils/ router/
```

---

## 8. Roadmap Rilis

```
MVP v1  → golden flow lengkap (auth, product, barcode, POS, order,
          payment, receipt, KDS, realtime, shift, inventory dasar,
          recipe, stock deduction, dashboard, sales report, CSV
          import, Excel/PDF export)
v1.1    → Supplier, Purchasing, Goods Receiving, Stock Opname, Waste, Expense
v1.2    → Customer, Loyalty, Promo, Coupon
v1.3    → QR Ordering, QR Menu, Online Payment
v1.4    → Offline POS, Sync, Multi-device
v2.0    → Multi Outlet, Advanced Analytics, Forecasting
```

---

## 9. Sprint Plan (12 Sprint)

| Sprint | Target |
|---|---|
| 1 | Foundation + UI system |
| 2 | Database + Auth + RBAC |
| 3 | Product + Category + Barcode |
| 4 | POS + Cart + Modifier |
| 5 | Order + Table + Payment |
| 6 | KDS + Realtime |
| 7 | Inventory + Recipe |
| 8 | Shift + Refund + Void + Audit Log |
| 9 | Purchasing + Supplier + Waste + Expense |
| 10 | Customer + Loyalty + Promo |
| 11 | Reports + Import + Export |
| 12 | Printer + Backup + Security + Production |

Detail task, acceptance criteria, dan ready-to-paste agent prompt per sprint ada di `SPRINTS.md`.

---

## 10. Definition of Done (contoh: POS)

Fitur **tidak** dianggap selesai hanya karena UI tampil. POS baru selesai kalau:

```
✓ Product bisa dipilih          ✓ Order tersimpan
✓ Barcode bisa scan             ✓ Invoice generated
✓ Modifier bekerja              ✓ Payment tersimpan
✓ Cart bekerja                  ✓ Receipt bisa dicetak
✓ Discount bekerja              ✓ KDS menerima order
✓ Inventory berkurang           ✓ Audit log tercatat
✓ RLS bekerja                   ✓ Error handling bekerja
```

Standar sama berlaku untuk semua modul lain — DoD spesifik per sprint ada di `SPRINTS.md`.

---

## 11. Golden Flow (jangan pernah dilanggar urutan/integritasnya)

```
CUSTOMER → QR/CASHIER → POS → ORDER
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
                PAYMENT                     KDS → BAR/KITCHEN → READY
                    └────────────┬────────────┘
                                 ▼
                            COMPLETED
                                 ▼
                          RECIPE ENGINE
                                 ▼
                            INVENTORY
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
                 REPORT     HPP/PROFIT      ALERT
                    ▼
                  OWNER
```

---

## 12. Dokumen Terkait

- `PRD.md` — requirement fungsional & non-fungsional per modul, skema database detail, scope MVP vs post-MVP.
- `AGENTS.md` — aturan main untuk OpenCode agent: konvensi kode, workflow THINKING→BUILD→EKSEKUSI→REVIEW→PERBAIKI, checklist keamanan.
- `SPRINTS.md` — breakdown 12 sprint + prompt siap pakai untuk tiap sprint.
