-- Login by PIN: RPC that bypasses RLS for PIN lookup
-- SECURITY DEFINER so unauthenticated users can call it

CREATE OR REPLACE FUNCTION public.login_by_pin(pin_hash TEXT)
RETURNS TABLE(id UUID, full_name TEXT, pin_code TEXT, role TEXT, outlet_id UUID, is_active BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.pin_code, p.role::text, p.outlet_id, p.is_active, p.created_at
  FROM profiles p
  WHERE p.pin_code = pin_hash AND p.is_active = true;
END;
$$;

COMMENT ON FUNCTION public.login_by_pin IS 'PIN login lookup — bypasses RLS via SECURITY DEFINER';
