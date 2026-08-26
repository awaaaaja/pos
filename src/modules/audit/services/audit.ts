import { supabase } from "@/services/supabase";
import type { AuditLog, ApiResponse } from "@/types";

export interface AuditLogFilters {
  dateFrom?: string;
  dateTo?: string;
  actor_id?: string;
  action?: string;
  entity_type?: string;
}

export async function getAuditLogs(
  filters: AuditLogFilters = {},
  limit = 100,
): Promise<ApiResponse<AuditLog[]>> {
  let query = supabase
    .from("audit_logs")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (filters.dateFrom) {
    query = query.gte("created_at", filters.dateFrom);
  }
  if (filters.dateTo) {
    query = query.lte("created_at", filters.dateTo);
  }
  if (filters.actor_id) {
    query = query.eq("actor_id", filters.actor_id);
  }
  if (filters.action) {
    query = query.eq("action", filters.action);
  }
  if (filters.entity_type) {
    query = query.eq("entity_type", filters.entity_type);
  }

  const { data, error } = await query;

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}
