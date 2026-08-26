<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { X, Check } from "lucide-vue-next";
import type { ModifierWithOptions, ModifierOption, CartItemModifier } from "@/types";

const props = defineProps<{
  product: { id: string; name: string; selling_price: number; image_url: string | null } | null;
  modifiers: ModifierWithOptions[];
  open: boolean;
}>();

const emit = defineEmits<{
  close: [];
  add: [
    product: { id: string; name: string; selling_price: number; image_url: string | null },
    modifiers: CartItemModifier[],
  ];
}>();

// Track selected options per modifier group
const selections = ref<Map<string, Set<string>>>(new Map());

watch(
  () => props.open,
  (val) => {
    if (val) initSelections();
  },
);

function initSelections() {
  selections.value = new Map();
  for (const mod of props.modifiers) {
    const defaults = mod.modifier_options
      .filter((o) => o.is_default)
      .slice(0, mod.max_selections)
      .map((o) => o.id);
    selections.value.set(mod.id, new Set(defaults));
  }
}

function toggleOption(modifierId: string, option: ModifierOption) {
  const mod = props.modifiers.find((m) => m.id === modifierId);
  if (!mod) return;

  const selected = selections.value.get(modifierId) ?? new Set();

  if (selected.has(option.id)) {
    if (mod.required && selected.size <= 1) return;
    selected.delete(option.id);
  } else {
    if (selected.size >= mod.max_selections) {
      // Replace: remove oldest, add new
      const arr = Array.from(selected);
      selected.delete(arr[0]!);
    }
    selected.add(option.id);
  }

  selections.value.set(modifierId, selected);
}

function isSelected(modifierId: string, optionId: string): boolean {
  return selections.value.get(modifierId)?.has(optionId) ?? false;
}

const selectedModifiers = computed<CartItemModifier[]>(() => {
  const result: CartItemModifier[] = [];
  for (const mod of props.modifiers) {
    const selected = selections.value.get(mod.id);
    if (!selected) continue;
    for (const opt of mod.modifier_options) {
      if (selected.has(opt.id)) {
        result.push({
          option_id: opt.id,
          option_name: opt.name,
          price_adjustment: opt.price_adjustment,
        });
      }
    }
  }
  return result;
});

const modifierTotal = computed(() =>
  selectedModifiers.value.reduce((sum, m) => sum + m.price_adjustment, 0),
);

const finalPrice = computed(() => {
  if (!props.product) return 0;
  return props.product.selling_price + modifierTotal.value;
});

function handleAdd() {
  if (!props.product) return;
  emit("add", props.product, selectedModifiers.value);
  emit("close");
}

function formatPrice(amount: number) {
  return `Rp${amount.toLocaleString("id-ID")}`;
}

// Validate: check required modifier groups
const isValid = computed(() => {
  for (const mod of props.modifiers) {
    if (mod.required) {
      const selected = selections.value.get(mod.id);
      if (!selected || selected.size === 0) return false;
    }
  }
  return true;
});
</script>

<template>
  <Teleport to="body">
    <!-- Overlay -->
    <Transition name="fade">
      <div v-if="open" class="fixed inset-0 z-40 bg-black/30" @click="emit('close')" />
    </Transition>

    <!-- Drawer -->
    <Transition name="slide-right">
      <div
        v-if="open && product"
        class="fixed right-0 top-0 z-50 flex h-full w-96 flex-col bg-surface shadow-xl"
      >
        <!-- Header -->
        <div class="flex items-center justify-between border-b px-5 py-4">
          <div>
            <h3 class="font-semibold">{{ product.name }}</h3>
            <p class="text-sm text-secondary">{{ formatPrice(product.selling_price) }}</p>
          </div>
          <button
            class="flex h-8 w-8 items-center justify-center rounded-lg text-secondary hover:bg-gray-100"
            @click="emit('close')"
          >
            <X :size="18" :stroke-width="2" />
          </button>
        </div>

        <!-- Modifier groups -->
        <div class="flex-1 overflow-y-auto p-5">
          <div v-for="mod in modifiers" :key="mod.id" class="mb-6">
            <div class="mb-2 flex items-center gap-2">
              <h4 class="text-sm font-medium">{{ mod.name }}</h4>
              <span
                v-if="mod.required"
                class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] text-primary"
              >
                Required
              </span>
              <span class="text-xs text-secondary"> Choose up to {{ mod.max_selections }} </span>
            </div>
            <div class="space-y-1.5">
              <button
                v-for="opt in mod.modifier_options"
                :key="opt.id"
                :class="[
                  isSelected(mod.id, opt.id)
                    ? 'border-primary bg-primary/5 ring-1 ring-primary'
                    : 'border-gray-200 hover:border-gray-300',
                ]"
                class="flex w-full items-center justify-between rounded-lg border px-3 py-2.5 text-left transition"
                @click="toggleOption(mod.id, opt)"
              >
                <div class="flex items-center gap-2">
                  <div
                    :class="isSelected(mod.id, opt.id) ? 'bg-primary' : 'border-gray-300'"
                    class="flex h-4 w-4 items-center justify-center rounded border"
                  >
                    <span v-if="isSelected(mod.id, opt.id)" class="text-white"><Check :size="10" :stroke-width="3" /></span>
                  </div>
                  <span class="text-sm">{{ opt.name }}</span>
                </div>
                <span v-if="opt.price_adjustment !== 0" class="text-xs text-secondary">
                  {{ opt.price_adjustment > 0 ? "+" : "" }}{{ formatPrice(opt.price_adjustment) }}
                </span>
              </button>
            </div>
          </div>
        </div>

        <!-- Footer: Add to order -->
        <div class="border-t px-5 py-4">
          <button
            :disabled="!isValid"
            class="w-full rounded-xl bg-primary py-3 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
            @click="handleAdd"
          >
            ADD TO ORDER — {{ formatPrice(finalPrice) }}
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.25s ease;
}
.slide-right-enter-from,
.slide-right-leave-to {
  transform: translateX(100%);
}
</style>
