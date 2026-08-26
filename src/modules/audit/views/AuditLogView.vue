<script setup lang="ts">
import { ref, onMounted } from "vue";
import { getAuditLogs, type AuditLogFilters } from "@/modules/audit/services/audit";
import type { AuditLog } from "@/types";

const logs = ref<AuditLog[]>([]);
const loading = ref(false);

const filters = ref<AuditLogFilters>({
  dateFrom: "",
  dateTo: "",
  action: "",
  entity_type: "",
});

const actions = [
  "login",
  "logout",
  "create",
  "update",
  "delete",
  "void",
  "refund",
  "discount",
  "payment",
  "stock_adjustment",
  "stock_opname",
  "shift_open",
  "shift_close",
  "import",
  "export",
];

onMounted(() => fetchLogs());

async function fetchLogs() {
  loading.value = true;
  const result = await getAuditLogs(filters.value, 200);
  logs.value = result.data ?? [];
  loading.value = false;
}

function clearFilters() {
  filters.value = { dateFrom: "", dateTo: "", action: "", entity_type: "" };
  fetchLogs();
}

function formatTime(ts: string) {
  return new Date(ts).toLocaleString("id-ID", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

const actionColors: Record<string, string> = {
  login: "bg-blue-100 text-blue-700",
  logout: "bg-gray-100 text-gray-700",
  create: "bg-green-100 text-green-700",
  update: "bg-yellow-100 text-yellow-700",
  delete: "bg-red-100 text-red-700",
  void: "bg-red-100 text-red-700",
  refund: "bg-orange-100 text-orange-700",
  payment: "bg-green-100 text-green-700",
  shift_open: "bg-blue-100 text-blue-700",
  shift_close: "bg-indigo-100 text-indigo-700",
  discount: "bg-purple-100 text-purple-700",
};
</script>

<template>
  <div>
    <h2 class="mb-6 text-2xl font-semibold">Audit Log</h2>

    <!-- Filters -->
    <div class="mb-4 flex flex-wrap items-end gap-3 rounded-2xl border bg-surface p-4">
      <div>
        <label class="mb-1 block text-xs text-secondary">From</label>
        <input
          v-model="filters.dateFrom"
          type="datetime-local"
          class="rounded-lg border px-2 py-1.5 text-sm"
          @change="fetchLogs"
        />
      </div>
      <div>
        <label class="mb-1 block text-xs text-secondary">To</label>
        <input
          v-model="filters.dateTo"
          type="datetime-local"
          class="rounded-lg border px-2 py-1.5 text-sm"
          @change="fetchLogs"
        />
      </div>
      <div>
        <label class="mb-1 block text-xs text-secondary">Action</label>
        <select
          v-model="filters.action"
          class="rounded-lg border px-2 py-1.5 text-sm"
          @change="fetchLogs"
        >
          <option value="">All</option>
          <option v-for="a in actions" :key="a" :value="a">{{ a }}</option>
        </select>
      </div>
      <div>
        <label class="mb-1 block text-xs text-secondary">Entity Type</label>
        <input
          v-model="filters.entity_type"
          type="text"
          placeholder="e.g. order"
          class="rounded-lg border px-2 py-1.5 text-sm"
          @change="fetchLogs"
        />
      </div>
      <button
        class="rounded-lg border px-3 py-1.5 text-sm text-secondary hover:bg-gray-50"
        @click="clearFilters"
      >
        Clear
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="py-12 text-center text-secondary">Loading...</div>

    <!-- Empty -->
    <div
      v-else-if="logs.length === 0"
      class="rounded-2xl border bg-surface py-12 text-center text-secondary"
    >
      No audit logs found
    </div>

    <!-- Log table -->
    <div v-else class="overflow-x-auto rounded-2xl border bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b bg-gray-50 text-xs text-secondary">
          <tr>
            <th class="px-4 py-2">Timestamp</th>
            <th class="px-4 py-2">Actor</th>
            <th class="px-4 py-2">Action</th>
            <th class="px-4 py-2">Entity</th>
            <th class="px-4 py-2">Detail</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="log in logs" :key="log.id" class="hover:bg-gray-50">
            <td class="whitespace-nowrap px-4 py-2 text-xs">{{ formatTime(log.created_at) }}</td>
            <td class="px-4 py-2 text-sm">{{ log.actor_name || "system" }}</td>
            <td class="px-4 py-2">
              <span
                :class="actionColors[log.action] || 'bg-gray-100 text-gray-700'"
                class="inline-block rounded-full px-2 py-0.5 text-xs font-medium"
              >
                {{ log.action }}
              </span>
            </td>
            <td class="px-4 py-2 text-xs text-secondary">
              {{ log.entity_type || "-" }}
              <span v-if="log.entity_id" class="font-mono text-[10px]">
                {{ log.entity_id.slice(0, 8) }}...
              </span>
            </td>
            <td class="max-w-xs truncate px-4 py-2 text-xs">
              <span v-if="log.reason" class="text-secondary italic">"{{ log.reason }}"</span>
              <span v-else-if="log.detail" class="font-mono text-secondary">
                {{ JSON.stringify(log.detail).slice(0, 60) }}
              </span>
              <span v-else class="text-secondary">-</span>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="border-t px-4 py-2 text-xs text-secondary">{{ logs.length }} entries</div>
    </div>
  </div>
</template>
