/******************************************************************/
-- Exercise 3 - Import and export spatial vector and raster data, spatial clustering
/******************************************************************/

/******************************************************************/
-- Exercise 3.1 - Import and export spatial vector data
/******************************************************************/

/*******************************/
-- Landuse data from: 
-- https://data.sa.gov.au/data/dataset/land-use-generalised/resource/797444b1-633f-47ed-804d-fcbbeafca352

-- !! Either upload the zipped shapefile via HANA Database Explorer, the kml file via QGIS, and the world population via GDAL
-- or copy from RAW_DATA schema !!
CREATE TABLE "TECHED_USER_000"."LandUseGeneralised2021_GDA2020" LIKE "RAW_DATA"."LandUseGeneralised2021_GDA2020" WITH DATA;
CREATE TABLE "TECHED_USER_000"."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" LIKE "RAW_DATA"."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" WITH DATA;
CREATE TABLE "TECHED_USER_000"."WORLDPOP_ADELAIDE_POLYGONIZED" LIKE "RAW_DATA"."WORLDPOP_ADELAIDE_POLYGONIZED" WITH DATA;


SELECT COUNT(*) FROM "TECHED_USER_000"."LandUseGeneralised2021_GDA2020";
SELECT * FROM "TECHED_USER_000"."LandUseGeneralised2021_GDA2020";
SELECT "descriptio", COUNT(*) AS c, SUM("shape_area") AS AREA FROM TECHED_USER_000."LandUseGeneralised2021_GDA2020"
	GROUP BY "descriptio"
	ORDER BY AREA DESC;

-- Import wards .kml file via QGIS
SELECT COUNT(*) FROM TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020";
SELECT * FROM TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" LIMIT 5;
	ALTER TABLE TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" SET SHAPE_28354 = "geom".ST_TRANSFORM(28354);



/******************************************************************/
-- Exercise 3.2 - Convert raster data using GDAL
/******************************************************************/
/**************************/
-- Australia population density from 
-- https://hub.worldpop.org/geodata/summary?id=6297 or
-- https://saphanagcoe.maps.arcgis.com/home/item.html?id=8c2db10c952e45b68efdfc78f64267b0

/* GDAL commands

-- contour
gdal_contour -p -amin DN -i 10.0 "C:\raster\worldpop_adelaide.tif" "C:\data\raster\contour\worldpop_adelaide_contour.shp"

--polygonize
gdal_polygonize "C:\raster\worldpop_adelaide.tif" "C:\raster\polygonized\worldpop_adelaide_polygonized.shp"

-- upload to HANA
ogr2ogr -s_srs "+proj=latlong +datum=WGS84 +axis=neu +wktext" -t_srs "+proj=latlong +datum=WGS84 +axis=enu +wktext" -f "HANA" -nln WORLDPOP_ADELAIDE_POLYGONIZED -progress -preserve_fid HANA:"DRIVER=HDBODBC;HOST=[host];PORT=443;USER=[user];PASSWORD=[pwd];SCHEMA=TECHED_USER_000" C:\data\raster\polygonized\worldpop_adelaide_polygonized.shp"
 
*/
 
SELECT * FROM "TECHED_USER_000"."WORLDPOP_ADELAIDE_POLYGONIZED" ORDER BY DN DESC;
SELECT DN, COUNT(*) AS C FROM "TECHED_USER_000"."WORLDPOP_ADELAIDE_POLYGONIZED" GROUP BY DN ORDER BY C DESC;
	ALTER TABLE TECHED_USER_000."WORLDPOP_ADELAIDE_POLYGONIZED" ADD ("SHAPE_28354" ST_GEOMETRY(28354));
	UPDATE TECHED_USER_000."WORLDPOP_ADELAIDE_POLYGONIZED" SET SHAPE_28354 = "OGR_GEOMETRY".ST_SRID(4326).ST_TRANSFORM(28354);



/******************************************************************/
-- Exercise 3.2 - Spatial clustering
/******************************************************************/

/*************************************/
-- Fixed location clustering
-- Count POIs per Ward
SELECT WAR."ward", COUNT(*) AS "NUM_POIS"
	FROM TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" AS WAR
	LEFT JOIN TECHED_USER_000.POIS AS POI ON POI.SHAPE_28354.ST_WITHIN(WAR.SHAPE_28354) = 1
	GROUP BY WAR."ward"
	ORDER BY "NUM_POIS" DESC;

-- Additional GROUP BY attribute: amenity
SELECT WAR."ward", POI."tags.amenity", COUNT(*) AS "NUM_POIS"
	FROM TECHED_USER_000."Wards_GDA2020 — LocalGovernmentAreaWards_GDA2020" AS WAR
	LEFT JOIN TECHED_USER_000.POIS AS POI ON POI.SHAPE_28354.ST_WITHIN(WAR.SHAPE_28354) = 1
	GROUP BY WAR."ward", POI."tags.amenity"
	ORDER BY WAR."ward", "NUM_POIS" DESC;

/*************************************/
-- Hex/Grid clustering
SELECT ST_ClusterID() AS "LOCATION_ID", ST_ClusterCell() AS "CCELL", COUNT(*) AS "NUM_POIS"
	FROM TECHED_USER_000."POIS" 
	GROUP CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 40;

-- Additional GROUP BY attribute: amenity
SELECT "CID", "CCELL", "tags.amenity", COUNT(*) AS "NUM_POIS" FROM (
	SELECT "id", "tags.amenity", 
		ST_ClusterId() OVER (CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 40) "CID",
		ST_ClusterCell() OVER (CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 40) AS "CCELL"
		FROM TECHED_USER_000."POIS"
	)
	GROUP BY "CID", "CCELL", "tags.amenity"
	ORDER BY "NUM_POIS" DESC;

-- different aggregations
SELECT "CID", "CCELL", STRING_AGG("tags.amenity"||':'||"NUM_POIS", ',' ORDER BY "NUM_POIS" DESC) FROM (
		SELECT "CID", "CCELL", "tags.amenity", COUNT(*) AS "NUM_POIS" FROM (
			SELECT "id", "tags.amenity", 
				ST_ClusterId() OVER (CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 40) "CID",
				ST_ClusterCell() OVER (CLUSTER BY "SHAPE_28354" USING HEXAGON X CELLS 40) AS "CCELL"
				FROM TECHED_USER_000."POIS"
			)
			GROUP BY "CID", "CCELL", "tags.amenity"
	)
	GROUP BY "CID", "CCELL"
;

/*************************************/
-- How about clustering non-POINT geometries? Let's cluster the number of TRIPS per HEX cell.
-- Grid generator:
SELECT "I"||'#'||"J" AS "LOCATION_ID", "GEOM" AS "CCELL"
		FROM ST_HexagonGrid(2000, 'HORIZONTAL',	ST_GeomFromEWKT('SRID=4326;LINESTRING(138.40561 -35.35189, 139.06481 -34.58470)').ST_TRANSFORM(28354));

-- Joining the GRIDS to LINESTRINGS using intersects:
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_HEX_GRID_TRIPS" AS 
SELECT "LOCATION_ID", "CCELL", COUNT(*) AS "NUM_TRIPS", COUNT(DISTINCT "route_id") AS "NUM_ROUTES" FROM ( 
	(SELECT "I"||'#'||"J" AS "LOCATION_ID", "GEOM" AS "CCELL"
		FROM ST_HexagonGrid(1000, 'HORIZONTAL',	ST_GeomFromEWKT('SRID=4326;LINESTRING(138.40561 -35.35189, 139.06481 -34.58470)').ST_TRANSFORM(28354))
	) AS GRID
	INNER JOIN "TECHED_USER_000"."V_TRIP_LINES" AS "TRILIN" ON "TRILIN"."SHAPE_28354".ST_Intersects("GRID"."CCELL") = 1)
	GROUP BY "LOCATION_ID", "CCELL";



















