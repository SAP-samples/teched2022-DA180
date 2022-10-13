/*********************************/
-- Exercise 1 - Routing on a spatio-temporal Graph
-- 1.1 - Importing Points of Interest from OpenStreetMaps and General Transit Feed Specification data

/*********************************/
-- POIs
/*********************************/
-- OSM POI data is pulled from the overpass API and stored in a HANA collection/table using python

/*********************************/
-- CREATE PREDEFINED SPATIAL REFERENCE SYSTEM IDENTIFIED BY 28354;

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



/*********************************/
-- We have loaded a GTFS dataset for Adelaide using python
-- Let's inspect the GTFS data

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
SELECT * FROM "TECHED_USER_000"."GTFS_SHAPES"ORDER BY "shape_id", "shape_pt_sequence";
	ALTER TABLE "TECHED_USER_000"."GTFS_SHAPES" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE "TECHED_USER_000"."GTFS_SHAPES" SET "SHAPE_28354" = "shape_pt_lon_shape_pt_lat_GEO".ST_TRANSFORM(28354);

-- STOPTIMES indicate when a TRIP stops at a STOP
SELECT COUNT(*) FROM "TECHED_USER_000"."GTFS_STOPTIMES";
SELECT * FROM "TECHED_USER_000"."GTFS_STOPTIMES"ORDER BY "trip_id", "stop_sequence";


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
-- There are multiple TRIPs running on a ROUTE... makes sense
SELECT ROU."route_id", COUNT(*) AS "#TRIPS" 
	FROM "TECHED_USER_000"."GTFS_ROUTES" AS ROU 
	LEFT JOIN "TECHED_USER_000"."GTFS_TRIPS" AS TRI ON ROU."route_id" = TRI."route_id" 
	GROUP BY ROU."route_id"
	ORDER BY "#TRIPS" DESC;


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



/*************************************/
-- Now we want to build a graph in HANA which represents the transport network.
-- The graph's VERTICES are STOPS and POIS
-- The graph's EDGES are 
--	(1) transport connections along a TRIP's STOPTIMES, 
--	(2) walks between STOPS, and 
--	(3) walks between STOPS and POIs

-- Step 1 - create EDGES from TRIPS
--DROP TABLE "TECHED_USER_000"."EDGES";
CREATE COLUMN TABLE "TECHED_USER_000"."EDGES" AS (
	SELECT "trip_id" , "SOURCE", "dep_time", "TARGET", "arr_time", 'transport' AS "transfer_type" FROM (
		SELECT "trip_id", "stop_sequence", "dep_time", "stop_id" AS "SOURCE", 
			LEAD("arr_time") over (partition by "trip_id" order by "stop_sequence" ASC) as "arr_time",
			LEAD("stop_id") over (partition by "trip_id" order by "stop_sequence" ASC) as "TARGET"
			FROM "TECHED_USER_000"."GTFS_STOPTIMES"
		)
	WHERE "TARGET" IS NOT NULL AND "dep_time" IS NOT NULL AND "arr_time" IS NOT NULL 
);

ALTER TABLE "TECHED_USER_000"."EDGES" ADD ("ID" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY);
ALTER TABLE "TECHED_USER_000"."EDGES" ALTER ("SOURCE" BIGINT NOT NULL, "TARGET" BIGINT NOT NULL, "dep_time" TIME NULL);
ALTER TABLE "TECHED_USER_000"."EDGES" ADD ("dep_sec" INT GENERATED ALWAYS AS SECONDS_BETWEEN(TO_TIME('00:00:00'), "dep_time"));
ALTER TABLE "TECHED_USER_000"."EDGES" ADD ("arr_sec" INT GENERATED ALWAYS AS SECONDS_BETWEEN(TO_TIME('00:00:00'), "arr_time"));
ALTER TABLE "TECHED_USER_000"."EDGES" ADD ("diff_sec" INT);
ALTER TABLE "TECHED_USER_000"."EDGES" ADD ("distance" DOUBLE);
UPDATE "TECHED_USER_000"."EDGES" SET "diff_sec" = SECONDS_BETWEEN("dep_time", "arr_time");

SELECT COUNT(*) FROM "TECHED_USER_000"."EDGES";
SELECT * FROM "TECHED_USER_000"."EDGES" ORDER BY "trip_id", "dep_sec";

-- Step 2 - adding walk transfers from STOPS to STOPS
DO() BEGIN
	T_AllPairs = SELECT STO1."stop_id" AS "SOURCE", STO2."stop_id" AS "TARGET", STO1."SHAPE_28354".ST_DISTANCE(STO2."SHAPE_28354") AS "distance"
		FROM "TECHED_USER_000"."GTFS_STOPS" AS STO1
		INNER JOIN "TECHED_USER_000"."GTFS_STOPS" AS STO2 ON STO1."SHAPE_28354".ST_WITHINDISTANCE(STO2."SHAPE_28354", 500, 'meter') = 1;
	INSERT INTO "TECHED_USER_000"."EDGES"("SOURCE", "TARGET", "transfer_type", "diff_sec", "distance")
		SELECT "SOURCE", "TARGET", 'walk' AS "transfer_type", "distance"/1.2 AS "diff_sec", "distance" 
	 	FROM :T_AllPairs WHERE "SOURCE" != "TARGET";
END;

-- Step 3 - adding walk transfers from STOPS to POIS
DO() BEGIN
	T_AllPairs = SELECT STO."stop_id" AS "SOURCE", POI."id" AS "TARGET", STO."SHAPE_28354".ST_DISTANCE(POI."SHAPE_28354") AS "distance"
		FROM "TECHED_USER_000"."GTFS_STOPS" AS STO
		INNER JOIN "TECHED_USER_000"."POIS" AS POI ON STO."SHAPE_28354".ST_WITHINDISTANCE(POI."SHAPE_28354", 500, 'meter') = 1;
	INSERT INTO "TECHED_USER_000"."EDGES"("SOURCE", "TARGET", "transfer_type", "diff_sec", "distance")
		SELECT "SOURCE", "TARGET", 'walk' AS "transfer_type", "distance"/1.2 AS "diff_sec", "distance" 
	 	FROM :T_AllPairs WHERE "SOURCE" != "TARGET";
END;

SELECT * FROM "TECHED_USER_000"."EDGES" WHERE "transfer_type" = 'walk';
SELECT "transfer_type", COUNT(*) AS C FROM "TECHED_USER_000"."EDGES" GROUP BY "transfer_type";


-- Step 4 - creating the VERTICES from STOPS and POIS
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_VERTICES" AS (
	SELECT "stop_id" AS "ID", 'stop' AS "TYPE", 'stop' AS "POI_TYPE", "stop_name" AS "NAME", "SHAPE_28354" FROM "TECHED_USER_000".GTFS_STOPS
	UNION
	SELECT "id" AS "ID", 'poi' AS "TYPE", "tags.amenity" AS "POI_TYPE", "tags.name" AS "NAME", "SHAPE_28354" FROM "TECHED_USER_000".POIS
);
SELECT "TYPE", "POI_TYPE", COUNT(*) AS C FROM "TECHED_USER_000"."V_VERTICES" GROUP BY "TYPE", "POI_TYPE" ORDER BY C DESC;


/***************************************/
-- Create a GRAPH WORKSPACE from edges and vertices
CREATE OR REPLACE GRAPH WORKSPACE "TECHED_USER_000"."GRAPH_GTFS_POIS"
	EDGE TABLE "TECHED_USER_000"."EDGES"
		SOURCE COLUMN "SOURCE"
		TARGET COLUMN "TARGET"
		KEY COLUMN "ID"
	VERTEX TABLE "TECHED_USER_000"."V_VERTICES" 
		KEY COLUMN "ID";


/***************************************/
-- Finding shortest paths in the transportation network using the built-in Shortest_Path function.
-- The hardest part is to define an edge weight function:
	-- if we take a bus, it's departure time needs to be in the future and we probably need to wait
	-- but we can walk anytime
CREATE OR REPLACE FUNCTION "TECHED_USER_000"."F_SPOO_GTFS_POIS"(
	IN i_startVertex BIGINT, 		-- the ID of the start vertex, this is a STOP or a POI
	IN i_endVertex BIGINT, 			-- the ID of the end vertex
	IN i_startSec INT				-- the time at which the TRIP should start, in seconds from midnight. So 9*3600 is 9am
	)
RETURNS TABLE ("ID" BIGINT, "EDGE_ORDER" BIGINT, "transfer_type" NVARCHAR(9), "trip_id" INT, "dep_sec" INT, "SOURCE" BIGINT, "arr_sec" INT, "TARGET" BIGINT, "diff_sec" INT, "distance" DOUBLE)
LANGUAGE GRAPH READS SQL DATA AS
BEGIN
	GRAPH g = Graph("TECHED_USER_000", "GRAPH_GTFS_POIS");
	VERTEX v_start = Vertex(:g, :i_startVertex);
	VERTEX v_end = Vertex(:g, :i_endVertex);
	WeightedPath<INT> p = SHORTEST_PATH(:g, :v_start, :v_end,
		(EDGE e, INT current_path_sec)=> INT{ 
  			IF(:e."transfer_type" == 'transport' AND (:i_startSec + :current_path_sec) <= :e."dep_sec") { -- the edge is a transport and the depature is in the future
  				RETURN (:e."dep_sec" - (:i_startSec + :current_path_sec)) + :e."diff_sec"; -- return potential wait time plus traverse time
  			}
            ELSE { -- the edge is a walk between stops
            	IF(:e."transfer_type" == 'walk') { RETURN :e."diff_sec"; } -- its a transfer, i.e. you can walk any time
            	ELSE { END TRAVERSE; } --not a valid edge
            }
  		}, 'OUTGOING');	
	RETURN SELECT :e."ID", :EDGE_ORDER, :e."transfer_type", :e."trip_id", :e."dep_sec", :e."SOURCE", :e."arr_sec", :e."TARGET", :e."diff_sec", :e."distance" 
		FOREACH e IN Edges(:p) WITH ORDINALITY AS EDGE_ORDER;
END;

-- get some sample data
SELECT * FROM "TECHED_USER_000"."V_VERTICES" ORDER BY RAND();
-- call the function and join some data from better understanding
SELECT RES."transfer_type", ADD_SECONDS(TO_TIME('00:00:00'),RES."dep_sec") AS "departure_time", STOPOI1."NAME" AS "from", 
		ADD_SECONDS(TO_TIME('00:00:00'),RES."arr_sec") AS "arrival_time", STOPOI2."NAME" AS "to", STOPOI2."TYPE",RES."diff_sec", RES."distance", 
		STOPOI1."SHAPE_28354", STOPOI2."SHAPE_28354" 
	FROM "TECHED_USER_000"."F_SPOO_GTFS_POIS"(i_startVertex => 2994, i_endVertex => 2406703047, i_startSec => 20*3600) AS RES 
	LEFT JOIN "TECHED_USER_000"."V_VERTICES" AS STOPOI1 ON RES."SOURCE" = STOPOI1."ID"
	LEFT JOIN "TECHED_USER_000"."V_VERTICES" AS STOPOI2 ON RES."TARGET" = STOPOI2."ID"
	;
	


/***************************************/
-- Now we want to understand the travel time to each other vertex in the graph
-- The edge weight function is the same as above, but this time we use SHORTEST_PATHS_ONE_TO_ALL
CREATE OR REPLACE FUNCTION "TECHED_USER_000"."F_SPOA_GTFS_POIS"(
	IN i_startVertex BIGINT, 		-- the ID of the start vertex
	IN i_startSec INT 
	)
RETURNS TABLE ("stop_id" BIGINT, "SHAPE_28354" ST_GEOMETRY(28354), "TRAVEL_TIME" INT)
LANGUAGE GRAPH READS SQL DATA AS
BEGIN
	GRAPH g = Graph("TECHED_USER_000", "GRAPH_GTFS_POIS");
	VERTEX v_start = Vertex(:g, :i_startVertex);
	GRAPH g_spoa = SHORTEST_PATHS_ONE_TO_ALL(:g, :v_start, "TRAVEL_TIME", 
		(EDGE e, INT current_path_sec)=> INT{ 
  			IF(:e."transfer_type" == 'transport' AND (:i_startSec + :current_path_sec) <= :e."dep_sec") {
  				RETURN (:e."dep_sec" - (:i_startSec + :current_path_sec)) + :e."diff_sec"; -- potenital wait time plus traverse time
  			}
            ELSE { 
            	IF(:e."transfer_type" == 'walk') { RETURN :e."diff_sec"; } -- its a transfer, i.e. you can walk any time
            	ELSE { END TRAVERSE; } --not a valid edge
            }
  		}, 'OUTGOING');
	RETURN SELECT :v."ID", :v."SHAPE_28354", :v."TRAVEL_TIME" FOREACH v IN Vertices(:g_spoa);
END;

-- We add spatial clustering to the results and wrap this function in a view so we can show the results in QGIS
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_ISO" AS (
	SELECT ST_ClusterID() AS "LOCATION_ID", ST_ClusterCell() AS "CLUSTER_CELL", AVG("TRAVEL_TIME") AS "AVG_TRAVEL_TIME" FROM (
		SELECT * FROM "TECHED_USER_000"."F_SPOA_GTFS_POIS"(2994, 8*3600) AS RES ORDER BY "TRAVEL_TIME" 
		)
		GROUP CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 60
);



/***************************************/
-- No what if we want to find the nearest pub?
-- We could use the SHORTEST_PATHS_ONE_TO_ALL as above, and filter the result.
-- But there is a better way: "hooking" into the shortest path traversal and inspecting the vertices as we discover them
-- This allows us to add some evaluation logic and to stop the execution once we found what we need.
CREATE OR REPLACE PROCEDURE "TECHED_USER_000"."F_TOP_K_NEAREST_POIS"(
	IN i_startVertex BIGINT, 
	IN i_startSec INT,
	IN i_poiType NVARCHAR(5000),	-- NULL will find any amenity/POI; possible values are 'pub' or 'clinic'
	IN i_k BIGINT,					-- indicates how many POIs ARE returned
	OUT o_vertices TABLE ("ID" BIGINT, "TYPE" NVARCHAR(5000), "POI_TYPE" NVARCHAR(5000), "NAME" NVARCHAR(5000), "TRAVEL_TIME" INT, "SHAPE_28354" ST_GEOMETRY(28354)),
	OUT o_paths TABLE ("DISCOVERED_POI" BIGINT, "transfer_type" NVARCHAR(5000), "SOURCE" BIGINT, "TARGET" BIGINT, "diff_sec" INT, "distance" DOUBLE)
	)
LANGUAGE GRAPH READS SQL DATA AS
BEGIN
	GRAPH g = Graph("TECHED_USER_000", "GRAPH_GTFS_POIS");
	VERTEX v_start = Vertex(:g, :i_startVertex);
	MAP<VERTEX, INT> m_travelTimeMap = MAP<VERTEX, INT>(:g, :i_k);
	TRAVERSERESULT<INT> shortest_path_tree = TRAVERSERESULT<INT>(:g);
	TRAVERSE DIJKSTRA :g FROM :v_start WITH RESULT :shortest_path_tree WITH WEIGHT (EDGE e, INT current_path_sec)=> INT{ 
  			IF(:e."transfer_type" == 'transport' AND (:i_startSec + :current_path_sec) <= :e."dep_sec") { -- the edge is a transport and the depature is in the future
  				RETURN (:e."dep_sec" - (:i_startSec + :current_path_sec)) + :e."diff_sec"; -- return potential wait time plus traverse time
  			}
            ELSE { -- the edge is a walk between stops
            	IF(:e."transfer_type" == 'walk') { RETURN :e."diff_sec"; } -- its a transfer, i.e. you can walk any time
            	ELSE { END TRAVERSE; } --not a valid edge
            }
  		}
		ON VISIT VERTEX (Vertex v_visited, INT travel_time) {
			IF ( :v_visited."TYPE" == 'poi' AND (:v_visited."POI_TYPE" == :i_poiType OR :i_poiType IS NULL) ) { -- check if POI
				m_travelTimeMap[:v_visited] = :travel_time; -- store vertex AND distance IN the map
				IF (COUNT(:m_travelTimeMap) >= :i_k) { END TRAVERSE ALL; } -- if we found what we need, let's stop the traversal
			}
		};
	o_vertices = SELECT :v_discoveredVertex."ID", :v_discoveredVertex."TYPE", :v_discoveredVertex."POI_TYPE", :v_discoveredVertex."NAME", :travel_time, :v_discoveredVertex."SHAPE_28354" 
		FOREACH (v_discoveredVertex, travel_time) IN :m_travelTimeMap;
	BIGINT idx = 1L;
	FOREACH (v_discoveredVertex, travel_time) IN :m_travelTimeMap {
    	WEIGHTEDPATH<INT> p = GET_PATH(:shortest_path_tree, :v_discoveredVertex);
    	FOREACH e IN Edges(:p) {
    		o_paths."DISCOVERED_POI"[:idx] = :v_discoveredVertex."ID";
    		o_paths."transfer_type"[:idx] = :e."transfer_type";
    		o_paths."SOURCE"[:idx] = :e."SOURCE";
    		o_paths."TARGET"[:idx] = :e."TARGET";
    		o_paths."diff_sec"[:idx] = :e."diff_sec";
    		o_paths."distance"[:idx] = :e."distance";
    		idx = :idx + 1L;
    	}
    }
END;

-- call the procedure and do some additional data transformation
DO(
	IN i_startVertex BIGINT => 2994,
	IN i_startSec INT => 20*3600,
	IN i_poiType NVARCHAR(5000) => 'pub',
	IN i_k BIGINT => 5
) BEGIN
	-- calling the procedure, the result is stored in o_vertices and o_paths
	CALL "TECHED_USER_000"."F_TOP_K_NEAREST_POIS" (:i_startVertex, :i_startSec, :i_poiType, :i_k, o_vertices, o_paths);
	
	-- adding some vertex information to the path's edges
	SELECT "DISCOVERED_POI", SUM("diff_sec") AS "NET_TRAVEL_TIME", ST_UnionAggr("LINE_28354") FROM ( 
		SELECT PAT."DISCOVERED_POI", "diff_sec", ST_MakeLine(SOU.SHAPE_28354, TAR.SHAPE_28354) AS "LINE_28354"
			FROM :o_paths AS PAT 
			LEFT JOIN "TECHED_USER_000"."V_VERTICES" AS SOU ON PAT."SOURCE" = SOU."ID" 
			LEFT JOIN "TECHED_USER_000"."V_VERTICES" AS TAR ON PAT."TARGET" = TAR."ID")
		GROUP BY "DISCOVERED_POI" ORDER BY "NET_TRAVEL_TIME" ASC;
	SELECT PAT.*, TAR."POI_TYPE", TAR."SHAPE_28354" 
		FROM :o_paths AS PAT 
		LEFT JOIN "TECHED_USER_000"."V_VERTICES" AS TAR ON PAT."TARGET" = TAR."ID" ;
	
	-- adding the start vertex to the nearest neighbors result  
	SELECT "ID", "TYPE", "POI_TYPE", "NAME", 0 AS "TRAVEL_TIME", "SHAPE_28354" 
		FROM TECHED_USER_000.V_VERTICES WHERE "ID" = :i_startVertex
		UNION 
		SELECT * FROM :o_vertices ORDER BY TRAVEL_TIME ASC;
END;




/***************************************/	
-- Realtime vehicle positions are store in LOC_RT (overwrite) and LOC_RT_HISTORY (append)
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
	




























	