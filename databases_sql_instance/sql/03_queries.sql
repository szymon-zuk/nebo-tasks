-- Demonstration queries: SELECT, JOIN, WHERE, ORDER BY (run as app user)

\echo '--- All customers (ordered by name) ---'
SELECT id, email, name, created_at
FROM customers
ORDER BY name;

\echo '--- Orders over 1000 cents with customer details (JOIN + WHERE + ORDER BY) ---'
SELECT c.name AS customer_name,
       c.email,
       o.product_sku,
       o.quantity,
       o.total_cents,
       o.ordered_at
FROM customers c
JOIN orders o ON o.customer_id = c.id
WHERE o.total_cents > 1000
ORDER BY o.ordered_at DESC, c.name;

\echo '--- Order totals per customer ---'
SELECT c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.total_cents), 0) AS sum_total_cents
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY sum_total_cents DESC;
