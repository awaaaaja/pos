<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "@/modules/auth/stores/auth";
import { hasOwner } from "@/modules/auth/services/auth";

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();

const mode = ref<"email" | "pin">("email");
const email = ref("");
const password = ref("");
const pin = ref("");
const errorMsg = ref("");
const checking = ref(true);

onMounted(async () => {
  const exists = await hasOwner();
  if (!exists) {
    router.replace({ name: "setup" });
    return;
  }
  checking.value = false;
});

async function handleEmailLogin() {
  errorMsg.value = "";
  const success = await auth.login(email.value, password.value);
  if (success) {
    const redirect = (route.query.redirect as string) || "/";
    router.push(redirect);
  } else {
    errorMsg.value = auth.error || "Login failed";
  }
}

async function handlePinLogin() {
  errorMsg.value = "";
  if (pin.value.length < 4) {
    errorMsg.value = "PIN must be at least 4 digits";
    return;
  }
  const success = await auth.loginWithPin(pin.value);
  if (success) {
    const role = auth.role;
    if (role === "cashier") {
      router.push({ name: "cashier-pos" });
    } else if (role === "barista") {
      router.push({ name: "kds-main" });
    } else {
      router.push({ name: "owner-dashboard" });
    }
  } else {
    errorMsg.value = auth.error || "Invalid PIN";
  }
}

function switchMode() {
  errorMsg.value = "";
  mode.value = mode.value === "email" ? "pin" : "email";
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-background">
    <div class="w-full max-w-sm rounded-2xl bg-surface p-8 shadow-sm">
      <div class="mb-8 text-center">
        <h1 class="text-2xl font-semibold text-primary">KopiPOS</h1>
        <p class="mt-1 text-sm text-secondary">Sign in to continue</p>
      </div>

      <div v-if="checking" class="py-8 text-center text-sm text-secondary">Loading...</div>

      <template v-else>
        <!-- Email Login (Owner) -->
        <form v-if="mode === 'email'" class="space-y-4" @submit.prevent="handleEmailLogin">
          <div>
            <label class="mb-1 block text-sm font-medium text-text">Email</label>
            <input
              v-model="email"
              type="email"
              placeholder="owner@kopipos.com"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              required
            />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium text-text">Password</label>
            <input
              v-model="password"
              type="password"
              placeholder="••••••••"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              required
            />
          </div>

          <p v-if="errorMsg" class="text-sm text-danger">{{ errorMsg }}</p>

          <button
            type="submit"
            :disabled="auth.loading"
            class="w-full rounded-lg bg-primary py-2.5 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50"
          >
            {{ auth.loading ? "Signing in..." : "Sign In" }}
          </button>
        </form>

        <!-- PIN Login (Cashier / Barista) -->
        <form v-else class="space-y-4" @submit.prevent="handlePinLogin">
          <div>
            <label class="mb-1 block text-sm font-medium text-text">Enter PIN</label>
            <input
              v-model="pin"
              type="password"
              inputmode="numeric"
              maxlength="6"
              placeholder="••••"
              class="w-full rounded-lg border border-gray-300 px-3 py-3 text-center text-2xl tracking-[0.5em] focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              autofocus
              required
            />
          </div>

          <p v-if="errorMsg" class="text-sm text-danger">{{ errorMsg }}</p>

          <button
            type="submit"
            :disabled="auth.loading"
            class="w-full rounded-lg bg-primary py-2.5 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50"
          >
            {{ auth.loading ? "Signing in..." : "Sign In with PIN" }}
          </button>
        </form>

        <button
          class="mt-4 w-full text-center text-sm text-secondary hover:text-primary"
          @click="switchMode"
        >
          {{ mode === "email" ? "Sign in with PIN instead" : "Sign in with email instead" }}
        </button>
      </template>
    </div>
  </div>
</template>
