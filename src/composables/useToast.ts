import { ref } from "vue";

export type ToastType = "success" | "error" | "info" | "warning";

interface Toast {
  id: number;
  message: string;
  type: ToastType;
}

const toasts = ref<Toast[]>([]);
let nextId = 0;

function show(message: string, type: ToastType = "info", durationMs = 3000) {
  const id = nextId++;
  toasts.value.push({ id, message, type });
  setTimeout(() => {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }, durationMs);
}

export function useToast() {
  return {
    toasts,
    success: (msg: string) => show(msg, "success"),
    error: (msg: string) => show(msg, "error", 5000),
    info: (msg: string) => show(msg, "info"),
    warning: (msg: string) => show(msg, "warning", 4000),
  };
}
