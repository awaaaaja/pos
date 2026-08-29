# KopiPOS

Sistem Point of Sale & Manajemen untuk Coffee Shop. Dibangun dengan Vue 3 + TypeScript + Supabase.

## Tech Stack

- **Frontend:** Vue 3, TypeScript, Vite, Tailwind CSS v4, Pinia, Vue Router
- **Backend:** Supabase (PostgreSQL, Auth, RLS, Realtime, Edge Functions)
- **UI:** shadcn-vue components, Lucide icons

## Fitur

### Cashier (POS)
- Grid produk dengan foto & kategori
- Modifier (Ukuran, Tingkat Manis, Jenis Susu)
- Cart dengan quantity, note, subtotal
- Payment: Cash, QRIS, Debit, Credit, E-Wallet, Transfer
- Shift management (buka/tutup kasir)
- Hold & Resume order

### KDS (Kitchen Display)
- 3-column layout: NEW → PREPARING → READY
- Realtime updates via Supabase Realtime
- Multi-station: BAR & KITCHEN

### Owner Dashboard
- Dashboard: revenue, orders, top products, low stock alerts
- Produk & Kategori management
- Inventory: Stock Opname, Ingredients, Waste tracking
- Purchasing: Supplier & Purchase Order
- Customers & Loyalty
- Reports: Sales, expense breakdown
- Settings: Store info, tax, service charge, backup

## Akun Default

| Role | Login | PIN |
|------|-------|-----|
| Owner | `admin@kopipos.com` / `admin123` | - |
| Cashier | `cashier@kopipos.local` | `1111` |
| Barista | `barista@kopipos.local` | `2222` |

## Setup

```bash
# Install dependencies
npm install

# Copy env file
cp .env.example .env.local

# Edit .env.local with your Supabase credentials
# VITE_SUPABASE_URL=your_url
# VITE_SUPABASE_PUBLISHABLE_KEY=your_key

# Run development server
npm run dev

# Build for production
npm run build
```

## Database

- 36 tables dengan RLS policies
- 28 RPC functions
- 92 RLS policies
- Seed data: 36 produk, 5 kategori, 27 ingredients, 5 suppliers, 12 customers

Migrations ada di `supabase/migrations/`. Full setup SQL ada di `supabase/FULL_SETUP.sql`.

## Struktur

```
src/
├── modules/
│   ├── auth/          # Login, PIN auth, session
│   ├── pos/           # POS, cart, payment, modifiers
│   ├── kds/           # Kitchen display system
│   ├── products/      # Product & category management
│   ├── inventory/     # Stock opname, ingredients, waste
│   ├── purchasing/    # Suppliers & purchase orders
│   ├── customers/     # Customer & loyalty
│   ├── reports/       # Sales reports & dashboard
│   ├── shifts/        # Shift management
│   ├── expenses/      # Expense tracking
│   ├── settings/      # App settings
│   └── exports/       # Backup & export
├── layouts/           # OwnerLayout, CashierLayout, KdsLayout
├── services/          # Supabase client, printer, barcode
├── types/             # TypeScript types
└── router/            # Vue Router config
```

## License

Private - Untuk penggunaan internal.
