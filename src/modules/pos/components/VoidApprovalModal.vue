<script setup lang="ts">
import { ref } from "vue";
import { voidOrder } from "@/modules/pos/services/payment";
import { useAuthStore } from "@/modules/auth/stores/auth";

const props = defineProps<{
  orderId: string;
}>();

const emit = defineEmits<{
  (e: "close"): void;
  (e: "voided"): void;
}>();

const auth = useAuthStore();
const ownerPin = ref("");
const reason = ref("");
const loading = ref(false);
const error = ref<string | null>(null);

async function handleVoid() {
  if (!ownerPin.value || !reason.value.trim()) return;
  loading.value = true;
  error.value = null;

  // Verify owner PIN
  const pinValid = await auth.verifyPin(ownerPin.value);
  if (!pinValid) {
    error.value = "Invalid owner PIN";
    loading.value = false;
    return;
  }

  const result = await voidOrder(props.orderId, reason.value, auth.user?.id ?? "");
  loading.value = false;

  if (result.error) {
    error.value = result.error;
    return;
  }

  emit("voided");
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
      <h3 class="mb-1 text-lg font-semibold text-danger">Void Order</h3>
      <p class="mb-4 text-sm text-secondary">Owner PIN required for approval</p>

      <form class="space-y-4" @submit.prevent="handleVoid">
        <div>
          <label class="mb-1 block text-sm font-medium">Owner PIN</label>
          <input
            v-model="ownerPin"
            type="password"
            inputmode="numeric"
            maxlength="6"
            placeholder="Enter 6-digit PIN"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-center text-lg tracking-[0.3em] focus:border-danger focus:outline-none focus:ring-1 focus:ring-danger"
            required
          />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">Reason</label>
          <textarea
            v-model="reason"
            rows="2"
            placeholder="Why voiding this order?"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-danger focus:outline-none focus:ring-1 focus:ring-danger"
            required
          />
        </div>

        <p v-if="error" class="text-sm text-danger">{{ error }}</p>

        <div class="flex gap-2 pt-2">
          <button
            type="button"
            class="flex-1 rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
            @click="emit('close')"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="!ownerPin || !reason.trim() || loading"
            class="flex-1 rounded-lg bg-danger px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-40"
          >
            {{ loading ? "Processing..." : "Void Order" }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
