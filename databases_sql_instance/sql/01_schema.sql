-- Lab schema: customers and orders (run as master / admin)

CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers (id),
  product_sku VARCHAR(64) NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
  ordered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id);
