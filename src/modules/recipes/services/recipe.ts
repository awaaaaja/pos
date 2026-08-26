import { supabase } from "@/services/supabase";
import type { Recipe, RecipeItem } from "@/types";

export async function fetchRecipes(): Promise<Recipe[]> {
  const { data, error } = await supabase
    .from("recipes")
    .select(`
      *,
      product:products(name),
      recipe_items(*, ingredient:ingredients(name, unit))
    `)
    .eq("is_active", true)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("fetchRecipes error:", error);
    return [];
  }
  return (data as Recipe[]) ?? [];
}

export async function createRecipe(
  productId: string,
  items: { ingredient_id: string; qty: number }[],
): Promise<Recipe | null> {
  const { data, error } = await supabase
    .from("recipes")
    .insert({ product_id: productId })
    .select()
    .single();

  if (error || !data) {
    console.error("createRecipe error:", error);
    return null;
  }

  if (items.length > 0) {
    const { error: itemsError } = await supabase.from("recipe_items").insert(
      items.map((i) => ({
        recipe_id: data.id,
        ingredient_id: i.ingredient_id,
        qty: i.qty,
      })),
    );

    if (itemsError) {
      console.error("createRecipeItems error:", itemsError);
    }
  }

  return data as Recipe;
}

export async function updateRecipeItems(
  recipeId: string,
  items: { ingredient_id: string; qty: number }[],
): Promise<boolean> {
  // Delete existing items
  await supabase.from("recipe_items").delete().eq("recipe_id", recipeId);

  // Insert new items
  if (items.length > 0) {
    const { error } = await supabase.from("recipe_items").insert(
      items.map((i) => ({
        recipe_id: recipeId,
        ingredient_id: i.ingredient_id,
        qty: i.qty,
      })),
    );
    return !error;
  }
  return true;
}

export async function deleteRecipe(recipeId: string): Promise<boolean> {
  const { error } = await supabase
    .from("recipes")
    .update({ is_active: false })
    .eq("id", recipeId);

  return !error;
}
