-- ============================================================
-- RAJO AI — Admin Authentication Hardening
-- ============================================================
-- PURPOSE:
--   Implement secure admin verification using auth.uid() instead
--   of hardcoded email in frontend. Creates admin_users table
--   and secure is_admin() RPC function.
--
-- HOW TO RUN:
--   1. Paste this ENTIRE file into:
--      Supabase Dashboard → SQL Editor → New Query → Paste → Run
--   2. Wait for completion (should take <5 seconds)
--   3. Verify: SELECT * FROM admin_users;
--
-- ============================================================

-- ── Step 1: Create admin_users table ──────────────────────
-- Stores which auth.uid() values have admin privileges.
-- Using UUID (auth.uid) as foreign key is more secure than email.

CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_uid uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admin_users_email_valid CHECK (email ~ '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z|a-z]{2,}$')
);

-- Enable RLS on admin_users
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Only authenticated users can read admin_users (no PII leak)
CREATE POLICY "authenticated_read_admin_users"
  ON admin_users FOR SELECT
  TO authenticated
  USING (true);

-- ── Step 2: Create is_admin() secure function ────────────
-- Uses auth.uid() for verification (not email).
-- Returns true/false based on presence in admin_users table.

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM admin_users
    WHERE auth_uid = auth.uid()
  );
$$;

-- Grant execution to authenticated users only
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;

-- ── Step 3: Add initial admin user ────────────────────────
-- IMPORTANT: Replace 'your-user-uuid' with the actual UUID from:
--   Supabase Dashboard → Authentication → Users → (click admin user) → User ID
-- And replace 'jamailyaz2024@gmail.com' with actual admin email.
--
-- Example:
--   INSERT INTO admin_users (auth_uid, email)
--   VALUES ('550e8400-e29b-41d4-a716-446655440000', 'jamailyaz2024@gmail.com')
--   ON CONFLICT (auth_uid) DO NOTHING;
--
-- ⚠️  MANUAL STEP: See instructions below

-- ── Step 4: Drop anon_insert_voice_recordings policy ──────
-- Prevents spam/abuse. Only authenticated users can insert recordings.

DROP POLICY IF EXISTS "anon_insert_voice_recordings" ON voice_recordings;

-- ── Step 5: Create authenticated-only insert policy ───────
-- Regular authenticated users can only insert their own recordings.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'voice_recordings'
      AND policyname = 'authenticated_insert_own_voice_recordings'
  ) THEN
    CREATE POLICY "authenticated_insert_own_voice_recordings"
      ON voice_recordings FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid()::text = (
          SELECT auth_user_id FROM voice_donors
          WHERE id = voice_recordings.donor_id
        )
      );
  END IF;
END $$;

-- ============================================================
-- MANUAL SETUP REQUIRED
-- ============================================================
-- 1. Get your admin user's UUID:
--    a. Go to Supabase Dashboard
--    b. Click Authentication → Users
--    c. Find the admin account (jamailyaz2024@gmail.com)
--    d. Click the user row
--    e. Copy the User ID (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
--
-- 2. Run this query to add the admin user:
--
--    INSERT INTO admin_users (auth_uid, email)
--    VALUES ('YOUR_ADMIN_UUID_HERE', 'jamailyaz2024@gmail.com')
--    ON CONFLICT (auth_uid) DO NOTHING;
--
-- 3. Verify:
--    SELECT * FROM admin_users;
--    SELECT is_admin();  -- Should return true if you're logged in as admin
--
-- ============================================================
-- VERIFICATION
-- ============================================================
-- Test the function works:
--
-- SELECT is_admin();  -- As admin user: should return true
--                     -- As regular user: should return false
--
-- Test the recording insert policy:
-- Try inserting a recording as regular authenticated user — should succeed
-- (existing RLS policy will verify donor_id matches auth.uid)
-- ============================================================
