<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useCartStore } from "@/modules/pos/stores/cart";
import { useCategoryStore } from "@/modules/products/stores/category";
import { useProductStore } from "@/modules/products/stores/product";
import { getModifiersByProduct } from "@/modules/pos/services/modifier";
import ModifierDrawer from "@/modules/pos/components/ModifierDrawer.vue";
import ScanBarcode from "@/modules/barcode/components/ScanBarcode.vue";
import { Camera, Coffee, ShoppingCart, X } from "lucide-vue-next";
import type { ModifierWithOptions, CartItemModifier } from "@/types";

const router = useRouter();
const cart = useCartStore();
const categoryStore = useCategoryStore();
const productStore = useProductStore();

// Filters
const selectedCategoryId = ref<string | null>(null);
const searchQuery = ref("");

// Modifier drawer
const showModifierDrawer = ref(false);
const selectedProduct = ref<{
  id: string;
  name: string;
  selling_price: number;
  image_url: string | null;
} | null>(null);
const productModifiers = ref<ModifierWithOptions[]>([]);

// Hold/Resume
const showResumeModal = ref(false);
const draftOrders = ref<
  { id: string; invoice_number: string | null; item_count: number; total: number }[]
>([]);
const loadingDrafts = ref(false);

// Scan
const showScanner = ref(false);

onMounted(() => {
  categoryStore.fetchCategories();
  productStore.fetchProducts();
});

const filteredProducts = computed(() => {
  let list = productStore.products.filter((p) => p.is_active);
  if (selectedCategoryId.value) {
    list = list.filter((p) => p.category_id === selectedCategoryId.value);
  }
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        p.sku?.toLowerCase().includes(q) ||
        p.barcode?.includes(q),
    );
  }
  return list;
});

async function onProductClick(product: (typeof productStore.products)[0]) {
  // Check if product has modifiers
  const result = await getModifiersByProduct(product.id);
  if (result.data && result.data.length > 0) {
    selectedProduct.value = product;
    productModifiers.value = result.data;
    showModifierDrawer.value = true;
  } else {
    cart.addItem(product);
  }
}

function onModifierAdd(
  product: { id: string; name: string; selling_price: number; image_url: string | null },
  modifiers: CartItemModifier[],
) {
  cart.addItem(product, modifiers);
}

function onProductFound(product: {
  id: string;
  name: string;
  selling_price: number;
  barcode: string | null;
}) {
  // Find full product data from store
  const full = productStore.products.find((p) => p.id === product.id);
  if (full) {
    onProductClick(full);
  }
}

async function handleHold() {
  const result = await cart.holdOrder();
  if (result.success) {
    alert(`Order held${cart.holdInvoiceNumber ? ` (${cart.holdInvoiceNumber})` : ""}`);
    cart.clearCart();
  } else {
    alert(result.error || "Failed to hold order");
  }
}

async function openResumeModal() {
  loadingDrafts.value = true;
  draftOrders.value = await cart.resumeDraftOrders();
  loadingDrafts.value = false;
  showResumeModal.value = true;
}

async function handleResume(orderId: string) {
  const result = await cart.resumeOrder(orderId);
  showResumeModal.value = false;
  if (!result.success) {
    alert(result.error || "Failed to resume order");
  }
}

function formatPrice(amount: number) {
  return `Rp${amount.toLocaleString("id-ID")}`;
}

async function handlePayment() {
  // Hold order first (save to DB as DRAFT)
  const holdResult = await cart.holdOrder();
  if (!holdResult.success) {
    alert(holdResult.error || "Failed to save order");
    return;
  }

  // Confirm order via RPC (DRAFT → CONFIRMED, generates invoice#)
  const orderId = cart.holdOrderId;
  if (!orderId) {
    alert("No order to confirm");
    return;
  }

  // Navigate to payment page with order ID
  router.push({ name: "cashier-payment", params: { orderId } });
}
</script>

<template>
  <div class="flex h-full">
    <!-- Left: Categories + Products -->
    <div class="flex flex-1 flex-col overflow-hidden">
      <!-- Top bar: Search + Scanner + Order type -->
      <div class="flex items-center gap-3 border-b bg-surface px-4 py-3">
        <!-- Search / Barcode -->
        <div class="relative flex-1">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search product / Scan barcode..."
            class="w-full rounded-lg border border-gray-300 py-2.5 pl-3 pr-10 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          />
          <button
            class="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-secondary hover:bg-gray-100"
            title="Scan barcode"
            @click="showScanner = !showScanner"
          >
            <Camera :size="18" :stroke-width="1.8" />
          </button>
        </div>

        <!-- Order type toggle -->
        <div class="flex overflow-hidden rounded-lg border">
          <button
            :class="cart.orderType === 'dine_in' ? 'bg-primary text-white' : 'text-secondary'"
            class="px-3 py-1.5 text-xs font-medium transition"
            @click="cart.orderType = 'dine_in'"
          >
            Dine In
          </button>
          <button
            :class="cart.orderType === 'takeaway' ? 'bg-primary text-white' : 'text-secondary'"
            class="px-3 py-1.5 text-xs font-medium transition"
            @click="cart.orderType = 'takeaway'"
          >
            Takeaway
          </button>
        </div>

        <!-- Hold / Resume -->
        <button
          :disabled="cart.isEmpty"
          class="rounded-lg border border-warning bg-warning/10 px-3 py-2 text-xs font-medium text-warning transition hover:bg-warning/20 disabled:opacity-40"
          @click="handleHold"
        >
          Hold
        </button>
        <button
          class="rounded-lg border px-3 py-2 text-xs font-medium text-secondary transition hover:bg-gray-50"
          @click="openResumeModal"
        >
          Resume
        </button>
      </div>

      <!-- Scanner panel -->
      <div v-if="showScanner" class="border-b bg-gray-50 px-4 py-3">
        <ScanBarcode autofocus @product-found="onProductFound" />
      </div>

      <!-- Category filter + Product grid -->
      <div class="flex flex-1 overflow-hidden">
        <!-- Categories sidebar -->
        <div class="w-44 shrink-0 overflow-y-auto border-r bg-surface p-3">
          <button
            :class="selectedCategoryId === null ? 'bg-primary text-white' : 'hover:bg-gray-100'"
            class="mb-1 w-full rounded-lg px-3 py-2 text-left text-sm font-medium transition"
            @click="selectedCategoryId = null"
          >
            All
          </button>
          <button
            v-for="cat in categoryStore.categories.filter((c) => c.is_active)"
            :key="cat.id"
            :class="
              selectedCategoryId === cat.id
                ? 'bg-primary text-white'
                : 'hover:bg-gray-100 text-secondary'
            "
            class="mb-1 w-full rounded-lg px-3 py-2 text-left text-sm transition"
            @click="selectedCategoryId = cat.id"
          >
            {{ cat.name }}
          </button>
        </div>

        <!-- Product grid -->
        <div class="flex-1 overflow-y-auto p-4">
          <div v-if="productStore.loading" class="py-12 text-center text-secondary">
            Loading products...
          </div>
          <div v-else-if="filteredProducts.length === 0" class="py-12 text-center text-secondary">
            No products found
          </div>
          <div v-else class="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
            <button
              v-for="product in filteredProducts"
              :key="product.id"
              class="group flex flex-col items-center rounded-xl border bg-surface p-3 transition hover:border-primary/30 hover:shadow-sm active:scale-[0.97]"
              @click="onProductClick(product)"
            >
              <div
                class="mb-2 flex h-16 w-16 items-center justify-center overflow-hidden rounded-lg bg-gray-100"
              >
                <img
                  v-if="product.image_url"
                  :src="product.image_url"
                  :alt="product.name"
                  class="h-full w-full object-cover"
                />
                <span v-else class="text-gray-300"><Coffee :size="28" :stroke-width="1.5" /></span>
              </div>
              <p class="w-full truncate text-center text-[13px] font-medium">{{ product.name }}</p>
              <p class="text-xs font-semibold text-primary">
                {{ formatPrice(product.selling_price) }}
              </p>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Right: Cart -->
    <aside class="flex w-80 shrink-0 flex-col border-l bg-surface">
      <!-- Cart header -->
      <div class="flex items-center justify-between border-b px-4 py-3">
        <h3 class="font-semibold">Cart</h3>
        <span class="text-xs text-secondary">{{ cart.itemCount }} items</span>
      </div>

      <!-- Cart items -->
      <div class="flex-1 overflow-y-auto">
        <div
          v-if="cart.isEmpty"
          class="flex flex-col items-center justify-center py-12 text-secondary"
        >
          <ShoppingCart :size="36" :stroke-width="1.5" class="mb-2 text-gray-300" />
          <p class="text-sm">Cart is empty</p>
          <p class="text-xs">Select a product to start</p>
        </div>

        <div v-else class="divide-y">
          <div v-for="(item, index) in cart.items" :key="index" class="px-4 py-3">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <p class="text-sm font-medium">{{ item.product_name }}</p>
                <p v-if="item.modifiers.length" class="text-xs text-secondary">
                  {{ item.modifiers.map((m) => m.option_name).join(" · ") }}
                </p>
                <p class="mt-1 text-xs text-secondary">
                  {{ formatPrice(item.unit_price + item.modifier_total) }} × {{ item.quantity }}
                </p>
              </div>
              <p class="ml-2 text-sm font-medium">{{ formatPrice(item.subtotal) }}</p>
            </div>

            <!-- Qty controls + notes -->
            <div class="mt-2 flex items-center gap-2">
              <div class="flex items-center overflow-hidden rounded-lg border">
                <button
                  class="px-2 py-1 text-sm hover:bg-gray-100"
                  @click="cart.decrementQuantity(index)"
                >
                  −
                </button>
                <span class="min-w-[2rem] text-center text-sm font-medium">{{
                  item.quantity
                }}</span>
                <button
                  class="px-2 py-1 text-sm hover:bg-gray-100"
                  @click="cart.incrementQuantity(index)"
                >
                  +
                </button>
              </div>
              <input
                :value="item.notes"
                type="text"
                placeholder="Note..."
                class="flex-1 rounded-lg border px-2 py-1 text-xs focus:border-primary focus:outline-none"
                @input="cart.setItemNotes(index, ($event.target as HTMLInputElement).value)"
              />
              <button class="text-xs text-danger hover:underline" @click="cart.removeItem(index)">
                <X :size="14" :stroke-width="2" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Cart footer: Summary -->
      <div v-if="!cart.isEmpty" class="border-t px-4 py-4">
        <div class="mb-3 space-y-1 text-sm">
          <div class="flex justify-between">
            <span class="text-secondary">Subtotal</span>
            <span>{{ formatPrice(cart.subtotal) }}</span>
          </div>
          <div v-if="cart.modifierTotal > 0" class="flex justify-between">
            <span class="text-secondary">Modifiers</span>
            <span>{{ formatPrice(cart.modifierTotal) }}</span>
          </div>
          <div class="flex justify-between border-t pt-1 font-semibold">
            <span>Total</span>
            <span class="text-primary">{{ formatPrice(cart.total) }}</span>
          </div>
        </div>

        <!-- Order notes -->
        <input
          v-model="cart.notes"
          type="text"
          placeholder="Order notes..."
          class="mb-3 w-full rounded-lg border px-3 py-2 text-xs focus:border-primary focus:outline-none"
        />

        <button
          class="w-full rounded-xl bg-primary py-3 text-sm font-semibold text-white transition hover:opacity-90"
          @click="handlePayment"
        >
          PAYMENT — {{ formatPrice(cart.total) }}
        </button>
      </div>
    </aside>

    <!-- Modifier Drawer -->
    <ModifierDrawer
      :product="selectedProduct"
      :modifiers="productModifiers"
      :open="showModifierDrawer"
      @close="showModifierDrawer = false"
      @add="onModifierAdd"
    />

    <!-- Resume Draft Modal -->
    <Teleport to="body">
      <div
        v-if="showResumeModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showResumeModal = false"
      >
        <div class="w-full max-w-md rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">Resume Draft Order</h3>

          <div v-if="loadingDrafts" class="py-8 text-center text-secondary">Loading...</div>

          <div v-else-if="draftOrders.length === 0" class="py-8 text-center text-secondary">
            No draft orders found
          </div>

          <div v-else class="space-y-2">
            <button
              v-for="draft in draftOrders"
              :key="draft.id"
              class="flex w-full items-center justify-between rounded-xl border p-4 text-left transition hover:border-primary/30 hover:bg-gray-50"
              @click="handleResume(draft.id)"
            >
              <div>
                <p class="text-sm font-medium">{{ draft.invoice_number || "Draft" }}</p>
                <p class="text-xs text-secondary">{{ draft.item_count }} items</p>
              </div>
              <p class="text-sm font-semibold text-primary">{{ formatPrice(draft.total) }}</p>
            </button>
          </div>

          <button
            class="mt-4 w-full rounded-lg border py-2 text-sm text-secondary hover:bg-gray-50"
            @click="showResumeModal = false"
          >
            Cancel
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>
