USE Digital_Analysis

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





 

