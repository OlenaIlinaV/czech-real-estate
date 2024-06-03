
select count(*)
from "dataset-items" -- Initial table
where "createdAt" >= '2019-01-01'-- 3.6 ml rows (total 4.8 ml)
;-- 3 559 696

-- Convert all NULL values to '0' 

UPDATE "dataset-items" set "data_priceTotal" = IFNULL(try_to_decimal("data_priceTotal"),0) -- 4 817 733 updated rows


-- Creating a table with necessary fields

CREATE OR REPLACE TABLE main_table AS
WITH CorrectedData AS (
    SELECT
        "id" AS "Id",
        "createdAt"::DATE AS "Date", -- date of posting (we are interested since 2019)
        "data_title" AS "Title",
        "data_description" AS "Description", -- description from the landlord / seller
        "data_arrangement" AS "Arrangement",
        "data_offerType" AS "offerType", -- rent/sale
        "data_type" AS "propertyType", -- property type - house/flat
        TRY_TO_DECIMAL("data_priceTotal") AS "Price", -- price
        "data_priceCurrency" AS "Currency", -- currency
        TRY_TO_DECIMAL("data_livingArea") AS "livingArea",
        SPLIT_PART(SPLIT_PART("data_url", '/', 3), '.', 2) AS "Source",
        "googleGeometry_location_coordinates_0" AS "Longitude",
        "googleGeometry_location_coordinates_1" AS "Latitude",
        "data_address" AS "Address",
        "data_city" AS "City",
        COALESCE(NULLIF(TRIM("data_district"), ''), "data_city") AS "District"
        
    FROM
        "dataset-items"
    WHERE "createdAt" >= '2019-01-01'
        AND (
            ("data_offerType" = 'rent' AND TRY_TO_DECIMAL("data_priceTotal") >= 4000)
            OR ("data_offerType" = 'sale' AND TRY_TO_DECIMAL("data_priceTotal") >= 2000000)
        )
        AND "data_offerType" != 'auction'
        AND "data_type" NOT IN ('commercial', 'land', 'other') -- 'other' - like garages
        AND ("data_description" NOT ILIKE '%Pronájem pokoj%' -- exclude room rentals
            AND "data_description" NOT ILIKE '%Pronájem, Pokoj%'
            AND "data_description" NOT ILIKE '%Pronájem,Pokoj%'
            AND "data_description" NOT ILIKE '%Pronájem - Pokoj%'  
            AND "data_description" NOT ILIKE '%pokoj%')
)
SELECT *,   
    CASE
        WHEN "District" IN ('Praha', 'Hlavní město Praha') OR "Address" ILIKE '%praha%' OR "Address" ILIKE '%hlavní%' THEN 'Hlavní město Praha'
        WHEN "District" IN ('Benešov', 'Beroun', 'Kladno', 'Kolín', 'Kutná Hora', 'Mělník', 'Mladá Boleslav', 'Nymburk', 'Praha-východ', 'Praha-západ', 'Příbram', 'Rakovník') OR "Address" ILIKE '%Středoč%' OR "Address" ILIKE '%Kladno%' THEN 'Středočeský kraj'
        WHEN "District" IN ('České Budějovice', 'Český Krumlov', 'Tábor', 'Písek', 'Strakonice', 'Prachatice', 'Jindřichův Hradec') OR "Address" ILIKE '%Jihočeský%' THEN 'Jihočeský kraj'
        WHEN "District" IN ('Plzeň', 'Plzeň-město', 'Plzeň-jih', 'Plzeň-sever', 'Klatovy', 'Domažlice', 'Tachov', 'Rokycany') OR "Address" ILIKE '%Plzeň%' THEN 'Plzeňský kraj'
        WHEN "District" IN ('Karlovy Vary', 'Cheb', 'Sokolov') OR "Address" ILIKE '%Karlovarský%' THEN 'Karlovarský kraj'
        WHEN "District" IN ('Ústí nad Labem', 'Chomutov', 'Teplice', 'Děčín', 'Litoměřice', 'Louny', 'Most') OR "Address" ILIKE '%Ústecký%' OR "Address" ILIKE '%Teplice%' THEN 'Ústecký kraj'
        WHEN "District" IN ('Liberec', 'Jablonec nad Nisou', 'Česká Lípa', 'Semily') OR "Address" ILIKE '%Liberecký%' THEN 'Liberecký kraj'
        WHEN "District" IN ('Hradec Králové', 'Rychnov nad Kněžnou', 'Náchod', 'Jičín', 'Trutnov') OR "Address" ILIKE '%Královéhradecký%' THEN 'Královéhradecký kraj'
        WHEN "District" IN ('Pardubice', 'Chrudim', 'Svitavy', 'Ústí nad Orlicí') OR "Address" ILIKE '%Pardubic%' THEN 'Pardubický kraj'
        WHEN "District" IN ('Jihlava', 'Havlíčkův Brod', 'Pelhřimov', 'Třebíč', 'Žďár nad Sázavou') OR "Address" ILIKE '%Vysočina%' THEN 'Kraj Vysočina'
        WHEN "District" IN ('Brno', 'Brno-město', 'Brno-venkov', 'Znojmo', 'Vyškov', 'Blansko', 'Břeclav', 'Hodonín') OR "Address" ILIKE '%Jihomoravský%' OR "Address" ILIKE '%Brno%' OR "Address" ILIKE '%Břeclav%' THEN 'Jihomoravský kraj'
        WHEN "District" IN ('Olomouc', 'Prostějov', 'Přerov', 'Šumperk', 'Jeseník') OR "Address" ILIKE '%Olomoucký%' THEN 'Olomoucký kraj'
        WHEN "District" IN ('Zlín', 'Uherské Hradiště', 'Kroměříž', 'Vsetín') OR "Address" ILIKE '%Zlínský%' THEN 'Zlínský kraj'
        WHEN "District" IN ('Ostrava', 'Ostrava-město', 'Opava', 'Karviná', 'Frýdek-Místek', 'Nový Jičín', 'Bruntál') OR "Address" ILIKE '%Moravskoslezský%' THEN 'Moravskoslezský kraj'
        ELSE 'Not recognized'
    END AS "Region"
FROM
    CorrectedData
WHERE
    "District" != '' AND "City" != '' AND "Region" != 'Not recognized'
;

select count(*)
from main_table
; -- 851 803

select *
from main_table
;


-- Duplicates

select * from (
    select 
      (coalesce("propertyType", '') || '-' || coalesce("offerType", '') || '-' || coalesce("livingArea"::varchar, '') || '-' || coalesce("Price"::varchar, '') || '-' || YEAR("Date") || '-' || coalesce("City", '') || '-' || coalesce("District", '') || '-' || coalesce("Region", '') || '-' || coalesce("Title", '') ) as calculated,
      row_number() over (partition by calculated order by "Date" desc) as cc,
      *
    from main_table
) sub
where cc > 1
order by calculated, "Date" desc
;

-- 851,803


DELETE FROM main_table where "Id" in (
    select "Id" from (
        select 
          (coalesce("propertyType", '') || '-' || coalesce("offerType", '') || '-' || coalesce("livingArea"::varchar, '') || '-' || coalesce("Price"::varchar, '') || '-' || YEAR("Date") || '-' || coalesce("City", '') || '-' || coalesce("District", '') || '-' || coalesce("Region", '') || '-' || coalesce("Title", '') ) as calculated,
          row_number() over (partition by calculated order by "Date" desc) as cc,
          "Id"
        from main_table
    ) sub
    where cc > 1
)
; -- 251 996 rows


-- Add a new calculation column to the table (price per meter square)

ALTER TABLE main_table
ADD "PricePerM2" INT
;

SELECT *
FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 36 099


--  Replaces all non-breaking spaces (code 160 in the ASCII table, which corresponds to &nbsp; in HTML) with normal spaces.

UPDATE main_table
SET "Title" = REPLACE("Title", CHAR(160), ' '), "Description" = REPLACE("Description", CHAR(160), ' ')
; -- 599 807 rows


-- Find from "Title" and "Description" m² or m2

UPDATE main_table
SET "livingArea" = REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Title"), '(([^+]\\d+\\s)?\\d\\d+([.,]?\\d*)?)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 36 099 rows


UPDATE main_table
SET "livingArea" = REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 1 107

SELECT "Title",
       "livingArea", 
       "Description",
       "propertyType",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Title"), '(([^+]\\d+\\s)?\\d\\d+([.,]?\\d*)?)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d
FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0) AND "propertyType" = 'apartment'
order by extracted_area
;


DELETE FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 677 rows removed



-- Replace strange huge livingArea with lower from description > 350

SELECT "Title",
       "livingArea",
REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE "livingArea" > 350 AND extracted_area_d < "livingArea" and "propertyType" = 'apartment'
ORDER BY "livingArea"
;

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area
FROM (
    SELECT "Id",
        REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area
    FROM main_table
    WHERE "livingArea" > 350 AND "propertyType" = 'apartment' AND "livingArea" > extracted_area
) AS sub
WHERE mt."Id"= sub."Id" and mt."livingArea" > sub.extracted_area
; -- 279



-- Apartment's living area is not correct (1-10)

SELECT 
        "Id",
        "Title",
       "livingArea",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_first,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE "livingArea" <= 15 AND extracted_area_d > "livingArea" AND extracted_area_first != "livingArea" AND "propertyType" = 'apartment' AND "Id" <> '65d648b1d39528558e8acdd4'
ORDER BY "livingArea"
; -- 164

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area_d
FROM (
    SELECT "Id",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_first,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
    FROM main_table
    WHERE "livingArea" <= 15 AND extracted_area_d > "livingArea" AND extracted_area_first != "livingArea" AND "propertyType" = 'apartment' AND "Id" <> '65d648b1d39528558e8acdd4'
) AS sub
WHERE mt."Id"= sub."Id" and mt."livingArea" < sub.extracted_area_d
; -- 164


-- Replace strange huge livingArea with lower from description > 200

SELECT "Id","Title",
       "livingArea",
REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE 
    "livingArea" > 200 AND 
    extracted_area_d < "livingArea" and 
    "propertyType" = 'apartment' and (
        (
            (
                "Title" like '%4+kk%' OR "Title" like '%5+kk%' OR "Title" like '%6+kk%' OR 
                "Title" like '%4+1%' OR "Title" like '%5+1%' OR "Title" like '%6+1%' OR "Title" like '%6 pokojů%' OR "Title" like '%atypick%'
            ) and extracted_area_d > 70
        ) or (
            "Title" not like '%4+kk%' AND "Title" not like '%5+kk%' AND "Title" not like '%6+kk%' AND 
            "Title" not like '%4+1%' AND "Title" not like '%5+1%' AND "Title" not like '%6+1%' AND "Title" not like '%6 pokojů%' AND "Title" not like '%atypick%'
        )
    ) AND "Id" NOT IN ('reJCWDrBJwzznEL9f', 'oKeNYymRXfbG2aoBJ', '79iBqGSZAdhXBWfXw', 'nffKrmEGkduvJManz', 'o8J9p9e3RsDYWPtbe')
ORDER BY "livingArea"
;

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area_d
FROM (
    SELECT 
        "Id","Title",
       "livingArea",
        REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
    FROM main_table
    WHERE 
        "livingArea" > 200 AND 
        extracted_area_d < "livingArea" and 
        "propertyType" = 'apartment' and (
            (
                (
                    "Title" like '%4+kk%' OR "Title" like '%5+kk%' OR "Title" like '%6+kk%' OR 
                    "Title" like '%4+1%' OR "Title" like '%5+1%' OR "Title" like '%6+1%' OR "Title" like '%6 pokojů%' OR "Title" like '%atypick%'
                ) and extracted_area_d > 70
            ) or (
                "Title" not like '%4+kk%' AND "Title" not like '%5+kk%' AND "Title" not like '%6+kk%' AND 
                "Title" not like '%4+1%' AND "Title" not like '%5+1%' AND "Title" not like '%6+1%' AND "Title" not like '%6 pokojů%' AND "Title" not like '%atypick%'
            )
        ) AND "Id" NOT IN ('reJCWDrBJwzznEL9f', 'oKeNYymRXfbG2aoBJ', '79iBqGSZAdhXBWfXw', 'nffKrmEGkduvJManz', 'o8J9p9e3RsDYWPtbe')
) AS sub
WHERE mt."Id"= sub."Id" -- and mt."livingArea" > sub.extracted_area
; -- 417


-- Delete extreme values

select * from main_table
where "livingArea" <9
; -- 57

DELETE FROM main_table
WHERE "livingArea" < 9
; -- 57 rows



SELECT *
FROM main_table
WHERE "livingArea" > 370 AND "propertyType" = 'apartment'
order by "livingArea"
;

DELETE FROM main_table
WHERE "livingArea" > 370 AND "propertyType" = 'apartment'
; -- 184



UPDATE main_table
SET "PricePerM2" = "Price" / "livingArea"
; -- 599 140 rows

SELECT * FROM main_table
WHERE "propertyType" = 'apartment'
ORDER BY "PricePerM2"
;



-- Create a table with salaries from the statistics website

SELECT *
FROM "urad_data"
;

CREATE OR REPLACE TABLE salary_table AS

SELECT REPLACE("Kraj", '_', ' ') AS "Region",
    "sledovane_obdobi_mesicni_mzda" AS "AvrSalary", 
    SUBSTRING("rok", 5, 4) AS "Year"
FROM "urad_data"
WHERE "Kraj" IN (
    'Hlavní_město_Praha',
    'Středočeský_kraj',
    'Jihočeský_kraj',
    'Plzeňský_kraj',
    'Karlovarský_kraj',
    'Ústecký_kraj',
    'Liberecký_kraj',
    'Královéhradecký_kraj',
    'Pardubický_kraj',
    'Kraj_Vysočina',
    'Jihomoravský_kraj',
    'Olomoucký_kraj',
    'Zlínský_kraj',
    'Moravskoslezský_kraj')
--ORDER BY "Year"
;

SELECT *
FROM salary_table
;



-- Non-rental price

UPDATE main_table
SET "offerType" = 'sale'
WHERE "Id" = 'kAryahLNF5ACBxjaF'; -- price 25,000,000

UPDATE main_table
SET "offerType" = 'sale'
WHERE "Id" = '5EWoTzt3j5SnXpGKf'; -- price 4,490,000 "Date" = '2023-11-20'


DELETE FROM main_table
WHERE "Id" IN ('wF7s35EECinn4smmo', 'ABKuc2vnTRLqsXoxe', 'fXzC79BKZiWsfrEA4', 'yQfKfsmXu3nBE3Hnn') -- Karlovarský kraj
;

select * from main_table
where "Id" = 'fXzC79BKZiWsfrEA4'
;

select * from "dataset-items"
where "id" = 'rgMaofQEdLTfQFHcc'
;



select *
from main_table
where "propertyType" = 'apartment' AND "livingArea" > 300
order by "PricePerM2"
--order by "livingArea"
;

-- Point changes

UPDATE main_table
SET "livingArea" = '40'
WHERE "Id" = '5uGARajjf6hm3jGmH'
;

select *
from "dataset-items"
where "id" = 'd9Nhv3s3aG52k8Fdn'
;

select *
from main_table
where "Id" = 'hjAaua6RGJri99cuS'
;
