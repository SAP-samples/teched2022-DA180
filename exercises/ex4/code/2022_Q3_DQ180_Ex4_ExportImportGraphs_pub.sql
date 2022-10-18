/******************************************************************/
-- Exercise 4 - Import and export graphs
/******************************************************************/

/******************************************************************/
-- Exercise 4.1 - Export graphs
/******************************************************************/

SELECT * FROM "TECHED_USER_000"."GTFS_ROUTES";

-- You can easily hop from one route to another if both share a stop.
-- Let's make a graph that shows how well route(groups) are connected.

-- Create EDGES table by joining the routegroups
CREATE TABLE TECHED_USER_000.ROUTE_EDGES AS (
	WITH ROU AS ( -- get all a routegroups's stops
		SELECT DISTINCT ROU."agency_id", ROU."RouteGroup", ST."stop_id"
			FROM TECHED_USER_000.GTFS_ROUTES AS ROU
			LEFT JOIN TECHED_USER_000.GTFS_TRIPS AS TRI ON ROU."route_id" = TRI."route_id" 
			LEFT JOIN TECHED_USER_000.GTFS_STOPTIMES AS ST ON TRI."trip_id" = ST."trip_id"
			WHERE "RouteGroup" IS NOT NULL
	)
	SELECT ROU1."RouteGroup" AS "SOURCE", ROU2."RouteGroup" AS "TARGET", COUNT(*) AS "NUM_SHARED_STOPS"
		FROM ROU AS ROU1, ROU AS ROU2
		WHERE ROU1."stop_id" = ROU2."stop_id" AND ROU1."RouteGroup" < ROU2."RouteGroup" -- join two distinct routegroups if they share a stop 
		GROUP BY ROU1."RouteGroup", ROU2."RouteGroup"
);
-- add a primary key and not null constraints
ALTER TABLE "TECHED_USER_000"."ROUTE_EDGES" ADD ("ID" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY);
ALTER TABLE "TECHED_USER_000"."ROUTE_EDGES" ALTER ("SOURCE" NVARCHAR(5000) NOT NULL, "TARGET" NVARCHAR(5000) NOT NULL);

-- create a VERTCICES view
CREATE OR REPLACE VIEW "TECHED_USER_000"."V_ROUTE_VERTICES" AS (
	SELECT DISTINCT "RouteGroup", "agency_id" FROM "TECHED_USER_000"."GTFS_ROUTES" WHERE "RouteGroup" IS NOT NULL
);

-- create GRAPH WORKSPACE
CREATE OR REPLACE GRAPH WORKSPACE "TECHED_USER_000"."GRAPH_GTFS_ROUTES"
	EDGE TABLE "TECHED_USER_000"."ROUTE_EDGES"
		SOURCE COLUMN "SOURCE"
		TARGET COLUMN "TARGET"
		KEY COLUMN "ID"
	VERTEX TABLE "TECHED_USER_000"."V_ROUTE_VERTICES" 
		KEY COLUMN "RouteGroup";


SELECT COUNT(*) AS C FROM "TECHED_USER_000"."V_ROUTE_VERTICES";
SELECT COUNT(*) AS C FROM "TECHED_USER_000"."ROUTE_EDGES";




/******************************************************************/
-- Exercise 4.2 - Import graphs
/******************************************************************/
-- BC on NIC
CREATE OR REPLACE PROCEDURE TECHED_USER_000.P_BC (
	OUT o_VERTEX_BC TABLE ("SUID" BIGINT, "type" NVARCHAR(5000),"BC" DOUBLE),
	OUT o_EDGE_BC TABLE ("SUID" BIGINT, "BC" DOUBLE)
	)
LANGUAGE GRAPH READS SQL DATA AS
BEGIN
	Graph g = Graph(TECHED_USER_000, "NCI_GRAPH");
	MAP<VERTEX, DOUBLE> m_v_bc =  MAP<VERTEX, DOUBLE>(:g, 1000L);
	MAP<EDGE, DOUBLE> m_e_bc = BETWEENNESS_EDGE_CENTRALITY(:g, :m_v_bc);
	o_VERTEX_BC = SELECT :v."SUID", :v."type", :c FOREACH(v, c) IN :m_v_bc;
	o_EDGE_BC = SELECT :e."SUID", :c FOREACH(e, c) IN :m_e_bc;
END;
DO() BEGIN
	CALL TECHED_USER_000.P_BC(v_bc, e_bc);
	SELECT * FROM :v_bc ORDER BY BC DESC;
	SELECT * FROM :e_bc ORDER BY BC DESC;
END;









