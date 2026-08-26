import type { Router } from "vue-router";
import { useAuthStore } from "@/modules/auth/stores/auth";

/**
 * Setup auth middleware for Vue Router.
 * Must be called after router is created and Pinia is installed.
 */
export function setupAuthMiddleware(router: Router) {
  router.beforeEach(async (to, _from, next) => {
    const auth = useAuthStore();

    // Initialize auth state on first navigation
    if (!auth.user && !auth.loading) {
      await auth.init();
    }

    const requiresAuth = to.matched.some((record) => record.meta.requiresAuth);
    const requiredRole = to.meta.role as string | undefined;

    // Public routes — no auth needed
    if (!requiresAuth) {
      // If already logged in and going to login page, redirect to dashboard
      if (to.name === "login" && auth.isAuthenticated) {
        return next(getDashboardRoute(auth.role));
      }
      return next();
    }

    // Auth required but not logged in
    if (!auth.isAuthenticated) {
      return next({ name: "login", query: { redirect: to.fullPath } });
    }

    // Role check
    if (requiredRole && auth.role !== requiredRole) {
      // Redirect to own dashboard
      return next(getDashboardRoute(auth.role));
    }

    next();
  });
}

function getDashboardRoute(role: string | null): { name: string } {
  switch (role) {
    case "owner":
      return { name: "owner-dashboard" };
    case "cashier":
      return { name: "cashier-pos" };
    case "barista":
      return { name: "kds-main" };
    default:
      return { name: "login" };
  }
}
