import { supabase } from "@/services/supabase";
import type { Profile, ApiResponse, UserRole } from "@/types";

export interface AuthUser {
  id: string;
  email?: string;
  profile: Profile;
}

/**
 * Login owner via email + password (Supabase Auth)
 */
export async function loginOwner(email: string, password: string): Promise<ApiResponse<AuthUser>> {
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (authError || !authData.user) {
    return { data: null, error: authError?.message || "Login failed" };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", authData.user.id)
    .single();

  if (profileError || !profile) {
    return { data: null, error: "Profile not found" };
  }

  if (profile.role !== "owner") {
    await supabase.auth.signOut();
    return { data: null, error: "This account is not an owner account" };
  }

  if (!profile.is_active) {
    await supabase.auth.signOut();
    return { data: null, error: "Account is inactive" };
  }

  return {
    data: {
      id: authData.user.id,
      email: authData.user.email,
      profile,
    },
    error: null,
  };
}

/**
 * Login cashier/barista via PIN
 * Looks up profile by PIN hash, then creates a session via Supabase Auth
 * using the owner's service or a dedicated edge function.
 *
 * For MVP simplicity: we use a custom approach where PIN users
 * get a magic link session or we use a database function.
 *
 * Simplified approach: PIN is checked against profiles table,
 * and we use supabase.auth.signInWithPassword with a generated
 * email pattern: {pin}@kopipos.local
 */
export async function loginByPin(pin: string): Promise<ApiResponse<AuthUser>> {
  // Hash the PIN using SHA-256 (same as what we store)
  const encoder = new TextEncoder();
  const data = encoder.encode(pin);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const pinHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

  // Look up profile via RPC (bypasses RLS)
  const { data: rows, error: rpcError } = await supabase
    .rpc("login_by_pin", { pin_hash: pinHash })
    .single();

  if (rpcError || !rows) {
    return { data: null, error: "Invalid PIN" };
  }

  // RPC no longer returns pin_code (security fix)
  const pinUser = rows as { id: string; full_name: string; role: string; outlet_id: string; is_active: boolean; created_at: string };

  // Create real Supabase Auth session so RLS policies pass
  // Email pattern: {role}@kopipos.local (seeded in auth.users)
  const email = `${pinUser.role}@kopipos.local`;
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password: pin,
  });

  if (signInError) {
    return { data: null, error: "Login failed: " + signInError.message };
  }

  // Build profile object (without pin_code hash)
  const profile: Profile = {
    id: pinUser.id,
    full_name: pinUser.full_name,
    pin_code: null,
    role: pinUser.role as UserRole,
    outlet_id: pinUser.outlet_id,
    is_active: pinUser.is_active,
    created_at: pinUser.created_at,
    updated_at: pinUser.created_at,
  };

  return {
    data: {
      id: pinUser.id,
      profile,
    },
    error: null,
  };
}

/**
 * Logout current user
 */
export async function logout(): Promise<void> {
  await supabase.auth.signOut();
}

/**
 * Get current session
 */
export async function getCurrentUser(): Promise<AuthUser | null> {
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) return null;

    const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).single();

    if (!profile) return null;

    return {
      id: user.id,
      email: user.email,
      profile,
    };
  } catch {
    return null;
  }
}

/**
 * Check if any owner exists in the system
 */
export async function hasOwner(): Promise<boolean> {
  const { data } = await supabase.rpc("has_owner");
  return data === true;
}

/**
 * Setup first owner (signUp via Supabase Auth)
 */
export async function setupOwner(
  email: string,
  password: string,
  fullName: string,
  pinCode: string,
): Promise<ApiResponse<AuthUser>> {
  // Check if owner already exists
  const exists = await hasOwner();
  if (exists) {
    return { data: null, error: "Owner already exists. Use login instead." };
  }

  // Hash PIN
  const encoder = new TextEncoder();
  const pinData = encoder.encode(pinCode);
  const pinBuffer = await crypto.subtle.digest("SHA-256", pinData);
  const pinHash = Array.from(new Uint8Array(pinBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Sign up via Supabase Auth
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, role: "owner", pin_code: pinHash },
    },
  });

  if (authError || !authData.user) {
    return { data: null, error: authError?.message || "Setup failed" };
  }

  // Wait a moment for trigger to create profile, then update it
  await new Promise((r) => setTimeout(r, 1000));

  // Ensure profile exists with correct data
  await supabase.from("profiles").upsert({
    id: authData.user.id,
    full_name: fullName,
    role: "owner",
    pin_code: pinHash,
    is_active: true,
  });

  // Fetch the profile
  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", authData.user.id)
    .single();

  if (!profile) {
    return { data: null, error: "Profile creation failed" };
  }

  return {
    data: {
      id: authData.user.id,
      email: authData.user.email,
      profile,
    },
    error: null,
  };
}

/**
 * Log audit event via database function
 */
export async function logAuditEvent(params: {
  action: string;
  entity_type?: string;
  entity_id?: string;
  detail?: Record<string, unknown>;
  reason?: string;
  approved_by?: string;
}): Promise<void> {
  let actorId: string | null = null;
  let actorName = "system";

  try {
    const { data: { user } } = await supabase.auth.getUser();
    actorId = user?.id ?? null;
    actorName = user?.email || "system";
  } catch {
    // No auth session (e.g. PIN login) — use defaults
  }

  await supabase.rpc("log_audit_event", {
    p_actor_id: actorId,
    p_actor_name: actorName,
    p_action: params.action,
    p_entity_type: params.entity_type || null,
    p_entity_id: params.entity_id || null,
    p_detail: params.detail || null,
    p_reason: params.reason || null,
    p_approved_by: params.approved_by || null,
  });
}
