



--Q1. Finding Top Traffic Sources: What is the breakdown of sessions by UTM source, campaign, and referring domain 
--up to April 12, 2012. 


SELECT 
    utm_source,
    utm_campaign,
    http_referer,
    COUNT(website_session_id) AS session_count
FROM 
    website_sessions
WHERE 
    created_at <= '2012-04-12'
GROUP BY 
    utm_source,
    utm_campaign,
    http_referer
ORDER BY 
    session_count DESC;


--Q2 Traffic Conversion Rates: Calculate conversion rate (CVR) from sessions to order. 
--If CVR is 4% >=, then increase bids to drive volume, otherwise reduce bids. 
--(Filter sessions < 2012-04-12, utm_source = gsearch and utm_campaign = nonbrand) 

-- Step 1: Calculate the total number of sessions
WITH SessionData AS (
    SELECT 
        COUNT(*) AS total_sessions
    FROM 
        website_sessions
    WHERE 
        created_at < '2012-04-12'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
),

-- Step 2: Calculate the total number of orders
OrderData AS (
    SELECT 
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        orders o
    JOIN 
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE 
        ws.created_at < '2012-04-12'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
)

-- Step 3: Calculate the conversion rate (CVR)
SELECT 
    sd.total_sessions,
    od.total_orders,
    ROUND(CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100,2) AS 'conversion_rate(%)',
    CASE 
        WHEN CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100 >= 4 THEN 'Increase bids'
        ELSE 'Reduce bids'
    END AS bidding_strategy
FROM 
    SessionData sd,
    OrderData od;


--Q3. Traffic Source Trending: After bidding down on Apr 15, 2012, what is the trend and impact on sessions 
--for gsearch nonbrand campaign? Find weekly sessions before 2012-05-10.

SELECT 
	DATEADD(DAY,1-DATEPART(WEEKDAY, ws.created_at),CAST(ws.created_at AS DATE)) AS week_start_date,
    COUNT(ws.website_session_id) AS weekly_sessions,
	COUNT(o.order_id) AS orders_count,
	FORMAT(COUNT(o.order_id)*100.0/COUNT(*), '0.00') AS 'CVR%'
FROM 
    website_sessions ws
	LEFT JOIN orders o
	ON ws.website_session_id = o.website_session_id
WHERE 
    ws.created_at < '2012-05-10'
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY 
    DATEADD(DAY,1-DATEPART(WEEKDAY, ws.created_at),CAST(ws.created_at AS DATE))
ORDER BY 
    week_start_date;


--Q4. Traffic Source Bid Optimization: What is the conversion rate from session to order by device type? 

-- Step 1: Calculate the total number of sessions by device type
WITH SessionData AS (
    SELECT 
        device_type,
        COUNT(*) AS total_sessions
    FROM 
        website_sessions
	WHERE 
		created_at < '2012-05-11'
		AND utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        device_type
),

-- Step 2: Calculate the total number of orders by device type
OrderData AS (
    SELECT 
        ws.device_type,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        [orders] o
    JOIN 
        website_sessions ws ON o.website_session_id = ws.website_session_id
	WHERE 
		o.created_at < '2012-05-11'
		AND ws.utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        ws.device_type
)

-- Step 3: Calculate the conversion rate (CVR) by device type
SELECT 
    sd.device_type,
    sd.total_sessions,
    od.total_orders,
    CAST(od.total_orders AS FLOAT) / sd.total_sessions * 100 AS 'conversion_rate(%)'
FROM 
    SessionData sd
LEFT JOIN 
    OrderData od ON sd.device_type = od.device_type
ORDER BY 
    'conversion_rate(%)' DESC;


--Q5. Traffic Source Segment Trending: After bidding up on desktop channels on 2012-05-19, 
--what is the weekly session trend for both desktop and mobile?

-- Step 1: Calculate weekly sessions by device type

WITH WeeklySessions AS (
    SELECT 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
		sum(case when device_type = 'desktop' then 1 else 0 end) desktop_sessions,
		sum(case when device_type = 'mobile' then 1 else 0 end) mobile_sessions,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
		created_at >= ' 2012-04-15' and created_at < '2012-06-19'
		AND utm_source = 'gsearch'
		AND utm_campaign = 'nonbrand'
    GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
)

-- Step 2: Select the results and label the periods
SELECT 
    week_start_date,
    desktop_sessions,
	mobile_sessions
FROM 
    WeeklySessions
ORDER BY 
    week_start_date;


--Q6 Identifying Top Website Pages: What are the most viewed website pages ranked by session volume? 

SELECT 
    pageview_url,
    COUNT(DISTINCT website_session_id) AS session_volume
FROM 
    website_pageviews
WHERE 
	created_at < '2012-06-09'
GROUP BY 
    pageview_url
ORDER BY 
    session_volume DESC;
--
--Sakthi
--
SELECT  
	pageview_url,
	COUNT(pageview_url) AS COUNT
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url 
ORDER BY COUNT DESC

--Q7. Identifying Top Entry Pages: Pull a list of top entry pages?

WITH FirstPageview AS (
    SELECT 
        ws.website_session_id,
        wp.pageview_url,
        MIN(wp.created_at) AS first_pageview_time
    FROM 
        website_sessions ws
    JOIN 
        website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY 
        ws.website_session_id,
        wp.pageview_url
)

SELECT 
    pageview_url AS entry_page,
    COUNT(*) AS session_count
FROM 
    FirstPageview
GROUP BY 
    pageview_url
ORDER BY 
    session_count DESC;

---
--SAkthi
--

WITH entry_page AS
(
	SELECT
		website_session_id,
		website_pageview_id,
		created_at,
		pageview_url
	FROM
	(
		SELECT
			website_session_id,
			website_pageview_id,
			created_at,
			pageview_url,
			RANK() OVER(PARTITION BY website_session_id ORDER BY created_at) AS DENSE_RANKS
		FROM website_pageviews
		WHERE created_at < '2012-06-12 00:00:00.0000000'
	) RESULT
		WHERE DENSE_RANKS=1
)
SELECT
pageview_url,
COUNT(website_session_id) AS COUNT
FROM entry_page
GROUP BY pageview_url
ORDER BY COUNT DESC;


--Q8. Calculating Bounce Rates: Pull out the bounce rates for traffic landing on home page by sessions, 
--bounced sessions and bounce rate? 

WITH FirstPageview AS (
    SELECT 
        ws.website_session_id,
        ws.user_id,
        ws.created_at AS session_start_time,
        wp.pageview_url,
        MIN(wp.created_at) AS first_pageview_time
    FROM 
        website_sessions ws
    JOIN 
        website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY 
        ws.website_session_id,
        ws.user_id,
        ws.created_at,
        wp.pageview_url
),
HomePageSessions AS (
    SELECT 
        website_session_id,
        session_start_time,
        pageview_url
    FROM 
        FirstPageview
    WHERE 
        pageview_url = '/home'  -- Replace 'home_page_url' with the actual URL of the home page
),

SessionPageviews AS (
    SELECT 
        ws.website_session_id,
        COUNT(wp.pageview_url) AS pageviews_count
    FROM 
        website_sessions ws
    JOIN 
        website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY 
        ws.website_session_id
)

SELECT 
    hps.website_session_id,
    COUNT(*) AS sessions,
    SUM(CASE WHEN sp.pageviews_count = 1 THEN 1 ELSE 0 END) AS bounced_sessions,
    SUM(CASE WHEN sp.pageviews_count = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) * 100 AS bounce_rate
FROM 
    HomePageSessions hps
JOIN 
    SessionPageviews sp ON hps.website_session_id = sp.website_session_id
GROUP BY 
    hps.website_session_id
ORDER BY 
    bounce_rate DESC;


---
--Sakthi
--

WITH Single_Page_Sessions AS
--Session id that have viewed only once page
(
    SELECT 
        website_session_id,
        COUNT(*) AS page_count
    FROM website_pageviews
	WHERE created_at < '2012-06-14 '
    GROUP BY website_session_id
    HAVING COUNT(website_pageview_id) = 1
),Home_Page_Sessions AS 
(
--home page viewed sessions
    SELECT 
        website_session_id
    FROM website_pageviews
    WHERE pageview_url = '/home' AND  created_at < '2012-06-14'
),Single_Home_page_Sessions AS 
(
-- sessions that have viewed only the home page once
    SELECT 
        website_session_id
    FROM Home_Page_Sessions
    WHERE website_session_id IN (SELECT website_session_id FROM Single_Page_Sessions)
)
SELECT
    'Home' AS Landing_page,
    COUNT(DISTINCT H.website_session_id) AS Total_sessions,
    COUNT(DISTINCT S.website_session_id) AS Bounced_sessions,
    (CAST(COUNT(DISTINCT S.website_session_id) AS FLOAT) / 
     COUNT(DISTINCT H.website_session_id)) * 100 AS Bounce_rate
FROM Home_Page_Sessions H
LEFT JOIN Single_Page_Sessions  S ON H.website_session_id = S.website_session_id



--Q9. Analyzing Landing Page Tests: 
--What are the bounce rates for \lander-1 and \home in the A/B test conducted by ST for the gsearch nonbrand campaign,
--considering traffic received by \lander-1 and \home before <2012-07-28 to ensure a fair comparison?

WITH Campaign_Sessions AS
--sessiion id ad their respective pages from gsearch nonbrand between (June 19-2012 - July 17 2012)
(
    SELECT 
        website_session_id,
        pageview_url AS entry_page
    FROM Session_and_Pageview
    WHERE utm_source = 'gsearch' and utm_campaign= 'nonbrand' AND created_at>'2012-06-19' AND created_at<'2012-07-28'
    GROUP BY website_session_id, pageview_url
),Single_Page_Sessions AS (
--Sessions that have viewed only one page
    SELECT 
        website_session_id,
        COUNT(*) AS page_count
    FROM website_pageviews
	WHERE  created_at>'2012-06-19' and created_at<'2012-07-28'
    GROUP BY website_session_id
    HAVING COUNT(website_pageview_id) = 1
),Home_Page_Sessions AS 
--how many visites to home page
(
    SELECT 
        website_session_id
    FROM Campaign_Sessions
    WHERE entry_page = '/home'
),Lander_Page_Sessions AS 
--how many visites to Lander-1 page
(
	SELECT 
        website_session_id
    FROM Campaign_Sessions
    WHERE entry_page = '/lander-1'
),Single_Page_Home_Sessions AS
--visitors who have viewed only home page
(
    SELECT 
        website_session_id
    FROM Home_Page_Sessions
    WHERE website_session_id IN (SELECT website_session_id FROM Single_Page_Sessions)
),Single_Lander_Sessions AS 
--visitors who have viewed only lander-1 page
(
    SELECT 
        website_session_id
    FROM Lander_Page_Sessions
    WHERE website_session_id IN (SELECT website_session_id FROM Single_Page_Sessions)
)
SELECT
    'Home' AS landing_page,
    COUNT(DISTINCT Home_Page_Sessions.website_session_id) AS total_sessions,
    COUNT(DISTINCT Single_Page_Home_Sessions.website_session_id) AS bounced_sessions,
    ROUND((CAST(COUNT(DISTINCT Single_Page_Home_Sessions.website_session_id) AS FLOAT) *100/ 
     COUNT(DISTINCT Home_Page_Sessions.website_session_id)),2) AS bounce_rate
FROM Home_Page_Sessions
LEFT JOIN Single_Page_Home_Sessions 
ON Home_Page_Sessions.website_session_id = Single_Page_Home_Sessions.website_session_id

UNION ALL

SELECT
    'Lander-1' AS landing_page,
    COUNT(DISTINCT Lander_Page_Sessions.website_session_id) AS total_sessions,
    COUNT(DISTINCT Single_Lander_Sessions.website_session_id) AS bounced_sessions,
    ROUND((CAST(COUNT(DISTINCT Single_Lander_Sessions.website_session_id) AS FLOAT) *100/ 
     COUNT(DISTINCT Lander_Page_Sessions.website_session_id)),2) AS bounce_rate
FROM Lander_Page_Sessions
LEFT JOIN Single_Lander_Sessions 
ON Lander_Page_Sessions.website_session_id = Single_Lander_Sessions.website_session_id;





--Q10. Landing Page Trend Analysis: What is the trend of weekly paid gsearch nonbrand campaign traffic 
--on /home and /lander-1 pages since June 1, 2012, along with their respective bounce rates, as requested by ST? 
--Please limit the results to the period between June 1, 2012, and August 31, 2012, based on the email received
--on August 31, 2021.

Select * from Session_and_Pageview;
WITH CampaignSessions AS 
--Session id and their respective entry page and the start date of the week and the page out of the session 
(
    SELECT 
        website_session_id,
        pageview_url AS entry_page,
        DATEADD(WEEK, DATEDIFF(WEEK, 0, created_at), 0) AS week_start_date,
        COUNT(*) OVER (PARTITION BY website_session_id) AS page_count
    FROM Session_and_Pageview
    WHERE utm_campaign =  'nonbrand' AND utm_source='gsearch'
          AND created_at BETWEEN '2012-06-01' AND '2012-08-31'
),FilteredSessions AS 
--the details of home page and entry page
(
    SELECT 
        website_session_id,
        entry_page,
        week_start_date,
        page_count
    FROM 
        CampaignSessions
    WHERE 
        entry_page IN ('/home', '/lander-1')
)
SELECT
    week_start_date,
    entry_page,
    COUNT(DISTINCT website_session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN page_count = 1 THEN website_session_id END) AS bounced_sessions,
    (COUNT(DISTINCT CASE WHEN page_count = 1 THEN website_session_id END) * 100.0 / 
     COUNT(DISTINCT website_session_id)) AS bounce_rate
FROM FilteredSessions
GROUP BY week_start_date, entry_page
ORDER BY week_start_date, entry_page;

------Conversion Rate------------

WITH BILLED_SESSIONS AS
(
	SELECT 
		COUNT(order_id) Orders
		FROM orders
		
),TOTAL_SESSIONS AS
(
	SELECT 
		COUNT(DISTINCT(website_session_id)) [Total Sessions]
	FROM website_sessions
)

SELECT
	ROUND((CAST(Orders AS float)/CAST([Total Sessions] AS float))*100,2) [Conversion Rate]
FROM BILLED_SESSIONS,TOTAL_SESSIONS;




--Q11. Build Conversion Funnels for gsearch nonbrand traffic from /lander-1 to /thank you page: What are the 
--session counts and click percentages for \lander-1, product, mr fuzzy, cart, shipping, billing, and thank you pages 
--from August 5, 2012, to September 5, 2012? 

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




--Q12. Analyze Conversion Funnel Tests for /billing vs. new /billing-2 pages: what is the traffic and billing to order
--conversion rate of both pages new/billing-2 page?


WITH PageViewCounts AS 
(
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
    Round((CASE 
        WHEN pv.TotalPageViews > 0 THEN 
            CAST(COALESCE(oc.TotalOrders, 0) AS FLOAT) *100/ pv.TotalPageViews
        ELSE 
            0
    END ),2)AS ConversionRate
FROM 
    PageViewCounts pv
LEFT JOIN 
    OrderCounts oc
ON 
    pv.pageview_url = oc.pageview_url;



--Q13. Analyzing Channel Portfolios: What are the weekly sessions data for both gsearch and bsearch from 
--August 22nd to November 29th? 

/*SELECT 
    DATEPART(YEAR, created_at) AS year,
    DATEPART(WEEK, created_at) AS week,
    utm_source,
    COUNT(*) AS session_count
FROM 
    website_sessions
WHERE 
    created_at BETWEEN '2012-08-22' AND '2012-11-29'
    AND utm_source IN ('gsearch', 'bsearch')
GROUP BY 
    DATEPART(YEAR, created_at),
    DATEPART(WEEK, created_at),
    utm_source
ORDER BY 
    year,
    week,
    utm_source; */

SELECT 
	dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date)) week_start_date,
	sum(case when (utm_source = 'gsearch' and utm_campaign = 'nonbrand') then 1 else 0 end) AS gsearch_nonbrand_session,
	sum(case when (utm_source = 'bsearch' and utm_campaign = 'nonbrand') then 1 else 0 end) AS bsearch_nonbrand_session from website_sessions
WHERE 
	created_at > '2012-08-22' 
	AND cast(created_at AS datetime) < '2012-11-29'
GROUP BY  
	dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date))
ORDER BY week_start_date;

--Q14. Comparing Channel Characteristics: What are the mobile sessions data for non-brand campaigns of gsearch and 
--bsearch from August 22nd to November 30th, 
--including details such as utm_source, total sessions, mobile sessions, and the percentage of mobile sessions?

WITH  cte AS (
	SELECT  utm_source, 
			count(distinct website_session_id) total_sessions, 
			sum(case when device_type = 'mobile' then 1 else 0 end) mobile_sessions 
	FROM website_sessions
	WHERE 
		utm_campaign = 'nonbrand' 
		and cast(created_at AS datetime) > '2012-08-22' 
		and cast(created_at AS datetime) < '2012-11-30'
	GROUP BY utm_source
)

SELECT	utm_source, total_sessions, mobile_sessions, 
		round(mobile_sessions * 100/total_sessions,2) mobile_percent 
FROM cte;

--Q15. Cross-Channel Bid Optimization: provide the conversion rates from sessions to orders for non-brand campaigns 
--of gsearch and bsearch by device type, for the period spanning from August 22nd to September 18th?
--Additionally, include details such as device type, utm_source, total sessions, total orders, 
--and the corresponding conversion rates. 

WITH cte1 as(
	SELECT	device_type, 
			utm_source, 
			count(ws.website_session_id) sessions_, 
			count(o.order_id) orders_ 
	FROM website_sessions ws 
		 LEFT JOIN orders o 
		 ON ws.website_session_id = o.website_session_id 
			AND o.user_id = ws.user_id
	WHERE utm_source in ('gsearch', 'bsearch') 
		  AND cast(ws.created_at AS datetime) > '2012-08-22' and cast(ws.created_at AS datetime) < '2012-09-18'
	GROUP BY device_type, utm_source
)

SELECT device_type, utm_source, sessions_, orders_,
round((orders_ * 100.00/sessions_),2) 'conversion_rate%'
FROM cte1
ORDER BY device_type, utm_source;



--Q16. Channel Portfolio Trends: Retrieve the data for gsearch and bsearch non-brand sessions segmented by device type 
--from November 4th to December 22nd? Additionally, include details such as the start date of each week, 
--device type, utm_source, total sessions, bsearch comparison.

WITH cte2 AS (
	SELECT 
		dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date)) week_start_date, 
		sum(case when (utm_source = 'gsearch' and device_type = 'desktop') then 1 else 0 end) gsearch_desktop_sessions,
		sum(case when (utm_source = 'bsearch' and device_type = 'desktop') then 1 else 0 end) bsearch_desktop_sessions,
		sum(case when (utm_source = 'gsearch' and device_type = 'mobile') then 1 else 0 end) gsearch_mobile_sessions,
		sum(case when (utm_source = 'bsearch' and device_type = 'mobile') then 1 else 0 end) bsearch_mobile_sessions
	FROM website_sessions
	WHERE utm_campaign = 'nonbrand' 
	and cast(created_at AS datetime) > '2012-11-04' 
	and cast(created_at AS datetime) < '2012-12-22'
	GROUP BY dateadd(day, 1 - datepart(weekday, created_at), cast(created_at AS date))
)

SELECT  week_start_date, 
		gsearch_desktop_sessions,
		bsearch_desktop_sessions, 
		round((bsearch_desktop_sessions * 100.0/gsearch_desktop_sessions),2) AS 'bg_desktop_CVR%',
		gsearch_mobile_sessions, 
		bsearch_mobile_sessions,
		round((bsearch_mobile_sessions * 100.0/gsearch_mobile_sessions),2) AS 'bg_mobile_CVR%' from cte2
ORDER BY week_start_date


--Q17. Analyzing Free Channels: Could you pull organic search , direct type in and paid brand sessions by month 
--and show those sessions AS a % of paid search non brand? 

WITH cte3 AS (
SELECT  year(created_at) year_, 
		month(created_at) month_, 
		sum(case when utm_campaign = 'nonbrand' then 1 else 0 end) nonbrand_sessions,
		sum(case when utm_campaign = 'brand' then 1 else 0 end) brand_sessions,
		sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer = 'NULL') then 1 else 0 end) direct_sessions,
		sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer != 'NULL') then 1 else 0 end) organic_sessions
FROM website_sessions
WHERE year(created_at) = '2012'
GROUP BY  year(created_at), month(created_at)
)

SELECT 
	year_, 
	month_, 
	nonbrand_sessions, 
	brand_sessions, 
	round((brand_sessions* 100.0/nonbrand_sessions),2) brand_per_of_nonbrand, 
	direct_sessions,
	cast(round((direct_sessions * 100.0/nonbrand_sessions),2) AS float) direct_per_of_nonbrand, 
	organic_sessions,
	cast(round((organic_sessions * 100.0/nonbrand_sessions),2) AS float) organic_per_of_nonbrand from cte3
ORDER BY year_, month_;


--Q18. Analyzing Seasonality: Pull out sessions and orders by year, monthly and weekly for 2012?

-- Sessions by year, month
WITH session_data AS (
    SELECT 
        DATEPART(YEAR, created_at) AS year,
        DATEPART(MONTH, created_at) AS month,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
        DATEPART(YEAR, created_at) = 2012
	GROUP BY 
		DATEPART(YEAR, created_at),
        DATEPART(MONTH, created_at) 
  
),

-- no of Orders by year, month, and week
order_data AS (
    SELECT 
        DATEPART(YEAR, created_at) AS year,
        DATEPART(MONTH, created_at) AS month,
        COUNT(order_id) AS order_count
    FROM 
        [orders]
    WHERE 
        DATEPART(YEAR, created_at) = 2012
		GROUP BY 
		DATEPART(YEAR, created_at),
        DATEPART(MONTH, created_at)
)

-- Combining session and order data
SELECT 
    sd.year,
    sd.month,
    sd.session_count,
    od.order_count,
    Format(od.order_count*1.0/sd.session_count,'0.000') AS order_rate
FROM 
    session_data sd
LEFT JOIN 
    order_data od ON sd.year = od.year AND sd.month = od.month
ORDER BY 
    sd.year,
    sd.month;


-- Weekly Sessions 
WITH weekly_session_data AS (
    SELECT 
		DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
        COUNT(website_session_id) AS session_count
    FROM 
        website_sessions
    WHERE 
        DATEPART(YEAR, created_at) = 2012
	GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
  
),

-- no of Orders by  week
weekly_order_data AS (
    SELECT 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE)) AS week_start_date,
        COUNT(order_id) AS order_count
    FROM 
        [orders]
    WHERE 
        DATEPART(YEAR, created_at) = 2012
		GROUP BY 
        DATEADD(DAY,1-DATEPART(WEEKDAY, created_at),CAST(created_at AS DATE))
)

-- Combining session and order data
SELECT 
    sd.week_start_date,
    sd.session_count,
    od.order_count,
	Format(od.order_count*1.0/sd.session_count,'0.000') AS order_rate
FROM 
    weekly_session_data sd
LEFT JOIN 
    weekly_order_data od ON sd.week_start_date = od.week_start_date
ORDER BY 
    sd.week_start_date;



--Q19. Analyzing Business Patterns: What is the average website session volume , categorized by 
		--hour of the day and day of the week, 
		--between September 15th and November 15th ,2013, 
		--excluding holidays to assist in determining appropriate staffing levels for live chat support on the website?



-- Step 1: Create a CTE to filter out holidays and sessions within the specified date range

WITH FilteredSessions AS (
    SELECT 
        website_session_id,
        created_at,
        DATEPART(HOUR, created_at) AS hour_of_day,
        DATEPART(WEEKDAY, created_at) AS day_of_week
    FROM 
        website_sessions
    WHERE 
        created_at BETWEEN '2013-09-15' AND '2013-11-15'
)

-- Step 2: Calculate average session volume categorized by hour of the day and day of the week
SELECT
	day_of_week,
	CASE
		WHEN day_of_week = 1 THEN 'Sun'
        WHEN day_of_week = 2 THEN 'Mon'
        WHEN day_of_week = 3 THEN 'Tues'
        WHEN day_of_week = 4 THEN 'Wed'
        WHEN day_of_week = 5 THEN 'Thur'
        WHEN day_of_week = 6 THEN 'Fri'
        WHEN day_of_week = 7 THEN 'Sat'
    END AS day_of_week_name,
    hour_of_day,
    COUNT(website_session_id) AS session_count,
    AVG(COUNT(website_session_id)) OVER (PARTITION BY day_of_week) AS avg_session_volume
FROM 
    FilteredSessions
GROUP BY 
    day_of_week,
    hour_of_day
ORDER BY 
    day_of_week,
    hour_of_day;

		
--Q20. Product Level Sales Analysis: What is monthly trends to date for number of sales , 
--total revenue and total margin generated for business?

 SELECT
    FORMAT(created_at, 'yyyy-MM') AS month,
    primary_product_id,
    SUM(items_purchased) AS total_units_sold,
    SUM(price_usd) AS total_revenue,
    SUM(price_usd - cogs_usd) AS total_margin
FROM
    orders
GROUP BY
    FORMAT(created_at, 'yyyy-MM'),
    primary_product_id
ORDER BY
    month,
    Primary_product_id;



--Q21. Product Launch Sales Analysis: Could you generate trending analysis including monthly order volume, 
--overall conversion rates, revenue per session, and a breakdown of sales by product since April 1, 2013, 
--considering the launch of the second product on January 6th 2013?

-- Monthly Order Volume
SELECT 
  FORMAT(created_at, 'yyyy-MM') AS month,
  COUNT(order_id) AS order_volume
FROM orders
WHERE created_at >= '2013-04-01'
GROUP BY FORMAT(created_at, 'yyyy-MM')
ORDER BY FORMAT(created_at, 'yyyy-MM');

--Overall Conversion Rates
SELECT 
  FORMAT(s.created_at, 'yyyy-MM') AS month,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(DISTINCT s.website_session_id) AS total_sessions,
  (COUNT(DISTINCT o.order_id)*100.00)/ COUNT(DISTINCT s.website_session_id) AS 'conversion_rate%'
FROM website_sessions s
LEFT JOIN orders o ON s.website_session_id = o.website_session_id
WHERE s.created_at >= '2013-04-01'
GROUP BY FORMAT(s.created_at, 'yyyy-MM')
ORDER BY FORMAT(s.created_at, 'yyyy-MM');

--Revenue per Session
SELECT 
  FORMAT(s.created_at, 'yyyy-MM') AS month,
  SUM(o.price_usd) / COUNT(DISTINCT s.website_session_id) AS revenue_per_session
FROM website_sessions s
LEFT JOIN orders o ON s.website_session_id = o.website_session_id
WHERE s.created_at >= '2013-04-01'
GROUP BY FORMAT(s.created_at, 'yyyy-MM')
ORDER BY FORMAT(s.created_at, 'yyyy-MM');

--Breakdown of Sales by Product
SELECT 
  FORMAT(o.created_at, 'yyyy-MM') AS month,
  p.product_name,
  COUNT(o.order_id) AS order_volume,
  SUM(o.price_usd) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.created_at >= '2013-04-01'
GROUP BY FORMAT(o.created_at, 'yyyy-MM'), p.product_name
ORDER BY FORMAT(o.created_at, 'yyyy-MM'), p.product_name;

--Breakdown of Sales by Product
SELECT 
  FORMAT(o.created_at, 'yyyy-MM') AS month,
  p.product_name,
  COUNT(o.order_id) AS order_volume,
  SUM(o.price_usd) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.created_at >= '2013-04-01'
GROUP BY FORMAT(o.created_at, 'yyyy-MM'), p.product_name
ORDER BY FORMAT(o.created_at, 'yyyy-MM'), p.product_name;




--Q22. Product Pathing Analysis: What are the clickthrough rates from /products since the new product launch on January 6th 2013,
--by product and compare to the 3 months leading up to launch as a baseline? 




--Q23. Product Conversion Funnels: provide a comparison of the conversion funnels from the product pages to conversion 
--for two products since January 6th, analyzing all website traffic?

SELECT website_session_id,
website_pageview_id,
pageview_url AS product_page_seen into sessions_seeing_product_pages
FROM website_pageviews
WHERE created_at BETWEEN '2013-01-06' AND '2013-04-10'
AND pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear');


SELECT DISTINCT
website_pageviews.pageview_url
FROM sessions_seeing_product_pages as s
LEFT JOIN website_pageviews
ON s.website_session_id = website_pageviews.website_session_id
AND website_pageviews.website_pageview_id > s.website_pageview_id;
 
WITH cte1 AS (
    SELECT website_session, product_seen,
           SUM(cart_page) AS to_cart,
           SUM(shipping_page) AS to_ship,
           SUM(bill_page) AS to_bill,
           SUM(thankyou_page) AS to_thank
    FROM (
        SELECT S.website_session_id AS website_session,
               S.product_page_seen AS product_seen,
               CASE WHEN W.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
               CASE WHEN W.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
               CASE WHEN W.pageview_url = '/billing-2' THEN 1 ELSE 0 END AS bill_page,
               CASE WHEN W.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
        FROM sessions_seeing_product_pages AS S
        LEFT JOIN website_pageviews AS W
        ON S.website_session_id = W.website_session_id 
        AND W.website_pageview_id > S.website_pageview_id
    ) AS funnel
    GROUP BY website_session, product_seen
)
SELECT product_seen,
       COUNT(website_session) AS session,
       round(cast(SUM(to_cart) as float)/COUNT(website_session),3) as prod_page_click_rate,
       round(cast(SUM(to_ship) as float)/SUM(to_cart),3) AS cart_click_rate,
       round(cast(SUM(to_bill) as float)/SUM(to_ship),3) AS shipping_click_rate,
       round(cast(SUM(to_thank) as float)/SUM(to_bill),3) AS billing_click_rate

FROM cte1
GROUP BY product_seen
ORDER BY product_seen;



--Q24. Cross-Sell Analysis: Analyze the impact of offering customers the option to add a second 
--product on the /cart page, comparing the metrics from the month before the change to the month after? Specifically, 
--in comparing the click-through rate (CTR) from the /cart page, average products per order, average order value (AOV),
--and overall revenue per /cart page view. 



--Q25. Portfolio Expansion Analysis: Conduct a pre-post analysis comparing the month before and the month after the
--launch of the “Birthday Bear” product on December 12th, 2013? Specifically, containing the changes in 
--session-to-order conversion rate, average order value (AOV), products per order, and revenue per session.


--Session-to-Order Conversion Rate
SELECT 
  CASE 
    WHEN s.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END AS period,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(DISTINCT s.website_session_id) AS total_sessions,
  (COUNT(DISTINCT o.order_id) * 1.0 / COUNT(DISTINCT s.website_session_id)) * 100 AS conversion_rate
FROM website_sessions s
LEFT JOIN orders o ON s.website_session_id = o.website_session_id
WHERE s.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 
  CASE 
    WHEN s.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END;

 --Average Order Value (AOV)
  SELECT 
  CASE 
    WHEN created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END AS period,
  SUM(price_usd) / COUNT(order_id) AS average_order_value
FROM orders
WHERE created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 
  CASE 
    WHEN created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END;

  --Products per Order
  SELECT 
  CASE 
    WHEN o.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END AS period,
  AVG(o.items_purchased) AS avg_products_per_order
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 
  CASE 
    WHEN o.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END;

  --Revenue per Session
  SELECT 
  CASE 
    WHEN s.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END AS period,
  SUM(o.price_usd) / COUNT(DISTINCT s.website_session_id) AS revenue_per_session
FROM website_sessions s
LEFT JOIN orders o ON s.website_session_id = o.website_session_id
WHERE s.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 
  CASE 
    WHEN s.created_at < '2013-12-12' THEN 'pre-launch' 
    ELSE 'post-launch' 
  END;



--Q26. Product Refund Rates: What are monthly product refund rates, by product and confirm quality issues are now fixed?


WITH monthly_sales AS (
    SELECT
        FORMAT(order_items.created_at, 'yyyy-MM') AS month,
        products.product_name,
        COUNT(order_items.order_item_id) AS total_sold,
        SUM(order_items.price_usd) AS total_sales_value
    FROM
        order_items
    JOIN 
        products ON order_items.product_id = products.product_id
    GROUP BY 
        FORMAT(order_items.created_at, 'yyyy-MM'), products.product_name
),
monthly_refunds AS (
    SELECT
        FORMAT(order_item_refunds.created_at, 'yyyy-MM') AS month,
        products.product_name,
        COUNT(order_item_refunds.order_item_refund_id) AS total_refunds,
        SUM(order_item_refunds.refund_amount_usd) AS total_refund_value
    FROM
        order_item_refunds
    JOIN 
        order_items ON order_item_refunds.order_item_id = order_items.order_item_id
    JOIN 
        products ON order_items.product_id = products.product_id
    GROUP BY 
        FORMAT(order_item_refunds.created_at, 'yyyy-MM'), products.product_name
)
SELECT 
    s.month,
    s.product_name,
    COALESCE(r.total_refunds, 0) AS total_refunds,
    s.total_sold,
    COALESCE((CAST(r.total_refunds AS FLOAT) / s.total_sold) * 100, 0) AS refund_rate,
    s.total_sales_value,
    COALESCE(r.total_refund_value, 0) AS total_refund_value
FROM 
    monthly_sales s
LEFT JOIN 
    monthly_refunds r ON s.month = r.month AND s.product_name = r.product_name
ORDER BY 
    s.month, s.product_name;


--Q27. Identifying Repeat Visitors: Please pull data on how many of our website visitors
--come back for another session?2014 to date is good. 

SELECT 
	count(is_repeat_session) [Count of repeate visitors]
FROM website_sessions
WHERE is_repeat_session = 1 AND year(created_at) > 2014


--Q28. Analyzing Repeat Behavior: What is the minimum , maximum and average time between the 
--first and second session for customers who do come back?2014 to date is good. 

WITH cte4 AS(
SELECT 
	user_id, 
	min(case when rnk = 1 then created_at end) first_session, 
	min(case when rnk = 2 then created_at end) second_session 
FROM(
	select user_id, created_at, row_number() over(partition by user_id order by website_session_id) rnk 
	from website_sessions where year(created_at) > 2014
	) tbl1
GROUP BY user_id)

SELECT round(min(datediff(HOUR, first_session, second_session)), 2) AS min_time_in_fst_snd_session_hours, 
       round(max(datediff(HOUR, first_session, second_session)), 2) AS max_time_in_fst_snd_session_days, 
       round(avg(datediff(HOUR, first_session, second_session)), 2) AS avg_time_in_fst_snd_session_days
FROM cte4;

--Q29 New Vs. Repeat Channel Patterns: Analyze the channels through which repeat customers 
--return to our website, comparing them to new sessions? Specifically, interested in 
--understanding if repeat customers predominantly come through direct type-in or 
--if there’s a significant portion that originates from paid search ads. 
--This analysis should cover the period from the beginning of 2014 to the present date

SELECT
sum(case when (utm_campaign = 'nonbrand' and utm_source != 'NULL' and is_repeat_session = 0) then 1 else 0 end) new_paid_nonbrand_sessions,
sum(case when (utm_campaign = 'nonbrand' and utm_source != 'NULL' and is_repeat_session = 1) then 1 else 0 end) repeat_paid_nonbrand_sessions,
sum(case when (utm_campaign = 'brand' and utm_source != 'NULL' and is_repeat_session = 0) then 1 else 0 end) new_paid_brand_sessions,
sum(case when (utm_campaign = 'brand' and utm_source != 'NULL' and is_repeat_session = 1) then 1 else 0 end) repeat_paid_brand_sessions,
sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer = 'NULL' and is_repeat_session = 0) then 1 else 0 end) new_direct_sessions,
sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer = 'NULL' and is_repeat_session = 1) then 1 else 0 end) repeat_direct_sessions, 
sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer != 'NULL' and is_repeat_session = 0) then 1 else 0 end) new_organic_sessions,
sum(case when (utm_campaign = 'NULL'  and utm_content = 'NULL' and http_referer != 'NULL' and is_repeat_session = 1) then 1 else 0 end) repeat_organic_sessions
FROM website_sessions
WHERE year(created_at) > 2014;


-- Q30 New Vs. Repeat Performance: Provide analysis on comparison of conversion rates 
--and revenue per session for repeat sessions vs new sessions?2014 to date is good. 

WITH cte4 AS(
SELECT utm_source, is_repeat_session, 
count(ws.website_session_id) total_sessions,
count(o.order_id) total_orders, sum(price_usd) revenue_ 
FROM website_sessions ws 
	left join orders o 
	ON ws.user_id = o.user_id and ws.website_session_id = o.website_session_id
WHERE year(ws.created_at) >= 2014
GROUP BY utm_source, is_repeat_session
)

SELECT  utm_source, 
		is_repeat_session, 
		format((total_orders * 100.0 / total_sessions), '0.00') 'conversion_rate%', 
		format((revenue_/total_sessions), '0.00') revenue_per_session 
FROM cte4
ORDER BY utm_source, is_repeat_session;