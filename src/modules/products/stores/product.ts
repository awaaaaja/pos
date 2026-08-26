import { defineStore } from "pinia";
import { ref } from "vue";
import type { Product } from "@/types";
import {
  getProducts,
  createProduct,
  updateProduct,
  archiveProduct,
  restoreProduct,
  deleteProduct,
  uploadProductImage,
  type ProductInput,
} from "@/modules/products/services/product";
import { logAuditEvent } from "@/modules/auth/services/auth";

export const useProductStore = defineStore("products", () => {
  const products = ref<Product[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchProducts() {
    loading.value = true;
    const result = await getProducts();
    if (result.error) {
      error.value = result.error;
    } else {
      products.value = result.data ?? [];
    }
    loading.value = false;
  }

  async function addProduct(input: ProductInput) {
    const result = await createProduct(input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    products.value.unshift(result.data!);
    logAuditEvent({
      action: "create",
      entity_type: "product",
      entity_id: result.data!.id,
      detail: { name: input.name },
    });
    return true;
  }

  async function editProduct(id: string, input: Partial<ProductInput>) {
    const result = await updateProduct(id, input);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = products.value.findIndex((p) => p.id === id);
    if (idx !== -1) products.value[idx] = result.data!;
    logAuditEvent({ action: "update", entity_type: "product", entity_id: id, detail: input });
    return true;
  }

  async function archive(id: string) {
    const result = await archiveProduct(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = products.value.findIndex((p) => p.id === id);
    if (idx !== -1) products.value[idx] = result.data!;
    logAuditEvent({
      action: "update",
      entity_type: "product",
      entity_id: id,
      detail: { action: "archive" },
    });
    return true;
  }

  async function restore(id: string) {
    const result = await restoreProduct(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = products.value.findIndex((p) => p.id === id);
    if (idx !== -1) products.value[idx] = result.data!;
    logAuditEvent({
      action: "update",
      entity_type: "product",
      entity_id: id,
      detail: { action: "restore" },
    });
    return true;
  }

  async function remove(id: string) {
    const result = await deleteProduct(id);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    products.value = products.value.filter((p) => p.id !== id);
    logAuditEvent({ action: "delete", entity_type: "product", entity_id: id });
    return true;
  }

  async function uploadImage(productId: string, file: File) {
    const result = await uploadProductImage(productId, file);
    if (result.error) {
      error.value = result.error;
      return false;
    }
    const idx = products.value.findIndex((p) => p.id === productId);
    if (idx !== -1) products.value[idx].image_url = result.data!;
    return true;
  }

  return {
    products,
    loading,
    error,
    fetchProducts,
    addProduct,
    editProduct,
    archive,
    restore,
    remove,
    uploadImage,
  };
});
