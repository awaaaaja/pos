import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { Shift, CashMovement } from "@/types";
import {
  getOpenShift,
  openShift,
  closeShift,
  getCashMovements,
  recordCashMovement,
} from "@/modules/shifts/services/shift";

export const useShiftStore = defineStore("shift", () => {
  const currentShift = ref<Shift | null>(null);
  const movements = ref<CashMovement[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const isOpen = computed(() => currentShift.value?.status === "open");

  const cashIn = computed(() =>
    movements.value.filter((m) => m.type === "cash_in").reduce((sum, m) => sum + m.amount, 0),
  );

  const cashOut = computed(() =>
    movements.value.filter((m) => m.type === "cash_out").reduce((sum, m) => sum + m.amount, 0),
  );

  const cashSales = computed(() =>
    movements.value.filter((m) => m.type === "cash_sale").reduce((sum, m) => sum + m.amount, 0),
  );

  const refundTotal = computed(() =>
    movements.value.filter((m) => m.type === "refund").reduce((sum, m) => sum + m.amount, 0),
  );

  const expectedCash = computed(() => {
    if (!currentShift.value) return 0;
    return (
      currentShift.value.opening_cash +
      cashSales.value +
      cashIn.value -
      cashOut.value -
      refundTotal.value
    );
  });

  async function fetchOpenShift(cashierId: string) {
    loading.value = true;
    const result = await getOpenShift(cashierId);
    currentShift.value = result.data;
    if (result.data) {
      const movResult = await getCashMovements(result.data.id);
      movements.value = movResult.data ?? [];
    } else {
      movements.value = [];
    }
    loading.value = false;
  }

  async function openNewShift(outletId: string, cashierId: string, openingCash: number) {
    const result = await openShift(outletId, cashierId, openingCash);
    if (!result.success) {
      error.value = result.error || "Failed to open shift";
      return false;
    }
    await fetchOpenShift(cashierId);
    return true;
  }

  async function closeCurrentShift(closingCash: number) {
    if (!currentShift.value) return false;
    const result = await closeShift(currentShift.value.id, closingCash);
    if (!result.success) {
      error.value = result.error || "Failed to close shift";
      return false;
    }
    currentShift.value = {
      ...currentShift.value,
      status: "closed",
      closing_cash: closingCash,
      expected_cash: result.expected_cash ?? null,
      difference: result.difference ?? null,
      closed_at: new Date().toISOString(),
    };
    return true;
  }

  async function addCashMovement(
    type: "cash_in" | "cash_out",
    amount: number,
    description: string,
  ) {
    if (!currentShift.value) return false;
    const result = await recordCashMovement(
      currentShift.value.id,
      type,
      amount,
      undefined,
      description,
    );
    if (!result.success) {
      error.value = result.error || "Failed to record movement";
      return false;
    }
    const movResult = await getCashMovements(currentShift.value.id);
    movements.value = movResult.data ?? [];
    return true;
  }

  return {
    currentShift,
    movements,
    loading,
    error,
    isOpen,
    cashIn,
    cashOut,
    cashSales,
    refundTotal,
    expectedCash,
    fetchOpenShift,
    openNewShift,
    closeCurrentShift,
    addCashMovement,
  };
});
