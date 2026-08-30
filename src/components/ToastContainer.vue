<script setup lang="ts">
import { useToast } from "@/composables/useToast";

const { toasts } = useToast();

const colors: Record<string, string> = {
  success: "bg-green-600",
  error: "bg-red-600",
  warning: "bg-amber-600",
  info: "bg-primary",
};
</script>

<template>
  <div class="fixed bottom-4 right-4 z-[9999] flex flex-col gap-2">
    <TransitionGroup name="toast">
      <div
        v-for="t in toasts"
        :key="t.id"
        :class="[colors[t.type], 'text-white px-4 py-3 rounded-xl shadow-lg text-sm font-medium min-w-[200px] max-w-[350px]']"
      >
        {{ t.message }}
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.toast-enter-active,
.toast-leave-active {
  transition: all 0.25s ease;
}
.toast-enter-from {
  opacity: 0;
  transform: translateX(40px);
}
.toast-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}
</style>
