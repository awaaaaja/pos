import { supabase } from "@/services/supabase";
import type { Ingredient } from "@/types";

export async function fetchIngredients(): Promise<Ingredient[]> {
  const { data, error } = await supabase
    .from("ingredients")
    .select("*")
    .eq("is_active", true)
    .order("name");

  if (error) {
    console.error("fetchIngredients error:", error);
    return [];
  }
  return (data as Ingredient[]) ?? [];
}

export async function createIngredient(
  input: Omit<Ingredient, "id" | "created_at" | "updated_at" | "stock">,
): Promise<Ingredient | null> {
  const { data, error } = await supabase
    .from("ingredients")
    .insert(input)
    .select()
    .single();

  if (error) {
    console.error("createIngredient error:", error);
    return null;
  }
  return data as Ingredient;
}

export async function updateIngredient(
  id: string,
  input: Partial<Omit<Ingredient, "id" | "created_at">>,
): Promise<boolean> {
  const { error } = await supabase
    .from("ingredients")
    .update({ ...input, updated_at: new Date().toISOString() })
    .eq("id", id);

  return !error;
}

export async function archiveIngredient(id: string): Promise<boolean> {
  const { error } = await supabase
    .from("ingredients")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("id", id);

  return !error;
}
