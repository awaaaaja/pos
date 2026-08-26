import { defineStore } from "pinia";
import { ref } from "vue";
import type { TableStatus } from "@/types";
import {
  getTables,
  createTable,
  updateTable,
  deleteTable,
  transferTable,
  type TableRecord,
} from "@/modules/pos/services/table";

export const useTableStore = defineStore("tables", () => {
  const tables = ref<TableRecord[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchTables() {
    loading.value = true;
    const result = await getTables();
    if (result.error) {
      error.value = result.error;
    } else {
      tables.value = result.data ?? [];
    }
    loading.value = false;
  }

  async function addTable(input: { outlet_id: string; number: string; capacity: number }) {
    const result = await createTable(input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    tables.value.push(result.data!);
    return true;
  }

  async function editTable(
    id: string,
    input: Partial<{ number: string; capacity: number; status: TableStatus }>,
  ) {
    const result = await updateTable(id, input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = tables.value.findIndex((t) => t.id === id);
    if (idx !== -1) tables.value[idx] = result.data!;
    return true;
  }

  async function remove(id: string) {
    const result = await deleteTable(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    tables.value = tables.value.filter((t) => t.id !== id);
    return true;
  }

  async function transfer(fromId: string, toId: string) {
    const result = await transferTable(fromId, toId);
    if (!result.success) {
      error.value = result.error || "Transfer failed";
      return false;
    }
    await fetchTables(); // refresh
    return true;
  }

  return {
    tables,
    loading,
    error,
    fetchTables,
    addTable,
    editTable,
    remove,
    transfer,
  };
});
