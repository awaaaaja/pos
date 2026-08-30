<script setup lang="ts">
import { ref, onMounted } from "vue";
import { createBackup } from "@/modules/exports/services/backup";
import { Settings, Download, Shield, Store } from "lucide-vue-next";

const storeName = ref("KopiPOS");
const storeAddress = ref("");
const storePhone = ref("");
const taxRate = ref(10);
const serviceCharge = ref(5);
const lowStockThreshold = ref(10);
const saving = ref(false);
const backedUp = ref(false);

onMounted(() => {
  const saved = localStorage.getItem("kopipos_settings");
  if (saved) {
    const s = JSON.parse(saved);
    storeName.value = s.storeName ?? "KopiPOS";
    storeAddress.value = s.storeAddress ?? "";
    storePhone.value = s.storePhone ?? "";
    taxRate.value = s.taxRate ?? 10;
    serviceCharge.value = s.serviceCharge ?? 5;
    lowStockThreshold.value = s.lowStockThreshold ?? 10;
  }
});

function save() {
  saving.value = true;
  localStorage.setItem(
    "kopipos_settings",
    JSON.stringify({
      storeName: storeName.value,
      storeAddress: storeAddress.value,
      storePhone: storePhone.value,
      taxRate: taxRate.value,
      serviceCharge: serviceCharge.value,
      lowStockThreshold: lowStockThreshold.value,
    }),
  );
  saving.value = false;
}

async function handleBackup() {
  const r = await createBackup();
  backedUp.value = r.success;
}

</script>

<template>
  <div class="mx-auto max-w-2xl space-y-6">
    <h2 class="text-lg font-semibold text-white">Settings</h2>

    <!-- Store Info -->
    <div class="rounded-xl border border-gray-700 bg-gray-800 p-5">
      <h3 class="mb-4 flex items-center gap-2 text-sm font-medium text-gray-300">
        <Store class="h-4 w-4" /> Store Information
      </h3>
      <div class="space-y-3">
        <div>
          <label class="mb-1 block text-xs text-gray-400">Store Name</label>
          <input v-model="storeName" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
        <div>
          <label class="mb-1 block text-xs text-gray-400">Address</label>
          <input v-model="storeAddress" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
        <div>
          <label class="mb-1 block text-xs text-gray-400">Phone</label>
          <input v-model="storePhone" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
      </div>
    </div>

    <!-- POS Behavior -->
    <div class="rounded-xl border border-gray-700 bg-gray-800 p-5">
      <h3 class="mb-4 flex items-center gap-2 text-sm font-medium text-gray-300">
        <Settings class="h-4 w-4" /> POS Behavior
      </h3>
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="mb-1 block text-xs text-gray-400">Tax Rate (%)</label>
          <input v-model.number="taxRate" type="number" min="0" max="100" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
        <div>
          <label class="mb-1 block text-xs text-gray-400">Service Charge (%)</label>
          <input v-model.number="serviceCharge" type="number" min="0" max="100" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
        <div>
          <label class="mb-1 block text-xs text-gray-400">Low Stock Threshold</label>
          <input v-model.number="lowStockThreshold" type="number" min="0" class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        </div>
      </div>
    </div>

    <!-- Backup -->
    <div class="rounded-xl border border-gray-700 bg-gray-800 p-5">
      <h3 class="mb-4 flex items-center gap-2 text-sm font-medium text-gray-300">
        <Download class="h-4 w-4" /> Backup
      </h3>
      <p class="mb-3 text-sm text-gray-400">Export all data as JSON file for portability.</p>
      <button
        class="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500"
        @click="handleBackup"
      >
        <Download class="h-4 w-4" />
        {{ backedUp ? "Backup Saved!" : "Download Backup" }}
      </button>
    </div>

    <!-- Security Info -->
    <div class="rounded-xl border border-gray-700 bg-gray-800 p-5">
      <h3 class="mb-4 flex items-center gap-2 text-sm font-medium text-gray-300">
        <Shield class="h-4 w-4" /> Security
      </h3>
      <ul class="space-y-2 text-sm text-gray-400">
        <li>RLS policies active on all tables</li>
        <li>Owner PIN required for void/refund</li>
        <li>Audit logging enabled for all sensitive operations</li>
        <li>PIN hashed with SHA-256</li>
      </ul>
    </div>

    <button
      class="w-full rounded-lg bg-amber-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-amber-500"
      @click="save"
    >
      {{ saving ? "Saving..." : "Save Settings" }}
    </button>
  </div>
</template>
