
USE Digital_Analysis

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