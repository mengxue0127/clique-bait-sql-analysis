-- =========================================================
-- CLIQUE BAIT CASE STUDY
-- 02. PRODUCT FUNNEL ANALYSIS
-- =========================================================

USE clique_bait;


-- =========================================================
-- PART 1. CREATE PRODUCT-LEVEL FUNNEL TABLE
-- One row represents one product.
-- =========================================================

-- Delete the old category table first because it is built
-- from the product_funnel table.
DROP TABLE IF EXISTS product_category_summary;

DROP TABLE IF EXISTS product_funnel;


CREATE TABLE product_funnel AS

SELECT
    ph.product_id,
    ph.page_name AS product_name,
    ph.product_category,

    -- Count product page-view events.
    SUM(
        CASE
            WHEN e.event_type = 1 THEN 1
            ELSE 0
        END
    ) AS views,

    -- Count product add-to-cart events.
    SUM(
        CASE
            WHEN e.event_type = 2 THEN 1
            ELSE 0
        END
    ) AS cart_adds,

    -- Count products added to cart in visits
    -- that did not contain a purchase event.
    SUM(
        CASE
            WHEN e.event_type = 2
             AND vs.has_purchase = 0
            THEN 1
            ELSE 0
        END
    ) AS abandoned,

    -- Count products added to cart in visits
    -- that contained a purchase event.
    SUM(
        CASE
            WHEN e.event_type = 2
             AND vs.has_purchase = 1
            THEN 1
            ELSE 0
        END
    ) AS purchases

FROM events AS e


-- Create one purchase flag for every visit_id.
JOIN (
    SELECT
        visit_id,

        MAX(
            CASE
                WHEN event_type = 3 THEN 1
                ELSE 0
            END
        ) AS has_purchase

    FROM events

    GROUP BY visit_id
) AS vs

    ON e.visit_id = vs.visit_id


-- Add product names, categories and product IDs.
JOIN page_hierarchy AS ph

    ON e.page_id = ph.page_id


-- Remove Home Page, Checkout, Confirmation
-- and other non-product pages.
WHERE ph.product_id IS NOT NULL


-- Produce one row for every product.
GROUP BY
    ph.product_id,
    ph.page_name,
    ph.product_category;



-- Preview the product-level output table.
SELECT
    *
FROM product_funnel
ORDER BY product_id;



-- =========================================================
-- PART 2. CREATE PRODUCT-CATEGORY FUNNEL TABLE
-- One row represents one product category.
-- =========================================================

CREATE TABLE product_category_summary AS

SELECT
    product_category,

    SUM(views) AS views,
    SUM(cart_adds) AS cart_adds,
    SUM(abandoned) AS abandoned,
    SUM(purchases) AS purchases

FROM product_funnel

GROUP BY product_category;



-- Preview the category-level output table.
SELECT
    *
FROM product_category_summary
ORDER BY product_category;



-- =========================================================
-- VALIDATION CHECK
-- Cart adds should equal abandoned plus purchases.
-- This query should return difference = 0 for every product.
-- =========================================================

SELECT
    product_id,
    product_name,
    cart_adds,
    abandoned,
    purchases,

    cart_adds
    - abandoned
    - purchases AS difference

FROM product_funnel

ORDER BY product_id;



-- =========================================================
-- Q1. Which product had the most views,
--     cart adds and purchases?
-- =========================================================

WITH ranked_products AS (
    SELECT
        product_id,
        product_name,
        views,
        cart_adds,
        purchases,

        ROW_NUMBER() OVER (
            ORDER BY views DESC, product_id
        ) AS views_rank,

        ROW_NUMBER() OVER (
            ORDER BY cart_adds DESC, product_id
        ) AS cart_adds_rank,

        ROW_NUMBER() OVER (
            ORDER BY purchases DESC, product_id
        ) AS purchases_rank

    FROM product_funnel
)

SELECT
    metric,
    product_name,
    metric_value

FROM (
    SELECT
        1 AS metric_order,
        'Most Views' AS metric,
        product_name,
        views AS metric_value

    FROM ranked_products

    WHERE views_rank = 1


    UNION ALL


    SELECT
        2 AS metric_order,
        'Most Cart Adds' AS metric,
        product_name,
        cart_adds AS metric_value

    FROM ranked_products

    WHERE cart_adds_rank = 1


    UNION ALL


    SELECT
        3 AS metric_order,
        'Most Purchases' AS metric,
        product_name,
        purchases AS metric_value

    FROM ranked_products

    WHERE purchases_rank = 1
) AS results

ORDER BY metric_order;



-- =========================================================
-- Q2. Which product was most likely to be abandoned?
-- =========================================================

SELECT
    product_id,
    product_name,
    cart_adds,
    abandoned,

    ROUND(
        abandoned * 100.0 / cart_adds,
        2
    ) AS abandonment_rate

FROM product_funnel

WHERE cart_adds > 0

ORDER BY
    abandonment_rate DESC,
    product_id

LIMIT 1;



-- =========================================================
-- Q3. Which product had the highest
--     view-to-purchase percentage?
-- =========================================================

SELECT
    product_id,
    product_name,
    views,
    purchases,

    ROUND(
        purchases * 100.0 / views,
        2
    ) AS view_to_purchase_percentage

FROM product_funnel

WHERE views > 0

ORDER BY
    view_to_purchase_percentage DESC,
    product_id

LIMIT 1;



-- =========================================================
-- Q4. What is the average conversion rate
--     from view to cart add?
-- =========================================================

SELECT
    SUM(views) AS total_views,
    SUM(cart_adds) AS total_cart_adds,

    ROUND(
        SUM(cart_adds) * 100.0
        / SUM(views),
        2
    ) AS view_to_cart_conversion_rate

FROM product_funnel;



-- =========================================================
-- Q5. What is the average conversion rate
--     from cart add to purchase?
-- =========================================================

SELECT
    SUM(cart_adds) AS total_cart_adds,
    SUM(purchases) AS total_purchases,

    ROUND(
        SUM(purchases) * 100.0
        / SUM(cart_adds),
        2
    ) AS cart_to_purchase_conversion_rate

FROM product_funnel;



-- =========================================================
-- ANALYTICAL ASSUMPTION
-- =========================================================

-- The source dataset contains a purchase event at the
-- visit level, but it does not contain order-item details
-- or remove-from-cart events.
--
-- Therefore, a product is treated as purchased when:
--
-- 1. The product was added to the cart.
-- 2. The same visit_id contained a purchase event.
--
-- Product purchases in this analysis are inferred rather
-- than directly verified using an order-item table.