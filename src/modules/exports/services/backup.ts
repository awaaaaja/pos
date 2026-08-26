import { supabase } from "@/services/supabase";

export interface BackupRecord {
  id: string;
  filename: string;
  created_at: string;
  size: number;
}

export async function createBackup(): Promise<{ success: boolean; data?: string; error?: string }> {
  try {
    const [products, customers, orders, expenses, ingredients] = await Promise.all([
      supabase.from("products").select("*"),
      supabase.from("customers").select("*"),
      supabase.from("orders").select("*, order_items(*)"),
      supabase.from("expenses").select("*"),
      supabase.from("ingredients").select("*"),
    ]);

    const backup = {
      version: "1.0",
      created_at: new Date().toISOString(),
      data: {
        products: products.data ?? [],
        customers: customers.data ?? [],
        orders: orders.data ?? [],
        expenses: expenses.data ?? [],
        ingredients: ingredients.data ?? [],
      },
    };

    const json = JSON.stringify(backup, null, 2);
    const blob = new Blob([json], { type: "application/json" });
    const filename = `kopipos-backup-${new Date().toISOString().slice(0, 10)}.json`;

    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);

    return { success: true, data: json };
  } catch (e) {
    return { success: false, error: String(e) };
  }
}

export async function exportOrdersCSV(): Promise<void> {
  const { data } = await supabase
    .from("orders")
    .select("invoice_number, status, total, payment_method, created_at")
    .order("created_at", { ascending: false });

  const rows = (data ?? []).map((r) =>
    [r.invoice_number, r.status, r.total, r.payment_method, r.created_at].join(","),
  );
  const csv = "Invoice,Status,Total,Payment,Date\n" + rows.join("\n");
  downloadCSV(csv, `orders-${new Date().toISOString().slice(0, 10)}.csv`);
}

function downloadCSV(csv: string, filename: string) {
  const blob = new Blob([csv], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
