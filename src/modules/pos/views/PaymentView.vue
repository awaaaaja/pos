<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useCartStore } from "@/modules/pos/stores/cart";
import { getOrderWithItems, createPayment } from "@/modules/pos/services/payment";
import VoidApprovalModal from "@/modules/pos/components/VoidApprovalModal.vue";
import RefundModal from "@/modules/pos/components/RefundModal.vue";
import {
  Banknote,
  Smartphone,
  CreditCard,
  Wallet,
  Building2,
} from "lucide-vue-next";
import type { PaymentMethod } from "@/types";

const route = useRoute();
const router = useRouter();
const cart = useCartStore();

const orderId = computed(() => route.params.orderId as string | undefined);
const order = ref<Record<string, unknown> | null>(null);
const loading = ref(true);
const submitting = ref(false);

// Void
const showVoidModal = ref(false);
const showRefundModal = ref(false);
const orderStatus = computed(() => order.value?.status as string | undefined);

// Payment form
const method = ref<PaymentMethod>("cash");
const receivedAmount = ref(0);
const referenceNumber = ref("");
const orderItems = ref<Record<string, unknown>[]>([]);

// Computed
const subtotal = computed(() => (order.value?.subtotal as number) ?? 0);
const discount = computed(() => (order.value?.discount as number) ?? 0);
const tax = computed(() => (order.value?.tax as number) ?? 0);
const serviceCharge = computed(() => (order.value?.service_charge as number) ?? 0);
const total = computed(() => (order.value?.total as number) ?? 0);
const cashChange = computed(() =>
  method.value === "cash" ? Math.max(0, receivedAmount.value - total.value) : 0,
);
const isValid = computed(() => {
  if (method.value === "cash") return receivedAmount.value >= total.value;
  if (["qris", "debit", "credit", "ewallet", "transfer"].includes(method.value))
    return referenceNumber.value.trim().length > 0;
  return true;
});

const methods: { value: PaymentMethod; label: string; icon: typeof Banknote }[] = [
  { value: "cash", label: "Cash", icon: Banknote },
  { value: "qris", label: "QRIS", icon: Smartphone },
  { value: "debit", label: "Debit", icon: CreditCard },
  { value: "credit", label: "Credit", icon: CreditCard },
  { value: "ewallet", label: "E-Wallet", icon: Wallet },
  { value: "transfer", label: "Transfer", icon: Building2 },
];

const quickAmounts = [50000, 100000, 150000, 200000];

onMounted(async () => {
  // If we have an orderId in route, load that order
  // Otherwise, we're coming from POS with a fresh confirm
  if (orderId.value) {
    const result = await getOrderWithItems(orderId.value);
    if (result.data) {
      order.value = result.data;
      orderItems.value = (result.data.order_items as Record<string, unknown>[]) ?? [];
    }
  } else {
    // Fallback: show empty state
    order.value = {
      total: cart.total,
      subtotal: cart.subtotal,
      discount: 0,
      tax: 0,
      service_charge: 0,
    };
  }
  loading.value = false;
});

async function handlePay() {
  if (!isValid.value || submitting.value) return;
  submitting.value = true;

  const oId = orderId.value || cart.holdOrderId;
  if (!oId) {
    alert("No order to pay");
    submitting.value = false;
    return;
  }

  const result = await createPayment(oId, method.value, total.value, referenceNumber.value);
  if (result.error) {
    alert("Payment failed: " + result.error);
    submitting.value = false;
    return;
  }

  // Complete the order
  const { completeOrder } = await import("@/modules/pos/services/payment");
  const completeResult = await completeOrder(oId);
  if (completeResult.error) {
    alert("Payment recorded but order completion failed: " + completeResult.error);
  }

  cart.clearCart();
  router.push("/cashier");
}

function formatCurrency(n: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
  }).format(n);
}

function getItemName(item: Record<string, unknown>): string {
  const product = item.product as Record<string, unknown> | undefined;
  return (product?.name as string) || "Item";
}
</script>

<template>
  <div class="mx-auto max-w-lg py-6">
    <h2 class="mb-6 text-2xl font-semibold">Payment</h2>

    <!-- Loading -->
    <div v-if="loading" class="py-12 text-center text-secondary">Loading order...</div>

    <template v-else>
      <!-- Order Summary -->
      <div class="mb-6 rounded-2xl border bg-surface p-4">
        <p class="mb-2 text-xs text-secondary">Order Items</p>
        <div
          v-for="(item, i) in orderItems"
          :key="i"
          class="flex justify-between border-b py-2 text-sm last:border-0"
        >
          <span>{{ getItemName(item) }} x{{ item.quantity }}</span>
          <span class="font-medium">{{ formatCurrency(Number(item.subtotal)) }}</span>
        </div>
      </div>

      <!-- Breakdown -->
      <div class="mb-6 rounded-2xl border bg-surface p-4 space-y-2">
        <div class="flex justify-between text-sm">
          <span class="text-secondary">Subtotal</span>
          <span>{{ formatCurrency(subtotal) }}</span>
        </div>
        <div v-if="discount > 0" class="flex justify-between text-sm">
          <span class="text-secondary">Discount</span>
          <span class="text-danger">-{{ formatCurrency(discount) }}</span>
        </div>
        <div v-if="tax > 0" class="flex justify-between text-sm">
          <span class="text-secondary">Tax (11%)</span>
          <span>{{ formatCurrency(tax) }}</span>
        </div>
        <div v-if="serviceCharge > 0" class="flex justify-between text-sm">
          <span class="text-secondary">Service Charge</span>
          <span>{{ formatCurrency(serviceCharge) }}</span>
        </div>
        <div class="border-t pt-2 text-lg font-bold">
          <div class="flex justify-between">
            <span>Total</span>
            <span class="text-primary">{{ formatCurrency(total) }}</span>
          </div>
        </div>
      </div>

      <!-- Payment Method -->
      <div class="mb-6">
        <p class="mb-3 text-sm font-medium">Payment Method</p>
        <div class="grid grid-cols-3 gap-2">
          <button
            v-for="m in methods"
            :key="m.value"
            :class="[
              method === m.value
                ? 'border-primary bg-primary/5 ring-1 ring-primary'
                : 'border-gray-200 hover:border-gray-300',
            ]"
            class="flex flex-col items-center gap-1 rounded-xl border p-3 text-sm transition"
            @click="method = m.value"
          >
            <component :is="m.icon" :size="22" :stroke-width="1.8" />
            <span>{{ m.label }}</span>
          </button>
        </div>
      </div>

      <!-- Cash Input -->
      <div v-if="method === 'cash'" class="mb-6 rounded-2xl border bg-surface p-4">
        <label class="mb-2 block text-sm font-medium">Received Amount</label>
        <input
          v-model.number="receivedAmount"
          type="number"
          :placeholder="`Min ${total}`"
          class="w-full rounded-lg border border-gray-300 px-3 py-3 text-lg font-semibold focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
        />
        <div class="mt-3 flex gap-2">
          <button
            v-for="amt in quickAmounts"
            :key="amt"
            class="rounded-lg border px-3 py-1 text-sm hover:bg-gray-50"
            @click="receivedAmount = amt"
          >
            {{ formatCurrency(amt) }}
          </button>
        </div>
        <div v-if="receivedAmount >= total" class="mt-3 rounded-lg bg-green-50 p-3 text-center">
          <p class="text-sm text-secondary">Change</p>
          <p class="text-xl font-bold text-green-700">{{ formatCurrency(cashChange) }}</p>
        </div>
      </div>

      <!-- Reference Input (non-cash) -->
      <div v-if="method !== 'cash'" class="mb-6 rounded-2xl border bg-surface p-4">
        <label class="mb-2 block text-sm font-medium">Reference Number</label>
        <input
          v-model="referenceNumber"
          type="text"
          placeholder="Transaction reference / last 4 digits"
          class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      <!-- Pay Button -->
      <button
        :disabled="!isValid || submitting"
        class="w-full rounded-xl bg-primary py-4 text-lg font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
        @click="handlePay"
      >
        {{ submitting ? "Processing..." : `Pay ${formatCurrency(total)}` }}
      </button>

      <button
        class="mt-3 w-full text-center text-sm text-secondary hover:underline"
        @click="router.back()"
      >
        Cancel
      </button>

      <!-- Void button (only for confirmed orders) -->
      <button
        v-if="orderStatus === 'confirmed'"
        class="mt-2 w-full text-center text-sm text-danger hover:underline"
        @click="showVoidModal = true"
      >
        Void this order
      </button>

      <!-- Refund button (only for completed orders) -->
      <button
        v-if="orderStatus === 'completed'"
        class="mt-2 w-full text-center text-sm text-orange-600 hover:underline"
        @click="showRefundModal = true"
      >
        Refund this order
      </button>
    </template>

    <!-- Void Approval Modal -->
    <VoidApprovalModal
      v-if="showVoidModal && orderId"
      :order-id="orderId"
      @close="showVoidModal = false"
      @voided="router.push('/cashier')"
    />

    <!-- Refund Modal -->
    <RefundModal
      v-if="showRefundModal && orderId"
      :order-id="orderId"
      :amount="total"
      @close="showRefundModal = false"
      @refunded="router.push('/cashier')"
    />
  </div>
</template>
