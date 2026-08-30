<script setup lang="ts">
import { onMounted, ref, computed } from "vue";
import { useShiftStore } from "@/modules/shifts/stores/shift";
import { useAuthStore } from "@/modules/auth/stores/auth";

const shift = useShiftStore();
const auth = useAuthStore();

const showOpenModal = ref(false);
const showCloseModal = ref(false);
const showCashModal = ref(false);
const cashModalType = ref<"cash_in" | "cash_out">("cash_in");

const openingCash = ref(0);
const closingCash = ref(0);
const cashAmount = ref(0);
const cashDescription = ref("");

const cashierId = computed(() => auth.user?.id ?? "");
const outletId = computed(() => auth.user?.profile.outlet_id ?? "");

onMounted(() => {
  if (cashierId.value) {
    shift.fetchOpenShift(cashierId.value, outletId.value);
  }
});

function openCashModal(type: "cash_in" | "cash_out") {
  cashModalType.value = type;
  cashAmount.value = 0;
  cashDescription.value = "";
  showCashModal.value = true;
}

async function handleOpenShift() {
  const ok = await shift.openNewShift(outletId.value, cashierId.value, openingCash.value);
  if (ok) showOpenModal.value = false;
}

async function handleCloseShift() {
  const ok = await shift.closeCurrentShift(closingCash.value);
  if (ok) showCloseModal.value = false;
}

async function handleCashMovement() {
  const ok = await shift.addCashMovement(
    cashModalType.value,
    cashAmount.value,
    cashDescription.value,
  );
  if (ok) showCashModal.value = false;
}

function formatCurrency(n: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
  }).format(n);
}
</script>

<template>
  <div class="mx-auto max-w-lg py-6">
    <h2 class="mb-6 text-2xl font-semibold">Shift</h2>

    <div v-if="shift.loading" class="py-12 text-center text-secondary">Loading...</div>

    <!-- No open shift -->
    <div v-else-if="!shift.isOpen" class="rounded-2xl border bg-surface p-6 text-center">
      <p class="mb-4 text-secondary">No active shift</p>
      <button
        class="rounded-xl bg-primary px-6 py-3 text-sm font-semibold text-white hover:opacity-90"
        @click="showOpenModal = true"
      >
        Open Shift
      </button>
    </div>

    <!-- Active shift -->
    <template v-else>
      <!-- Status card -->
      <div class="mb-6 rounded-2xl border bg-surface p-4">
        <div class="mb-3 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="h-2 w-2 rounded-full bg-green-500" />
            <span class="text-sm font-medium">Shift Open</span>
          </div>
          <span class="text-xs text-secondary">
            Opened {{ new Date(shift.currentShift!.opened_at).toLocaleTimeString("id-ID") }}
          </span>
        </div>
        <div class="grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-lg bg-gray-50 p-3">
            <p class="text-xs text-secondary">Opening Cash</p>
            <p class="font-semibold">{{ formatCurrency(shift.currentShift!.opening_cash) }}</p>
          </div>
          <div class="rounded-lg bg-gray-50 p-3">
            <p class="text-xs text-secondary">Cash Sales</p>
            <p class="font-semibold text-green-700">{{ formatCurrency(shift.cashSales) }}</p>
          </div>
          <div class="rounded-lg bg-gray-50 p-3">
            <p class="text-xs text-secondary">Cash In</p>
            <p class="font-semibold text-blue-700">{{ formatCurrency(shift.cashIn) }}</p>
          </div>
          <div class="rounded-lg bg-gray-50 p-3">
            <p class="text-xs text-secondary">Cash Out</p>
            <p class="font-semibold text-red-700">{{ formatCurrency(shift.cashOut) }}</p>
          </div>
          <div class="col-span-2 rounded-lg bg-primary/5 p-3">
            <p class="text-xs text-secondary">Expected Cash in Drawer</p>
            <p class="text-lg font-bold text-primary">{{ formatCurrency(shift.expectedCash) }}</p>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="mb-6 flex gap-3">
        <button
          class="flex-1 rounded-xl border px-4 py-3 text-sm font-medium transition hover:bg-gray-50"
          @click="openCashModal('cash_in')"
        >
          Cash In
        </button>
        <button
          class="flex-1 rounded-xl border px-4 py-3 text-sm font-medium transition hover:bg-gray-50"
          @click="openCashModal('cash_out')"
        >
          Cash Out
        </button>
        <button
          class="flex-1 rounded-xl bg-danger px-4 py-3 text-sm font-medium text-white transition hover:opacity-90"
          @click="showCloseModal = true"
        >
          Close Shift
        </button>
      </div>

      <!-- Movements list -->
      <div v-if="shift.movements.length > 0">
        <h3 class="mb-3 text-sm font-medium">Cash Movements</h3>
        <div class="divide-y rounded-2xl border bg-surface">
          <div
            v-for="m in shift.movements"
            :key="m.id"
            class="flex items-center justify-between px-4 py-3"
          >
            <div>
              <p class="text-sm font-medium capitalize">{{ m.type.replace("_", " ") }}</p>
              <p class="text-xs text-secondary">
                {{ m.description || m.reference || "-" }}
                {{ new Date(m.created_at).toLocaleTimeString("id-ID") }}
              </p>
            </div>
            <span
              :class="
                m.type === 'cash_out' || m.type === 'refund' ? 'text-danger' : 'text-green-700'
              "
              class="text-sm font-semibold"
            >
              {{ m.type === "cash_out" || m.type === "refund" ? "-" : "+" }}
              {{ formatCurrency(m.amount) }}
            </span>
          </div>
        </div>
      </div>
    </template>

    <!-- Open Shift Modal -->
    <Teleport to="body">
      <div
        v-if="showOpenModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showOpenModal = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">Open Shift</h3>
          <form class="space-y-4" @submit.prevent="handleOpenShift">
            <div>
              <label class="mb-1 block text-sm font-medium">Opening Cash</label>
              <input
                v-model.number="openingCash"
                type="number"
                min="0"
                placeholder="Amount in drawer"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div class="flex justify-end gap-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showOpenModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                Open
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Close Shift Modal -->
      <div
        v-if="showCloseModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showCloseModal = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">Close Shift</h3>
          <div class="mb-4 rounded-lg bg-gray-50 p-3 text-sm">
            <p class="text-secondary">Expected cash:</p>
            <p class="text-lg font-bold text-primary">{{ formatCurrency(shift.expectedCash) }}</p>
          </div>
          <form class="space-y-4" @submit.prevent="handleCloseShift">
            <div>
              <label class="mb-1 block text-sm font-medium">Actual Cash in Drawer</label>
              <input
                v-model.number="closingCash"
                type="number"
                min="0"
                placeholder="Count and enter"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div v-if="closingCash > 0" class="rounded-lg p-3 text-sm">
              <p class="text-secondary">Difference:</p>
              <p
                :class="closingCash - shift.expectedCash >= 0 ? 'text-green-700' : 'text-danger'"
                class="text-lg font-bold"
              >
                {{ formatCurrency(closingCash - shift.expectedCash) }}
              </p>
            </div>
            <p v-if="shift.error" class="text-sm text-danger">{{ shift.error }}</p>
            <div class="flex justify-end gap-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showCloseModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-danger px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                Close Shift
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Cash In/Out Modal -->
      <div
        v-if="showCashModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showCashModal = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold capitalize">
            {{ cashModalType === "cash_in" ? "Cash In" : "Cash Out" }}
          </h3>
          <form class="space-y-4" @submit.prevent="handleCashMovement">
            <div>
              <label class="mb-1 block text-sm font-medium">Amount</label>
              <input
                v-model.number="cashAmount"
                type="number"
                min="1"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Description</label>
              <input
                v-model="cashDescription"
                type="text"
                placeholder="e.g. Petty cash, Change fund"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div class="flex justify-end gap-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showCashModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                Record
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>
