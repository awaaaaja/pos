import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { Profile, UserRole } from "@/types";
import {
  loginOwner,
  loginByPin,
  logout as authLogout,
  getCurrentUser,
  logAuditEvent,
} from "@/modules/auth/services/auth";

export const useAuthStore = defineStore("auth", () => {
  const user = ref<{ id: string; email?: string; profile: Profile } | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Getters
  const isAuthenticated = computed(() => !!user.value);
  const profile = computed(() => user.value?.profile ?? null);
  const role = computed<UserRole | null>(() => user.value?.profile.role ?? null);
  const isOwner = computed(() => role.value === "owner");
  const isCashier = computed(() => role.value === "cashier");
  const isBarista = computed(() => role.value === "barista");

  function hasPermission(_permissionKey: string): boolean {
    if (!profile.value) return false;
    // Owner has all permissions
    if (profile.value.role === "owner") return true;
    // For cashier/barista, check against role_permissions
    // TODO(sprint-2): load permissions from DB and cache
    return false;
  }

  // Actions
  async function login(email: string, password: string) {
    loading.value = true;
    error.value = null;

    const result = await loginOwner(email, password);

    if (result.error) {
      error.value = result.error;
      loading.value = false;
      return false;
    }

    user.value = result.data;
    loading.value = false;

    await logAuditEvent({ action: "login" });
    return true;
  }

  async function loginWithPin(pin: string) {
    loading.value = true;
    error.value = null;

    const result = await loginByPin(pin);

    if (result.error) {
      error.value = result.error;
      loading.value = false;
      return false;
    }

    user.value = result.data;
    loading.value = false;

    // PIN login audit
    await logAuditEvent({ action: "login", detail: { method: "pin", user: result.data?.profile.full_name } }).catch(() => {});
    return true;
  }

  async function logout() {
    await logAuditEvent({ action: "logout" });
    await authLogout();
    user.value = null;
    error.value = null;
  }

  async function verifyPin(pin: string): Promise<boolean> {
    const result = await loginByPin(pin);
    return !result.error && result.data?.profile.role === "owner";
  }

  async function init() {
    loading.value = true;
    try {
      const currentUser = await getCurrentUser();
      if (currentUser) {
        user.value = currentUser;
      }
    } catch {
      // No session — not logged in, that's fine
    }
    loading.value = false;
  }

  return {
    user,
    loading,
    error,
    isAuthenticated,
    profile,
    role,
    isOwner,
    isCashier,
    isBarista,
    hasPermission,
    login,
    loginWithPin,
    logout,
    verifyPin,
    init,
  };
});
