
USE Digital_Analysis

--LANDING PAGE ANANYSIS
		
WITH SinglePageSessions AS 
(
    SELECT 
        wp.website_session_id,
        MIN(pageview_url) AS landing_page,
        COUNT(*) AS pageviews
    FROM website_pageviews wp
	JOIN website_sessions ws on wp.website_session_id=ws.website_session_id
	GROUP BY wp.website_session_id
    HAVING COUNT(*) = 1
),
ConversionData AS (
    SELECT 
        wp.website_session_id,
        CASE WHEN COUNT(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 END) > 0 THEN 1 ELSE 0 END AS is_conversion
    FROM website_pageviews wp
	JOIN website_sessions ws on wp.website_session_id=ws.website_session_id
    GROUP BY wp.website_session_id
),
PageMetrics AS (
    SELECT 
        pageview_url,
        COUNT(user_id) AS view_count,
        AVG(DATEPART(hour, wp.created_at) * 60 + DATEPART(minute, wp.created_at)) AS avg_time_on_page,
        SUM(cd.is_conversion) AS total_conversions,
        COUNT(DISTINCT wp.website_session_id) AS total_sessions
		FROM website_pageviews wp
		JOIN website_sessions ws on wp.website_session_id=ws.website_session_id
		LEFT JOIN ConversionData cd ON wp.website_session_id= cd.website_session_id
    GROUP BY pageview_url
)

SELECT 
    wp.pageview_url,
    pm.view_count,
    pm.avg_time_on_page,
    COUNT(sps.website_session_id) AS single_page_sessions,
    (CAST(COUNT(sps.website_session_id) AS FLOAT) / (SELECT COUNT(DISTINCT wp.website_session_id) FROM website_pageviews wp
													JOIN website_sessions ws on wp.website_session_id=ws.website_session_id)) * 100 AS [Bounce rate],
    (CAST(pm.total_conversions AS FLOAT) / pm.total_sessions) * 100 AS [Conversion rate]
FROM website_pageviews wp
JOIN website_sessions ws ON wp.website_session_id=ws.website_session_id
LEFT JOIN SinglePageSessions sps ON wp.website_session_id = sps.website_session_id AND wp.pageview_url = sps.landing_page
JOIN PageMetrics pm ON wp.pageview_url = pm.pageview_url
GROUP BY 
    wp.pageview_url,
	pm.view_count,
	pm.avg_time_on_page, 
	pm.total_conversions, 
	pm.total_sessions
ORDER BY view_count DESC;

--Revenue for new sessions

/*SELECT * FROM website_sessions
SELECT distinct((user_id)) FROM website_sessions order by user_id
SELECT count(distinct(user_id)) FROM website_sessions
SELECT count(distinct(website_session_id)) FROM website_sessions

with sessionss as(
SELECT 
distinct(user_id),
website_session_id,
DENSE_RANK() over (partition by user_id order by website_session_id) as dense_ranks
FROM website_sessions 
)
SELECT 
distinct(user_id),
website_session_id
from sessionss 
where dense_ranks=1
order by user_id

select * from orders
select * from order_items*/



--7. Analyze Conversion Funnel Tests for /billing vs. new /billing-2 pages 
--: what is the traffic and billing to order conversion rate of both pages new/billing-2 page

WITH PageViewCounts AS 
(
    SELECT 
        pageview_url,
        COUNT(*) AS TotalPageViews
    FROM website_pageviews
	where pageview_url in ('/billing','/billing-2')
    GROUP BY pageview_url
),OrderCounts AS 
(
    SELECT 
        pageview_url,
        COUNT(*) AS TotalOrders
    FROM Orders o join website_pageviews wp on o.website_session_id=wp.website_session_id
	where pageview_url in ('/billing','/billing-2')
    GROUP BY pageview_url
)
SELECT 
    pv.pageview_url,
    pv.TotalPageViews,
    COALESCE(oc.TotalOrders, 0) AS TotalOrders,
    CASE WHEN pv.TotalPageViews > 0 THEN  CAST(COALESCE(oc.TotalOrders, 0) AS FLOAT) / pv.TotalPageViews ELSE 0 END AS ConversionRate
FROM PageViewCounts pv
LEFT JOIN OrderCounts oc ON pv.pageview_url = oc.pageview_url;




WITH PageViewCounts AS (
    SELECT 
        pageview_url,
        COUNT(*) AS TotalPageViews
    FROM website_pageviews
	where pageview_url in ('/billing','/billing-2') and created_at<'2012-10-10'
    GROUP BY pageview_url
),
OrderCounts AS (
    SELECT 
        pageview_url,
        COUNT(*) AS TotalOrders
    FROM Orders o join website_pageviews wp on o.website_session_id=wp.website_session_id
	where pageview_url in ('/billing','/billing-2') and wp.created_at<'2012-10-10'
    GROUP BY pageview_url
)
SELECT 
    pv.pageview_url,
    pv.TotalPageViews,
    COALESCE(oc.TotalOrders, 0) AS TotalOrders,
    CASE 
        WHEN pv.TotalPageViews > 0 THEN 
            CAST(COALESCE(oc.TotalOrders, 0) AS FLOAT) / pv.TotalPageViews
        ELSE 
            0
    END AS ConversionRate
FROM 
    PageViewCounts pv
LEFT JOIN 
    OrderCounts oc
ON 
    pv.pageview_url = oc.pageview_url;


	/*11.Build Conversion Funnels for gsearch nonbrand traffic from /lander-1 to /thank you page:
	What are the session counts and click percentages for \lander-1, product, mr fuzzy, cart, shipping, billing, 
	and thank you pages from August 5, 2012, to September 5, 2012? */

	select * from Session_and_Pageview

--1
WITH FINDING_PAGE AS 
	(
	SELECT
        DISTINCT website_session_id AS sessionss,
		MAX(CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS lander,
		MAX(CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END) AS product,
        MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS fuzzy,
        MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart,
        MAX(CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END) AS shipping,
        MAX(CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing,
        MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS thankyou
    FROM Session_and_Pageview
	WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND created_at BETWEEN '2012-08-05' AND '2012-09-05'
	GROUP BY website_session_id

),total_sessions as
(
	SELECT
		COUNT(DISTINCT sessionss) as total_sessions,
		SUM(lander) AS lander_page,
		SUM(CASE WHEN lander = 1 THEN product ELSE 0 END) product_page,
		SUM(CASE WHEN lander = 1 AND product = 1 THEN fuzzy ELSE 0 END) fuzzy_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 THEN cart ELSE 0 END) cart_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 THEN shipping ELSE 0 END) shipping_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 AND shipping = 1 THEN billing ELSE 0 END) billing_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 AND shipping = 1 AND billing = 1 THEN thankyou ELSE 0 END) thankyou_page
	FROM FINDING_PAGE
)
SELECT
	total_sessions,
	product_page,
	fuzzy_page,
	cart_page,
	shipping_page,
	billing_page,
	thankyou_page,
	ROUND((CAST (product_page AS FLOAT) / lander_page)*100,2) AS products_click_rate,
	ROUND((CAST (fuzzy_page AS FLOAT) / product_page)*100,2) AS fuzzy_click_rate,
	ROUND((CAST (cart_page AS FLOAT) / fuzzy_page)*100,2) AS cart_click_rate,
	ROUND((CAST (shipping_page AS FLOAT) / cart_page)*100,2) AS shipping_click_rate,
	ROUND((CAST  (billing_page AS FLOAT) / shipping_page)*100,2) AS billing_click_rate,
	ROUND((CAST  (thankyou_page AS FLOAT) / billing_page)*100,2) AS thankyou_click_rate
FROM total_sessions

--2.without total
WITH FINDING_PAGE AS 
	(
	SELECT
        DISTINCT website_session_id AS sessionss,
		MAX(CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS lander,
		MAX(CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END) AS product,
        MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS fuzzy,
        MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart,
        MAX(CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END) AS shipping,
        MAX(CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing,
        MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS thankyou
    FROM Session_and_Pageview
	WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND created_at BETWEEN '2012-08-05' AND '2012-09-05'
	GROUP BY website_session_id
),total_sessions as
(
	SELECT
		COUNT(DISTINCT sessionss) as total_sessions,
		SUM(lander) AS lander_page,
		SUM(CASE WHEN lander = 1 THEN product ELSE 0 END) product_page,
		SUM(CASE WHEN lander = 1 AND product = 1 THEN fuzzy ELSE 0 END) fuzzy_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 THEN cart ELSE 0 END) cart_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 THEN shipping ELSE 0 END) shipping_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 AND shipping = 1 THEN billing ELSE 0 END) billing_page,
		SUM(CASE WHEN lander = 1 AND product = 1 AND fuzzy = 1 AND cart = 1 AND shipping = 1 AND billing = 1 THEN thankyou ELSE 0 END) thankyou_page
	FROM FINDING_PAGE
)
SELECT
	total_sessions,
	ROUND((CAST (product_page AS FLOAT) / lander_page)*100,2) AS products_click_rate,
	ROUND((CAST (fuzzy_page AS FLOAT) / product_page)*100,2) AS fuzzy_click_rate,
	ROUND((CAST (cart_page AS FLOAT) / fuzzy_page)*100,2) AS cart_click_rate,
	ROUND((CAST (shipping_page AS FLOAT) / cart_page)*100,2) AS shipping_click_rate,
	ROUND((CAST  (billing_page AS FLOAT) / shipping_page)*100,2) AS billing_click_rate,
	ROUND((CAST  (thankyou_page AS FLOAT) / billing_page)*100,2) AS thankyou_click_rate
FROM total_sessions



