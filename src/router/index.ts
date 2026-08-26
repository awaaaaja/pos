import { createRouter, createWebHistory } from "vue-router";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/setup",
      name: "setup",
      component: () => import("@/modules/auth/views/SetupView.vue"),
      meta: { requiresAuth: false },
    },
    {
      path: "/login",
      name: "login",
      component: () => import("@/modules/auth/views/LoginView.vue"),
      meta: { requiresAuth: false },
    },
    {
      path: "/",
      redirect: "/owner",
    },
    {
      path: "/owner",
      component: () => import("@/layouts/OwnerLayout.vue"),
      meta: { requiresAuth: true, role: "owner" },
      children: [
        {
          path: "",
          name: "owner-dashboard",
          component: () => import("@/modules/pos/views/DashboardView.vue"),
        },
        {
          path: "categories",
          name: "owner-categories",
          component: () => import("@/modules/products/views/CategoryView.vue"),
        },
        {
          path: "products",
          name: "owner-products",
          component: () => import("@/modules/products/views/ProductView.vue"),
        },
        {
          path: "tables",
          name: "owner-tables",
          component: () => import("@/modules/pos/views/TableView.vue"),
        },
        {
          path: "audit",
          name: "owner-audit",
          component: () => import("@/modules/audit/views/AuditLogView.vue"),
        },
        {
          path: "suppliers",
          name: "owner-suppliers",
          component: () => import("@/modules/purchasing/views/SupplierView.vue"),
        },
        {
          path: "purchase-orders",
          name: "owner-pos",
          component: () => import("@/modules/purchasing/views/PurchaseOrderView.vue"),
        },
        {
          path: "stock-opname",
          name: "owner-opname",
          component: () => import("@/modules/inventory/views/StockOpnameView.vue"),
        },
        {
          path: "waste",
          name: "owner-waste",
          component: () => import("@/modules/inventory/views/WasteView.vue"),
        },
        {
          path: "ingredients",
          name: "owner-ingredients",
          component: () => import("@/modules/inventory/views/IngredientsView.vue"),
        },
        {
          path: "recipes",
          name: "owner-recipes",
          component: () => import("@/modules/recipes/views/RecipeView.vue"),
        },
        {
          path: "customers",
          name: "owner-customers",
          component: () => import("@/modules/customers/views/CustomerView.vue"),
        },
        {
          path: "promos",
          name: "owner-promos",
          component: () => import("@/modules/promos/views/PromoView.vue"),
        },
        {
          path: "expenses",
          name: "owner-expenses",
          component: () => import("@/modules/expenses/views/ExpenseView.vue"),
        },
        {
          path: "sales-report",
          name: "owner-sales-report",
          component: () => import("@/modules/reports/views/SalesReportView.vue"),
        },
        {
          path: "import",
          name: "owner-import",
          component: () => import("@/modules/imports/views/ImportProductView.vue"),
        },
        {
          path: "export",
          name: "owner-export",
          component: () => import("@/modules/exports/views/ExportView.vue"),
        },
        {
          path: "settings",
          name: "owner-settings",
          component: () => import("@/modules/settings/views/SettingsView.vue"),
        },
      ],
    },
    {
      path: "/cashier",
      component: () => import("@/layouts/CashierLayout.vue"),
      meta: { requiresAuth: true, role: "cashier" },
      children: [
        {
          path: "",
          name: "cashier-pos",
          component: () => import("@/modules/pos/views/PosView.vue"),
        },
        {
          path: "payment/:orderId?",
          name: "cashier-payment",
          component: () => import("@/modules/pos/views/PaymentView.vue"),
        },
        {
          path: "shift",
          name: "cashier-shift",
          component: () => import("@/modules/shifts/views/ShiftView.vue"),
        },
      ],
    },
    {
      path: "/kds",
      component: () => import("@/layouts/KdsLayout.vue"),
      meta: { requiresAuth: true, role: "barista" },
      children: [
        {
          path: "",
          name: "kds-main",
          component: () => import("@/modules/kds/views/KdsView.vue"),
        },
      ],
    },
  ],
});

export default router;
