-- Sample data (run as application user with INSERT privileges)

INSERT INTO customers (email, name)
SELECT 'alice@example.com', 'Alice Example'
WHERE NOT EXISTS (SELECT 1 FROM customers WHERE email = 'alice@example.com');

INSERT INTO customers (email, name)
SELECT 'bob@example.com', 'Bob Example'
WHERE NOT EXISTS (SELECT 1 FROM customers WHERE email = 'bob@example.com');

INSERT INTO customers (email, name)
SELECT 'carol@example.com', 'Carol Example'
WHERE NOT EXISTS (SELECT 1 FROM customers WHERE email = 'carol@example.com');

INSERT INTO orders (customer_id, product_sku, quantity, total_cents)
SELECT c.id, 'SKU-100', 2, 1999
FROM customers c
WHERE c.email = 'alice@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM orders o
    JOIN customers c2 ON o.customer_id = c2.id
    WHERE c2.email = 'alice@example.com' AND o.product_sku = 'SKU-100'
  );

INSERT INTO orders (customer_id, product_sku, quantity, total_cents)
SELECT c.id, 'SKU-200', 1, 4999
FROM customers c
WHERE c.email = 'bob@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM orders o
    JOIN customers c2 ON o.customer_id = c2.id
    WHERE c2.email = 'bob@example.com' AND o.product_sku = 'SKU-200'
  );

INSERT INTO orders (customer_id, product_sku, quantity, total_cents)
SELECT c.id, 'SKU-100', 3, 2999
FROM customers c
WHERE c.email = 'carol@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM orders o
    JOIN customers c2 ON o.customer_id = c2.id
    WHERE c2.email = 'carol@example.com' AND o.product_sku = 'SKU-100'
  );
