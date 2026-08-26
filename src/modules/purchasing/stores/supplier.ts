import { defineStore } from "pinia";
import { ref } from "vue";
import type { Supplier } from "@/types";
import {
  getSuppliers,
  createSupplier,
  updateSupplier,
  deleteSupplier,
} from "@/modules/purchasing/services/supplier";
import { logAuditEvent } from "@/modules/auth/services/auth";

export const useSupplierStore = defineStore("suppliers", () => {
  const suppliers = ref<Supplier[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetch() {
    loading.value = true;
    const r = await getSuppliers();
    suppliers.value = r.data ?? [];
    error.value = r.error;
    loading.value = false;
  }

  async function add(input: Omit<Supplier, "id" | "created_at" | "updated_at" | "is_active">) {
    const r = await createSupplier(input);
    if (r.error) {
      error.value = r.error;
      return false;
    }
    suppliers.value.push(r.data!);
    logAuditEvent({
      action: "create",
      entity_type: "supplier",
      entity_id: r.data!.id,
      detail: { name: input.name },
    });
    return true;
  }

  async function edit(id: string, input: Partial<Supplier>) {
    const r = await updateSupplier(id, input);
    if (r.error) {
      error.value = r.error;
      return false;
    }
    const idx = suppliers.value.findIndex((s) => s.id === id);
    if (idx !== -1) suppliers.value[idx] = r.data!;
    logAuditEvent({ action: "update", entity_type: "supplier", entity_id: id, detail: input });
    return true;
  }

  async function remove(id: string) {
    const r = await deleteSupplier(id);
    if (r.error) {
      error.value = r.error;
      return false;
    }
    suppliers.value = suppliers.value.filter((s) => s.id !== id);
    logAuditEvent({ action: "delete", entity_type: "supplier", entity_id: id });
    return true;
  }

  return { suppliers, loading, error, fetch, add, edit, remove };
});
