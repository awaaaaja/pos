<script setup lang="ts">
import { onMounted, ref } from "vue";
import { X } from "lucide-vue-next";
import { useToast } from "@/composables/useToast";
import {
  getPOs,
  createPO,
  approvePO,
  orderPO,
  getPO,
  receivePO,
} from "@/modules/purchasing/services/purchaseOrder";
import { useSupplierStore } from "@/modules/purchasing/stores/supplier";
import { useProductStore } from "@/modules/products/stores/product";
import { useAuthStore } from "@/modules/auth/stores/auth";
import ScanBarcode from "@/modules/barcode/components/ScanBarcode.vue";
import type { PurchaseOrder } from "@/types";

const supplierStore = useSupplierStore();
const productStore = useProductStore();
const auth = useAuthStore();
const toast = useToast();

const pos = ref<PurchaseOrder[]>([]);
const loading = ref(false);
const showCreateModal = ref(false);
const showReceiveModal = ref(false);
const showPoScan = ref(false);
const selectedPO = ref<PurchaseOrder | null>(null);

// Create form
const poForm = ref({ supplier_id: "", notes: "" });
const poItems = ref<
  { product_id: string; product_name: string; expected_qty: number; unit_cost: number }[]
>([]);

// Receive form
const receiveQty = ref(0);
const receiveProductId = ref<string | null>(null);

const statusColors: Record<string, string> = {
  draft: "bg-gray-100 text-gray-700",
  approved: "bg-blue-100 text-blue-700",
  ordered: "bg-yellow-100 text-yellow-700",
  partially_received: "bg-orange-100 text-orange-700",
  completed: "bg-green-100 text-green-700",
  cancelled: "bg-red-100 text-red-700",
};

onMounted(() => {
  fetch();
  supplierStore.fetch();
  productStore.fetchProducts();
});

async function fetch() {
  loading.value = true;
  const r = await getPOs();
  pos.value = r.data ?? [];
  loading.value = false;
}

function openCreate() {
  poForm.value = { supplier_id: "", notes: "" };
  poItems.value = [];
  showCreateModal.value = true;
}

function addPoItem() {
  poItems.value.push({ product_id: "", product_name: "", expected_qty: 1, unit_cost: 0 });
}

function removePoItem(i: number) {
  poItems.value.splice(i, 1);
}

function onPoBarcode(product: { id: string; name: string; barcode: string | null }) {
  if (poItems.value.some((i) => i.product_id === product.id)) return;
  poItems.value.push({
    product_id: product.id,
    product_name: product.name,
    expected_qty: 1,
    unit_cost: 0,
  });
}

async function handleCreatePO() {
  if (!poForm.value.supplier_id || poItems.value.length === 0) return;
  const items = poItems.value.map((i) => ({
    product_id: i.product_id,
    expected_qty: i.expected_qty,
    unit_cost: i.unit_cost,
  }));
  const r = await createPO(poForm.value.supplier_id, items, poForm.value.notes);
  if (r.error) {
    toast.error(r.error);
    return;
  }
  showCreateModal.value = false;
  await fetch();
}

async function handleApprove(id: string) {
  if (!confirm("Approve this PO?")) return;
  const r = await approvePO(id);
  if (r.error) toast.error(r.error);
  await fetch();
}

async function handleOrder(id: string) {
  if (!confirm("Mark as ordered?")) return;
  const r = await orderPO(id);
  if (r.error) toast.error(r.error);
  await fetch();
}

async function openReceive(po: PurchaseOrder) {
  const r = await getPO(po.id);
  selectedPO.value = r.data;
  receiveQty.value = 0;
  receiveProductId.value = null;
  showReceiveModal.value = true;
}

function onReceiveBarcode(product: { id: string; name: string; barcode: string | null }) {
  receiveProductId.value = product.id;
}

async function handleReceive() {
  if (!selectedPO.value || !receiveProductId.value || receiveQty.value <= 0) return;
  const outletId = auth.user?.profile.outlet_id || "";
  const r = await receivePO(
    selectedPO.value.id,
    receiveProductId.value,
    receiveQty.value,
    outletId,
  );
  if (r.error) {
    toast.error(r.error);
    return;
  }
  const updated = await getPO(selectedPO.value.id);
  selectedPO.value = updated.data;
  receiveQty.value = 0;
  receiveProductId.value = null;
  await fetch();
}
</script>

<template>
  <div class="mx-auto max-w-5xl py-6">
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Purchase Orders</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
        @click="openCreate"
      >
        + New PO
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-secondary">Loading...</div>
    <div
      v-else-if="pos.length === 0"
      class="rounded-2xl border border-dashed py-12 text-center text-secondary"
    >
      No purchase orders yet
    </div>
    <div v-else class="space-y-3">
      <div v-for="po in pos" :key="po.id" class="rounded-2xl border bg-surface p-4">
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-2">
              <span class="font-mono text-sm font-semibold">{{ po.order_number }}</span>
              <span
                :class="statusColors[po.status]"
                class="rounded-full px-2 py-0.5 text-xs font-medium"
                >{{ po.status.replace("_", " ") }}</span
              >
            </div>
            <p class="mt-1 text-sm text-secondary">
              {{ po.supplier?.name }} · {{ po.items?.length ?? 0 }} items
            </p>
          </div>
          <div class="flex gap-2">
            <button
              v-if="po.status === 'draft'"
              class="rounded-lg border px-3 py-1.5 text-xs font-medium hover:bg-gray-50"
              @click="handleApprove(po.id)"
            >
              Approve
            </button>
            <button
              v-if="po.status === 'approved'"
              class="rounded-lg border px-3 py-1.5 text-xs font-medium hover:bg-gray-50"
              @click="handleOrder(po.id)"
            >
              Mark Ordered
            </button>
            <button
              v-if="['ordered', 'partially_received'].includes(po.status)"
              class="rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white hover:opacity-90"
              @click="openReceive(po)"
            >
              Receive
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Create PO Modal -->
    <Teleport to="body">
      <div
        v-if="showCreateModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showCreateModal = false"
      >
        <div
          class="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-lg"
        >
          <h3 class="mb-4 text-lg font-semibold">New Purchase Order</h3>
          <form class="space-y-4" @submit.prevent="handleCreatePO">
            <div>
              <label class="mb-1 block text-sm font-medium">Supplier *</label>
              <select
                v-model="poForm.supplier_id"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                required
              >
                <option value="" disabled>Select supplier...</option>
                <option v-for="s in supplierStore.suppliers" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Notes</label>
              <input
                v-model="poForm.notes"
                type="text"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <div class="mb-2 flex items-center justify-between">
                <label class="text-sm font-medium">Items</label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="rounded border px-2 py-1 text-xs hover:bg-gray-50"
                    @click="addPoItem"
                  >
                    + Manual
                  </button>
                  <button
                    type="button"
                    class="rounded border px-2 py-1 text-xs hover:bg-gray-50"
                    @click="showPoScan = !showPoScan"
                  >
                    + Scan
                  </button>
                </div>
              </div>
              <div v-if="showPoScan" class="mb-2 rounded-lg bg-gray-50 p-2">
                <ScanBarcode autofocus @product-found="onPoBarcode" />
              </div>
              <div v-if="poItems.length === 0" class="py-4 text-center text-sm text-secondary">
                No items added
              </div>
              <div v-else class="space-y-2">
                <div v-for="(item, i) in poItems" :key="i" class="flex items-center gap-2">
                  <select
                    v-model="item.product_id"
                    class="flex-1 rounded-lg border px-2 py-1.5 text-sm"
                  >
                    <option value="" disabled>Select...</option>
                    <option
                      v-for="p in productStore.products.filter((p) => p.is_active)"
                      :key="p.id"
                      :value="p.id"
                    >
                      {{ p.name }}
                    </option>
                  </select>
                  <input
                    v-model.number="item.expected_qty"
                    type="number"
                    min="1"
                    class="w-20 rounded-lg border px-2 py-1.5 text-sm"
                    placeholder="Qty"
                  />
                  <input
                    v-model.number="item.unit_cost"
                    type="number"
                    min="0"
                    class="w-28 rounded-lg border px-2 py-1.5 text-sm"
                    placeholder="Cost"
                  />
                  <button type="button" class="text-xs text-danger" @click="removePoItem(i)">
                    <X :size="14" :stroke-width="2" />
                  </button>
                </div>
              </div>
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showCreateModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                Create PO
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Receive Modal -->
      <div
        v-if="showReceiveModal && selectedPO"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showReceiveModal = false"
      >
        <div class="w-full max-w-lg rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-2 text-lg font-semibold">Receive — {{ selectedPO.order_number }}</h3>
          <div class="mb-4 rounded-lg bg-gray-50 p-3 text-sm">
            <ScanBarcode autofocus @product-found="onReceiveBarcode" />
          </div>
          <div v-if="receiveProductId" class="mb-4">
            <p class="text-sm">
              Product:
              <strong>{{
                selectedPO.items?.find((i) => i.product_id === receiveProductId)?.product?.name ||
                receiveProductId
              }}</strong>
            </p>
            <label class="mb-1 mt-2 block text-sm font-medium">Qty Received</label>
            <input
              v-model.number="receiveQty"
              type="number"
              min="0.01"
              class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
            />
          </div>
          <div v-if="selectedPO.items" class="mb-4">
            <p class="mb-1 text-xs text-secondary">PO Items:</p>
            <div
              v-for="item in selectedPO.items"
              :key="item.id"
              class="flex justify-between border-b py-1 text-sm"
            >
              <span>{{ item.product?.name }}</span>
              <span class="text-secondary">{{ item.received_qty }}/{{ item.expected_qty }}</span>
            </div>
          </div>
          <div class="flex justify-end gap-2">
            <button
              class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
              @click="showReceiveModal = false"
            >
              Close
            </button>
            <button
              :disabled="!receiveProductId || receiveQty <= 0"
              class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-40"
              @click="handleReceive"
            >
              Confirm Receive
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
