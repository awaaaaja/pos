<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { setupOwner, hasOwner } from "@/modules/auth/services/auth";

const router = useRouter();

const fullName = ref("");
const email = ref("");
const password = ref("");
const confirmPassword = ref("");
const pinCode = ref("");
const errorMsg = ref("");
const loading = ref(false);
const checking = ref(true);

onMounted(async () => {
  const exists = await hasOwner();
  if (exists) {
    router.replace("/login");
    return;
  }
  checking.value = false;
});

async function handleSetup() {
  errorMsg.value = "";

  if (!fullName.value || !email.value || !password.value || !pinCode.value) {
    errorMsg.value = "All fields are required";
    return;
  }

  if (password.value !== confirmPassword.value) {
    errorMsg.value = "Passwords do not match";
    return;
  }

  if (password.value.length < 6) {
    errorMsg.value = "Password must be at least 6 characters";
    return;
  }

  if (pinCode.value.length < 4 || pinCode.value.length > 6) {
    errorMsg.value = "PIN must be 4-6 digits";
    return;
  }

  loading.value = true;
  const result = await setupOwner(email.value, password.value, fullName.value, pinCode.value);
  loading.value = false;

  if (result.error) {
    errorMsg.value = result.error;
    return;
  }

  router.push({ name: "owner-dashboard" });
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-background">
    <div class="w-full max-w-sm rounded-2xl bg-surface p-8 shadow-sm">
      <div class="mb-8 text-center">
        <h1 class="text-2xl font-semibold text-primary">KopiPOS Setup</h1>
        <p class="mt-1 text-sm text-secondary">Create your owner account</p>
      </div>

      <div v-if="checking" class="py-8 text-center text-sm text-secondary">Checking system...</div>

      <form v-else class="space-y-4" @submit.prevent="handleSetup">
        <div>
          <label class="mb-1 block text-sm font-medium text-text">Full Name</label>
          <input
            v-model="fullName"
            type="text"
            placeholder="Your name"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            required
          />
        </div>
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
            placeholder="At least 6 characters"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            required
          />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-text">Confirm Password</label>
          <input
            v-model="confirmPassword"
            type="password"
            placeholder="Re-enter password"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            required
          />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-text">PIN Code (4-6 digits)</label>
          <input
            v-model="pinCode"
            type="password"
            inputmode="numeric"
            maxlength="6"
            placeholder="••••"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-center text-2xl tracking-[0.5em] focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            required
          />
        </div>

        <p v-if="errorMsg" class="text-sm text-danger">{{ errorMsg }}</p>

        <button
          type="submit"
          :disabled="loading"
          class="w-full rounded-lg bg-primary py-2.5 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50"
        >
          {{ loading ? "Setting up..." : "Create Owner Account" }}
        </button>
      </form>
    </div>
  </div>
</template>
