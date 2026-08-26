<script setup lang="ts">
import { RouterView } from "vue-router";
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
  <div class="flex h-screen flex-col bg-gray-950 text-white">
    <header class="flex items-center justify-between border-b border-gray-800 px-4 py-2">
      <h1 class="text-lg font-semibold">BAR / KITCHEN</h1>
      <button
        class="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-gray-400 transition hover:bg-gray-800 hover:text-white"
        @click="handleLogout"
      >
        <LogOut :size="16" :stroke-width="1.8" />
        Logout
      </button>
    </header>
    <main class="flex-1 overflow-auto p-4">
      <RouterView />
    </main>
  </div>
</template>
