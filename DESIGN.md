# 🎨 DESIGN.md — KopiPOS Design System & UI/UX Direction

Referensi: `PLAN.md` (arsitektur), `PRD.md` (requirement fungsional), `AGENTS.md` (konvensi kode). Dokumen ini adalah source of truth untuk **visual & interaction design** — dibaca sebelum membangun komponen UI apapun, khususnya di Sprint 1 (design system) dan tiap sprint yang menyentuh UI baru.

**Konsep:** *Warm Interactive Coffee OS* — premium, minimal, warm, elegant, functional, fast, clean. Bukan template admin dashboard, bukan juga coffee shop yang terlalu dekoratif. Formula komposisi: **40% Clean/Minimal · 25% Coffee Aesthetic · 20% Interactive · 10% Animation · 5% Delight.**

Prinsip tertinggi yang mengalahkan semua estetika: **ini software operasional.** Setiap workflow kasir harus selesai dalam sesedikit mungkin klik — kecepatan transaksi > efek visual.

---

## 1. Design Tokens

### 1.1 Warna

```css
--color-background: #F7F5F1;   /* warm ivory */
--color-surface:    #FFFFFF;
--color-primary:    #3B2720;   /* espresso brown */
--color-secondary:  #8A6654;
--color-accent:     #C89B6D;   /* caramel */
--color-success:    #5F8068;
--color-warning:    #D49A4A;
--color-danger:     #C85C54;
--color-text:       #272321;
```

Aturan: warm coffee tone, **bukan** coklat berlebihan. Warna dipakai proporsional — primary untuk aksi utama & teks penting, accent untuk highlight/CTA sekunder, bukan sebagai warna dasar layout.

### 1.2 Tipografi

- **Primary typeface:** Plus Jakarta Sans atau Inter.
- **Angka POS/finansial:** wajib pakai `font-variant-numeric: tabular-nums` supaya rata dan mudah dibaca cepat oleh kasir.

| Konteks | Size / Weight |
|---|---|
| Page title (mis. "Dashboard") | 24px / Semibold |
| Metrik besar (mis. "Rp8.425.000") | 32px / Bold |
| Label metrik (mis. "Today's Sales") | 14px / Medium |
| Nama produk di kartu | 15px / Semibold |

### 1.3 Radius, Shadow, Spacing

- Corner radius: 12–16px.
- Shadow: sangat subtle — jangan heavy drop shadow.
- Spacing & layout mengikuti skala Tailwind default, konsisten lintas modul.

### 1.4 Ikon

Thin + rounded style (Lucide Icons — sudah ditetapkan di `PLAN.md` §3).

---

## 2. Design System — Dibangun Sebelum Halaman

Wajib dibangun sebagai fondasi Sprint 1 (`SPRINTS.md`), sebelum halaman bisnis apapun:

```
Design System
├── Foundations: Colors, Typography, Spacing, Radius, Shadows, Icons
├── Primitives (shadcn-vue base): Button, Input, Select, Dropdown,
│   Dialog, Drawer, Tabs, Badge, Table, Card, Toast, Tooltip,
│   Pagination, DatePicker
└── POS Components: ProductCard, CartItem, ModifierSelector,
    PaymentMethod, TableCard, OrderCard, KDSCard, StockCard,
    KPI, SalesChart, BarcodeScanner
```

**Rule penting:** komponen harus konsisten di seluruh aplikasi — dibangun sekali di `components/ui/` dan `components/pos/`, dipakai ulang, tidak dibuat ad-hoc per halaman.

---

## 3. Prinsip Desain per Role

Ini yang paling penting — **jangan pakai satu template dashboard untuk ketiganya.**

| Role | Information density | Karakter |
|---|---|---|
| **Owner** | Medium | Dashboard, charts, tables, analytics — *Warm Premium Analytics* |
| **Cashier** | High | Large buttons, fast search, keyboard shortcuts, barcode, sticky cart, minimal animation — *Fast Interactive POS* |
| **Barista** | Low | Huge cards, huge text, high contrast, timer, status, few buttons — *Dark Animated KDS* |

### 3.1 Owner UI

Layout: sidebar kiri + topbar (logo, search, notifikasi, profil) + konten dashboard.

**Sidebar (jangan terlalu banyak menu, dikelompokkan):**
```
OVERVIEW    → Dashboard
OPERATIONS  → POS, Orders, Tables
CATALOG     → Products, Categories, Recipes
INVENTORY   → Stock, Purchasing, Suppliers, Stock Opname
CUSTOMERS   → Customers, Loyalty, Promos
FINANCE     → Expenses, Reports
SYSTEM      → Users, Audit Log, Settings
```

**Dashboard:**
- Greeting kontekstual sesuai waktu (lihat §8 Coffee Shop Personality) + tanggal.
- KPI cards prioritas: Revenue, Orders, Gross Profit, Average Order — jangan semua card dibuat besar, cukup 3–4 metrik utama di baris atas.
- Di bawahnya: Sales Chart (line, dengan area gradient tipis) + Top Items (bar mini).
- KPI card **clickable** → expand ke mini detail (lihat §7 Interactive Dashboard).

### 3.2 Cashier UI

Tidak pakai sidebar besar — kasir butuh speed.

```
┌──────────────────────────────────────────────────────┐
│ ☕ KopiPOS     Table A02     Andi      Shift #024    │
├───────────┬──────────────────────────────┬───────────┤
│ Categories│          PRODUCTS             │   CART    │
│ (kiri)    │          (grid tengah)         │  (sticky, │
│           │                                │  kanan)   │
└───────────┴──────────────────────────────┴───────────┘
```

Topbar POS menampilkan konteks kerja langsung: meja aktif, nama kasir, nomor shift — bukan menu navigasi berat.

### 3.3 Barista/Kitchen UI (KDS)

Dark mode permanen (default, bukan opsional — kontras tinggi, mengurangi glare di layar dapur):

```
┌──────────────────────────────────────────────────────┐
│ BAR / KITCHEN                    14:32   🔊          │
├──────────────┬──────────────┬────────────────────────┤
│ NEW          │ PREPARING    │ READY                  │
└──────────────┴──────────────┴────────────────────────┘
```

Order card: nomor order, item + modifier, timer berjalan, satu tombol aksi (`START` / `READY` / `DONE`). Sesedikit mungkin elemen — barista butuh baca sekilas, bukan analisis.

---

## 4. Halaman Utama (Site Map)

```
AUTH      → Login, Forgot Password, Reset Password
OWNER     → Dashboard, Products, Categories, Recipes, Inventory,
            Stock Opname, Suppliers, Purchasing, Customers, Loyalty,
            Promotions, Expenses, Reports, Users, Audit Logs, Settings
CASHIER   → POS, Tables, Orders, Customers, Shift
BARISTA   → KDS, Order History
```

---

## 5. Komponen POS Kunci — Spesifikasi Interaksi

### 5.1 Product Card

```
┌─────────────────┐
│    ☕ IMAGE      │
├─────────────────┤
│ Iced Latte      │
│ Rp25.000        │
└─────────────────┘
```
Sederhana — gambar, nama, harga. Hover: `translateY` naik tipis + shadow muncul. Klik: card compress skala 0.96, lalu buka **Modifier Drawer** (bukan modal).

### 5.2 Modifier Drawer (right-side, bukan modal kecil)

Slide dari kanan, berisi grup pilihan (SIZE, MILK, SUGAR, EXTRA) dengan single/multi-select yang jelas secara visual (border + background transition + check icon scale-in saat dipilih). Ditutup dengan CTA harga dinamis: `ADD TO ORDER — Rp38.000` — harga di tombol update realtime sesuai pilihan modifier.

### 5.3 Barcode Scanner UI

Search bar POS bersifat multifungsi (`🔍 Search product / Scan barcode...`), dengan ikon kamera untuk mode scan. Overlay kamera pakai frame target + garis laser bergerak selama scanning. Hasil: state sukses (✓ Product found + nama & harga + tombol ADD) atau state gagal (lihat §9 Error State).

### 5.4 Cart (sticky, kanan)

Tiap item: nama × qty, varian modifier di bawahnya (mis. "Large · Oat"), subtotal item, kontrol `− qty +`. Ringkasan bawah: Subtotal → Discount → Tax → **TOTAL**, diikuti CTA besar `[ PAYMENT → ]`. Cart harus selalu terlihat tanpa scroll saat menambah produk.

### 5.5 Payment

Full-screen sheet (bukan halaman baru, bukan modal kecil) — dua kolom: TOTAL besar di kiri, pilihan metode + input di kanan. Untuk Cash: input `Received` → `Change` dihitung & ditampilkan realtime. CTA akhir: `[ COMPLETE PAYMENT ]`.

### 5.6 Table Management

Floor plan visual, bukan tabel data:
```
Green  = Available     Brown = Occupied
Orange = Waiting payment    Red = Problem
```
Klik meja → expand jadi drawer ringkas: nomor order aktif, item, total, aksi (`VIEW ORDER`, `TRANSFER`, `SPLIT BILL`).

### 5.7 Inventory & Stock Opname

Tabel Item/Stock/Min/Status dengan indikator warna status (Healthy/Low). Detail item menampilkan current stock, cost, dan riwayat movement singkat (+purchase, −sales, −waste). Stock Opname pakai mode scan berurutan: scan → system qty ditampilkan → input actual → selisih otomatis → pilih reason → save → next item.

### 5.8 Import Wizard

Step eksplisit, bukan upload-langsung-jadi:
```
01 Upload → 02 Mapping → 03 Validation → 04 Preview → 05 Import
```
Preview wajib menampilkan jumlah valid/warning/error sebelum commit — **jangan pernah import data bermasalah secara diam-diam** (selaras dengan `PRD.md` §3.19).

---

## 6. Motion & Animation System

### 6.1 Filosofi

Animasi adalah **respons terhadap aksi pengguna**, bukan dekorasi acak. Kalau semua elemen bergerak, UX justru terasa lambat — gunakan animasi secara hierarkis dan bertujuan.

### 6.2 Skala Durasi

| Tingkat | Durasi | Contoh |
|---|---|---|
| Micro | 150–200ms | Button hover, checkbox check |
| Normal | 250–350ms | Drawer masuk, add-to-cart fly animation |
| Important | 350–500ms | Modal, payment sheet transition |
| Success | 500–800ms | Payment success checkmark |

Easing: `ease-out`, jangan berlebihan.

### 6.3 Katalog Micro-interaction

```
Button hover      → Lift
Button click       → Press (scale down)
Add to cart        → Fly-to-cart / product shrinks toward cart icon
Remove from cart    → Slide-out + fade
Quantity change     → Number slide transition (bukan snap)
Discount applied     → Price morph (angka lama → baru, smooth)
Payment success      → Circle expand → checkmark → text fade-in
Barcode scan         → Laser sweep animation
KDS new order         → Slide-in from top + subtle pulse + optional sound (toggle-able, default tidak keras)
KDS status change      → Layout transition antar kolom (Vue `<TransitionGroup>`)
Stock change             → Count-up/down animasi angka
Low stock warning         → Subtle pulse (bukan blink agresif)
Toast                      → Slide-in
Modal                       → Scale + fade
Drawer                       → Slide dari sisi terkait
Tab                           → Sliding indicator
Page navigation                → Fade + slide 8px (bukan full-screen loading tiap navigasi)
```

### 6.4 Library

- **Motion for Vue** — layout animation, spring, hover, drag, modal, drawer, list animation.
- **CSS transitions** — hover, focus, transisi sederhana.
- **Vue `<Transition>` / `<TransitionGroup>`** — page transition, list, conditional rendering.
- **Jangan** tambahkan GSAP kalau Motion + CSS sudah cukup — hindari over-engineering motion stack.

### 6.5 Larangan Eksplisit

```
❌ Glassmorphism berlebihan
❌ Floating everything
❌ Parallax
❌ Animasi besar/lambat yang menghalangi kerja
❌ Loading animation berlebihan
❌ Confetti / efek selebrasi berlebihan pada success state
```

---

## 7. Interactive Dashboard (Owner)

KPI card tidak statis — klik untuk expand ke detail:

```
Revenue Rp8.42M → klik → Today / Yesterday / This Week / This Month
                        + Top Product ranking (bar) → klik produk →
                        Product Analytics (sales, revenue, margin,
                        inventory usage, peak hour)
```

Sales chart interaktif: hover titik data menampilkan tooltip (tanggal, revenue, jumlah order); transisi chart yang halus saat filter periode berubah.

---

## 8. Coffee Shop Personality (Voice & Tone)

Greeting dashboard kontekstual sesuai waktu, tetap profesional — bukan garing:

```
Pagi   → "Good morning ☀️ Ready to brew something great?"
Siang  → "Good afternoon ☕ Here's how your shop is doing."
Malam  → "Good evening 🌙 Let's close the day strong."
```

**Prinsip penulisan UI (selaras dengan `frontend-design` skill):**
- Tulis dari sudut pandang pengguna: sebutkan apa yang mereka lakukan, bukan istilah sistem (mis. "Simpan perubahan", bukan "Submit").
- Aksi konsisten di seluruh alur: tombol "Bayar" → toast/notifikasi hasil juga bilang "Pembayaran berhasil", bukan istilah lain.
- Error tidak minta maaf dan tidak vague — jelaskan apa yang salah dan cara memperbaikinya, dalam suara sistem operasional (lihat §9 Error State).
- Empty state adalah ajakan bertindak, bukan pernyataan kosong pasif.

---

## 9. Empty, Loading & Error States

### 9.1 Empty State

Jangan pernah hanya "No data found." Selalu beri ikon kontekstual + penjelasan singkat + CTA jika relevan:

```
☕ No orders yet
Orders placed today will appear here.
[ GO TO POS ]

📦 Stock looks good
No low-stock items right now.
```

### 9.2 Loading State

Skeleton, bukan spinner terus-menerus — terutama grid produk POS harus terasa cepat dan tidak mengganggu alur kasir.

### 9.3 Error State

Ikon peringatan + judul jelas + penjelasan singkat + aksi pemulihan:

```
! Barcode not found
8991234567890
[ Search manually ]  [ Try again ]

! Payment failed
Please check the payment and try again.
[ TRY AGAIN ]
```

---

## 10. Dark Mode

| Role | Default | Opsional |
|---|---|---|
| Owner | Light | Dark |
| Cashier | Light | Dark |
| Barista/Kitchen | **Dark (permanen)** | — |

KDS default dark karena butuh kontras tinggi dan mengurangi glare di layar operasional dapur — ini bukan preferensi, tapi requirement fungsional (§3.3).

---

## 11. Responsive Breakpoints

| Konteks | Breakpoint / Resolusi optimal |
|---|---|
| Owner | Desktop ≥1280px, Tablet ≥768px, Mobile ≥390px |
| Cashier | 1024×768, 1280×800, 1920×1080 |
| KDS | 1280×720, 1920×1080 |

---

## 12. Visual Hierarchy per Flow

```
POS      : PRODUCT → CART → TOTAL → PAYMENT
KDS      : ORDER NUMBER → ITEMS → TIMER → ACTION
Owner    : KPI → TREND → INSIGHT → DETAIL
```

Setiap layout baru yang dibangun harus bisa dipetakan ke salah satu hierarki ini — kalau tidak cocok, pertanyakan apakah layout tersebut memang diperlukan.

---

## 13. Implementasi Teknis (selaras `AGENTS.md`)

- Semua token warna di §1.1 didefinisikan sebagai CSS variable di root, dipetakan ke Tailwind config (`tailwind.config` extend colors) — komponen **tidak** hardcode hex value.
- Komponen primitif dibangun di atas shadcn-vue sesuai daftar §2, ditempatkan di `components/ui/`.
- Komponen POS spesifik (`ProductCard`, `CartItem`, `ModifierSelector`, `PaymentMethod`, `TableCard`, `OrderCard`, `KDSCard`, `StockCard`, `KPI`, `SalesChart`, `BarcodeScanner`) ditempatkan di `components/pos/` dan `components/charts/`, dipakai lintas modul — dibangun di Sprint 1 sebagai bagian dari design system, bukan diciptakan ulang tiap modul butuh.
- Reduced motion dihormati (`prefers-reduced-motion`) — semua animasi non-esensial dinonaktifkan/diperlambat untuk pengguna yang mengaktifkan setting ini.
- Keyboard focus harus selalu terlihat jelas, khususnya di Cashier UI yang mengandalkan kecepatan (kemungkinan keyboard shortcut untuk workflow tertentu).

---

## 14. Checklist Sebelum Sprint UI Dianggap Selesai

```
✓ Menggunakan token warna/tipografi dari §1, bukan nilai ad-hoc
✓ Komponen dipakai dari design system (§2), bukan dibuat ulang lokal
✓ Density & tone sesuai role yang dituju (§3) — Owner ≠ Cashier ≠ Barista
✓ Animasi mengikuti skala durasi §6.2, ada alasan fungsional (bukan dekorasi)
✓ Ada empty/loading/error state untuk setiap halaman data (§9)
✓ Dark mode KDS aktif secara default, Owner/Cashier default light (§10)
✓ Responsive sesuai breakpoint role terkait (§11)
✓ prefers-reduced-motion dihormati, keyboard focus terlihat (§13)
```

Checklist ini melengkapi (bukan menggantikan) Definition of Done universal di `AGENTS.md` §4.
