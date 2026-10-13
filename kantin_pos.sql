-- ============================================================
-- DATABASE POS KANTIN
-- Kompatibel dengan MySQL 8.0+ / MariaDB modern
-- Cara impor: mysql -u root -p < kantin_pos.sql
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS kantin_pos
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE kantin_pos;

-- Hapus objek lama agar file aman diimpor ulang saat latihan.
DROP VIEW IF EXISTS v_ringkasan_penjualan;
DROP TABLE IF EXISTS sale_items;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS products_practice;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS cashiers;
DROP TABLE IF EXISTS categories;

-- ============================================================
-- 1. MASTER DATA
-- ============================================================

CREATE TABLE categories (
  category_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(50) NOT NULL,
  CONSTRAINT uq_categories_name UNIQUE (category_name)
) ENGINE = InnoDB;

CREATE TABLE cashiers (
  cashier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  username VARCHAR(50) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_cashiers_username UNIQUE (username)
) ENGINE = InnoDB;

CREATE TABLE products (
  product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_id SMALLINT UNSIGNED NOT NULL,
  product_code VARCHAR(20) NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  product_description VARCHAR(255) NULL,
  price DECIMAL(12,2) UNSIGNED NOT NULL,
  stock INT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_products_code UNIQUE (product_code),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_products_price CHECK (price > 0)
) ENGINE = InnoDB;

-- Indeks membantu pencarian awalan nama, filter kategori, dan produk aktif.
CREATE INDEX idx_products_name ON products(product_name);
CREATE INDEX idx_products_category_active ON products(category_id, is_active);

-- ============================================================
-- 2. TRANSAKSI PENJUALAN
-- ============================================================

CREATE TABLE sales (
  sale_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  invoice_no VARCHAR(50) NOT NULL,
  cashier_id INT UNSIGNED NOT NULL,
  sale_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(12,2) UNSIGNED NOT NULL,
  discount DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0,
  total DECIMAL(12,2) UNSIGNED NOT NULL,
  payment_method ENUM('CASH', 'QRIS', 'DEBIT') NOT NULL,
  amount_paid DECIMAL(12,2) UNSIGNED NOT NULL,
  change_amount DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('PAID', 'VOID') NOT NULL DEFAULT 'PAID',
  notes VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_sales_invoice UNIQUE (invoice_no),
  CONSTRAINT fk_sales_cashier
    FOREIGN KEY (cashier_id) REFERENCES cashiers(cashier_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_sales_total CHECK (total = subtotal - discount),
  CONSTRAINT chk_sales_payment CHECK (amount_paid >= total)
) ENGINE = InnoDB;

CREATE TABLE sale_items (
  sale_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sale_id BIGINT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  quantity SMALLINT UNSIGNED NOT NULL,
  unit_price DECIMAL(12,2) UNSIGNED NOT NULL,
  line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  CONSTRAINT fk_sale_items_sale
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_sale_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_sale_items_quantity CHECK (quantity > 0)
) ENGINE = InnoDB;

CREATE INDEX idx_sales_time ON sales(sale_time);
CREATE INDEX idx_sales_status_time ON sales(status, sale_time);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);

-- ============================================================
-- 3. DATA CONTOH
-- ============================================================

INSERT INTO categories (category_id, category_name) VALUES
  (1, 'Makanan Berat'),
  (2, 'Makanan Ringan'),
  (3, 'Minuman');

INSERT INTO cashiers (cashier_id, full_name, username) VALUES
  (1, 'Ayu Lestari', 'ayu.kasir'),
  (2, 'Bima Saputra', 'bima.kasir');

INSERT INTO products
  (product_id, category_id, product_code, product_name, product_description, price, stock)
VALUES
  (1, 1, 'MKN-001', 'Nasi Goreng Kampus', 'Nasi goreng dengan telur', 15000.00, 48),
  (2, 1, 'MKN-002', 'Mie Ayam', 'Mie ayam dan pangsit', 14000.00, 39),
  (3, 2, 'SNK-001', 'Roti Bakar Cokelat', 'Roti bakar isi cokelat', 12000.00, 29),
  (4, 2, 'SNK-002', 'Pisang Goreng', 'Satu porsi berisi 4 buah', 10000.00, 35),
  (5, 3, 'MNM-001', 'Es Teh Manis', 'Teh manis dingin', 5000.00, 78),
  (6, 3, 'MNM-002', 'Kopi Susu', 'Kopi susu gula aren', 8000.00, 48),
  (7, 3, 'MNM-003', 'Air Mineral', 'Botol 600 ml', 6000.00, 59),
  (8, 3, 'MNM-004', 'Jus Jeruk', 'Jeruk segar tanpa pengawet', 10000.00, 25);

INSERT INTO sales
  (sale_id, invoice_no, cashier_id, sale_time, subtotal, discount, total,
   payment_method, amount_paid, change_amount, status, notes)
VALUES
  (1, 'INV-20261013-001', 1, '2026-10-13 08:15:00', 40000.00, 0.00, 40000.00,
   'CASH', 50000.00, 10000.00, 'PAID', NULL),
  (2, 'INV-20261013-002', 1, '2026-10-13 09:05:00', 20000.00, 0.00, 20000.00,
   'QRIS', 20000.00, 0.00, 'PAID', 'Pembayaran berhasil'),
  (3, 'INV-20261013-003', 2, '2026-10-13 11:30:00', 28000.00, 0.00, 28000.00,
   'DEBIT', 28000.00, 0.00, 'PAID', NULL),
  (4, 'INV-20261013-004', 2, '2026-10-13 12:10:00', 10000.00, 0.00, 10000.00,
   'CASH', 10000.00, 0.00, 'VOID', 'Pesanan dibatalkan');

INSERT INTO sale_items (sale_item_id, sale_id, product_id, quantity, unit_price) VALUES
  (1, 1, 1, 2, 15000.00),
  (2, 1, 5, 2, 5000.00),
  (3, 2, 2, 1, 14000.00),
  (4, 2, 7, 1, 6000.00),
  (5, 3, 3, 1, 12000.00),
  (6, 3, 6, 2, 8000.00),
  (7, 4, 4, 1, 10000.00);

-- Salinan aman untuk mencoba perintah ALTER TABLE tanpa merusak tabel utama.
CREATE TABLE products_practice LIKE products;
INSERT INTO products_practice SELECT * FROM products;

-- ============================================================
-- 4. VIEW LAPORAN SEDERHANA
-- ============================================================

CREATE VIEW v_ringkasan_penjualan AS
SELECT
  s.sale_id,
  s.invoice_no,
  s.sale_time,
  c.full_name AS cashier_name,
  COUNT(si.sale_item_id) AS item_rows,
  COALESCE(SUM(si.quantity), 0) AS total_quantity,
  s.total,
  s.payment_method,
  s.status
FROM sales AS s
JOIN cashiers AS c ON c.cashier_id = s.cashier_id
LEFT JOIN sale_items AS si ON si.sale_id = s.sale_id
GROUP BY
  s.sale_id, s.invoice_no, s.sale_time, c.full_name,
  s.total, s.payment_method, s.status;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- QUERY PEMERIKSAAN SETELAH IMPOR
-- ============================================================

SELECT 'Database kantin_pos berhasil diimpor' AS import_status;
SELECT * FROM v_ringkasan_penjualan ORDER BY sale_time;

-- CATATAN:
-- Contoh UPDATE, DELETE, transaction, ALTER TABLE, dan INDEX lengkap
-- tersedia di file belajar-sql-pos-kantin.html agar database awal tetap utuh.
