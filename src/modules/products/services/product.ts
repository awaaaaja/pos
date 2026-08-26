import { supabase } from "@/services/supabase";
import type { Product, ApiResponse } from "@/types";

export type ProductInput = Omit<Product, "id" | "created_at" | "updated_at">;

export async function getProducts(): Promise<ApiResponse<Product[]>> {
  const { data, error } = await supabase
    .from("products")
    .select("*, categories(name)")
    .order("created_at", { ascending: false });

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getActiveProducts(): Promise<ApiResponse<Product[]>> {
  const { data, error } = await supabase
    .from("products")
    .select("*, categories(name)")
    .eq("is_active", true)
    .order("name");

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getProductByBarcode(barcode: string): Promise<ApiResponse<Product>> {
  const { data, error } = await supabase
    .from("products")
    .select("*, categories(name)")
    .eq("barcode", barcode)
    .eq("is_active", true)
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createProduct(input: ProductInput): Promise<ApiResponse<Product>> {
  const { data, error } = await supabase.from("products").insert(input).select().single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updateProduct(
  id: string,
  input: Partial<ProductInput>,
): Promise<ApiResponse<Product>> {
  const { data, error } = await supabase
    .from("products")
    .update(input)
    .eq("id", id)
    .select()
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function archiveProduct(id: string): Promise<ApiResponse<Product>> {
  return updateProduct(id, { is_active: false });
}

export async function restoreProduct(id: string): Promise<ApiResponse<Product>> {
  return updateProduct(id, { is_active: true });
}

export async function deleteProduct(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("products").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}

/**
 * Upload product image to Supabase Storage
 */
export async function uploadProductImage(
  productId: string,
  file: File,
): Promise<ApiResponse<string>> {
  const ext = file.name.split(".").pop();
  const path = `products/${productId}.${ext}`;

  const { error: uploadError } = await supabase.storage
    .from("product-images")
    .upload(path, file, { upsert: true });

  if (uploadError) return { data: null, error: uploadError.message };

  const {
    data: { publicUrl },
  } = supabase.storage.from("product-images").getPublicUrl(path);

  return { data: publicUrl, error: null };
}
