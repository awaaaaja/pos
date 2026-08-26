<script setup lang="ts">
import { RouterView, RouterLink } from "vue-router";
import { LogOut } from "lucide-vue-next";
import { useAuthStore } from "@/modules/auth/stores/auth";
import { useRouter } from "vue-router";

const auth = useAuthStore();
const router = useRouter();

async function handleLogout() {
  await auth.logout();
  router.push("/login");
}
</script>

<template>
  <div class="flex h-screen flex-col">
    <header class="flex items-center justify-between border-b bg-surface px-4 py-2">
      <RouterLink to="/cashier" class="text-lg font-semibold text-primary">KopiPOS</RouterLink>
      <nav class="flex items-center gap-3">
        <RouterLink
          to="/cashier/shift"
          class="rounded-lg px-3 py-1.5 text-sm text-secondary transition hover:bg-gray-100"
          active-class="!bg-primary/10 !text-primary font-medium"
        >
          Shift
        </RouterLink>
        <button
          class="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-gray-500 transition hover:bg-gray-100 hover:text-gray-700"
          @click="handleLogout"
        >
          <LogOut :size="16" :stroke-width="1.8" />
          Logout
        </button>
      </nav>
    </header>
    <main class="flex-1 overflow-auto">
      <RouterView />
    </main>
  </div>
</template>
