# 📋 PRD.md — KopiPOS Product Requirements Document

Referensi: `PLAN.md` (arsitektur & roadmap), `AGENTS.md` (aturan eksekusi), `SPRINTS.md` (breakdown kerja).

---

## 1. Tujuan Produk

KopiPOS adalah sistem POS & manajemen coffee shop yang menyatukan penjualan (POS), dapur/bar (KDS), inventory, resep (BOM), pembelian, loyalty, dan pelaporan dalam satu platform berbasis Supabase dengan realtime sync antara kasir dan dapur.

**Masalah yang diselesaikan:**
- Kasir dan barista tidak sinkron real-time → pakai Realtime KDS.
- Stok tidak otomatis berkurang sesuai resep → Recipe Engine + transactional deduction.
- Tidak ada audit trail untuk void/refund/adjustment → Audit Log wajib.
- Data barcode terpisah dari kasir dan gudang → Barcode System dipakai lintas modul (jual & terima barang).

---

## 2. Persona & Role

### Owner/Admin
Full access: dashboard, POS, products, inventory, recipe, supplier, purchasing, customers, promos, expenses, reports, users, settings, audit log, backup, import, export.

### Cashier
Akses: POS, Orders, Tables, Customers, Payment, Shift, limited reports.
**Tidak bisa:** modifikasi product/recipe, stock adjustment, user management, financial report, system settings.
**Void/refund flow:** Cashier request → Owner PIN approval → executed.

### Barista/Kitchen
Akses: KDS, Order Detail, Order History.
**Tidak bisa:** payment, product, inventory adjustment, reports, customers, settings.

---

## 3. Functional Requirements per Modul

### 3.1 Auth & RBAC
- Owner login via email+password; Cashier/Barista login via PIN.
- Middleware: `authMiddleware`, `roleMiddleware`, `permissionMiddleware`.
- RLS per tabel sesuai role — **security ditegakkan di database**, bukan hanya UI.

### 3.2 Product Management
- CRUD produk: create, read, update, archive, restore (soft delete via `is_active`/archive, bukan hard delete).
- Field: name, SKU, barcode, category, price, cost, image, tax, inventory tracking flag, status.
- Kategori: Coffee, Non-Coffee, Tea, Food, Dessert, Merchandise (extensible, bukan hardcoded enum di kode — simpan di tabel `categories`).

### 3.3 Barcode System
- Mode 1: USB scanner (keyboard-wedge input).
- Mode 2: Camera scanner (`ScanBarcode.vue`).
- Flow: SCAN → detect → search product → add to cart.
- Owner bisa assign barcode ke produk, generate barcode baru, preview, cetak.
- Bulk generate: pilih beberapa produk → generate barcode → PDF label → print.
- Barcode dipakai juga di **goods receiving** (Fase 17), bukan cuma di kasir.

### 3.4 POS
- Layout: search/scan bar, category filter kiri, product grid tengah, cart kanan.
- Fitur wajib: search, barcode scan, category filter, product grid, modifier, cart (qty, remove, notes), hold/resume order, dine-in/takeaway, pilih customer, discount, coupon, tax, service charge, payment, receipt.

### 3.5 Table Management
- Status: `AVAILABLE`, `OCCUPIED`, `WAITING_PAYMENT`.
- Fungsi: create, edit, delete, move order, merge table, split bill, transfer table.

### 3.6 Order Engine
- **State machine wajib** (enum, bukan string bebas):
  `DRAFT → CONFIRMED → PREPARING → READY → COMPLETED`
  Cancellation paths: `DRAFT→CANCELLED`, `CONFIRMED→VOID`, `COMPLETED→REFUND`.
- Transisi status hanya lewat fungsi terkontrol (service/DB function), tidak lewat update field bebas dari frontend.

### 3.7 KDS (Kitchen Display System)
- Kolom: NEW, PREPARING, READY.
- Order card menampilkan item, modifier, notes, waktu tunggu.
- Realtime: order INSERT di POS → Supabase Realtime → muncul di KDS otomatis.
- Barista klik START → `status = PREPARING` → cashier lihat update realtime.

### 3.8 Payment
- Breakdown: subtotal, discount, tax, service charge, total.
- Metode: Cash, QRIS, Debit, Credit, E-Wallet, Transfer.
- Cash: hitung kembalian otomatis (received − total).

### 3.9 Receipt & Printer
- Format struk sesuai contoh di `PLAN.md`.
- Support printer 58mm dan 80mm via ESC/POS.

### 3.10 Shift Management
- Open: input opening cash.
- Selama shift: cash sales, cash in, cash out, refund tercatat.
- Close: expected vs actual vs difference.
- **Constraint:** shift tidak boleh ditutup jika masih ada order pending.

### 3.11 Inventory
- Ingredient: SKU, barcode, unit (g/kg/ml/L/pcs/pack), stock, minimum stock, cost, supplier.
- Semua pergerakan stok tercatat di `inventory_movements` (tidak ada update stok langsung tanpa jejak).

### 3.12 Recipe Engine (BOM)
- 1 produk → n ingredient dengan qty per unit.
- Saat order completed: deduct stok ingredient sesuai qty × jumlah produk terjual.
- **Wajib dilakukan dalam 1 database transaction/function** — order dan stok tidak boleh terpisah kalau salah satu proses gagal (all-or-nothing).

### 3.13 Stock Opname
- Flow: create opname → system stock ditampilkan → input actual → hitung selisih → review → confirm → jadi inventory adjustment tercatat.

### 3.14 Purchasing
- Supplier: nama, contact, address, payment terms.
- PO state machine: `Draft → Approved → Ordered → Partially Received → Completed`.

### 3.15 Barcode Receiving
- Flow: scan barcode → produk ditemukan → expected qty vs received qty → confirm → inventory bertambah.

### 3.16 Customer & Loyalty
- Field customer: name, phone, email, birthday, points, total spending.
- Loyalty rate: Rp10.000 = 1 poin (configurable, jangan hardcode).
- Transaksi loyalty: EARN, REDEEM, EXPIRE, ADJUSTMENT.

### 3.17 Promo
- Tipe: percentage, fixed, coupon, happy hour, buy 1 get 1, bundle, member discount.
- Coupon: code, discount, minimum purchase, maximum discount, usage limit, start/end date, customer eligibility.

### 3.18 Expense
- Field: category, amount, date, description, attachment, created by.
- Kategori: Rent, Electricity, Water, Internet, Salary, Gas, Maintenance, Marketing, Supplies, Other.

### 3.19 Import
- Template: SKU, Barcode, Name, Category, Cost, Price, Stock.
- Flow: upload → parse → validate → preview → tampilkan error → user perbaiki/pilih strategi partial import → confirm → import.
- **Jangan langsung import** tanpa preview & validasi.

### 3.20 Export
- Format: CSV, XLSX, PDF.
- Entity yang bisa diexport: products, customers, orders, payments, inventory, stock movement, PO, expenses, sales, profit, shift.
- Filter: date, category, cashier, payment, product.

### 3.21 Backup
- Export data aplikasi (data portability) + laporan.
- **Catatan penting:** backup database utama tetap mengandalkan fasilitas backup PostgreSQL/Supabase; export aplikasi bukan satu-satunya disaster recovery mechanism.

### 3.22 Dashboard (Owner)
- Metrik: Revenue, Orders, AOV, COGS, Gross Profit, Expenses, Net Profit.
- Widget: sales today/this month, top products, low stock, recent orders, payment breakdown, sales trend, best cashier, waste.

### 3.23 Reporting
- Sales (daily/weekly/monthly/custom), Product (best/worst seller, revenue, qty, profit, margin), Inventory (stock, low stock, movement, waste, opname, valuation), Finance (revenue, COGS, expense, gross/net profit), Employee (cashier sales, transaction count, void, refund, discount).

### 3.24 Audit Log
- Event yang dicatat: LOGIN, LOGOUT, CREATE, UPDATE, DELETE, VOID, REFUND, DISCOUNT, PAYMENT, STOCK_ADJUSTMENT, STOCK_OPNAME, SHIFT_OPEN, SHIFT_CLOSE, IMPORT, EXPORT.
- Format log mencakup: timestamp, actor, action, reference (mis. invoice), reason (untuk void/refund), approver.

### 3.25 QR Ordering (post-MVP, v1.3)
- Tiap meja punya QR → digital menu → customer browse → pilih → modifier → cart → submit → masuk ke POS + KDS.
- MVP QR ordering **tanpa online payment** — customer submit, cashier yang konfirmasi/payment.

### 3.26 Notification
- Owner: low stock, pending approval, large refund, stock adjustment, shift difference.
- Cashier: order ready, payment failed.
- Barista: new order, order cancelled, priority order.

### 3.27 Settings
- Store (name, logo, address, phone, tax, service charge, currency), POS (auto print, sound, receipt, invoice prefix), Inventory (negative stock policy, low stock threshold, units), Printer (receipt/kitchen/bar/barcode), Payment (cash, QRIS, debit, e-wallet, transfer).

### 3.28 Offline Mode (post-MVP, v1.4)
- POS → IndexedDB → offline queue → saat online → sync engine → Supabase.
- Harus menangani: duplicate transaction, conflict, retry, failed sync, payment reconciliation.
- **Jangan dikerjakan di awal development.**

---

## 4. Data Model (ringkasan tabel)

```
profiles, roles, permissions
outlets, tables
categories, products, product_variants, modifiers, modifier_options
ingredients, recipes, recipe_items
customers
orders, order_items, order_item_modifiers
payments, refunds, discounts
shifts, cash_movements
inventory_movements, stock_adjustments, stock_opnames, wastes
suppliers, purchase_orders, purchase_order_items, goods_receipts
expenses
loyalty_transactions
audit_logs
```

**Detail field kunci:**

```
products: id, category_id, name, sku, barcode, description, image_url,
          cost_price, selling_price, taxable, track_inventory, is_active,
          created_at, updated_at

orders: id, invoice_number, order_type, table_id, customer_id, cashier_id,
        status, subtotal, discount, tax, service_charge, total, notes,
        created_at, completed_at

order_items: id, order_id, product_id, variant_id, quantity, unit_price,
             discount, subtotal, notes, status

payments: id, order_id, method, amount, reference_number, status, paid_at

inventory_movements: id, ingredient_id, type, quantity, unit,
                      reference_type, reference_id, cost, created_by,
                      created_at
```

---

## 5. Non-Functional Requirements

- **Security:** RLS wajib aktif di semua tabel sensitif; validasi input dengan Zod di frontend **dan** validasi ulang di server/DB; tidak ada sensitive data di frontend; environment variable aman; audit log untuk semua operasi sensitif.
- **Reliability:** deduksi stok & completion order atomic (DB transaction); shift tidak bisa ditutup dengan order pending.
- **Performance:** realtime KDS latency rendah (Supabase Realtime); grid produk POS harus responsif di tablet.
- **Portability:** PWA installable, harus bisa dipakai di tablet kasir & desktop owner.
- **Auditability:** semua operasi CREATE/UPDATE/DELETE/VOID/REFUND/DISCOUNT/PAYMENT/STOCK_ADJUSTMENT/STOCK_OPNAME/SHIFT_OPEN/SHIFT_CLOSE/IMPORT/EXPORT tercatat di `audit_logs`.

---

## 6. Scope: MVP v1 vs Post-MVP

**MVP v1 (wajib selesai dulu):**
Auth, 3 Roles, Product, Category, SKU, Barcode Scan, Barcode Generate, POS, Modifier, Table, Order, Payment, Receipt, KDS, Realtime, Shift, Basic Inventory, Recipe, Stock Deduction, Dashboard, Sales Report, CSV Import, Excel/PDF Export.

**Post-MVP:**
- v1.1 — Supplier, Purchasing, Goods Receiving, Stock Opname, Waste, Expense
- v1.2 — Customer, Loyalty, Promo, Coupon
- v1.3 — QR Ordering, QR Menu, Online Payment
- v1.4 — Offline POS, Sync, Multi-device
- v2.0 — Multi Outlet, Advanced Analytics, Sales/Inventory Forecasting

---

## 7. Testing Requirements

- **Unit test:** perhitungan (discount, tax, recipe cost, deduksi inventory, loyalty poin, payment/kembalian).
- **Integration test:** Create Order → Payment → KDS → Complete → Inventory deduction (harus satu alur konsisten).
- **E2E:** Login Cashier → Scan Barcode → Add Modifier → Payment → Print Receipt → KDS → Barista Complete → Inventory Updated.

---

## 8. Security Checklist (wajib per sprint yang relevan)

```
✓ Supabase RLS               ✓ No sensitive data in frontend
✓ Role permission            ✓ Secure environment variables
✓ Input validation           ✓ Rate limiting where applicable
✓ Zod validation             ✓ File upload validation
✓ Server-side validation     ✓ Backup
✓ Audit log                  ✓ Error logging
```

Void, Refund, Stock Adjustment, dan Discount Override **wajib** divalidasi di backend/database — tidak cukup disembunyikan dari UI saja.

---

## 9. Out of Scope (untuk MVP)

- Offline mode (v1.4)
- Multi-outlet (v2.0)
- Online payment gateway penuh untuk QR ordering (v1.3 hanya submit order)
- Sales/inventory forecasting (v2.0)
