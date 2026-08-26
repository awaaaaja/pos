import { defineStore } from "pinia";
import { ref } from "vue";
import type { Category } from "@/types";
import {
  getCategories,
  createCategory,
  updateCategory,
  archiveCategory,
  restoreCategory,
  deleteCategory,
} from "@/modules/products/services/category";
import { logAuditEvent } from "@/modules/auth/services/auth";

export const useCategoryStore = defineStore("categories", () => {
  const categories = ref<Category[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchCategories() {
    loading.value = true;
    const result = await getCategories();
    if (result.error) {
      error.value = result.error;
    } else {
      categories.value = result.data ?? [];
    }
    loading.value = false;
  }

  async function addCategory(input: Pick<Category, "name" | "description" | "sort_order">) {
    const result = await createCategory(input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    categories.value.push(result.data!);
    logAuditEvent({
      action: "create",
      entity_type: "category",
      entity_id: result.data!.id,
      detail: { name: input.name },
    });
    return true;
  }

  async function editCategory(
    id: string,
    input: Partial<Pick<Category, "name" | "description" | "sort_order" | "is_active">>,
  ) {
    const result = await updateCategory(id, input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = categories.value.findIndex((c) => c.id === id);
    if (idx !== -1) categories.value[idx] = result.data!;
    logAuditEvent({ action: "update", entity_type: "category", entity_id: id, detail: input });
    return true;
  }

  async function archive(id: string) {
    const result = await archiveCategory(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = categories.value.findIndex((c) => c.id === id);
    if (idx !== -1) categories.value[idx] = result.data!;
    logAuditEvent({
      action: "update",
      entity_type: "category",
      entity_id: id,
      detail: { action: "archive" },
    });
    return true;
  }

  async function restore(id: string) {
    const result = await restoreCategory(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = categories.value.findIndex((c) => c.id === id);
    if (idx !== -1) categories.value[idx] = result.data!;
    logAuditEvent({
      action: "update",
      entity_type: "category",
      entity_id: id,
      detail: { action: "restore" },
    });
    return true;
  }

  async function remove(id: string) {
    const result = await deleteCategory(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    categories.value = categories.value.filter((c) => c.id !== id);
    logAuditEvent({ action: "delete", entity_type: "category", entity_id: id });
    return true;
  }

  return {
    categories,
    loading,
    error,
    fetchCategories,
    addCategory,
    editCategory,
    archive,
    restore,
    remove,
  };
});
