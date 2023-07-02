USE mavenfuzzyfactory;

/*Q.1 Pull monthly trends of traffic  for gsearch and all other searches before 27th Nov, 2012*/

SELECT Year,
	   Mon,
       COUNT(DISTINCT(website_session_id)) total_sessions,
       COUNT(DISTINCT(CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END)) gsearch_sessions,
       COUNT(DISTINCT(CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END)) bsearch_sessions,
       COUNT(DISTINCT(CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_session_id ELSE NULL END)) organic_sessions,
       COUNT(DISTINCT(CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_session_id ELSE NULL END)) direct_typein_sessions
FROM
(SELECT  YEAR(WS.created_at) Year,
		MONTH(WS.created_at) Mon,
		website_session_id,
        utm_source,
        utm_campaign,
        http_referer
FROM website_sessions WS
WHERE WS.created_at < '2012-11-27') AS session_with_source
GROUP BY 1,2;


/*Q.2. Pull monthly trends for gsearch session, orders and session to order conversion rate*/

WITH cte AS(
SELECT 
		YEAR(WS.created_at) Year,
        MONTH(WS.created_at) Mon,
        WS.website_session_id,
        orders.order_id
FROM website_sessions WS 
LEFT JOIN orders  
ON WS.website_session_id = orders.website_session_id
WHERE WS.created_at < '2012-11-27'
AND utm_source = 'gsearch')

SELECT Year,
	   Mon,
	   COUNT(DISTINCT(website_session_id)) gsearch_session,
       COUNT(DISTINCT(order_id)) sessions_with_order,
       COUNT(DISTINCT(order_id))*100/COUNT(DISTINCT(website_session_id)) AS session_to_order_rt
FROM cte
GROUP BY Year,Mon;



/*Q.3 pull monthly sessions and orders and conversion rate  spilt by device type for gsearch non brand. Use data before
 27th Nov for analysis*/

SELECT 
	Year(WS.created_at) Year,
    Month(WS.created_at) Mon,
    COUNT(DISTINCT(WS.website_session_id)) gsearch_sessions,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'mobile' THEN WS.website_session_id ELSE NULL END)) mobile_sessions,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'desktop' THEN WS.website_session_id ELSE NULL END)) desktop_sessions,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'mobile' THEN O.order_id ELSE NULL END)) mobile_orders,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'desktop' THEN O.order_id ELSE NULL END)) desktop_orders,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'mobile' THEN O.order_id ELSE NULL END))/
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'mobile' THEN WS.website_session_id ELSE NULL END)) mobile_order_cnv_rt,
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'desktop' THEN O.order_id ELSE NULL END))/
    COUNT(DISTINCT(CASE WHEN WS.device_type = 'desktop' THEN WS.website_session_id ELSE NULL END)) desktop_order_cnv_rt
    
FROM website_sessions WS
LEFT JOIN orders O ON O.website_session_id = WS.website_session_id 
WHERE WS.utm_source = 'gsearch' 
AND WS.created_at < '2012-11-27'
GROUP BY 1,2;


/*Q.4 Analyze the impact of adding new landing page '/lander-1'. Do the analysis before 27th Nov, 2012*/

-- getting date when a session first landed on lander-1
SELECT MIN(created_at) FROM website_pageviews
WHERE pageview_url = '/lander-1';
-- date on which first session landed on lander-1 = 2012-06-19 00:35:54

-- getting date for latest session landing on home page
SELECT MAX(website_pageviews.created_at) FROM website_pageviews
INNER JOIN website_sessions ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE pageview_url = '/home'
AND website_sessions.utm_source = 'gsearch' AND website_sessions.utm_campaign = 'nonbrand';
-- date on which last session landed on home page = 2012-07-29 23:48:16

-- doing a fair comparison between two landing pages for dates between 2012-06-19 00:35:54 & 2012-07-29 23:48:16 using session to order conversion rate metric
SELECT 
	WP.pageview_url,
    COUNT(DISTINCT(WS.website_session_id)) sessions,
    COUNT(DISTINCT(O.order_id)) orders,
    COUNT(DISTINCT(O.order_id))/COUNT(DISTINCT(WS.website_session_id)) session_order_cnv_rate
FROM Website_sessions WS
INNER JOIN website_pageviews WP ON WP.website_session_id = WS.website_session_id
LEFT JOIN orders O ON O.website_session_id = WS.website_session_id
WHERE WS.utm_source = 'gsearch' AND WS.utm_campaign ='nonbrand'
AND WS.created_at BETWEEN '2012-06-19 00:35:54' AND '2012-07-29 23:48:16'
AND WP.pageview_url IN ('/home','/lander-1')
GROUP BY 1;
-- 0.0318 conversion rate for home, 0.0406 conversion rate for lander-1, 0.0088 extra orders per session for lander-1
-

-- counting sessions we've had since this session
SELECT COUNT(DISTINCT(website_session_id)) total_sessions
FROM website_sessions
WHERE created_at> '2012-07-29 23:48:16'
AND created_at < '2012-11-27'
AND utm_source = 'gsearch'
AND utm_campaign = 'nonbrand';
/*22972 sessions since rerouting 
incremental rate was 0.0088 for lander-1. 
(22972 session)*0.0088(order/session) = 202 extra/incremental orders since 29 July
roughly 50 incremental orders per month*/



/*Q.5 Pull quarterly trends for sessions to order conversion rate, revenue per session, revenue per order
since the launch of business */

SELECT
	 Year(WS.created_at) yr,
	 QUARTER(WS.created_at) quarter,
     COUNT(DISTINCT(Dayofyear(WS.created_at))) days_in_quarter,
     COUNT(DISTINCT(WS.website_session_id)) sessions,
     COUNT(DISTINCT(O.order_id)) orders,
     COUNT(DISTINCT(O.order_id))/  COUNT(DISTINCT(WS.website_session_id)) session_to_order_cnv_rt,
     SUM(O.price_usd)/COUNT(DISTINCT(O.order_id)) revenue_per_order,
     SUM(O.price_usd)/COUNT(DISTINCT(WS.website_session_id))  revenue_per_session
FROM website_sessions WS
LEFT JOIN orders O 
ON O.website_session_id = WS.website_session_id
GROUP BY 1,2; 



/*Q.6 Pull quarterly trend of orders to show how each of the channels have grown over time. Evaluate session to order conversion rate for each channel.
Make note of any seasonality trend*/

-- first getting quarterly trend of orders
SELECT YEAR(WS.created_at) Year,
	   QUARTER(WS.created_at) quarter, 
	   COUNT(DISTINCT(Dayofyear(WS.created_at))) days_in_quarter,
       COUNT(DISTINCT(orders.order_id)) orders,
       COUNT(DISTINCT(CASE WHEN WS.utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)) gsearch_nonbrand_orders,
       COUNT(DISTINCT(CASE WHEN WS.utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)) bsearch_nonbrand_orders,
       COUNT(DISTINCT(CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END)) brand_orders,
       COUNT(DISTINCT(CASE WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN orders.order_id ELSE NULL END)) organic_orders,
       COUNT(DISTINCT(CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END)) direct_typein_orders
       
FROM website_sessions WS
LEFT JOIN orders 
ON WS.website_session_id = orders.website_session_id 
GROUP BY 1,2;
-- Most orders coming through gsearch. Orders coming through Organic and Directtype in have also grwon significatnly

-- Getting session to order conversion rate
SELECT 
	Year(WS.created_at) yr,
	QUARTER(WS.created_at) quarter,
	COUNT(DISTINCT(Dayofyear(WS.created_at))) days_in_quarter,
    
    COUNT(DISTINCT(CASE WHEN WS.utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN O.order_id ELSE NULL END))
    /COUNT(DISTINCT(CASE WHEN WS.utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN WS.website_session_id ELSE NULL END)) g_nonbrand_ssn_order_cnv_rt,
   
    COUNT(DISTINCT(CASE WHEN WS.utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN O.order_id ELSE NULL END))
    /COUNT(DISTINCT(CASE WHEN WS.utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN WS.website_session_id ELSE NULL END)) b_nonbrand_ssn_order_cnv_rt,
    
    COUNT(DISTINCT(CASE WHEN utm_campaign = 'brand' THEN O.order_id ELSE NULL END))
    /COUNT(DISTINCT(CASE WHEN utm_campaign = 'brand' THEN WS.website_session_id ELSE NULL END)) brand_ssn_order_cnv_rt,
   
    COUNT(DISTINCT(CASE WHEN WS.utm_source IS NULL  AND http_referer IS NOT NULL THEN O.order_id ELSE NULL END))
    /COUNT(DISTINCT(CASE WHEN WS.utm_source IS NULL  AND http_referer IS NOT NULL THEN WS.website_session_id ELSE NULL END)) organic_ssn_order_cnv_rt,
    
    COUNT(DISTINCT(CASE WHEN WS.utm_source IS NULL  AND http_referer IS NULL THEN O.order_id ELSE NULL END))
    /COUNT(DISTINCT(CASE WHEN WS.utm_source IS NULL  AND http_referer IS  NULL THEN WS.website_session_id ELSE NULL END)) direct_typein_ssn_order_cnv_rt
FROM website_sessions WS
LEFT JOIN orders O
ON WS.website_session_id = O.website_session_id
GROUP BY 1,2;



/* Q.7 Pull monthly trend of revenue and profit margin product wise. Notice seaonality trend */

WITH cte1 AS(SELECT YEAR(orders.created_at) Year,
	   MONTH(orders.created_at) Mon,
       
       SUM(CASE WHEN product_id = 1 THEN order_items.price_USD ELSE NULL END) product1_revenue,
       SUM(CASE WHEN product_id = 1 THEN order_items.price_USD ELSE NULL END)- SUM(CASE WHEN product_id = 1 THEN order_items.cogs_usd ELSE NULL END) product1_margin,
       
       SUM(CASE WHEN product_id = 2 THEN order_items.price_USD ELSE NULL END) product2_revenue,
       SUM(CASE WHEN product_id = 2 THEN order_items.price_USD ELSE NULL END)- SUM(CASE WHEN product_id = 2 THEN order_items.cogs_usd ELSE NULL END) product2_margin,
       
       SUM(CASE WHEN product_id = 3 THEN order_items.price_USD ELSE NULL END) product3_revenue,
       SUM(CASE WHEN product_id = 3 THEN order_items.price_USD ELSE NULL END)- SUM(CASE WHEN product_id = 3 THEN order_items.cogs_usd ELSE NULL END) product3_margin,
       
       SUM(CASE WHEN product_id = 4 THEN order_items.price_USD ELSE NULL END) product4_revenue,
       SUM(CASE WHEN product_id = 4 THEN order_items.price_USD ELSE NULL END)- SUM(CASE WHEN product_id = 4 THEN order_items.cogs_usd ELSE NULL END) product4_margin

FROM orders
INNER JOIN order_items 
ON order_items.order_id = orders.order_id
GROUP BY 1,2),

cte2 AS(SELECT
		YEAR(orders.created_at) Year,
	    MONTH(orders.created_at) Month,
		SUM(orders.items_purchased) total_sales,
        SUM(orders.price_usd) total_revenue
FROM orders
GROUP BY 1,2)

SELECT cte1.Year,
		cte1.Mon,
        cte2.total_sales,
        cte2.total_revenue,
        cte1.product1_revenue,
		cte1.product1_margin,
        cte1.product2_revenue,
		cte1.product2_margin,
        cte1.product3_revenue,
		cte1.product3_margin,
        cte1.product4_revenue,
		cte1.product4_margin
        
FROM cte1
INNER JOIN cte2 
ON cte2.Month = cte1.Mon
AND cte2.Year = cte1.Year;
/* -- seasonality trends coudld be found for following months of years :
 2012/11, 2012/12, 2013/3, 2013/11, 2013/12, 2014/11, 2014/12
need to dig deep into these specific months to get specific week of month and day of week we can see spike up/dpwm and try looking at cause/effect
and be prepared with staffs.inventory */




/* Q.8 Analyze the impact of introducing new products. Pull monthly trend of sessions landing on product page,
clickthrough rates of product page & order conversion rate*/

SELECT  YEAR(WP.created_at) Year,
		MONTH(WP.created_at) Mon,
		COUNT(DISTINCT(WP.website_session_id)) sessions, 
        
		COUNT(DISTINCT(CASE WHEN WP.pageview_url = '/products' THEN WP.website_session_id ELSE NULL END)) AS to_products,
        COUNT(DISTINCT(CASE WHEN WP.pageview_url IN ('/the-original-mr-fuzzy','/the-forever-love-bear','/the-birthday-sugar-panda','/the-hudson-river-mini-bear') THEN WP.website_session_id ELSE NULL END)) to_next_page,
        COUNT(DISTINCT(CASE WHEN WP.pageview_url IN ('/the-original-mr-fuzzy','/the-forever-love-bear','/the-birthday-sugar-panda','/the-hudson-river-mini-bear') THEN WP.website_session_id ELSE NULL END))/
        COUNT(DISTINCT(CASE WHEN WP.pageview_url = '/products' THEN WP.website_session_id ELSE NULL END)) clickthough_products,
        
       COUNT(DISTINCT(CASE WHEN WP.pageview_url = '/products' THEN orders.order_id ELSE NULL END))  orders_placed,
         COUNT(DISTINCT(CASE WHEN WP.pageview_url = '/products' THEN orders.order_id ELSE NULL END))/COUNT(DISTINCT(CASE WHEN WP.pageview_url = '/products' THEN WP.website_session_id ELSE NULL END)) product_to_order_cnv_rt
FROM website_pageviews WP
LEFT JOIN orders 
ON orders.website_session_id = WP.website_session_id
GROUP BY 1,2;




/* Q.9 Cross sell analysis : 4th product is available to be purchased as primary product since 5th DEC 2014
(previously only cross sold item). Since 5th dec 2014, show how well each product cross sells with one other*/

WIth cte AS(
SELECT 
	O.order_id,
    O.items_purchased,
    O.primary_product_id,
    OI.product_id AS X_sell_product
FROM orders O
INNER JOIN order_items OI
ON OI.order_id = O.order_id
WHERE O.created_at > '2014-12-05'
AND OI.is_primary_item =0)

SELECT primary_product_id,
		 COUNT(DISTINCT(order_id)) total_orders,
	 COUNT(DISTINCT( CASE WHEN X_sell_product = 1 THEN order_id ELSE NULL END)) product1_x_sold,
      COUNT(DISTINCT(CASE WHEN X_sell_product = 2 THEN order_id ELSE NULL END)) product2_x_sold,
      COUNT(DISTINCT(CASE WHEN X_sell_product = 3 THEN order_id ELSE NULL END)) product3_x_sold,
      COUNT(DISTINCT(CASE WHEN X_sell_product = 4 THEN order_id ELSE NULL END)) product4_x_sold
FROM cte
GROUP BY 1;
-- product 4 is cross sold max with each product

