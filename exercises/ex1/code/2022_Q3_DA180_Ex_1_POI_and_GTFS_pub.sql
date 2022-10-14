/******************************************************************/
-- Exercise 1 - Loading and visualizing a public transportation network
/******************************************************************/

/******************************************************************/
-- Exercise 1.1 - Importing Points of Interest from OpenStreetMaps and General Transit Feed Specification data
/******************************************************************/

/*********************************/
-- POIs
-- OSM POI data is pulled from the overpass API and stored in a HANA collection/table using python

/*********************************/

-- Check the POIs which we imported using python, optionally in DBX
SELECT * FROM "TECHED_USER_000"."POI_COLLECTION_SMALL";
SELECT * FROM "TECHED_USER_000"."POIS_SMALL";
SELECT "tags.amenity", COUNT(*) AS C FROM "TECHED_USER_000"."POIS_SMALL" GROUP BY "tags.amenity" ORDER BY C DESC;

-- For the exercises, we will use a larger set of POI data
-- We'll copy this data from the "RAW_DATA" schema
CREATE TABLE "TECHED_USER_000"."POIS" LIKE "RAW_DATA"."POIS" WITH DATA;
-- Let's add a column to store the point geometry in a projected spatial reference system which is suitable for Australia data
	ALTER TABLE "TECHED_USER_000"."POIS" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE "TECHED_USER_000"."POIS" SET "SHAPE_28354" = "lon_lat_GEO".ST_TRANSFORM(28354);



/*********************************/
-- GTFS data
-- GTFS is a data specification for public transport schedules
-- There is a catalog of GTFS dataset at https://github.com/MobilityData/mobility-database-catalogs
-- The records for data_type=gtfs-rt indicate how to get real-time information for vehicle positions (vp), trip updates (tu), and service alerts (sa).

SELECT "data_type", "location.country_code", "location.subdivision_name", "location.municipality", "urls.direct_download", "urls.latest", "features", "status", 
	"urls.authentication_type", "urls.api_key_parameter_name", st_geomfromwkt('LINESTRING('||"location.bounding_box.minimum_longitude"||' '||"location.bounding_box.minimum_latitude"||','||"location.bounding_box.maximum_longitude"||' '||"location.bounding_box.maximum_latitude"||')', 4326).st_transform(28354).ST_envelope()
	FROM "RAW_DATA"."GTFS_SOURCES"
	WHERE ("status" != 'inactive' OR "status" IS NULL) --AND "data_type" = 'gtfs-rt'
	ORDER BY "location.country_code", "location.subdivision_name", "location.municipality";



/******************************************************************/
-- Exercise 1.2 - Understanding the GTFS datamodel
/******************************************************************/
-- !! either use the Jupyter Notebook to import the GTFS data files
-- or copy the tables from RAW_DATA schema !!
CREATE TABLE "TECHED_USER_000"."GTFS_ROUTES" LIKE "RAW_DATA"."GTFS_ROUTES" WITH DATA;
CREATE TABLE "TECHED_USER_000"."GTFS_SHAPES" LIKE "RAW_DATA"."GTFS_SHAPES" WITH DATA;
CREATE TABLE "TECHED_USER_000"."GTFS_STOPS" LIKE "RAW_DATA"."GTFS_STOPS" WITH DATA;
CREATE TABLE "TECHED_USER_000"."GTFS_STOPTIMES" LIKE "RAW_DATA"."GTFS_STOPTIMES" WITH DATA;
CREATE TABLE "TECHED_USER_000"."GTFS_TRIPS" LIKE "RAW_DATA"."GTFS_TRIPS" WITH DATA;

-- The ROUTE table is masterdata
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_ROUTES";
SELECT * FROM "TECHED_USER_000"."GTFS_ROUTES";

-- The STOPS have geolocations
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_STOPS";
SELECT * FROM "TECHED_USER_000"."GTFS_STOPS";
	ALTER TABLE "TECHED_USER_000"."GTFS_STOPS" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE "TECHED_USER_000"."GTFS_STOPS" SET "SHAPE_28354" = "stop_lon_stop_lat_GEO".ST_TRANSFORM(28354);

-- A specific TRIP runs on a ROUTE and its shape is defined by records in the SHAPES table
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_TRIPS";
SELECT * FROM "TECHED_USER_000"."GTFS_TRIPS";

-- The SHAPES table is an ordered set of points which make up the TRIP
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_SHAPES";
SELECT * FROM "TECHED_USER_000"."GTFS_SHAPES" ORDER BY "shape_id", "shape_pt_sequence";
	ALTER TABLE "TECHED_USER_000"."GTFS_SHAPES" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE "TECHED_USER_000"."GTFS_SHAPES" SET "SHAPE_28354" = "shape_pt_lon_shape_pt_lat_GEO".ST_TRANSFORM(28354);

-- STOPTIMES indicate when a TRIP stops at a STOP
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_STOPTIMES";
SELECT * FROM "TECHED_USER_000"."GTFS_STOPTIMES" ORDER BY "trip_id", "stop_sequence";


/*********************************/
-- A TRIP relates to SHAPE, and STOPS (via STOPTIMES).
-- This query shows the set of STOPS for a TRIP
SELECT TRI."trip_id", ST_UNIONAGGR(STO."SHAPE_28354") AS LINE_OF_STOPS 
	FROM "TECHED_USER_000"."GTFS_TRIPS" AS TRI, "TECHED_USER_000"."GTFS_STOPTIMES" AS ST, "TECHED_USER_000"."GTFS_STOPS" AS STO
	WHERE TRI."trip_id" = ST."trip_id" AND ST."stop_id" = STO."stop_id"
		AND TRI."trip_id" = 606101
	GROUP BY TRI."trip_id";

-- This query show the set of SHAPEs for a TRIP, describing the path of the vehicle in detail
SELECT TRI."trip_id", ST_UNIONAGGR(SHA."SHAPE_28354") AS LINE_OF_SHAPES 
	FROM "TECHED_USER_000"."GTFS_TRIPS" AS TRI, "TECHED_USER_000"."GTFS_SHAPES" AS SHA
	WHERE TRI."shape_id" = SHA."shape_id"
		AND TRI."trip_id" = 606101
	GROUP BY TRI."trip_id";


/*********************************/
-- For better visualization, we will create a linestring from the ordered set of points
-- Create an empty table first
CREATE COLUMN TABLE "TECHED_USER_000"."GTFS_SHAPE_LINES"(
	"shape_id" NVARCHAR(5000) PRIMARY KEY, 
	"SHAPE_28354" ST_GEOMETRY(28354)
);

INSERT INTO "TECHED_USER_000"."GTFS_SHAPE_LINES"("shape_id", "SHAPE_28354")
	SELECT "shape_id", ST_GEOMFROMTEXT('LINESTRING(' || string_agg(PAIRS, ',' ORDER BY "shape_pt_sequence") || ')', 4326).ST_TRANSFORM(28354) FROM
		(SELECT "shape_id", "shape_pt_sequence" , ("shape_pt_lon" ||' '|| "shape_pt_lat") AS PAIRS FROM "TECHED_USER_000"."GTFS_SHAPES")
	GROUP BY "shape_id";

SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_SHAPE_LINES";
SELECT * FROM "TECHED_USER_000"."GTFS_SHAPE_LINES" LIMIT 5;


/*********************************/
-- Joining the SHAPE_LINES to the TRIPS to understand the path of each TRIP
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_TRIP_LINES" AS (
	SELECT TRI."trip_id", TRI."route_id", SHALIN."SHAPE_28354" 
	FROM "TECHED_USER_000"."GTFS_TRIPS" AS TRI
	INNER JOIN "TECHED_USER_000"."GTFS_SHAPE_LINES" AS SHALIN ON TRI."shape_id" = SHALIN."shape_id" 
);
SELECT * FROM "TECHED_USER_000"."V_TRIP_LINES";


/*********************************/
-- There are multiple TRIPs running on a ROUTE
SELECT ROU."route_id", COUNT(*) AS "NUM_TRIPS" 
	FROM "TECHED_USER_000"."GTFS_ROUTES" AS ROU 
	LEFT JOIN "TECHED_USER_000"."GTFS_TRIPS" AS TRI ON ROU."route_id" = TRI."route_id" 
	GROUP BY ROU."route_id"
	ORDER BY "NUM_TRIPS" DESC;


/*********************************/
-- Generating ROUTE "lines" - let's take the longest of it's TRIPs
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_ROUTE_LINES" AS
SELECT "route_id", "SHAPE_28354" FROM (	
	SELECT *, RANK() OVER(PARTITION BY "route_id" ORDER BY NP DESC) AS R FROM 
		(SELECT DISTINCT "route_id", SHAPE_28354, SHAPE_28354.ST_NumPoints() AS NP FROM "TECHED_USER_000"."V_TRIP_LINES")
	) 
	WHERE R = 1; 

SELECT * FROM "TECHED_USER_000"."V_ROUTE_LINES";


/*********************************/
-- Cleansing... STOPTIMES with "wrong" times
ALTER TABLE "TECHED_USER_000"."GTFS_STOPTIMES" ADD ("arr_time" TIME, "dep_time" TIME);
UPDATE "TECHED_USER_000"."GTFS_STOPTIMES" SET "arr_time" = TO_TIME("arrival_time") WHERE "arrival_time" <= '24:00:00';
UPDATE "TECHED_USER_000"."GTFS_STOPTIMES" SET "dep_time" = TO_TIME("departure_time") WHERE "departure_time" <= '24:00:00';



/******************************************************************/
-- Exercise 1.3 - Polling for real-time vehicle positions
/******************************************************************/

/*********************************/	
-- Realtime vehicle positions are stored in LOC_RT (overwrite) and LOC_RT_HISTORY (append)
SELECT COUNT(*) FROM TECHED_USER_000.LOC_RT;
SELECT * FROM TECHED_USER_000.LOC_RT ORDER BY "vehicle.timestamp" DESC;
SELECT COUNT(*) FROM TECHED_USER_000.LOC_RT_HISTORY;

-- create a view for AGE calculation to show a nice symbology in QGIS
CREATE OR REPLACE VIEW TECHED_USER_000."V_LOC_RT" AS (
	SELECT *, SECONDS_BETWEEN("vehicle.timestamp", NOW()) AS "AGE" FROM TECHED_USER_000."LOC_RT"
);

CREATE OR REPLACE VIEW TECHED_USER_000."V_LOC_RT_HISTORY" AS (
	SELECT *, SECONDS_BETWEEN("vehicle.timestamp", NOW()) AS "AGE" FROM TECHED_USER_000."LOC_RT_HISTORY"
);


-- Check if vehicles or "on track", i.e. close to their route, using a distance calculation
SELECT * FROM (
	SELECT "id", "vehicle.trip.trip_id" AS "trip_id", "vehicle.trip.route_id" AS "route_id", "vehicle.position.longitude_vehicle.position.latitude_GEO" AS "LOC_4326",
		LOC."vehicle.timestamp",
		TRI."SHAPE_28354", "vehicle.position.longitude_vehicle.position.latitude_GEO".ST_TRANSFORM(28354).ST_DISTANCE(TRI."SHAPE_28354") AS "DIST"
	FROM TECHED_USER_000."LOC_RT" AS LOC
	LEFT JOIN TECHED_USER_000."V_TRIP_LINES" AS TRI ON LOC."vehicle.trip.trip_id" = TRI."trip_id"
) ORDER BY DIST DESC;
	
	