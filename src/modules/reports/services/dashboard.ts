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

export async function getDashboardMetrics(): Promise<DashboardMetrics> {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  const [ordersToday, ordersMonth, topProducts, lowStock, payments] = await Promise.all([
    supabase
      .from("orders")
      .select("total")
      .gte("created_at", todayStart)
      .in("status", ["completed"]),
    supabase
      .from("orders")
      .select("total")
      .gte("created_at", monthStart)
      .in("status", ["completed"]),
    supabase
      .from("order_items")
      .select("quantity, subtotal, product:products(name)")
      .gte("created_at", monthStart),
    supabase
      .from("ingredients")
      .select("name, stock, minimum_stock")
      .eq("is_active", true),
    supabase
      .from("payments")
      .select("method, amount")
      .gte("created_at", monthStart),
  ]);

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
    const name = (item.product as { name: string } | null)?.name ?? "Unknown";
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
    .slice(0, 5);

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
