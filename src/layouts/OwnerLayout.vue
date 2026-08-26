<script setup lang="ts">
import { RouterView, RouterLink } from "vue-router";
import {
  LayoutDashboard,
  Tag,
  Coffee,
  Armchair,
  Factory,
  Package,
  ClipboardList,
  Trash2,
  Coins,
  ScrollText,
  Carrot,
  BookOpen,
  Users,
  Tag as TagIcon,
  BarChart3,
  Upload,
  Download,
  LogOut,
  Settings,
} from "lucide-vue-next";
import { useAuthStore } from "@/modules/auth/stores/auth";
import { useRouter } from "vue-router";

const auth = useAuthStore();
const router = useRouter();

async function handleLogout() {
  await auth.logout();
  router.push("/login");
}

const nav = [
  { label: "Dashboard", to: "/owner", icon: LayoutDashboard },
  { label: "Categories", to: "/owner/categories", icon: Tag },
  { label: "Products", to: "/owner/products", icon: Coffee },
  { label: "Customers", to: "/owner/customers", icon: Users },
  { label: "Promos", to: "/owner/promos", icon: TagIcon },
  { label: "Tables", to: "/owner/tables", icon: Armchair },
  { label: "Ingredients", to: "/owner/ingredients", icon: Carrot },
  { label: "Recipes", to: "/owner/recipes", icon: BookOpen },
  { label: "Suppliers", to: "/owner/suppliers", icon: Factory },
  { label: "Purchase Orders", to: "/owner/purchase-orders", icon: Package },
  { label: "Stock Opname", to: "/owner/stock-opname", icon: ClipboardList },
  { label: "Waste", to: "/owner/waste", icon: Trash2 },
  { label: "Expenses", to: "/owner/expenses", icon: Coins },
  { label: "Sales Report", to: "/owner/sales-report", icon: BarChart3 },
  { label: "Import", to: "/owner/import", icon: Upload },
  { label: "Export", to: "/owner/export", icon: Download },
  { label: "Settings", to: "/owner/settings", icon: Settings },
  { label: "Audit Log", to: "/owner/audit", icon: ScrollText },
];
</script>

<template>
  <div class="flex h-screen">
    <aside class="flex w-60 flex-col border-r bg-surface">
      <div class="border-b px-4 py-4">
        <h1 class="text-lg font-semibold text-primary">KopiPOS</h1>
        <p class="text-xs text-secondary">Owner</p>
      </div>
      <nav class="flex-1 space-y-1 p-3">
        <RouterLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition hover:bg-gray-100"
          active-class="!bg-primary/10 !text-primary font-medium"
          :exact="item.to === '/owner'"
        >
          <component :is="item.icon" :size="18" :stroke-width="1.8" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="border-t p-3">
        <button
          class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-gray-500 transition hover:bg-gray-100 hover:text-gray-700"
          @click="handleLogout"
        >
          <LogOut :size="18" :stroke-width="1.8" />
          <span>Logout</span>
        </button>
      </div>
    </aside>

    <main class="flex-1 overflow-auto p-6">
      <RouterView />
    </main>
  </div>
</template>
