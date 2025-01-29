USE Digital_Analysis

--landing page trend analysis
--landing page is the Page where the user lands after clicking the ad

--landing page with session id and ad page

SELECT
DISTINCT PAGES
FROM(
select 
ws.utm_content,
wp.website_session_id,
wp.pageview_url AS PAGES
from website_pageviews wp
join website_sessions ws on wp.website_session_id=ws.website_session_id
where ws.utm_content <> 'Direct_Search'
)RESULT




--no.of visitors through landing page


select
count(distinct(website_session_id)) session_count_of_non_organic_search
from Session_and_Pageview
where utm_content <>'Direct_Search'





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