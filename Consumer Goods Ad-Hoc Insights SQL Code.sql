-- CONSUMER GOODS AD-HOCH INSIGHTS - INSIGHTS TO MANAGEMENT OF ATLIQ HARDWARE

USE gdb023


/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region. */

SELECT DISTINCT(Market) 
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';



/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg */

WITH unique_products_count AS (
     SELECT COUNT(DISTINCT(product_code)) AS unique_products_2020, 
	        (SELECT COUNT(DISTINCT(product_code)) FROM fact_sales_monthly WHERE fiscal_year=2021) AS unique_products_2021
	 FROM fact_sales_monthly
	 WHERE fiscal_year=2020
	 )
SELECT unique_products_2020,unique_products_2021,CAST(((unique_products_2021-unique_products_2020)*100/unique_products_2020) 
       AS DECIMAL(10,2)) AS percentage_chg
FROM unique_products_count;



/* 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields,
segment
product_count */

SELECT Segment, COUNT(DISTINCT(product_code)) AS product_count 
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;



/* 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */

WITH up20 AS ( SELECT Segment, COUNT(DISTINCT(p.product_code)) AS product_count_2020 
	 FROM fact_sales_monthly AS ms
	 JOIN dim_product AS p 
	 ON p.product_code = ms.product_code
	 WHERE fiscal_year=2020
	 GROUP BY Segment
	 ),
up21 AS ( SELECT Segment, COUNT(DISTINCT(p.product_code)) AS product_count_2021 
	 FROM fact_sales_monthly AS ms
	 JOIN dim_product AS p 
	 ON p.product_code = ms.product_code
	 WHERE fiscal_year=2021
	 GROUP BY Segment
	 )
SELECT u1.Segment, product_count_2020,product_count_2021,(product_count_2021-product_count_2020) AS difference
FROM up20 AS u1
JOIN up21 AS u2
ON u1.Segment = u2.Segment
ORDER BY difference DESC;



/* 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,
product_code
product
manufacturing_cost */

SELECT m.product_code, product, manufacturing_cost
FROM fact_manufacturing_cost AS m
JOIN dim_product AS p
ON m.product_code=p.product_code
WHERE manufacturing_cost=(SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost) OR
      manufacturing_cost=(SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;



/* 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

SELECT TOP 5 c.customer_code, customer, CAST((AVG(pre_invoice_discount_pct)*100) AS DECIMAL(10,2)) AS average_discount_percentage
FROM dim_customer AS c
JOIN fact_pre_invoice_deductions AS d
ON c.customer_code = d.customer_code
WHERE market = 'India' AND fiscal_year = 2021
GROUP BY c.customer_code, customer
ORDER BY average_discount_percentage DESC;



/* 7.Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount */

SELECT CASE WHEN RIGHT(ms.date,2)=01 THEN 'January' 
            WHEN RIGHT(ms.date,2)=02 THEN 'February'
			WHEN RIGHT(ms.date,2)=03 THEN 'March'
			WHEN RIGHT(ms.date,2)=04 THEN 'April'
			WHEN RIGHT(ms.date,2)=05 THEN 'May'
			WHEN RIGHT(ms.date,2)=06 THEN 'June'
			WHEN RIGHT(ms.date,2)=07 THEN 'July'
			WHEN RIGHT(ms.date,2)=08 THEN 'August'
			WHEN RIGHT(ms.date,2)=09 THEN 'September'
			WHEN RIGHT(ms.date,2)=10 THEN 'October'
			WHEN RIGHT(ms.date,2)=11 THEN 'November'
			WHEN RIGHT(ms.date,2)=12 THEN 'December'
            END AS Month, 
            ms.fiscal_year AS Year ,CAST(SUM(ms.sold_quantity * g.gross_price)/1000000 AS DECIMAL(10,2)) AS 'Gross Sales Amount (mn)'
FROM dim_customer AS c
JOIN fact_sales_monthly AS ms ON c.customer_code=ms.customer_code
JOIN fact_gross_price AS g ON g.product_code=ms.product_code
WHERE customer='Atliq Exclusive' 
GROUP BY RIGHT(ms.date,2), ms.fiscal_year
ORDER BY ms.fiscal_year DESC, RIGHT(ms.date,2) ASC;

/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity -
Quarter
total_sold_quantity */

WITH Qtr AS (
    SELECT  CASE 
            WHEN RIGHT(date, 2) IN (09, 10, 11) THEN 'Q1'
            WHEN RIGHT(date, 2) IN (12, 01, 02) THEN 'Q2'
            WHEN RIGHT(date, 2) IN (03, 04, 05) THEN 'Q3'
            WHEN RIGHT(date, 2) IN (06, 07, 08) THEN 'Q4'
            END AS Quarter,
            sold_quantity
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
)
SELECT Quarter, CAST(SUM(sold_quantity)/1000000 AS DECIMAL(10,2)) AS total_sold_quantity_mn
FROM Qtr
GROUP BY Quarter
ORDER BY total_sold_quantity_mn DESC;



/* 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields-
channel
gross_sales_mln
percentage */

SELECT Channel, CAST(SUM(gp.gross_price*ms.sold_quantity)/1000000 AS DECIMAL(10,2)) AS gross_sales_mln,
       CAST((SUM(gp.gross_price*ms.sold_quantity)*100/(SELECT SUM(gp.gross_price*ms.sold_quantity) FROM fact_sales_monthly AS ms
	                                                   JOIN fact_gross_price AS gp ON gp.product_code=ms.product_code WHERE ms.fiscal_year=2021))
													   AS DECIMAL(10,2) )AS percentage
FROM dim_customer AS c
JOIN fact_sales_monthly AS ms ON ms.customer_code=c.customer_code
JOIN fact_gross_price AS gp ON gp.product_code=ms.product_code
WHERE ms.fiscal_year=2021
GROUP BY Channel;



/* 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields-
division
product_code
product
total_sold_quantity
rank_order */

WITH qty_sold AS(
     SELECT division, p.product_code, product, SUM(sold_quantity) AS total_sold_quantity
	 FROM dim_product AS p
     JOIN fact_sales_monthly AS ms
     ON ms.product_code=p.product_code
     WHERE ms.fiscal_year=2021 
     GROUP BY division,p.product_code, product
),
rnk AS(
    SELECT *, 
           DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM qty_sold
)
SELECT * FROM rnk WHERE rank_order<4
ORDER BY division ASC;





