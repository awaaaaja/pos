-- ============================================
-- KopiPOS — Sprint 3: Storage Bucket for Product Images
-- Migration: 20240103000000_storage_product_images.sql
-- ============================================

-- Create product-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,                -- public read for product images
  5242880,             -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
);

-- RLS policies for storage.objects (product-images bucket)

-- Anyone can read product images (public bucket)
CREATE POLICY "product_images_select_public" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'product-images');

-- Only authenticated users can upload
CREATE POLICY "product_images_insert_auth" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND auth.role() = 'authenticated'
  );

-- Only owner can delete product images
CREATE POLICY "product_images_delete_owner" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'product-images'
    AND (
      SELECT role FROM profiles WHERE id = auth.uid()
    ) = 'owner'
  );

-- Only owner can update (replace) product images
CREATE POLICY "product_images_update_owner" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'product-images'
    AND (
      SELECT role FROM profiles WHERE id = auth.uid()
    ) = 'owner'
  );
