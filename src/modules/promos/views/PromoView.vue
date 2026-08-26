<script setup lang="ts">
import { ref, onMounted } from "vue";
import {
  getPromos, createPromo, deletePromo,
  getCoupons, createCoupon, deleteCoupon,
} from "@/modules/promos/services/promo";
import type { Promo, Coupon } from "@/types";
import { Tag, Plus, X, Ticket } from "lucide-vue-next";

const promos = ref<Promo[]>([]);
const coupons = ref<Coupon[]>([]);
const tab = ref<"promos" | "coupons">("promos");
const showPromoForm = ref(false);
const showCouponForm = ref(false);

const promoForm = ref({
  name: "",
  type: "percentage" as Promo["type"],
  discount_value: 0,
  minimum_purchase: 0,
  maximum_discount: 0,
  start_date: "",
  end_date: "",
});

const couponForm = ref({
  promo_id: "",
  code: "",
  usage_limit: 0,
  min_purchase: 0,
  max_discount: 0,
  start_date: "",
  end_date: "",
  customer_eligibility: "all" as Coupon["customer_eligibility"],
});

const promoTypes: Promo["type"][] = ["percentage", "fixed", "coupon", "bogo", "bundle", "member_discount"];
const eligibility: Coupon["customer_eligibility"][] = ["all", "member", "new"];

async function load() {
  const [r1, r2] = await Promise.all([getPromos(), getCoupons()]);
  promos.value = r1.data ?? [];
  coupons.value = r2.data ?? [];
}

async function submitPromo() {
  if (!promoForm.value.name) return;
  await createPromo({
    ...promoForm.value,
    start_date: promoForm.value.start_date || null,
    end_date: promoForm.value.end_date || null,
    maximum_discount: promoForm.value.maximum_discount || null,
  });
  showPromoForm.value = false;
  await load();
}

async function submitCoupon() {
  if (!couponForm.value.code || !couponForm.value.promo_id) return;
  await createCoupon({
    ...couponForm.value,
    start_date: couponForm.value.start_date || null,
    end_date: couponForm.value.end_date || null,
    max_discount: couponForm.value.max_discount || null,
    usage_limit: couponForm.value.usage_limit || null,
  });
  showCouponForm.value = false;
  await load();
}

async function removePromo(id: string) {
  if (!confirm("Delete this promo?")) return;
  await deletePromo(id);
  await load();
}

async function removeCoupon(id: string) {
  if (!confirm("Delete this coupon?")) return;
  await deleteCoupon(id);
  await load();
}

onMounted(load);
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Promos & Coupons</h2>
      <div class="flex gap-2">
        <button
          v-if="tab === 'promos'"
          class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
          @click="showPromoForm = !showPromoForm"
        >
          <Plus class="h-4 w-4" /> Add Promo
        </button>
        <button
          v-if="tab === 'coupons'"
          class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
          @click="showCouponForm = !showCouponForm"
        >
          <Plus class="h-4 w-4" /> Add Coupon
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 rounded-lg bg-gray-800 p-1">
      <button
        class="flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition"
        :class="tab === 'promos' ? 'bg-amber-600 text-white' : 'text-gray-400 hover:text-white'"
        @click="tab = 'promos'"
      >
        <Tag class="mr-1 inline h-4 w-4" /> Promos
      </button>
      <button
        class="flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition"
        :class="tab === 'coupons' ? 'bg-amber-600 text-white' : 'text-gray-400 hover:text-white'"
        @click="tab = 'coupons'"
      >
        <Ticket class="mr-1 inline h-4 w-4" /> Coupons
      </button>
    </div>

    <!-- Promo Form -->
    <div v-if="showPromoForm" class="rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div class="mb-3 flex items-center justify-between">
        <h3 class="text-sm font-medium text-white">New Promo</h3>
        <button @click="showPromoForm = false" class="text-gray-400 hover:text-white"><X class="h-4 w-4" /></button>
      </div>
      <form @submit.prevent="submitPromo" class="grid grid-cols-2 gap-3">
        <input v-model="promoForm.name" placeholder="Name *" class="col-span-2 rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500" required />
        <select v-model="promoForm.type" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white">
          <option v-for="t in promoTypes" :key="t" :value="t">{{ t }}</option>
        </select>
        <input v-model.number="promoForm.discount_value" type="number" placeholder="Value *" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <input v-model.number="promoForm.minimum_purchase" type="number" placeholder="Min purchase" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <input v-model.number="promoForm.maximum_discount" type="number" placeholder="Max discount" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <input v-model="promoForm.start_date" type="date" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <input v-model="promoForm.end_date" type="date" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <button type="submit" class="col-span-2 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-500">Save</button>
      </form>
    </div>

    <!-- Coupon Form -->
    <div v-if="showCouponForm" class="rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div class="mb-3 flex items-center justify-between">
        <h3 class="text-sm font-medium text-white">New Coupon</h3>
        <button @click="showCouponForm = false" class="text-gray-400 hover:text-white"><X class="h-4 w-4" /></button>
      </div>
      <form @submit.prevent="submitCoupon" class="grid grid-cols-2 gap-3">
        <select v-model="couponForm.promo_id" class="col-span-2 rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white">
          <option value="" disabled>Select promo *</option>
          <option v-for="p in promos.filter(p => p.type === 'coupon')" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
        <input v-model="couponForm.code" placeholder="CODE *" class="col-span-2 rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm font-mono text-white placeholder-gray-500 uppercase" required />
        <input v-model.number="couponForm.usage_limit" type="number" placeholder="Usage limit" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <input v-model.number="couponForm.min_purchase" type="number" placeholder="Min purchase" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <select v-model="couponForm.customer_eligibility" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white">
          <option v-for="e in eligibility" :key="e" :value="e">{{ e }}</option>
        </select>
        <input v-model.number="couponForm.max_discount" type="number" placeholder="Max discount" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" />
        <button type="submit" class="col-span-2 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-500">Save</button>
      </form>
    </div>

    <!-- Promos List -->
    <div v-if="tab === 'promos'" class="space-y-2">
      <div v-for="p in promos" :key="p.id" class="flex items-center justify-between rounded-xl border border-gray-700 bg-gray-800 px-4 py-3">
        <div>
          <span class="font-medium text-white">{{ p.name }}</span>
          <span class="ml-2 rounded-full bg-gray-700 px-2 py-0.5 text-xs text-gray-300">{{ p.type }}</span>
          <p class="mt-0.5 text-xs text-gray-400">Discount: {{ p.discount_value }} | Min: {{ p.minimum_purchase.toLocaleString() }}</p>
        </div>
        <button @click="removePromo(p.id)" class="text-xs text-gray-500 hover:text-red-400">Delete</button>
      </div>
      <p v-if="promos.length === 0" class="py-12 text-center text-gray-500">No promos yet</p>
    </div>

    <!-- Coupons List -->
    <div v-if="tab === 'coupons'" class="space-y-2">
      <div v-for="c in coupons" :key="c.id" class="flex items-center justify-between rounded-xl border border-gray-700 bg-gray-800 px-4 py-3">
        <div>
          <span class="font-mono font-bold text-white">{{ c.code }}</span>
          <p class="mt-0.5 text-xs text-gray-400">
            {{ c.promo?.name }} | Used: {{ c.used_count }}/{{ c.usage_limit ?? "∞" }} | {{ c.customer_eligibility }}
          </p>
        </div>
        <button @click="removeCoupon(c.id)" class="text-xs text-gray-500 hover:text-red-400">Delete</button>
      </div>
      <p v-if="coupons.length === 0" class="py-12 text-center text-gray-500">No coupons yet</p>
    </div>
  </div>
</template>
