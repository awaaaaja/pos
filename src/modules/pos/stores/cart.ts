import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { supabase } from "@/services/supabase";
import type { CartItem, CartItemModifier } from "@/types";
import * as paymentService from "@/modules/pos/services/payment";

export const useCartStore = defineStore("cart", () => {
  const items = ref<CartItem[]>([]);
  const holdOrderId = ref<string | null>(null);
  const holdInvoiceNumber = ref<string | null>(null);
  const orderType = ref<"dine_in" | "takeaway">("dine_in");
  const notes = ref("");

  // Settings (tax/service charge) — loaded from DB
  const taxPercent = ref(0);
  const serviceChargePercent = ref(0);
  const taxEnabled = ref(false);
  const serviceChargeEnabled = ref(false);

  // Discount state
  const discount = ref(0);
  const discountType = ref<string | null>(null); // "manual" | "coupon" | "promo"
  const couponCode = ref("");
  const couponId = ref<string | null>(null);
  const promoId = ref<string | null>(null);
  const customerId = ref<string | null>(null);

  // ── Getters ──────────────────────────────────────────────

  const itemCount = computed(() => items.value.reduce((sum, i) => sum + i.quantity, 0));

  const subtotal = computed(() => items.value.reduce((sum, i) => sum + i.subtotal, 0));

  const modifierTotal = computed(() =>
    items.value.reduce((sum, i) => sum + i.modifier_total * i.quantity, 0),
  );

  const tax = computed(() =>
    taxEnabled.value ? Math.round(subtotal.value * taxPercent.value) : 0,
  );

  const serviceCharge = computed(() =>
    serviceChargeEnabled.value ? Math.round(subtotal.value * serviceChargePercent.value) : 0,
  );

  // ponytail: subtotal already includes modifier_total via calcItemSubtotal
  const total = computed(() => Math.max(0, subtotal.value - discount.value + tax.value + serviceCharge.value));

  const isEmpty = computed(() => items.value.length === 0);

  // ── Helpers ──────────────────────────────────────────────

  function calcItemSubtotal(item: CartItem): number {
    return (item.unit_price + item.modifier_total) * item.quantity;
  }

  // ── Actions ──────────────────────────────────────────────

  function addItem(
    product: { id: string; name: string; selling_price: number; image_url: string | null },
    modifiers: CartItemModifier[] = [],
  ) {
    const modifierKey = modifiers
      .map((m) => m.option_id)
      .sort()
      .join(",");

    // Check if same product + same modifiers already in cart
    const existing = items.value.find(
      (i) =>
        i.product_id === product.id &&
        i.modifiers
          .map((m) => m.option_id)
          .sort()
          .join(",") === modifierKey,
    );

    if (existing) {
      existing.quantity++;
      existing.subtotal = calcItemSubtotal(existing);
    } else {
      const modifierTotal = modifiers.reduce((sum, m) => sum + m.price_adjustment, 0);
      const newItem: CartItem = {
        product_id: product.id,
        product_name: product.name,
        product_price: product.selling_price,
        image_url: product.image_url,
        quantity: 1,
        unit_price: product.selling_price,
        modifiers,
        modifier_total: modifierTotal,
        notes: "",
        subtotal: product.selling_price + modifierTotal,
      };
      items.value.push(newItem);
    }
  }

  function removeItem(index: number) {
    items.value.splice(index, 1);
  }

  function updateQuantity(index: number, qty: number) {
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    const item = items.value[index];
    if (item) {
      item.quantity = qty;
      item.subtotal = calcItemSubtotal(item);
    }
  }

  function incrementQuantity(index: number) {
    const item = items.value[index];
    if (item) {
      item.quantity++;
      item.subtotal = calcItemSubtotal(item);
    }
  }

  function decrementQuantity(index: number) {
    const item = items.value[index];
    if (item) {
      if (item.quantity <= 1) {
        removeItem(index);
      } else {
        item.quantity--;
        item.subtotal = calcItemSubtotal(item);
      }
    }
  }

  function setItemNotes(index: number, note: string) {
    const item = items.value[index];
    if (item) item.notes = note;
  }

  function clearCart() {
    items.value = [];
    holdOrderId.value = null;
    holdInvoiceNumber.value = null;
    notes.value = "";
    clearDiscount();
  }

  // ── Settings ──────────────────────────────────────────────

  async function loadSettings(outletId: string) {
    const { data } = await supabase.rpc("get_settings", { p_outlet_id: outletId });
    if (!data) return;
    for (const row of data as { key: string; value: Record<string, unknown> }[]) {
      if (row.key === "tax") {
        taxPercent.value = ((row.value.percent as number) || 0) / 100;
        taxEnabled.value = (row.value.enabled as boolean) ?? false;
      }
      if (row.key === "service_charge") {
        serviceChargePercent.value = ((row.value.percent as number) || 0) / 100;
        serviceChargeEnabled.value = (row.value.enabled as boolean) ?? false;
      }
    }
  }

  // ── Discount / Coupon ──────────────────────────────────────

  function applyManualDiscount(amount: number) {
    discount.value = Math.min(amount, subtotal.value);
    discountType.value = "manual";
    couponCode.value = "";
    couponId.value = null;
    promoId.value = null;
  }

  async function applyCoupon(code: string): Promise<{ success: boolean; error?: string }> {
    const { data, error } = await supabase.rpc("validate_coupon", {
      p_code: code,
      p_amount: subtotal.value,
    });
    if (error) return { success: false, error: error.message };
    if (data?.error) return { success: false, error: data.error };

    discount.value = data.discount_amount;
    discountType.value = "coupon";
    couponCode.value = code;
    couponId.value = data.coupon_id;
    promoId.value = data.promo_id;
    return { success: true };
  }

  function clearDiscount() {
    discount.value = 0;
    discountType.value = null;
    couponCode.value = "";
    couponId.value = null;
    promoId.value = null;
  }

  // ── Hold / Resume (Draft Order) ──────────────────────────

  async function holdOrder(): Promise<{ success: boolean; error?: string }> {
    if (items.value.length === 0) return { success: false, error: "Cart is empty" };

    const {
      data: { user },
    } = await supabase.auth.getUser();

    // Get outlet_id from profile
    const { data: profile } = await supabase.from("profiles").select("outlet_id").eq("id", user?.id).single();
    const outletId = profile?.outlet_id ?? null;

    // If resuming a held order, delete old items first
    if (holdOrderId.value) {
      await supabase
        .from("order_item_modifiers")
        .delete()
        .in(
          "order_item_id",
          (
            await supabase.from("order_items").select("id").eq("order_id", holdOrderId.value)
          ).data?.map((i) => i.id) ?? [],
        );
      await supabase.from("order_items").delete().eq("order_id", holdOrderId.value);
    }

    const orderData = {
      order_type: orderType.value,
      cashier_id: user?.id ?? null,
      outlet_id: outletId,
      customer_id: customerId.value,
      status: "draft" as const,
      subtotal: subtotal.value,
      discount: discount.value,
      discount_type: discountType.value,
      coupon_id: couponId.value,
      promo_id: promoId.value,
      tax: tax.value,
      service_charge: serviceCharge.value,
      total: total.value,
      notes: notes.value || null,
    };

    let orderId = holdOrderId.value;

    if (orderId) {
      // Update existing draft
      const { error } = await supabase.from("orders").update(orderData).eq("id", orderId);
      if (error) return { success: false, error: error.message };
    } else {
      // Create new draft
      const { data, error } = await supabase
        .from("orders")
        .insert(orderData)
        .select("id, invoice_number")
        .single();
      if (error) return { success: false, error: error.message };
      orderId = data.id;
      holdOrderId.value = data.id;
      holdInvoiceNumber.value = data.invoice_number;
    }

    // Insert order items
    for (const item of items.value) {
      const { data: orderItem, error: itemError } = await supabase
        .from("order_items")
        .insert({
          order_id: orderId,
          product_id: item.product_id,
          product_name: item.product_name,
          quantity: item.quantity,
          unit_price: item.unit_price,
          modifier_total: item.modifier_total,
          discount: 0,
          subtotal: item.subtotal,
          notes: item.notes || null,
          status: "pending",
        })
        .select("id")
        .single();

      if (itemError) return { success: false, error: itemError.message };

      // Insert modifier selections
      if (item.modifiers.length > 0 && orderItem) {
        const modifierRows = item.modifiers.map((m) => ({
          order_item_id: orderItem.id,
          modifier_option_id: m.option_id,
          price_adjustment: m.price_adjustment,
        }));
        const { error: modError } = await supabase
          .from("order_item_modifiers")
          .insert(modifierRows);
        if (modError) return { success: false, error: modError.message };
      }
    }

    return { success: true };
  }

  async function resumeDraftOrders(): Promise<
    { id: string; invoice_number: string | null; item_count: number; total: number }[]
  > {
    // Get current user's outlet_id
    const { data: { user } } = await supabase.auth.getUser();
    const { data: profile } = await supabase.from("profiles").select("outlet_id").eq("id", user?.id).single();

    let query = supabase
      .from("orders")
      .select("id, invoice_number, total, order_items(id)")
      .eq("status", "draft")
      .order("created_at", { ascending: false });

    if (profile?.outlet_id) {
      query = query.eq("outlet_id", profile.outlet_id);
    }

    const { data: orders, error } = await query;

    if (error || !orders) return [];

    return orders.map((o) => ({
      id: o.id,
      invoice_number: o.invoice_number,
      item_count: o.order_items?.length ?? 0,
      total: o.total,
    }));
  }

  async function resumeOrder(orderId: string): Promise<{ success: boolean; error?: string }> {
    // Load order
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*, order_items(*, order_item_modifiers(*, modifier_option(*)))")
      .eq("id", orderId)
      .single();

    if (orderError || !order) return { success: false, error: "Order not found" };

    // Clear current cart
    clearCart();

    // Set order info
    holdOrderId.value = order.id;
    holdInvoiceNumber.value = order.invoice_number;
    orderType.value = order.order_type;
    notes.value = order.notes ?? "";

    // Load items into cart
    for (const oi of order.order_items ?? []) {
      const modifiers: CartItemModifier[] = (oi.order_item_modifiers ?? []).map(
        (oim: {
          modifier_option_id: string;
          price_adjustment: number;
          modifier_option?: { name: string };
        }) => ({
          option_id: oim.modifier_option_id,
          option_name: oim.modifier_option?.name ?? "",
          price_adjustment: oim.price_adjustment,
        }),
      );

      const modifierTotal = modifiers.reduce((sum, m) => sum + m.price_adjustment, 0);

      items.value.push({
        product_id: oi.product_id,
        product_name: oi.product?.name ?? "Unknown",
        product_price: oi.unit_price,
        image_url: oi.product?.image_url ?? null,
        quantity: oi.quantity,
        unit_price: oi.unit_price,
        modifiers,
        modifier_total: modifierTotal,
        notes: oi.notes ?? "",
        subtotal: oi.subtotal,
      });
    }

    return { success: true };
  }

  // ── Confirm Order (DRAFT → CONFIRMED) ──────────────────────

  async function confirmOrder(
    tableId?: string,
  ): Promise<{ success: boolean; invoice_number?: string; error?: string }> {
    if (items.value.length === 0) return { success: false, error: "Cart is empty" };

    // If no held order yet, hold first
    if (!holdOrderId.value) {
      const holdResult = await holdOrder();
      if (!holdResult.success) return { success: false, error: holdResult.error };
    }

    // Confirm via RPC (sets invoice#, table to OCCUPIED)
    const result = await paymentService.confirmOrder(holdOrderId.value!, tableId);
    if (!result.success) return { success: false, error: result.error };

    // Clear cart after successful confirm
    clearCart();
    return { success: true, invoice_number: result.invoice_number };
  }

  return {
    items,
    holdOrderId,
    holdInvoiceNumber,
    orderType,
    notes,
    itemCount,
    subtotal,
    modifierTotal,
    discount,
    discountType,
    couponCode,
    customerId,
    tax,
    serviceCharge,
    total,
    isEmpty,
    loadSettings,
    applyManualDiscount,
    applyCoupon,
    clearDiscount,
    addItem,
    removeItem,
    updateQuantity,
    incrementQuantity,
    decrementQuantity,
    setItemNotes,
    clearCart,
    holdOrder,
    resumeDraftOrders,
    resumeOrder,
    confirmOrder,
  };
});
