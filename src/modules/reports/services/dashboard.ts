import { supabase } from "@/services/supabase";

export interface DashboardMetrics {
  revenueToday: number;
  revenueMonth: number;
  ordersToday: number;
  ordersMonth: number;
  aov: number;
  topProducts: { name: string; qty: number; revenue: number }[];
  lowStock: { name: string; stock: number; minimum: number }[];
  paymentBreakdown: { method: string; count: number; total: number }[];
}

export async function getDashboardMetrics(outletId?: string): Promise<DashboardMetrics> {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  // Build queries with optional outlet scoping
  const ordersTodayQuery = supabase
    .from("orders")
    .select("total")
    .gte("created_at", todayStart)
    .in("status", ["completed"]);
  const ordersMonthQuery = supabase
    .from("orders")
    .select("total")
    .gte("created_at", monthStart)
    .in("status", ["completed"]);
  const paymentsQuery = supabase
    .from("payments")
    .select("method, amount")
    .gte("created_at", monthStart);

  if (outletId) {
    ordersTodayQuery.eq("outlet_id", outletId);
    ordersMonthQuery.eq("outlet_id", outletId);
    // payments scoped through orders
    const { data: orderIds } = await supabase.from("orders").select("id").eq("outlet_id", outletId);
    if (orderIds?.length) {
      paymentsQuery.in("order_id", orderIds.map((o) => o.id));
    } else {
      paymentsQuery.in("order_id", ["00000000-0000-0000-0000-000000000000"]);
    }
  }

  const [ordersToday, ordersMonth, lowStock, payments] = await Promise.all([
    ordersTodayQuery,
    ordersMonthQuery,
    supabase
      .from("ingredients")
      .select("name, stock, minimum_stock")
      .eq("is_active", true),
    paymentsQuery,
  ]);

  // Top products — scope via orders if outlet specified
  let topProductsQuery = supabase
    .from("order_items")
    .select("quantity, subtotal, product:products(name)")
    .gte("created_at", monthStart);
  if (outletId) {
    const { data: orderIds } = await supabase.from("orders").select("id").eq("outlet_id", outletId);
    if (orderIds?.length) {
      topProductsQuery = topProductsQuery.in("order_id", orderIds.map((o) => o.id));
    } else {
      topProductsQuery = topProductsQuery.in("order_id", ["00000000-0000-0000-0000-000000000000"]);
    }
  }
  const topProducts = await topProductsQuery;

  const todayOrders = ordersToday.data ?? [];
  const monthOrders = ordersMonth.data ?? [];

  const revenueToday = todayOrders.reduce((s, o) => s + (o.total ?? 0), 0);
  const revenueMonth = monthOrders.reduce((s, o) => s + (o.total ?? 0), 0);
  const ordersTodayCount = todayOrders.length;
  const ordersMonthCount = monthOrders.length;
  const aov = ordersMonthCount > 0 ? Math.round(revenueMonth / ordersMonthCount) : 0;

  // Top products
  const productMap = new Map<string, { name: string; qty: number; revenue: number }>();
  for (const item of topProducts.data ?? []) {
    const product = item.product as unknown as { name: string } | null;
    const name = product?.name ?? "Unknown";
    const existing = productMap.get(name) ?? { name, qty: 0, revenue: 0 };
    existing.qty += item.quantity;
    existing.revenue += item.subtotal;
    productMap.set(name, existing);
  }
  const topProductsList = [...productMap.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 5);

  // Low stock (manual filter since RPC filter won't work in select)
  const allIngredients = lowStock.data ?? [];
  const lowStockList = allIngredients
    .filter((i) => i.stock <= i.minimum_stock)
    .sort((a, b) => a.stock - b.stock)
    .slice(0, 5)
    .map((i) => ({ name: i.name as string, stock: i.stock as number, minimum: i.minimum_stock as number }));

  // Payment breakdown
  const methodMap = new Map<string, { count: number; total: number }>();
  for (const p of payments.data ?? []) {
    const existing = methodMap.get(p.method) ?? { count: 0, total: 0 };
    existing.count++;
    existing.total += p.amount;
    methodMap.set(p.method, existing);
  }
  const paymentBreakdown = [...methodMap.entries()].map(([method, v]) => ({
    method,
    ...v,
  }));

  return {
    revenueToday,
    revenueMonth,
    ordersToday: ordersTodayCount,
    ordersMonth: ordersMonthCount,
    aov,
    topProducts: topProductsList,
    lowStock: lowStockList,
    paymentBreakdown,
  };
}
