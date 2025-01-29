Create database Digital_Analysis

USE Digital_Analysis

SELECT * FROM products
SELECT * FROM orders
SELECT * FROM order_items
SELECT * FROM order_item_refunds
SELECT * FROM website_pageviews
SELECT * FROM website_sessions

---CREATING A NEW TABLE

SELECT 
	WP.pageview_url,WP.created_at,WP.website_pageview_id,WP.website_session_id,
	WS.device_type,WS.is_repeat_session,WS.user_id,WS.utm_campaign,WS.utm_content,WS.utm_source,WS.http_referer
INTO Session_and_Pageview
FROM website_pageviews WP
INNER JOIN website_sessions WS ON WP.website_session_id=WS.website_session_id

SELECT * FROM Session_and_Pageview

--total number of Visit

SELECT COUNT(website_session_id) AS [TotalVisit] FROM website_sessions



--Unique Visitors

SELECT DISTINCT COUNT(user_id) AS [Unique Users] FROM website_sessions



--Page Views 

SELECT COUNT(website_pageview_id)  [Page Views] FROM website_pageviews



-- Average session duration


WITH session_duration AS
 (
	SELECT distinct
		website_session_id,
		MIN(created_at) AS session_start_time,
		MAX(created_at) AS session_end_time,
		DATEDIFF(MINUTE, MIN(created_at), MAX(created_at))AS session_duration_MINUTES
	FROM Session_and_Pageview 
	GROUP BY website_session_id
	
)

SELECT
	AVG(session_duration_MINUTES) [Average Session Duration in Minutes]
FROM session_duration


--Revenue for new sessions


WITH NEW_SESSION AS
(
	SELECT  DISTINCT
		WS.user_id AS Userid,
		WS.website_session_id AS SessionId,
		OI.order_item_id AS orderitem,
		OI.price_usd AS Price,
		DENSE_RANK() OVER(PARTITION BY WS.user_id order by WS.website_session_id) AS RANKS
	FROM website_sessions WS
	JOIN orders O ON WS.website_session_id=O.website_session_id
	JOIN order_items OI ON O.order_id=OI.order_id
)

SELECT
	ROUND(CAST(SUM(PRICE) AS FLOAT),2)as [Revenue for New session]
FROM NEW_SESSION 
WHERE RANKS = 1 


--REVENUE FOR REPEATED SESSIONS


WITH REPEATED_SESSION AS
(
	SELECT  DISTINCT
		WS.user_id AS Userid,
		WS.website_session_id AS SessionId,
		OI.order_item_id AS orderitem,
		OI.price_usd AS Price,
		DENSE_RANK() OVER(PARTITION BY WS.user_id order by WS.website_session_id) AS RANKS
	FROM website_sessions WS
	JOIN orders O ON WS.website_session_id=O.website_session_id
	JOIN order_items OI ON O.order_id=OI.order_id
)

SELECT
	ROUND(CAST(SUM(PRICE) AS FLOAT),2)as [Revenue for Repeate session]
FROM REPEATED_SESSION 
WHERE RANKS >1

--Traffic source

-- Updating the null values to Direct_source

Update website_sessions
SET utm_source ='Direct_Source'
WHERE utm_source='NULL'

SELECT
	utm_source,
	COUNT(user_id) AS COUNT
FROM website_sessions 
GROUP BY utm_source


--Pages per session


SELECT
	AVG([Page Count]) [Avg Pages Viewed per session],
	MAX([Page Count]) [Max Pages viewed per session]
FROM
(
	SELECT
		website_session_id,
		COUNT(pageview_url) [Page Count]
	FROM website_pageviews
	GROUP BY website_session_id
)RESULT


--Time on page


WITH Each_page_time as
(
	SELECT
		pageview_url,
		(SUM(time_spent_SECONDS)/60.0) as [Time on page in Minutes],
		count(pageview_url) as counts
	FROM
	(
		SELECT 
			wp.website_session_id,
			wp.website_pageview_id,
			WP.pageview_url,
			wp.created_at AS page_start_time, 
			MIN(wp1.created_at) AS next_page_start_time,
			DATEDIFF(SECOND, wp.created_at, MIN(wp1.created_at)) AS time_spent_SECONDS
		FROM website_pageviews wp
		LEFT JOIN website_pageviews wp1 on wp.website_session_id=wp1.website_session_id
		AND wp.created_at< wp1.created_at
		GROUP BY 
			  wp.website_session_id,
			  wp.website_pageview_id,
			  wp.pageview_url,
			  wp.created_at
	)RESULT
	GROUP BY pageview_url
)
SELECT
	pageview_url,
	ROUND((CAST([Time on page in Minutes] AS FLOAT) /counts),1) [Time on Each Page in Min]
FROM Each_page_time


--Convesion Rate



WITH BILLED_SESSIONS AS
(
	SELECT 
		COUNT(distinct(order_id)) Orders
		FROM orders
),TOTAL_SESSIONS AS
(
	SELECT 
		COUNT(DISTINCT(website_session_id)) [Total Sessions]
	FROM website_sessions
)

SELECT
	ROUND((CAST(Orders AS float)/CAST([Total Sessions] AS float))*100,2) [Conversion Rate]
FROM BILLED_SESSIONS,TOTAL_SESSIONS


--Top website page


SELECT  
	pageview_url,
	COUNT(pageview_url) AS COUNT
FROM website_pageviews
GROUP BY pageview_url 
ORDER BY COUNT DESC


--New and Repeate website visitors

WITH TOTAL_SESSIONS AS
(
	SELECT  DISTINCT
		WS.user_id AS Userid,
		WS.website_session_id AS SessionId,
		DENSE_RANK() OVER(PARTITION BY WS.user_id order by WS.website_session_id) AS RANKS
	FROM website_sessions WS
	
),NEW_SESSION_COUNT AS
(
	SELECT
		count(SessionId)as [New Visitor]
	FROM TOTAL_SESSIONS 
	WHERE RANKS =1
),REPEATE_SESSION_COUNT AS
(
	SELECT
		count(SessionId)as [Repeate Visitor]
	FROM TOTAL_SESSIONS 
	WHERE RANKS >1
)

SELECT
	[New Visitor],
	[Repeate Visitor]
FROM NEW_SESSION_COUNT, REPEATE_SESSION_COUNT


with repeated_visitors as
(
select
count(website_session_id) repeate_visitors
from website_sessions
where is_repeat_session =1
),total_visitors as
(
select
count(website_session_id) total_visitor
from website_sessions
)

select
repeate_visitors,
difference(total_visitor,repeate_visitors)
from repeated_visitors ,total_visitors




--Entry page

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
			DENSE_RANK() OVER(PARTITION BY website_session_id ORDER BY created_at) AS DENSE_RANKS
		FROM website_pageviews
	) RESULT
		WHERE DENSE_RANKS=1
)
SELECT
pageview_url,
COUNT(pageview_url) AS COUNT
FROM entry_page
GROUP BY pageview_url
ORDER BY COUNT DESC


--landing page trend analysis
--landing page is the Page where the user lands after clicking the ad


--bounce rate of landing page


WITH SINGLE_PAGE_VIEW AS
(
	SELECT
	COUNT(counts) [SINGLE PAGE VIEW]
	FROM
	(
		SELECT 
			website_session_id,
			COUNT(website_session_id) as counts
		FROM Session_and_Pageview
		WHERE utm_content <> 'Direct_Search' 
		GROUP BY website_session_id
		HAVING COUNT(website_session_id)=1
	)RESULT
),TOTAL_VISIT AS
(
	SELECT 
		count(website_session_id) as [TOTAL PAGES]
	FROM Session_and_Pageview
	WHERE utm_content <> 'Direct_Search' 
)

SELECT
	ROUND((CAST([SINGLE PAGE VIEW] AS float)/CAST([TOTAL PAGES] AS FLOAT)*100),2) AS [Bounce rate of landing page]
FROM SINGLE_PAGE_VIEW,TOTAL_VISIT



--AVERAGE SESSION DURATION ON LANDING PAGE	

SELECT
	Round((CAST(AVG(time_spent_SECONDS) as float)/60.0),2) [Avg Session Duration oN Landing page in Minutes]
FROM
	(
		SELECT 
			wp.website_session_id AS WEBSITE_SESSION,
			wp.website_pageview_id AS WEBSITE_PAGEVIEW,
			WP.pageview_url AS PAGE_URL,
			wp.created_at AS page_start_time, 
			MIN(wp1.created_at) AS next_page_start_time,
			DATEDIFF(SECOND, wp.created_at, MIN(wp1.created_at)) AS time_spent_SECONDS,
			DENSE_RANK() OVER (PARTITION BY  wp.website_session_id ORDER BY WP.created_at) DENSE
		FROM website_sessions ws
		JOIN website_pageviews wp ON wp.website_session_id=ws.website_session_id
		LEFT JOIN website_pageviews wp1 on wp.website_session_id=wp1.website_session_id
		AND wp.created_at< wp1.created_at
		WHERE ws.utm_content <> 'Direct_Search'
		GROUP BY 
			  wp.website_session_id,
			  wp.website_pageview_id,
			  wp.pageview_url,
			  wp.created_at
	)RESULT
WHERE DENSE=1  AND next_page_start_time IS NOT NULL AND time_spent_SECONDS IS NOT NULL  


--AVERAGE SESSION DURATION Of each LANDING PAGE	
		
SELECT
	PAGE_URL,
    ROUND((CAST(AVG(time_spent_SECONDS) AS float) / 60.0), 2) AS [Avg Session Duration in Minutes]
FROM
(
    SELECT 
        wp.website_session_id AS WEBSITE_SESSION,
        wp.website_pageview_id AS WEBSITE_PAGEVIEW,
        wp.pageview_url AS PAGE_URL,
        wp.created_at AS page_start_time, 
        MIN(wp1.created_at) AS next_page_start_time,
        DATEDIFF(SECOND, wp.created_at, MIN(wp1.created_at)) AS time_spent_SECONDS,
        DENSE_RANK() OVER (PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS DENSE
    FROM website_sessions ws
    JOIN website_pageviews wp ON wp.website_session_id = ws.website_session_id
    LEFT JOIN website_pageviews wp1 ON wp.website_session_id = wp1.website_session_id
        AND wp.created_at < wp1.created_at
    WHERE ws.utm_content <> 'Direct_Search'
    GROUP BY 
        wp.website_session_id,
        wp.website_pageview_id,
        wp.pageview_url,
        wp.created_at
) RESULT
WHERE DENSE = 1  
    AND next_page_start_time IS NOT NULL 
    AND time_spent_SECONDS IS NOT NULL
GROUP BY PAGE_URL	

-------------Organic search traffic-----------------

--updating the utm_content NULL to direct search
Update website_sessions
SET utm_content='Direct_Search'
where utm_content='NULL'

--total organic sessions
SELECT
	COUNT(website_session_id)	[Count of organic Sessions]
FROM website_sessions
WHERE utm_content='Direct_Search'

--total unique users for organic search
SELECT
	COUNT(Distinct(user_id))	[Unique count of organic sessiosn]
FROM website_sessions
WHERE utm_content='Direct_Search'



--organic search trend

SELECT
	COUNT(DISTINCT(user_id))
FROM Session_and_Pageview
WHERE utm_content='Direct_Search'

SELECT
	COUNT(DISTINCT(website_session_id))
FROM Session_and_Pageview
WHERE utm_content='Direct_Search'

--MAX DIRECT SEARCH IS THROUGH WHICH DEVICE
SELECT 
device_type,
COUNT(device_type) COUNT
FROM Session_and_Pageview
WHERE utm_content='Direct_Search'
GROUP BY device_type

select
count(distinct(website_session_id)) direct_search_organic_session_count
from Session_and_Pageview
where utm_content ='Direct_Search'

select
count(distinct(website_session_id)) session_count_of_non_organic_search
from Session_and_Pageview
where utm_content <>'Direct_Search'

select count(distinct(website_session_id)) from Session_and_Pageview



--Bounce Rate

WITH SINGLE_PAGE_VIEW AS 
(
	SELECT 
		COUNT(counts) [Single page view] 
	FROM
	(
		SELECT 
			COUNT(website_session_id) AS counts
		FROM Session_and_Pageview
		GROUP BY website_session_id
		HAVING COUNT(website_session_id)=1
	)RESULT
),Total_session AS
(
	SELECT
		COUNT(website_session_id) [Total_sessions]
	FROM Session_and_Pageview
)

SELECT 
	ROUND((CAST(SINGLE_PAGE_VIEW.[Single page view] AS float)/CAST(Total_session.[Total_sessions] AS float))*100,0) as [Bounce Rate]
FROM SINGLE_PAGE_VIEW, Total_session


--bounce rate page wise

WITH single_page_session AS
(
	SELECT 
		website_session_id,
		COUNT(website_session_id) AS COUNTS
	FROM Session_and_Pageview
	GROUP BY website_session_id
	HAVING COUNT(website_session_id)=1
),session_page AS
(
	SELECT 
		sp.website_session_id,
		WP.pageview_url AS Pages
	FROM single_page_session sp
	JOIN website_pageviews WP ON WP.website_session_id = sp.website_session_id
),page_count AS
(
	SELECT
		Pages,
		COUNT(Pages) AS COUNT
	FROM session_page
	GROUP BY Pages
),TOTAL_COUNT_OF_PAGE_VIEW AS
(
	SELECT 
		pageview_url,
		count(pageview_url) as count
	FROM Session_and_Pageview
	GROUP BY pageview_url
)

SELECT
	T.pageview_url,
	ROUND((cast(p.COUNT as float)/cast(T.count as float))*100,2) as bounce_rate
FROM TOTAL_COUNT_OF_PAGE_VIEW T 
JOIN page_count p ON T.pageview_url=p.PAGES



--3. Calculating Bounce Rates
-- Pull out the bounce rates for traffic landing on home page by sessions, bounced sessions and bounce rate?

WITH SinglePageSessions AS (
    SELECT 
        website_session_id,
        COUNT(*) AS page_count
    FROM 
        website_pageviews
    GROUP BY 
        website_session_id
    HAVING 
        COUNT(website_pageview_id) = 1
),
HomePageSessions AS (
    SELECT 
        website_session_id
    FROM 
        website_pageviews
    WHERE 
        pageview_url = '/home'
),
SinglePageHomeSessions AS (
    SELECT 
        website_session_id
    FROM 
        HomePageSessions
    WHERE 
        website_session_id IN (SELECT website_session_id FROM SinglePageSessions)
)
SELECT
    'Home' AS landing_page,
    COUNT(DISTINCT HomePageSessions.website_session_id) AS total_sessions,
    COUNT(DISTINCT SinglePageHomeSessions.website_session_id) AS bounced_sessions,
    (CAST(COUNT(DISTINCT SinglePageHomeSessions.website_session_id) AS FLOAT) / 
     COUNT(DISTINCT HomePageSessions.website_session_id)) * 100 AS bounce_rate
FROM 
    HomePageSessions
LEFT JOIN 
    SinglePageHomeSessions 
ON 
    HomePageSessions.website_session_id = SinglePageHomeSessions.website_session_id

--4. Analyzing Landing Page Tests
--What are the bounce rates for \lander-1 and \home in the A/B test conducted by ST for the gsearch nonbrand 
--campaign, considering traffic received by \lander-1 and \home before

select * from website_pageviews
select * from website_sessions

WITH CampaignSessions AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url AS entry_page
    FROM 
        website_pageviews wp
    JOIN 
        website_sessions cd
    ON 
        wp.website_session_id = cd.website_session_id
    WHERE 
        cd.utm_source = 'gsearch' and cd.utm_campaign= 'nonbrand'
    GROUP BY 
        wp.website_session_id, wp.pageview_url
),
SinglePageSessions AS (
    SELECT 
        website_session_id,
        COUNT(*) AS page_count
    FROM 
        website_pageviews
    GROUP BY 
        website_session_id
    HAVING 
        COUNT(website_pageview_id) = 1
),
HomePageSessions AS (
    SELECT 
        website_session_id
    FROM 
        CampaignSessions
    WHERE 
        entry_page = '/home'
),
LanderPageSessions AS (
    SELECT 
        website_session_id
    FROM 
        CampaignSessions
    WHERE 
        entry_page = '/lander-1'
),
SinglePageHomeSessions AS (
    SELECT 
        website_session_id
    FROM 
        HomePageSessions
    WHERE 
        website_session_id IN (SELECT website_session_id FROM SinglePageSessions)
),
SinglePageLanderSessions AS (
    SELECT 
        website_session_id
    FROM 
        LanderPageSessions
    WHERE 
        website_session_id IN (SELECT website_session_id FROM SinglePageSessions)
)
SELECT
    'Home' AS landing_page,
    COUNT(DISTINCT HomePageSessions.website_session_id) AS total_sessions,
    COUNT(DISTINCT SinglePageHomeSessions.website_session_id) AS bounced_sessions,
    (CAST(COUNT(DISTINCT SinglePageHomeSessions.website_session_id) AS FLOAT) / 
     COUNT(DISTINCT HomePageSessions.website_session_id)) * 100 AS bounce_rate
FROM 
    HomePageSessions
LEFT JOIN 
    SinglePageHomeSessions 
ON 
    HomePageSessions.website_session_id = SinglePageHomeSessions.website_session_id

UNION ALL

SELECT
    'Lander-1' AS landing_page,
    COUNT(DISTINCT LanderPageSessions.website_session_id) AS total_sessions,
    COUNT(DISTINCT SinglePageLanderSessions.website_session_id) AS bounced_sessions,
    (CAST(COUNT(DISTINCT SinglePageLanderSessions.website_session_id) AS FLOAT) / 
     COUNT(DISTINCT LanderPageSessions.website_session_id)) * 100 AS bounce_rate
FROM 
    LanderPageSessions
LEFT JOIN 
    SinglePageLanderSessions 
ON 
    LanderPageSessions.website_session_id = SinglePageLanderSessions.website_session_id


--5. Landing Page Trend Analysis
--What is the trend of weekly paid gsearch nonbrand campaign traffic on /home and /lander-1 pages 
--since June 1, 2012, along with their respective bounce rates, as requested by ST? Please limit the 
--results to the period between June 1, 2012, and August 31, 2012, based on the email received on August 31, 2021.

WITH CampaignSessions AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url AS entry_page,
         DATEADD(WEEK, DATEDIFF(WEEK, 0, wp.created_at), 0) AS week_start_date,
        COUNT(*) OVER (PARTITION BY wp.website_session_id) AS page_count
    FROM 
        website_pageviews wp
    JOIN 
        website_sessions cd
    ON 
        wp.website_session_id = cd.website_session_id
    WHERE 
        cd.utm_campaign =  'nonbrand' and cd.utm_source='gsearch'
        AND wp.created_at BETWEEN '2012-06-01' AND '2012-08-31'
),
FilteredSessions AS (
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
FROM 
    FilteredSessions
GROUP BY
    week_start_date, entry_page
ORDER BY
    week_start_date, entry_page;


	



