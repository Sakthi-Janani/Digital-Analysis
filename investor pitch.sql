USE Digital_Analysis

--1. I’d like to tell the story of our website performance improvements over the course of the first 8 months. 
--Could you pull session to order  conversion rates, by month?


WITH MonthlySessions AS 
--finding the total sessions for first 8 months
(
    SELECT 
        YEAR(created_at) AS year,
        MONTH(created_at) AS month,
        COUNT(DISTINCT website_session_id) AS total_sessions
    FROM Session_and_Pageview
    WHERE created_at BETWEEN '2012-03-19 ' AND '2012-10-19'
    GROUP BY YEAR(created_at), MONTH(created_at)
),
--finding the total orders for first 8 months
MonthlyOrders AS 
(
    SELECT 
        YEAR(created_at) AS year,
        MONTH(created_at) AS month,
        COUNT(DISTINCT order_id) AS total_orders
    FROM orders
    WHERE created_at BETWEEN '2012-03-19 ' AND '2012-10-19 '
    GROUP BY YEAR(created_at), MONTH(created_at)
)
SELECT 
    MS.year,
    MS.month,
    MS.total_sessions,
    MO.total_orders,
    ROUND((CAST(MO.total_orders AS FLOAT) / MS.total_sessions) * 100,2) AS conversion_rate
FROM MonthlySessions MS
LEFT JOIN MonthlyOrders MO ON MS.year = MO.year AND MS.month = MO.month
ORDER BY MS.year, MO.month


--3.For the landing page test you analyzed previously, it would be great to show a full conversion funnel from each of the two pages to orders. 
--  You can use the same time period you analyzed last time (Jun 19 – Jul 28). 

--  Identification of sessions that viewed specific pages
WITH page_sessions AS (
  SELECT
    website_session_id,
    MAX(CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END) AS Homepage,
    MAX(CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS lander,
    MAX(CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END) AS product_page,
    MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS fuzzy_page,
    MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart_page,
    MAX(CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END) AS shipping_page,
    MAX(CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing_page,
    MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS thankyou_page
  FROM Session_and_Pageview
  WHERE utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
    AND created_at BETWEEN '2012-06-19' AND '2012-07-28'
  GROUP BY website_session_id
),

--  Group sessions by landing page and calculate conversion funnel metrics
conversion_funnel AS (
  SELECT
    CASE 
      WHEN Homepage = 1 THEN 'Homepage'
      WHEN lander = 1 THEN 'lander-1'
      ELSE 'check logic' 
    END AS segment,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_page = 1 THEN website_session_id ELSE NULL END) AS products_click_rate,
    COUNT(DISTINCT CASE WHEN fuzzy_page = 1 THEN website_session_id ELSE NULL END) AS fuzzy_click_rate,
    COUNT(DISTINCT CASE WHEN cart_page = 1 THEN website_session_id ELSE NULL END) AS cart_click_rate,
    COUNT(DISTINCT CASE WHEN shipping_page = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rate,
    COUNT(DISTINCT CASE WHEN billing_page = 1 THEN website_session_id ELSE NULL END) AS billing_click_rate,
    COUNT(DISTINCT CASE WHEN thankyou_page = 1 THEN website_session_id ELSE NULL END) AS thankyou_click_rate
  FROM page_sessions
  GROUP BY 
    CASE 
      WHEN Homepage = 1 THEN 'Homepage'
      WHEN lander = 1 THEN 'lander-1'
      ELSE 'check logic' 
    END
)

--Calculate click-through rates
SELECT
  segment,
  sessions,
  (products_click_rate *100/ sessions) AS product_click_rt,
  (fuzzy_click_rate *100/ products_click_rate) AS mrfuzzy_click_rt,
  (cart_click_rate *100/ fuzzy_click_rate) AS cart_click_rt,
  (shipping_click_rate *100 / cart_click_rate) AS shipping_click_rt,
  (billing_click_rate *100/ shipping_click_rate) AS billing_click_rt,
  (thankyou_click_rate *100/ billing_click_rate) AS thankyou_click_rt
FROM conversion_funnel;



--4.I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated from the test (Sep 10 – Nov 10),
--  in terms of revenue per billing page session, and then pull the number of billing page sessions for the past month to understand monthly impact.


-- total session and revenue for billing page before test
WITH before_test AS (
    SELECT
        COUNT(website_pageview_id) AS total_sessions,
        SUM(price_usd) AS total_revenue
    from website_pageviews wp
	JOIN orders o on o.website_session_id = wp.website_session_id
	WHERE pageview_url = ('/billing') 
	  AND wp.created_at < '2012-09-10' 
),
-- total session and revenue for billing page during test
during_test AS (
    SELECT
        COUNT(wp.website_session_id) AS total_sessions,
        SUM(price_usd) AS total_revenue
    FROM website_pageviews wp
	JOIN orders o on o.website_session_id = wp.website_session_id
	WHERE pageview_url  = ('/billing') 
	  AND wp.created_at BETWEEN '2012-09-10' AND '2012-11-10'
),
--total revenue of the billing page 
billing_revenue AS
(
	SELECT
		(before_test.total_revenue / before_test.total_sessions) AS revenue_per_session_before,
	    (during_test.total_revenue / during_test.total_sessions) AS revenue_per_session_during
	FROM
		before_test,
		during_test
),
--session count of billing page, one month before Sep-9
billing_month_before AS
(
	SELECT
		COUNT(WP.website_session_id) AS session_count_before_one_month
	FROM website_pageviews wp
	JOIN orders o ON o.website_session_id = wp.website_session_id
	WHERE pageview_url = ('/billing') 
	  AND wp.created_at  <= DATEADD(month, -1, '2012-09-10')

),
-- total session and revenue for billing-2 page before test
billing_2_before_test AS
(
    SELECT
        COUNT(website_pageview_id) AS total_sessions,
        SUM(price_usd) AS total_revenue
    FROM website_pageviews wp
	JOIN orders o on o.website_session_id = wp.website_session_id
	WHERE pageview_url = ('/billing-2') 
	  AND wp.created_at < '2012-09-10' 
),
-- total session and revenue for billing page during test
billing2_during_test AS 
(
    SELECT
        COUNT(wp.website_session_id) AS total_sessions,
        SUM(price_usd) AS total_revenue
    FROM website_pageviews wp
	JOIN orders o on o.website_session_id = wp.website_session_id
	WHERE pageview_url  =  ('/billing-2') 
	  AND wp.created_at BETWEEN '2012-09-10' AND '2012-11-10'
),
--total revenue of the billing-2 page 
billing2_revenue AS
(
	SELECT
		(billing_2_before_test.total_revenue / billing_2_before_test.total_sessions) AS revenue_per_session_before,
		(billing2_during_test.total_revenue / billing2_during_test.total_sessions) AS revenue_per_session_during
	FROM
		billing_2_before_test,
		   billing2_during_test
),
--session count of billing page, one month before Sep-9
billing2_month_before AS
(
	SELECT
		COUNT(WP.website_session_id) AS session_count_before_one_month
	FROM website_pageviews wp
	JOIN orders o ON o.website_session_id = wp.website_session_id
	WHERE pageview_url = ('/billing-2') 
	  AND wp.created_at  <= DATEADD(month, -1, '2012-09-10')
)

SELECT
	'billing' as page,
	before_test.total_sessions AS sessions_count_before,
	during_test.total_sessions AS session_count_during,
	revenue_per_session_before,
	revenue_per_session_during,
	revenue_per_session_during - revenue_per_session_before AS lift_in_revenue_per_session,
	session_count_before_one_month
FROM
    before_test,
    during_test,
	billing_revenue,
	billing_month_before

UNION ALL 

SELECT
	'billing_2' as page,
	billing_2_before_test.total_sessions AS sessions_count_before,
	billing2_during_test.total_sessions AS session_count_during,
	revenue_per_session_before,
    revenue_per_session_during,
	revenue_per_session_during - revenue_per_session_before AS lift_in_revenue_per_session,
	session_count_before_one_month

FROM
    billing_2_before_test,
    billing2_during_test,
	billing2_revenue,
	billing2_month_before
	











