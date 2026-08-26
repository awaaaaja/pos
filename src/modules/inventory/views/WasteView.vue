<script setup lang="ts">
import { ref, onMounted } from "vue";
import { CircleCheck } from "lucide-vue-next";
import { supabase } from "@/services/supabase";
import { useAuthStore } from "@/modules/auth/stores/auth";
import type { Product } from "@/types";

const auth = useAuthStore();
const products = ref<Product[]>([]);
const loading = ref(false);
const submitting = ref(false);

const form = ref({
  product_id: "",
  qty: 0,
  reason: "",
});

const outletId = ref("");
const success = ref(false);

onMounted(async () => {
  outletId.value = auth.user?.profile.outlet_id || "";
  loading.value = true;
  const { data } = await supabase.from("products").select("*").eq("is_active", true).order("name");
  products.value = data ?? [];
  loading.value = false;
});

async function handleSubmit() {
  if (!form.value.product_id || form.value.qty <= 0 || !form.value.reason.trim()) return;
  submitting.value = true;

  const { data, error } = await supabase.rpc("record_waste", {
    p_product_id: form.value.product_id,
    p_outlet_id: outletId.value,
    p_qty: form.value.qty,
    p_reason: form.value.reason,
    p_created_by: auth.user?.id,
  });

  submitting.value = false;

  if (error || data?.error) {
    alert(error?.message || data?.error || "Failed");
    return;
  }

  success.value = true;
  form.value = { product_id: "", qty: 0, reason: "" };
}
</script>

<template>
  <div class="mx-auto max-w-lg py-6">
    <h2 class="mb-6 text-2xl font-semibold">Record Waste</h2>

    <div v-if="loading" class="py-12 text-center text-secondary">Loading...</div>

    <form v-else class="rounded-2xl border bg-surface p-6" @submit.prevent="handleSubmit">
      <div class="space-y-4">
        <div>
          <label class="mb-1 block text-sm font-medium">Product *</label>
          <select
            v-model="form.product_id"
            class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
            required
          >
            <option value="" disabled>Select product...</option>
            <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">Quantity *</label>
          <input
            v-model.number="form.qty"
            type="number"
            min="0.01"
            step="0.01"
            class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
            required
          />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">Reason *</label>
          <textarea
            v-model="form.reason"
            rows="3"
            placeholder="Why is this being wasted?"
            class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
            required
          ></textarea>
        </div>
      </div>
      <div class="mt-6 flex justify-end">
        <button
          type="submit"
          :disabled="submitting"
          class="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-40"
        >
          {{ submitting ? "Recording..." : "Record Waste" }}
        </button>
      </div>
    </form>

    <Teleport to="body">
      <div
        v-if="success"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="success = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 text-center shadow-lg">
          <CircleCheck :size="40" :stroke-width="1.5" class="mx-auto mb-2 text-success" />
          <p class="text-lg font-semibold">Waste Recorded</p>
          <button
            class="mt-4 rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:opacity-90"
            @click="success = false"
          >
            OK
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>
