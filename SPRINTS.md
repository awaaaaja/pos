# 🏁 SPRINTS.md — Breakdown & Prompt Eksekusi per Sprint

Setiap sprint punya: tujuan, task list, Definition of Done, dan **prompt siap-paste** untuk OpenCode agent. Jalankan satu sprint penuh sebelum lanjut ke sprint berikutnya. Selalu buka sprint dengan agent membaca `PLAN.md`, `PRD.md`, `AGENTS.md` dulu.

---

## Sprint 1 — Foundation + UI System

**Tasks:**
- Init repo Git, Vue 3 + TS + Vite + Tailwind + shadcn-vue + ESLint + Prettier.
- Setup environment config (dev/staging/production) + `.env.example`.
- Setup project Supabase (dev).
- Buat struktur folder sesuai `AGENTS.md` §3.
- Setup vite-plugin-pwa (manifest, icon, basic service worker — belum offline logic).
- Setup routing dasar + 3 layout kosong (`OwnerLayout`, `CashierLayout`, `KdsLayout`).

**DoD:**
```
✓ Project bisa di-run lokal tanpa error
✓ Lint & format jalan tanpa warning
✓ 3 environment config terpisah dan tidak saling bocor secret
✓ PWA installable (manifest valid)
✓ Struktur folder module-based sudah ada (boleh kosong/berisi placeholder)
```

**Prompt:**
```
Baca PLAN.md, PRD.md, dan AGENTS.md di root project ini.
Kerjakan Sprint 1 — Foundation + UI System sesuai SPRINTS.md.

Scope:
1. Inisialisasi project Vue 3 + TypeScript + Vite.
2. Setup Tailwind CSS + shadcn-vue + Lucide Icons.
3. Setup ESLint + Prettier dengan config yang konsisten dengan konvensi di AGENTS.md §3.
4. Buat struktur folder modular (modules/, components/ui, layouts/, stores/,
   composables/, services/, types/, utils/, router/) sesuai AGENTS.md.
5. Setup environment config untuk dev/staging/production (.env.example).
6. Setup Supabase client service (services/supabase.ts) dengan tipe env yang aman.
7. Setup vite-plugin-pwa dengan manifest dasar (nama app: KopiPOS).
8. Buat 3 layout kosong: OwnerLayout.vue, CashierLayout.vue, KdsLayout.vue,
   dan routing dasar yang mengarah ke masing-masing (belum perlu auth guard).

Jangan bangun halaman/fitur bisnis apapun di sprint ini — murni foundation.
Setelah selesai, verifikasi terhadap DoD Sprint 1 di SPRINTS.md dan laporkan
checklist mana yang terpenuhi.
```

---

## Sprint 2 — Database + Auth + RBAC

**Tasks:**
- Migration SQL untuk: `profiles`, `roles`, `permissions`, `outlets`, `tables`, `categories`, `products` (skeleton), dan tabel inti lain sesuai `PRD.md` §4 (boleh bertahap, prioritas tabel yang dipakai sprint 2–5 dulu).
- RLS policy dasar per role (Owner/Cashier/Barista) untuk tabel yang sudah ada.
- Implementasi login Owner (email+password) dan login Cashier/Barista (PIN).
- `authMiddleware`, `roleMiddleware`, `permissionMiddleware`.
- Pinia store `auth` (session, role, profile).

**DoD:**
```
✓ Migration + RLS policy ada dalam PR yang sama (AGENTS.md §3)
✓ Owner bisa login email/password, Cashier/Barista bisa login PIN
✓ Role tersimpan di session dan dipakai route guard
✓ RLS teruji: role Cashier tidak bisa akses data yang bukan haknya (negative test)
✓ Audit log mencatat LOGIN/LOGOUT
```

**Prompt:**
```
Baca PLAN.md, PRD.md §2 (Persona & Role) dan §4 (Data Model), serta AGENTS.md.
Kerjakan Sprint 2 — Database + Auth + RBAC.

Scope:
1. Buat migration SQL untuk tabel: profiles, roles, permissions, outlets,
   tables, categories, products (skeleton kolom sesuai PRD §4 dan §3.2),
   audit_logs.
2. Buat RLS policy untuk tiap tabel di atas sesuai role Owner/Cashier/Barista
   (PRD §2). RLS adalah security layer utama — jangan hanya guard di frontend.
3. Implementasikan login Owner (email+password via Supabase Auth) dan
   login Cashier/Barista (PIN — desain skema PIN yang aman, hashed, terikat
   ke outlet).
4. Buat authMiddleware, roleMiddleware, permissionMiddleware di router.
5. Buat Pinia store `auth` yang menyimpan session, role aktif, dan profile.
6. Setiap LOGIN/LOGOUT menulis row ke audit_logs (AGENTS.md §2.4).

Tulis juga test RLS minimal: satu positive case (role yang berhak) dan satu
negative case (role yang tidak berhak) per tabel sensitif.
Verifikasi terhadap DoD Sprint 2 sebelum melapor selesai.
```

---

## Sprint 3 — Product + Category + Barcode

**Tasks:**
- CRUD Category & Product (Owner only) — create/read/update/archive/restore.
- Upload image produk ke Supabase Storage.
- Barcode: assign ke produk, generate barcode, generate label PDF (single & bulk).
- `ScanBarcode.vue`: mode USB (keyboard-wedge) dan mode kamera.

**DoD:**
```
✓ Owner bisa CRUD produk & kategori, Cashier/Barista tidak bisa (RLS + UI)
✓ Barcode bisa di-assign dan digenerate, label bisa diprint (PDF)
✓ Scan barcode (USB & kamera) berhasil mencari produk yang sesuai
✓ Produk yang diarsip tidak muncul di POS tapi tetap ada di riwayat order lama
```

**Prompt:**
```
Baca PRD.md §3.2 (Product Management) dan §3.3 (Barcode System), AGENTS.md.
Kerjakan Sprint 3 — Product + Category + Barcode.

Scope:
1. CRUD Category (modules/products) dan Product lengkap: name, sku, barcode,
   category_id, cost_price, selling_price, image_url, taxable,
   track_inventory, is_active. Hanya Owner yang boleh (RLS + route guard).
   Sertakan archive/restore, jangan hard delete produk yang sudah pernah
   dipakai di order.
2. Upload gambar produk ke Supabase Storage, validasi ukuran/tipe file.
3. Modul barcode (modules/barcode): assign barcode ke produk, generate
   barcode baru (algoritma barcode standar, mis. CODE128), preview, generate
   PDF label (single & bulk pilih banyak produk sekaligus — pakai jsPDF/pdfmake).
4. Komponen ScanBarcode.vue dua mode: (a) USB scanner sebagai keyboard input
   biasa dengan debounce/deteksi input cepat, (b) kamera dengan library
   scanning yang sesuai. Flow: scan → cari produk by barcode → emit event
   product-found untuk dipakai modul lain (POS nanti).

Verifikasi terhadap DoD Sprint 3 sebelum melapor selesai.
```

---

## Sprint 4 — POS + Cart + Modifier

**Tasks:**
- Layout POS sesuai `PLAN.md` §10 (search/scan, category, product grid, cart).
- Modifier & modifier options per produk.
- Cart: tambah/kurang qty, remove item, notes per item.
- Hold order & resume order (belum submit ke `orders` table permanen, atau simpan sebagai `DRAFT`).

**DoD:**
```
✓ Produk bisa ditambah ke cart via klik grid maupun scan barcode
✓ Modifier bisa dipilih dan mempengaruhi harga item
✓ Cart bisa diubah qty, dihapus, diberi notes
✓ Hold order tersimpan dan bisa di-resume oleh cashier yang sama/outlet sama
```

**Prompt:**
```
Baca PRD.md §3.4 (POS) dan §3.6 (Order Engine — khusus status DRAFT), AGENTS.md.
Kerjakan Sprint 4 — POS + Cart + Modifier.

Scope:
1. Bangun halaman /pos sesuai layout di PLAN.md §10: search/scan bar di atas,
   category filter di kiri, product grid di tengah, cart di kanan.
2. Integrasikan ScanBarcode.vue (dari Sprint 3) ke search bar POS.
3. Modul modifier: modifiers & modifier_options per produk (mis. size, milk
   type, extra shot), tampil sebagai pilihan saat produk ditambah ke cart.
4. Cart (Pinia store modules/pos/stores/cart.ts): tambah item, ubah qty,
   hapus item, notes per item, kalkulasi subtotal per item dan total cart.
5. Hold order: simpan cart sebagai order berstatus DRAFT (bukan localStorage
   — simpan ke tabel orders/order_items agar bisa diresume dari device lain
   di outlet yang sama). Resume order: load DRAFT ke cart kembali.

Belum perlu payment/table/discount penuh di sprint ini — itu Sprint 5.
Verifikasi terhadap DoD Sprint 4 sebelum melapor selesai.
```

---

## Sprint 5 — Order + Table + Payment

**Tasks:**
- Table management (`/tables`): CRUD, status, merge, split bill, transfer.
- Order Engine penuh: state machine `DRAFT→CONFIRMED→PREPARING→READY→COMPLETED`, cancellation paths.
- Payment screen: subtotal/discount/tax/service/total, metode pembayaran, kembalian cash.
- Generate invoice number.

**DoD:**
```
✓ Order transisi status hanya lewat function terkontrol (bukan update bebas)
✓ Table status berubah otomatis mengikuti order (AVAILABLE/OCCUPIED/WAITING_PAYMENT)
✓ Split bill & merge table bekerja tanpa merusak total
✓ Payment tersimpan dengan metode & referensi yang benar, kembalian dihitung tepat
✓ Invoice number unik & konsisten format (mis. INV-YYYYMMDD-XXXXX)
```

**Prompt:**
```
Baca PRD.md §3.5 (Table), §3.6 (Order Engine), §3.8 (Payment), AGENTS.md §2
(prinsip state machine & transaksi atomic).
Kerjakan Sprint 5 — Order + Table + Payment.

Scope:
1. Halaman /tables: CRUD meja, status AVAILABLE/OCCUPIED/WAITING_PAYMENT
   (enum Postgres), fungsi move order, merge table, split bill, transfer table.
2. Order Engine: implementasikan state machine sebagai enum + DB function
   untuk transisi (mis. RPC confirm_order, start_preparing, mark_ready,
   complete_order, cancel_order, void_order). Cancellation path sesuai PRD
   §3.6 (DRAFT→CANCELLED, CONFIRMED→VOID, COMPLETED→REFUND). Void wajib lewat
   approval Owner PIN (request dari Cashier → Owner PIN → executed).
3. Halaman payment: breakdown subtotal/discount/tax/service_charge/total,
   pilihan metode (Cash/QRIS/Debit/Credit/E-Wallet/Transfer), untuk Cash
   hitung kembalian dari received amount.
4. Generate invoice_number unik format INV-YYYYMMDD-XXXXX saat order
   dikonfirmasi.
5. Order confirmed mengubah status table jadi OCCUPIED, completed/paid
   mengubah balik ke AVAILABLE (atau WAITING_PAYMENT di antaranya).

Semua transisi status & payment ditulis ke audit_logs sesuai AGENTS.md §2.4.
Verifikasi terhadap DoD Sprint 5 sebelum melapor selesai.
```

---

## Sprint 6 — KDS + Realtime

**Tasks:**
- Halaman `/kds` dengan kolom NEW/PREPARING/READY.
- Order card menampilkan item, modifier, notes, waktu tunggu.
- Realtime subscription: order baru dari POS langsung muncul di KDS.
- Barista START → status PREPARING → cashier melihat update realtime.

**DoD:**
```
✓ Order baru dari POS muncul di KDS tanpa refresh manual
✓ Klik START mengubah status dan terlihat realtime di kedua sisi (POS & KDS)
✓ Order card menampilkan semua modifier & notes dengan benar
✓ Realtime channel unsubscribe saat komponen unmount (tidak ada memory leak)
```

**Prompt:**
```
Baca PRD.md §3.7 (KDS), AGENTS.md §3 (Realtime subscription pattern).
Kerjakan Sprint 6 — KDS + Realtime.

Scope:
1. Halaman /kds dengan 3 kolom: NEW, PREPARING, READY, menggunakan
   KdsLayout.vue (dari Sprint 1).
2. Order card menampilkan: invoice/nomor order, daftar item beserta modifier
   dan notes, waktu tunggu berjalan (elapsed timer dari created_at).
3. Komposable useRealtimeOrders yang subscribe ke Supabase Realtime channel
   untuk order_items dengan status relevan (scoped per outlet), auto update
   UI saat ada INSERT/UPDATE, dan unsubscribe saat unmount.
4. Tombol START di order card memanggil RPC start_preparing (dari Sprint 5)
   yang mengubah status jadi PREPARING — perubahan ini harus terlihat
   realtime juga di sisi POS/cashier (order status indicator).
5. Tombol untuk mark READY per item/order sesuai kebutuhan dapur.

Verifikasi terhadap DoD Sprint 6 sebelum melapor selesai.
```

---

## Sprint 7 — Inventory + Recipe

**Tasks:**
- CRUD ingredient (Owner only).
- Recipe Engine: mapping produk → ingredient + qty.
- Deduksi stok otomatis saat order completed, dalam 1 transaction dengan completion order.
- Halaman basic inventory (lihat stok, minimum stock, alert low stock).

**DoD:**
```
✓ Recipe bisa didefinisikan per produk (multi-ingredient)
✓ Order completed memicu deduksi stok sesuai recipe × qty terjual
✓ Deduksi stok & completion order atomic (gagal salah satu = rollback semua)
✓ Semua pergerakan stok tercatat di inventory_movements dengan reference ke order
✓ Low stock terdeteksi dan siap dipakai notifikasi (Sprint later)
```

**Prompt:**
```
Baca PRD.md §3.11 (Inventory), §3.12 (Recipe Engine), AGENTS.md §2.3
(atomicity requirement).
Kerjakan Sprint 7 — Inventory + Recipe.

Scope:
1. CRUD ingredient (modules/inventory): sku, barcode, unit, stock, minimum,
   cost, supplier_id (boleh nullable dulu, supplier module belum ada).
2. Modul recipe (modules/recipes): CRUD recipe & recipe_items yang memetakan
   product_id → list ingredient_id + qty per unit resep.
3. Buat DB function/RPC complete_order_with_deduction yang, dalam SATU
   transaction: mengubah order status jadi COMPLETED, menghitung total
   kebutuhan ingredient dari semua order_items × recipe_items, mengurangi
   stok ingredient, dan menulis row ke inventory_movements untuk tiap
   ingredient yang berubah (reference_type='order', reference_id=order.id).
   Jika ingredient tidak cukup dan setting negative_stock=false, transaction
   harus gagal total (rollback), tidak boleh partial deduction.
4. Halaman basic inventory: list stok saat ini, highlight yang di bawah
   minimum stock.

Verifikasi terhadap DoD Sprint 7 sebelum melapor selesai — khususnya
atomicity test: simulasikan kegagalan di tengah proses dan pastikan tidak
ada partial update.
```

---

## Sprint 8 — Shift + Refund + Void + Audit Log

**Tasks:**
- Shift open/close dengan expected vs actual cash.
- Cash movements (cash in/out) selama shift.
- Refund & Void flow lengkap dengan Owner PIN approval.
- Audit log viewer (Owner).

**DoD:**
```
✓ Shift tidak bisa ditutup jika masih ada order berstatus pending
✓ Selisih kas (expected vs actual) terhitung dan tercatat
✓ Void/refund wajib approval Owner PIN, tercatat lengkap dengan reason & approver
✓ Audit log viewer menampilkan semua event dari AGENTS.md §2.4 dengan filter dasar
```

**Prompt:**
```
Baca PRD.md §3.10 (Shift), §3.24 (Audit Log), dan bagian Void/Refund di §2
(Persona & Role), AGENTS.md.
Kerjakan Sprint 8 — Shift + Refund + Void + Audit Log.

Scope:
1. Modul shift (modules/shifts): open shift (input opening_cash), selama
   shift catat cash_movements (cash sales otomatis dari payment cash,
   cash in/out manual, refund), close shift (input actual cash, hitung
   expected dari opening_cash + cash_movements, tampilkan difference).
   Cegah close shift jika ada order dengan status selain COMPLETED/CANCELLED.
2. Flow void: Cashier request void dari order screen → modal minta alasan →
   perlu Owner PIN untuk approve → RPC void_order dieksekusi mencatat
   reason & approved_by.
3. Flow refund: mirip void tapi untuk order yang sudah COMPLETED, mengubah
   status ke REFUND, membuat row di refunds dengan amount & reason.
4. Halaman audit log (Owner only, /owner/audit): list semua row audit_logs
   dengan filter by date/actor/action, tampilan seperti contoh di PLAN.md §31.
5. Pastikan SEMUA event dari AGENTS.md §2.4 (termasuk yang dari sprint
   sebelumnya yang belum ditulis) benar-benar menulis ke audit_logs — audit
   sprint 1-7 kalau ada yang terlewat, lengkapi di sprint ini.

Verifikasi terhadap DoD Sprint 8 sebelum melapor selesai.
```

---

## Sprint 9 — Purchasing + Supplier + Waste + Expense

**Tasks:**
- Supplier CRUD.
- PO state machine: Draft→Approved→Ordered→Partially Received→Completed.
- Barcode receiving flow.
- Stock Opname flow.
- Waste recording.
- Expense CRUD dengan kategori & attachment.

**DoD:**
```
✓ PO mengikuti state machine yang benar, tidak bisa loncat status
✓ Goods receiving via scan barcode menambah stok dengan movement tercatat
✓ Stock opname menghasilkan adjustment yang tercatat, bukan overwrite stok diam-diam
✓ Waste tercatat sebagai pengurangan stok dengan alasan
✓ Expense bisa diinput dengan attachment tersimpan di Storage
```

**Prompt:**
```
Baca PRD.md §3.14 (Purchasing), §3.15 (Barcode Receiving), §3.13 (Stock
Opname — reference di PRD §3.13/PLAN §20), §3.18 (Expense), AGENTS.md.
Kerjakan Sprint 9 — Purchasing + Supplier + Waste + Expense.

Scope:
1. CRUD supplier (modules/purchasing): name, contact, address, payment_terms.
2. Purchase Order: state machine Draft→Approved→Ordered→Partially Received→
   Completed (enum + RPC transisi terkontrol), purchase_order_items dengan
   expected qty & cost.
3. Goods receiving: scan barcode produk yang datang dari supplier → cocokkan
   ke purchase_order_items → input received qty → confirm → RPC menambah
   stok ingredient/produk dan menulis inventory_movements
   (reference_type='goods_receipt').
4. Stock Opname (modules/inventory): create opname → snapshot stok sistem →
   input actual per item → hitung selisih → review → confirm → RPC membuat
   stock_adjustment dan inventory_movements (reference_type='opname').
5. Waste recording: form catat waste per ingredient dengan alasan, RPC
   mengurangi stok dan menulis inventory_movements (reference_type='waste').
6. CRUD expense (modules/expenses): category, amount, date, description,
   attachment (upload ke Storage), created_by.

Verifikasi terhadap DoD Sprint 9 sebelum melapor selesai.
```

---

## Sprint 10 — Customer + Loyalty + Promo

**Tasks:**
- Customer CRUD & lookup di POS.
- Loyalty: earn/redeem/expire/adjustment poin.
- Promo: percentage, fixed, coupon, happy hour, BOGO, bundle, member discount.
- Terapkan promo/coupon di cart POS.

**DoD:**
```
✓ Customer bisa dicari/dipilih saat order di POS
✓ Poin loyalty bertambah otomatis sesuai rate saat order completed
✓ Redeem poin mengurangi total order dan mengurangi saldo poin dengan benar
✓ Coupon divalidasi terhadap minimum purchase, usage limit, tanggal berlaku, eligibility
✓ Promo yang diterapkan tercatat di order (bukan cuma visual di cart)
```

**Prompt:**
```
Baca PRD.md §3.16 (Customer & Loyalty), §3.17 (Promo), AGENTS.md.
Kerjakan Sprint 10 — Customer + Loyalty + Promo.

Scope:
1. CRUD customer (modules/customers): name, phone, email, birthday, points,
   total_spending (computed/updated saat order completed). Integrasikan
   pencarian/pemilihan customer ke POS (Sprint 4/5 cart & order).
2. Loyalty (modules/loyalty): rate Rp10.000 = 1 poin (simpan sebagai
   setting, jangan hardcode), transaksi EARN saat order completed, REDEEM
   saat dipakai di POS (kurangi total order sesuai nilai poin), EXPIRE
   (job/manual), ADJUSTMENT (Owner manual, tercatat di audit_logs).
3. Modul promo: dukung percentage, fixed, coupon, happy hour, buy 1 get 1,
   bundle, member discount. Coupon punya field code, discount, minimum
   purchase, maximum discount, usage_limit, start/end date, customer
   eligibility.
4. Terapkan promo/coupon di cart POS (Sprint 4): validasi kondisi sebelum
   diterapkan, hasil promo tersimpan sebagai bagian dari order (discount
   breakdown), bukan hanya angka final tanpa jejak.

Verifikasi terhadap DoD Sprint 10 sebelum melapor selesai.
```

---

## Sprint 11 — Reports + Import + Export

**Tasks:**
- Dashboard Owner (metrik & widget).
- Reporting: sales, product, inventory, finance, employee.
- Import produk dari CSV/Excel dengan validasi & preview.
- Export ke CSV/XLSX/PDF untuk entity yang relevan.

**DoD:**
```
✓ Dashboard menampilkan metrik real (bukan dummy) dari data order/payment/expense
✓ Setiap kategori report (§3.23 PRD) punya minimal 1 view yang berfungsi
✓ Import menampilkan preview + error sebelum commit, mendukung partial import
   dengan strategi yang jelas ke user
✓ Export menghasilkan file yang valid dan bisa dibuka (CSV/XLSX/PDF)
```

**Prompt:**
```
Baca PRD.md §3.19 (Import), §3.20 (Export), §3.22 (Dashboard), §3.23
(Reporting), AGENTS.md.
Kerjakan Sprint 11 — Reports + Import + Export.

Scope:
1. Dashboard Owner (/owner/dashboard): hitung Revenue, Orders, AOV, COGS,
   Gross Profit, Expenses, Net Profit dari data real (orders, payments,
   recipe cost, expenses). Widget: sales today/this month, top products,
   low stock, recent orders, payment breakdown, sales trend (pakai ECharts),
   best cashier, waste.
2. Halaman reporting per kategori (§3.23): Sales (daily/weekly/monthly/
   custom range), Product (best/worst seller, revenue, qty, profit, margin),
   Inventory (stock, low stock, movement, waste, opname, valuation),
   Finance (revenue, COGS, expense, gross/net profit), Employee (cashier
   sales, transaction count, void, refund, discount). Semua dengan filter
   date/category/cashier/payment/product yang relevan.
3. Import produk (modules/imports): template CSV/Excel (SKU, Barcode, Name,
   Category, Cost, Price, Stock), pakai PapaParse/SheetJS untuk parse,
   validasi tiap row, tampilkan preview dengan jumlah valid vs error, user
   harus memperbaiki error atau memilih strategi partial import sebelum
   commit — TIDAK ADA auto-import tanpa preview.
4. Export (modules/exports): products, customers, orders, payments,
   inventory, stock movement, PO, expenses, sales, profit, shift — ke
   CSV (PapaParse), XLSX (SheetJS), PDF (jsPDF/pdfmake), dengan filter
   date/category/cashier/payment/product.

Verifikasi terhadap DoD Sprint 11 sebelum melapor selesai.
```

---

## Sprint 12 — Printer + Backup + Security + Production

**Tasks:**
- Integrasi printer ESC/POS (58mm/80mm) untuk receipt, kitchen, bar, barcode label.
- Backup: export data aplikasi + laporan, schedule, history, download.
- Security hardening penuh sesuai checklist `PRD.md` §8.
- Persiapan production deployment (GitHub → Vercel → Supabase).
- Settings module lengkap (§3.27 PRD).

**DoD:**
```
✓ Receipt tercetak dengan format sesuai contoh di PLAN.md §16, di printer 58mm & 80mm
✓ Backup bisa diexport & didownload, ada riwayat backup
✓ Semua item Security Checklist (PRD §8) terpenuhi dan diverifikasi ulang
   di seluruh modul (bukan hanya modul sprint ini)
✓ Deployment pipeline GitHub→Vercel→Supabase berjalan untuk staging & production
✓ Settings (store, POS, inventory, printer, payment) bisa diubah Owner dan
  langsung berefek ke behavior sistem
```

**Prompt:**
```
Baca PRD.md §3.9 (Receipt & Printer), §3.21 (Backup), §8 (Security
Checklist), §3.27 (Settings), AGENTS.md.
Kerjakan Sprint 12 — Printer + Backup + Security + Production.

Scope:
1. Integrasi ESC/POS untuk cetak: receipt (58mm/80mm sesuai setting outlet),
   kitchen ticket, bar ticket, barcode label (reuse dari Sprint 3).
   Format receipt mengikuti contoh di PLAN.md §16.
2. Modul backup (modules/exports atau modules baru "backup"): export data
   aplikasi + laporan ke file terunduh, simpan riwayat backup (tabel baru
   jika perlu), UI untuk lihat & download riwayat. Catat dengan jelas di
   UI bahwa ini data portability, backup database utama tetap mengandalkan
   fasilitas Postgres/Supabase (PRD §3.21).
3. Security hardening — audit ulang SEMUA modul dari Sprint 1-11 terhadap
   checklist PRD §8: RLS lengkap di semua tabel, validasi Zod + server-side
   di semua form, tidak ada secret di frontend bundle, rate limiting untuk
   endpoint yang relevan, validasi file upload (tipe & ukuran), error
   logging terpusat.
4. Setup deployment: GitHub Actions atau Vercel git integration, environment
   variables untuk staging vs production, smoke test setelah deploy.
5. Modul settings (modules/settings, Owner only): Store info, POS behavior
   (auto print, sound, invoice prefix), Inventory (negative stock policy,
   low stock threshold, units), Printer config per jenis, Payment method
   toggle. Pastikan perubahan setting benar-benar mengubah behavior modul
   terkait (bukan cuma tersimpan di database tanpa efek).

Ini sprint terakhir MVP v1 — setelah selesai, lakukan review menyeluruh
terhadap Golden Flow di PLAN.md §11 end-to-end sebelum dinyatakan
production-ready.
```

---

## Setelah MVP v1 Stabil

Lanjutkan ke roadmap post-MVP sesuai `PLAN.md` §8 (v1.1 Purchasing lanjutan sudah masuk Sprint 9 — sisanya v1.2 Loyalty/Promo sudah masuk Sprint 10; yang murni post-MVP adalah v1.3 QR Ordering, v1.4 Offline, v2.0 Multi Outlet). Buat file `SPRINTS-V2.md` terpisah saat siap masuk fase tersebut — jangan campur dengan sprint MVP di atas.
