<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useTableStore } from "@/modules/pos/stores/table";

const store = useTableStore();

const showModal = ref(false);
const editingId = ref<string | null>(null);
const form = ref({ number: "", capacity: 4 });
const showTransferModal = ref(false);
const transferFrom = ref<string | null>(null);
const transferTo = ref<string | null>(null);

onMounted(() => {
  store.fetchTables();
});

const statusConfig = {
  available: { label: "Available", color: "bg-green-100 text-green-700", dot: "bg-green-500" },
  occupied: { label: "Occupied", color: "bg-amber-100 text-amber-700", dot: "bg-amber-500" },
  waiting_payment: {
    label: "Waiting Payment",
    color: "bg-orange-100 text-orange-700",
    dot: "bg-orange-500",
  },
};

function openCreate() {
  editingId.value = null;
  form.value = { number: "", capacity: 4 };
  showModal.value = true;
}

function openEdit(table: { id: string; number: string; capacity: number }) {
  editingId.value = table.id;
  form.value = { number: table.number, capacity: table.capacity };
  showModal.value = true;
}

async function handleSubmit() {
  if (!form.value.number.trim()) return;

  if (editingId.value) {
    await store.editTable(editingId.value, form.value);
  } else {
    // Use first outlet for now
    const firstTable = store.tables[0];
    const outletId = firstTable?.outlet_id;
    if (!outletId) {
      alert("No outlet found. Create an outlet first.");
      return;
    }
    await store.addTable({ outlet_id: outletId, ...form.value });
  }
  showModal.value = false;
}

async function handleDelete(id: string) {
  if (confirm("Delete this table?")) {
    await store.remove(id);
  }
}

function openTransfer(tableId: string) {
  transferFrom.value = tableId;
  transferTo.value = null;
  showTransferModal.value = true;
}

async function handleTransfer() {
  if (!transferFrom.value || !transferTo.value) return;
  await store.transfer(transferFrom.value, transferTo.value);
  showTransferModal.value = false;
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Tables</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
        @click="openCreate"
      >
        + Add Table
      </button>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="py-12 text-center text-secondary">Loading...</div>

    <!-- Empty -->
    <div
      v-else-if="store.tables.length === 0"
      class="rounded-2xl border border-dashed border-gray-300 py-12 text-center"
    >
      <p class="text-secondary">No tables yet</p>
      <button class="mt-2 text-sm text-primary hover:underline" @click="openCreate">Add one</button>
    </div>

    <!-- Floor plan grid -->
    <div v-else class="grid grid-cols-3 gap-4 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
      <button
        v-for="table in store.tables"
        :key="table.id"
        :class="[
          table.status === 'available'
            ? 'border-green-300 bg-green-50 hover:border-green-400'
            : table.status === 'occupied'
              ? 'border-amber-300 bg-amber-50 hover:border-amber-400'
              : 'border-orange-300 bg-orange-50 hover:border-orange-400',
        ]"
        class="flex flex-col items-center rounded-xl border-2 p-4 transition"
        @click="openEdit(table)"
      >
        <div :class="statusConfig[table.status].dot" class="mb-2 h-3 w-3 rounded-full" />
        <p class="text-lg font-bold">{{ table.number }}</p>
        <p class="text-xs text-secondary">{{ table.capacity }} seats</p>
        <p class="mt-1 text-[10px] font-medium" :class="statusConfig[table.status].color">
          {{ statusConfig[table.status].label }}
        </p>
        <button
          v-if="table.status === 'occupied'"
          class="mt-2 rounded bg-primary/10 px-2 py-0.5 text-[10px] text-primary hover:bg-primary/20"
          @click.stop="openTransfer(table.id)"
        >
          Transfer
        </button>
      </button>
    </div>

    <!-- Create/Edit Modal -->
    <Teleport to="body">
      <div
        v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showModal = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">
            {{ editingId ? "Edit Table" : "New Table" }}
          </h3>
          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div>
              <label class="mb-1 block text-sm font-medium">Table Number</label>
              <input
                v-model="form.number"
                type="text"
                placeholder="e.g. A01"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Capacity</label>
              <input
                v-model.number="form.capacity"
                type="number"
                min="1"
                max="20"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                {{ editingId ? "Save" : "Create" }}
              </button>
            </div>
            <button
              v-if="editingId"
              type="button"
              class="w-full text-center text-sm text-danger hover:underline"
              @click="
                handleDelete(editingId!);
                showModal = false;
              "
            >
              Delete Table
            </button>
          </form>
        </div>
      </div>

      <!-- Transfer Modal -->
      <div
        v-if="showTransferModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showTransferModal = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">Transfer Table</h3>
          <div class="mb-4">
            <label class="mb-1 block text-sm font-medium">Move to Table</label>
            <select
              v-model="transferTo"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none"
            >
              <option value="" disabled>Select table...</option>
              <option
                v-for="t in store.tables.filter(
                  (t) => t.status === 'available' && t.id !== transferFrom,
                )"
                :key="t.id"
                :value="t.id"
              >
                {{ t.number }} (Available)
              </option>
            </select>
          </div>
          <div class="flex justify-end gap-2">
            <button
              class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
              @click="showTransferModal = false"
            >
              Cancel
            </button>
            <button
              :disabled="!transferTo"
              class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-40"
              @click="handleTransfer"
            >
              Transfer
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
