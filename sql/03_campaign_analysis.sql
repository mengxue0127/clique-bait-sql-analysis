-- =========================================================
-- CLIQUE BAIT CASE STUDY
-- 03. CAMPAIGN ANALYSIS
-- =========================================================

USE clique_bait;


-- =========================================================
-- PART 1. CREATE VISIT-LEVEL CAMPAIGN TABLE
-- One row represents one visit_id.
-- =========================================================

DROP TABLE IF EXISTS campaign_analysis;


CREATE TABLE campaign_analysis AS

WITH visit_summary AS (
    SELECT
        u.user_id,
        e.visit_id,

        -- The earliest event represents the visit start time.
        MIN(e.event_time) AS visit_start_time,

        -- Number of page-view events during the visit.
        SUM(
            CASE
                WHEN e.event_type = 1 THEN 1
                ELSE 0
            END
        ) AS page_views,

        -- Number of add-to-cart events during the visit.
        SUM(
            CASE
                WHEN e.event_type = 2 THEN 1
                ELSE 0
            END
        ) AS cart_adds,

        -- Purchase flag:
        -- 1 = the visit contained a purchase event
        -- 0 = the visit did not contain a purchase event
        MAX(
            CASE
                WHEN e.event_type = 3 THEN 1
                ELSE 0
            END
        ) AS purchase,

        -- Number of campaign impression events.
        SUM(
            CASE
                WHEN e.event_type = 4 THEN 1
                ELSE 0
            END
        ) AS impression,

        -- Number of campaign click events.
        SUM(
            CASE
                WHEN e.event_type = 5 THEN 1
                ELSE 0
            END
        ) AS click,

        -- Products added to the cart in visit sequence order.
        GROUP_CONCAT(
            CASE
                WHEN e.event_type = 2
                 AND ph.product_id IS NOT NULL
                THEN ph.page_name
            END
            ORDER BY e.sequence_number
            SEPARATOR ', '
        ) AS cart_products

    FROM events AS e

    LEFT JOIN users AS u
        ON e.cookie_id = u.cookie_id

    LEFT JOIN page_hierarchy AS ph
        ON e.page_id = ph.page_id

    GROUP BY
        u.user_id,
        e.visit_id
)


SELECT
    vs.user_id,
    vs.visit_id,
    vs.visit_start_time,
    vs.page_views,
    vs.cart_adds,
    vs.purchase,
    ci.campaign_name,
    vs.impression,
    vs.click,
    vs.cart_products

FROM visit_summary AS vs

LEFT JOIN campaign_identifier AS ci
    ON vs.visit_start_time >= ci.start_date

    -- Campaign end dates are stored at midnight.
    -- Adding one day includes the complete final date.
    AND vs.visit_start_time
        < DATE_ADD(ci.end_date, INTERVAL 1 DAY);
        

-- =========================================================
-- Q1. Compare the overall performance of each campaign.
-- =========================================================

SELECT
    campaign_name,

    COUNT(DISTINCT user_id) AS unique_users,

    COUNT(DISTINCT visit_id) AS total_visits,

    SUM(page_views) AS total_page_views,

    ROUND(
        AVG(page_views),
        2
    ) AS avg_page_views_per_visit,

    SUM(cart_adds) AS total_cart_adds,

    ROUND(
        AVG(cart_adds),
        2
    ) AS avg_cart_adds_per_visit,

    SUM(purchase) AS purchase_visits,

    ROUND(
        AVG(purchase) * 100,
        2
    ) AS visit_purchase_rate,

    SUM(impression) AS total_impressions,

    SUM(click) AS total_clicks,

    ROUND(
        SUM(click) * 100.0
        / NULLIF(SUM(impression), 0),
        2
    ) AS impression_click_through_rate

FROM campaign_analysis

WHERE campaign_name IS NOT NULL

GROUP BY campaign_name

ORDER BY MIN(visit_start_time);


-- =========================================================
-- Q2. Compare users who received campaign impressions
--     with users who did not receive an impression.
-- =========================================================

WITH campaign_users AS (
    SELECT
        campaign_name,
        user_id,

        COUNT(DISTINCT visit_id) AS total_visits,

        SUM(page_views) AS total_page_views,

        SUM(cart_adds) AS total_cart_adds,

        SUM(purchase) AS purchase_visits,

        MAX(purchase) AS purchased,

        MAX(
            CASE
                WHEN impression > 0 THEN 1
                ELSE 0
            END
        ) AS received_impression,

        MAX(
            CASE
                WHEN click > 0 THEN 1
                ELSE 0
            END
        ) AS clicked_ad

    FROM campaign_analysis

    WHERE campaign_name IS NOT NULL
      AND user_id IS NOT NULL

    GROUP BY
        campaign_name,
        user_id
)


SELECT
    campaign_name,

    CASE
        WHEN received_impression = 1
            THEN 'Received Impression'
        ELSE 'No Impression'
    END AS user_group,

    COUNT(*) AS users,

    ROUND(
        AVG(total_visits),
        2
    ) AS avg_visits_per_user,

    ROUND(
        AVG(total_page_views),
        2
    ) AS avg_page_views_per_user,

    ROUND(
        AVG(total_cart_adds),
        2
    ) AS avg_cart_adds_per_user,

    ROUND(
        AVG(purchase_visits),
        2
    ) AS avg_purchase_visits_per_user,

    ROUND(
        AVG(purchased) * 100,
        2
    ) AS user_purchase_rate

FROM campaign_users

GROUP BY
    campaign_name,
    received_impression

ORDER BY
    campaign_name,
    received_impression DESC;
    

-- =========================================================
-- Q3. Compare three mutually exclusive user groups:
--     1. No Impression
--     2. Impression Only
--     3. Clicked Impression
-- =========================================================

WITH campaign_users AS (
    SELECT
        campaign_name,
        user_id,

        COUNT(DISTINCT visit_id) AS total_visits,

        SUM(page_views) AS total_page_views,

        SUM(cart_adds) AS total_cart_adds,

        SUM(purchase) AS purchase_visits,

        MAX(purchase) AS purchased,

        MAX(
            CASE
                WHEN impression > 0 THEN 1
                ELSE 0
            END
        ) AS received_impression,

        MAX(
            CASE
                WHEN click > 0 THEN 1
                ELSE 0
            END
        ) AS clicked_ad

    FROM campaign_analysis

    WHERE campaign_name IS NOT NULL
      AND user_id IS NOT NULL

    GROUP BY
        campaign_name,
        user_id
),


classified_users AS (
    SELECT
        *,

        CASE
            WHEN clicked_ad = 1
                THEN 'Clicked Impression'

            WHEN received_impression = 1
             AND clicked_ad = 0
                THEN 'Impression Only'

            ELSE 'No Impression'
        END AS user_group

    FROM campaign_users
)


SELECT
    campaign_name,
    user_group,

    COUNT(*) AS users,

    ROUND(
        AVG(total_visits),
        2
    ) AS avg_visits_per_user,

    ROUND(
        AVG(total_page_views),
        2
    ) AS avg_page_views_per_user,

    ROUND(
        AVG(total_cart_adds),
        2
    ) AS avg_cart_adds_per_user,

    ROUND(
        AVG(purchase_visits),
        2
    ) AS avg_purchase_visits_per_user,

    ROUND(
        AVG(purchased) * 100,
        2
    ) AS user_purchase_rate

FROM classified_users

GROUP BY
    campaign_name,
    user_group

ORDER BY
    campaign_name,

    CASE user_group
        WHEN 'No Impression' THEN 1
        WHEN 'Impression Only' THEN 2
        WHEN 'Clicked Impression' THEN 3
    END;
    
    
-- =========================================================
-- Q4. What is the uplift in purchase rate for users who
--     clicked an impression compared with:
--
--     1. Users who received no impression
--     2. Users who received an impression but did not click
-- =========================================================

WITH campaign_users AS (
    SELECT
        campaign_name,
        user_id,

        MAX(purchase) AS purchased,

        MAX(
            CASE
                WHEN impression > 0 THEN 1
                ELSE 0
            END
        ) AS received_impression,

        MAX(
            CASE
                WHEN click > 0 THEN 1
                ELSE 0
            END
        ) AS clicked_ad

    FROM campaign_analysis

    WHERE campaign_name IS NOT NULL
      AND user_id IS NOT NULL

    GROUP BY
        campaign_name,
        user_id
),


classified_users AS (
    SELECT
        campaign_name,
        user_id,
        purchased,

        CASE
            WHEN clicked_ad = 1
                THEN 'Clicked Impression'

            WHEN received_impression = 1
             AND clicked_ad = 0
                THEN 'Impression Only'

            ELSE 'No Impression'
        END AS user_group

    FROM campaign_users
),


group_purchase_rates AS (
    SELECT
        campaign_name,
        user_group,

        AVG(purchased) * 100 AS purchase_rate

    FROM classified_users

    GROUP BY
        campaign_name,
        user_group
),


campaign_rates AS (
    SELECT
        campaign_name,

        MAX(
            CASE
                WHEN user_group = 'No Impression'
                THEN purchase_rate
            END
        ) AS no_impression_purchase_rate,

        MAX(
            CASE
                WHEN user_group = 'Impression Only'
                THEN purchase_rate
            END
        ) AS impression_only_purchase_rate,

        MAX(
            CASE
                WHEN user_group = 'Clicked Impression'
                THEN purchase_rate
            END
        ) AS clicked_purchase_rate

    FROM group_purchase_rates

    GROUP BY campaign_name
)


SELECT
    campaign_name,

    ROUND(
        no_impression_purchase_rate,
        2
    ) AS no_impression_purchase_rate,

    ROUND(
        impression_only_purchase_rate,
        2
    ) AS impression_only_purchase_rate,

    ROUND(
        clicked_purchase_rate,
        2
    ) AS clicked_purchase_rate,

    -- Percentage-point uplift:
    -- clicked rate minus no-impression rate
    ROUND(
        clicked_purchase_rate
        - no_impression_purchase_rate,
        2
    ) AS clicked_vs_no_impression_uplift_pp,

    -- Relative uplift:
    -- percentage growth relative to the comparison group
    ROUND(
        (
            clicked_purchase_rate
            - no_impression_purchase_rate
        )
        / NULLIF(no_impression_purchase_rate, 0)
        * 100,
        2
    ) AS clicked_vs_no_impression_relative_uplift,

    ROUND(
        clicked_purchase_rate
        - impression_only_purchase_rate,
        2
    ) AS clicked_vs_impression_only_uplift_pp,

    ROUND(
        (
            clicked_purchase_rate
            - impression_only_purchase_rate
        )
        / NULLIF(impression_only_purchase_rate, 0)
        * 100,
        2
    ) AS clicked_vs_impression_only_relative_uplift

FROM campaign_rates

ORDER BY campaign_name;


-- =========================================================
-- ANALYTICAL LIMITATION
-- =========================================================

-- These comparisons are observational rather than
-- experimental.
--
-- Users who click an advertisement may already have
-- stronger purchase intent than users who do not click.
--
-- Therefore, a higher purchase rate among clicked users
-- demonstrates an association, but it does not prove that
-- the campaign click caused the purchase.