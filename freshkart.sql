SELECT 
    po.po_id,
    po.sku_id,
    po.quantity_ordered,
    sd.quantity_received,
    (sd.quantity_received * 1.0 / po.quantity_ordered) * 100 AS fill_rate
FROM purchase__orders po
JOIN supplier_deliveries sd
    ON po.po_id = sd.po_id;

SELECT
  po.po_id,
  po.supplier_id,
  po.quantity_ordered,
  sd.quantity_received,
  sd.delivery_date,
  po.expected_delivery,
  CASE
    WHEN sd.quantity_received = po.quantity_ordered AND sd.on_time_flag = 1 THEN 1
    ELSE 0
  END AS otif_flag
FROM purchase__orders po
JOIN supplier_deliveries sd
  ON po.po_id = sd.po_id;

  SELECT
    po.supplier_id,
    COUNT(*) AS total_pos,
    SUM(
        CASE 
            WHEN sd.quantity_received = po.quantity_ordered 
                 AND sd.on_time_flag = 1 
            THEN 1 ELSE 0 
        END
    ) AS otif_count,
    (CAST(
        SUM(
            CASE 
                WHEN sd.quantity_received = po.quantity_ordered 
                     AND sd.on_time_flag = 1 
                THEN 1 ELSE 0 
            END
        ) AS REAL
     ) / COUNT(*)) * 100 AS otif_percent
FROM purchase__orders po
JOIN supplier_deliveries sd
    ON po.po_id = sd.po_id
GROUP BY po.supplier_id;

SELECT
    po.po_id,
    po.sku_id,
    po.quantity_ordered,
    sd.quantity_received,
    (po.quantity_ordered - sd.quantity_received) AS backorder_qty
FROM purchase__orders po
JOIN supplier_deliveries sd
    ON po.po_id = sd.po_id
WHERE sd.quantity_received < po.quantity_ordered;

SELECT warehouse_id, SUM(quantity) AS total_inbound
FROM warehouse_inbound
GROUP BY warehouse_id;

SELECT warehouse_id, SUM(quantity) AS total_outbound
FROM warehouse_outbound
GROUP BY warehouse_id;

SELECT
    w_in.warehouse_id,
    w_in.total_inbound,
    w_out.total_outbound,
    (w_in.total_inbound + w_out.total_outbound) AS total_throughput
FROM 
    (SELECT warehouse_id, SUM(quantity) AS total_inbound
     FROM warehouse_inbound
     GROUP BY warehouse_id) AS w_in
JOIN 
    (SELECT warehouse_id, SUM(quantity) AS total_outbound
     FROM warehouse_outbound
     GROUP BY warehouse_id) AS w_out
ON w_in.warehouse_id = w_out.warehouse_id
ORDER BY total_throughput DESC;

SELECT
    warehouse_id,
    SUM(CASE WHEN direction = 'inbound' THEN quantity ELSE 0 END) AS total_inbound,
    SUM(CASE WHEN direction = 'outbound' THEN quantity ELSE 0 END) AS total_outbound,
    SUM(CASE WHEN direction = 'inbound' THEN quantity ELSE -quantity END) AS net_flow
FROM (
    SELECT warehouse_id, quantity, 'inbound' AS direction
    FROM warehouse_inbound
    
    UNION ALL
    
    SELECT warehouse_id, quantity, 'outbound' AS direction
    FROM warehouse_outbound
) AS combined
GROUP BY warehouse_id
ORDER BY net_flow DESC;

WITH outbound_summary AS (
    SELECT
        sku_id,
        SUM(quantity) AS total_outbound
    FROM warehouse_outbound
    GROUP BY sku_id
),
avg_inventory AS (
    SELECT
        sku_id,
        AVG(stock_level) AS avg_stock
    FROM inventory_daily_snapshot
    GROUP BY sku_id
)
SELECT
    o.sku_id,
    o.total_outbound,
    a.avg_stock,
    (o.total_outbound * 1.0 / NULLIF(a.avg_stock, 0)) AS inventory_turnover
FROM outbound_summary o
JOIN avg_inventory a
    ON o.sku_id = a.sku_id
ORDER BY inventory_turnover DESC;

WITH daily_outbound AS (
    SELECT
        sku_id,
        outbound_date,
        SUM(quantity) AS daily_qty
    FROM warehouse_outbound
    GROUP BY sku_id, outbound_date
),
avg_inventory AS (
    SELECT
        sku_id,
        AVG(stock_level) AS avg_stock
    FROM inventory_daily_snapshot
    GROUP BY sku_id
),
avg_daily_demand AS (
    SELECT
        sku_id,
        AVG(daily_qty) AS avg_daily_outbound
    FROM daily_outbound
    GROUP BY sku_id
)
SELECT
    i.sku_id,
    i.avg_stock,
    d.avg_daily_outbound,
    (i.avg_stock * 1.0 / NULLIF(d.avg_daily_outbound, 0)) AS DOH
FROM avg_inventory i
JOIN avg_daily_demand d
    ON i.sku_id = d.sku_id
ORDER BY DOH DESC;

SELECT
    warehouse_id,
    sku_id,
    CASE 
        WHEN julianday('now') - julianday(date) <= 30 THEN '0-30 days'
        WHEN julianday('now') - julianday(date) BETWEEN 31 AND 60 THEN '31-60 days'
        ELSE '60+ days'
    END AS age_bucket,
    SUM(stock_level) AS total_stock
FROM inventory_daily_snapshot
GROUP BY warehouse_id, sku_id, age_bucket
ORDER BY warehouse_id, sku_id;










	

