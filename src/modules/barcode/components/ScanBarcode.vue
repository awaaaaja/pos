<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, nextTick } from "vue";
import { Check } from "lucide-vue-next";
import { Html5Qrcode } from "html5-qrcode";
import { getProductByBarcode } from "@/modules/products/services/product";

const mode = ref<"usb" | "camera">("usb");
const manualInput = ref("");
const scanning = ref(false);
const lastScanned = ref("");
const foundProduct = ref<{
  id: string;
  name: string;
  selling_price: number;
  barcode: string | null;
} | null>(null);
const notFoundBarcode = ref("");
const loading = ref(false);

const emit = defineEmits<{
  scanned: [value: string];
  productFound: [
    product: { id: string; name: string; selling_price: number; barcode: string | null },
  ];
  productNotFound: [barcode: string];
}>();

// USB scanner: detect fast keyboard input
let buffer = "";
let lastKeyTime = 0;
const SCAN_TIMEOUT = 100;

function handleKeydown(e: KeyboardEvent) {
  if (mode.value !== "usb") return;

  const now = Date.now();
  if (now - lastKeyTime > SCAN_TIMEOUT) buffer = "";
  lastKeyTime = now;

  if (e.key === "Enter") {
    if (buffer.length >= 4) searchByBarcode(buffer);
    buffer = "";
    return;
  }
  if (e.key.length === 1) buffer += e.key;
}

// Camera scanner
let html5Qrcode: Html5Qrcode | null = null;
const CAMERA_ID = "barcode-camera-region";

async function startCamera() {
  await nextTick();
  try {
    html5Qrcode = new Html5Qrcode(CAMERA_ID);
    await html5Qrcode.start(
      { facingMode: "environment" },
      { fps: 10, qrbox: { width: 280, height: 120 }, aspectRatio: 1.5 },
      (decodedText) => {
        searchByBarcode(decodedText);
      },
      () => {
        // ignore scan failures (no barcode in frame)
      },
    );
    scanning.value = true;
  } catch {
    // Camera not available or user denied
  }
}

async function stopCamera() {
  if (html5Qrcode) {
    try {
      if (html5Qrcode.isScanning) await html5Qrcode.stop();
    } catch {
      // ignore
    }
    html5Qrcode.clear();
    html5Qrcode = null;
  }
  scanning.value = false;
}

async function searchByBarcode(value: string) {
  lastScanned.value = value;
  notFoundBarcode.value = "";
  foundProduct.value = null;
  emit("scanned", value);

  loading.value = true;
  const result = await getProductByBarcode(value);
  loading.value = false;

  if (result.data) {
    foundProduct.value = result.data;
    emit("productFound", result.data);
  } else {
    notFoundBarcode.value = value;
    emit("productNotFound", value);
  }
}

function handleManualSubmit() {
  if (manualInput.value.trim()) {
    searchByBarcode(manualInput.value.trim());
    manualInput.value = "";
  }
}

function switchMode(newMode: "usb" | "camera") {
  if (mode.value === "camera") stopCamera();
  mode.value = newMode;
  if (newMode === "camera") startCamera();
}

onMounted(() => {
  document.addEventListener("keydown", handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener("keydown", handleKeydown);
  stopCamera();
});

watch(mode, (m) => {
  if (m === "camera") startCamera();
  else stopCamera();
});
</script>

<template>
  <div class="rounded-xl border bg-surface p-4">
    <div class="mb-3 flex items-center gap-2">
      <button
        :class="mode === 'usb' ? 'bg-primary text-white' : 'bg-gray-100 text-secondary'"
        class="rounded-lg px-3 py-1.5 text-xs font-medium transition"
        @click="switchMode('usb')"
      >
        USB Scanner
      </button>
      <button
        :class="mode === 'camera' ? 'bg-primary text-white' : 'bg-gray-100 text-secondary'"
        class="rounded-lg px-3 py-1.5 text-xs font-medium transition"
        @click="switchMode('camera')"
      >
        Camera
      </button>
    </div>

    <!-- USB Mode -->
    <div v-if="mode === 'usb'" class="space-y-3">
      <p class="text-xs text-secondary">
        Scan with USB barcode scanner — barcode will be detected automatically.
      </p>
      <div class="flex gap-2">
        <input
          v-model="manualInput"
          type="text"
          placeholder="Or type barcode manually..."
          class="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          @keydown.enter="handleManualSubmit"
        />
        <button
          class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
          @click="handleManualSubmit"
        >
          Search
        </button>
      </div>
    </div>

    <!-- Camera Mode -->
    <div v-if="mode === 'camera'" class="space-y-3">
      <div :id="CAMERA_ID" class="overflow-hidden rounded-lg" />
      <p v-if="!scanning" class="text-center text-xs text-secondary">Starting camera...</p>
      <p v-else class="text-center text-xs text-secondary">
        Point camera at barcode — detection is automatic
      </p>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mt-3 text-center text-xs text-secondary">Searching product...</div>

    <!-- Found -->
    <div
      v-if="foundProduct && !loading"
      class="mt-3 flex items-center justify-between rounded-lg border border-success/30 bg-success/5 p-3"
    >
      <div>
        <p class="text-sm font-medium text-success"><Check :size="14" :stroke-width="2.5" class="inline" /> Product found</p>
        <p class="text-sm font-medium">{{ foundProduct.name }}</p>
        <p class="text-xs text-secondary">
          Rp{{ foundProduct.selling_price.toLocaleString("id-ID") }}
        </p>
      </div>
      <button
        class="rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white hover:opacity-90"
        @click="foundProduct && emit('productFound', foundProduct)"
      >
        ADD
      </button>
    </div>

    <!-- Not found -->
    <div
      v-if="notFoundBarcode && !loading && !foundProduct"
      class="mt-3 rounded-lg border border-danger/30 bg-danger/5 p-3 text-center"
    >
      <p class="text-sm font-medium text-danger">! Barcode not found</p>
      <p class="font-mono text-xs">{{ notFoundBarcode }}</p>
    </div>

    <!-- Last scanned -->
    <div
      v-if="lastScanned && !foundProduct && !notFoundBarcode"
      class="mt-3 rounded-lg bg-gray-50 p-2 text-center"
    >
      <span class="text-xs text-secondary">Last scanned: </span>
      <span class="font-mono text-sm font-medium">{{ lastScanned }}</span>
    </div>
  </div>
</template>
