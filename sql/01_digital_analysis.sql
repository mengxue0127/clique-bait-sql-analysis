-- =========================================================
-- CLIQUE BAIT CASE STUDY
-- 01. DIGITAL ANALYSIS
-- =========================================================

USE clique_bait;

-- =========================================================
-- Q1. How many users are there?
-- =========================================================

SELECT
    COUNT(DISTINCT user_id) AS total_users
FROM users;


-- =========================================================
-- Q2. How many cookies does each user have on average?
-- =========================================================

WITH user_cookie_counts AS (
    SELECT
        user_id,
        COUNT(DISTINCT cookie_id) AS cookie_count
    FROM users
    GROUP BY user_id
)

SELECT
    ROUND(AVG(cookie_count), 2) AS avg_cookies_per_user
FROM user_cookie_counts;


-- =========================================================
-- Q3. What is the unique number of visits by all users
--     per month?
-- =========================================================

WITH visit_starts AS (
    SELECT
        visit_id,
        MIN(event_time) AS visit_start_time
    FROM events
    GROUP BY visit_id
)

SELECT
    DATE_FORMAT(visit_start_time, '%Y-%m') AS visit_month,
    COUNT(*) AS unique_visits
FROM visit_starts
GROUP BY DATE_FORMAT(visit_start_time, '%Y-%m')
ORDER BY visit_month;


-- =========================================================
-- Q4. What is the number of events for each event type?
-- =========================================================

SELECT
    ei.event_type,
    ei.event_name,
    COUNT(*) AS event_count
FROM events AS e

JOIN event_identifier AS ei
    ON e.event_type = ei.event_type

GROUP BY
    ei.event_type,
    ei.event_name

ORDER BY ei.event_type;


-- =========================================================
-- Q5. What is the percentage of visits which have
--     a purchase event?
-- =========================================================

SELECT
    ROUND(
        COUNT(
            DISTINCT CASE
                WHEN event_type = 3 THEN visit_id
            END
        ) * 100.0
        /
        COUNT(DISTINCT visit_id),
        2
    ) AS purchase_visit_percentage
FROM events;


-- =========================================================
-- Q6. What is the percentage of visits which view the
--     checkout page but do not have a purchase event?
-- =========================================================

WITH visit_status AS (
    SELECT
        visit_id,

        MAX(
            CASE
                WHEN page_id = 12
                 AND event_type = 1
                THEN 1
                ELSE 0
            END
        ) AS viewed_checkout,

        MAX(
            CASE
                WHEN event_type = 3
                THEN 1
                ELSE 0
            END
        ) AS purchased

    FROM events
    GROUP BY visit_id
)

SELECT
    ROUND(
        AVG(
            CASE
                WHEN viewed_checkout = 1
                 AND purchased = 0
                THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS checkout_without_purchase_percentage
FROM visit_status;


-- =========================================================
-- Q7. What are the top 3 pages by number of views?
-- =========================================================

SELECT
    ph.page_id,
    ph.page_name,
    COUNT(*) AS page_views
FROM events AS e

JOIN page_hierarchy AS ph
    ON e.page_id = ph.page_id

WHERE e.event_type = 1

GROUP BY
    ph.page_id,
    ph.page_name

ORDER BY page_views DESC
LIMIT 3;


-- =========================================================
-- Q8. What is the number of views and cart adds
--     for each product category?
-- =========================================================

SELECT
    ph.product_category,

    SUM(
        CASE
            WHEN e.event_type = 1
            THEN 1
            ELSE 0
        END
    ) AS views,

    SUM(
        CASE
            WHEN e.event_type = 2
            THEN 1
            ELSE 0
        END
    ) AS cart_adds

FROM events AS e

JOIN page_hierarchy AS ph
    ON e.page_id = ph.page_id

WHERE ph.product_category IS NOT NULL

GROUP BY ph.product_category

ORDER BY ph.product_category;


-- =========================================================
-- Q9. What are the top 3 products by purchases?
-- =========================================================

WITH purchased_visits AS (
    SELECT DISTINCT
        visit_id
    FROM events
    WHERE event_type = 3
)

SELECT
    ph.product_id,
    ph.page_name AS product_name,
    COUNT(*) AS purchases
FROM events AS e

JOIN purchased_visits AS pv
    ON e.visit_id = pv.visit_id

JOIN page_hierarchy AS ph
    ON e.page_id = ph.page_id

WHERE e.event_type = 2
  AND ph.product_id IS NOT NULL

GROUP BY
    ph.product_id,
    ph.page_name

ORDER BY purchases DESC
LIMIT 3;