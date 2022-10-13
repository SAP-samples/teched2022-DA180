# Exercise 1 - Routing on a Spatio-Temporal Graph

In this exercise, we will look at the public transportation network of Adelaide, Australia, and learn how to run routing/pathifinding queries on this spatio-temporal network.
First, we will load two sets of data. One is a list of Points of Interest (POIs) which we pull from OpenStreetMap (OSM). The other one is a GTFS (General Transportation Feed Specification) set of files. The GTFS files describe public transport schedules, so basically when busses/metros depart from stations. We will take a look at the GTFS datamodel and do some transformations in the seconds exercise, before we create a Graph Workspace in SAP HANA.
The Graph Workspace is then used to run some "GraphScript" functions, which will answer "shortest path one-to-on" and "top k nearest neighbors" queries.

## Exercise 1.1 Importing Points of Interest from OpenStreetMaps and General Transit Feed Specification data<a name="subex1"></a>

After completing these steps you will know how you can call the OSM overpass API and load geolocation data using "SAP HANA Python Client API for machine learning algorithms" (hana-ml).

We will run the [python code](code/2022_Q3_1_1_POI_and_GTFS_pub.ipynb) in a Jupyter Notebook, and the [SQL statements](code/2022_Q3_DA180_1_POI_and_GTFS) from a SQL console (SAP HANA Database Explorer or DBeaver). Below is the description of the important steps.

This is how we create a query for cafe/restaurant/bar type of amenities within 500m of Adelaide city center.
```` Python
# Get cafe|restaurant|bar amenities from 500m around Adelaide's center
# This query pulls a rather small amount of data from OSM
overpass_query = """
    [out:json];
    (
        node[amenity=cafe](around:500, -34.927975, 138.601394);
        node[amenity=restaurant](around:500, -34.927975, 138.601394);
        node[amenity=bar](around:500, -34.927975, 138.601394);
    );
    out geom;
"""
overpass_url = "http://overpass-api.de/api/interpreter"
response = requests.get(overpass_url, params={'data': overpass_query})
data_small = response.json()
````
The call returns data in JSON format which can be store in the SAP HANA JSON Document Store.
````python
# The overpass API resturns JSON which we can store in the HANA Document Store.
from hana_ml.docstore import create_collection_from_elements
coll = create_collection_from_elements(
    connection_context = cc,
    schema = schema,
    collection_name = 'POI_COLLECTION_SMALL',
    elements = data_small["elements"],
    drop_exist_coll = True)
  ````
  As an alternative, here is how you can flatten the data into a pandas dataframe...
  ````python
df_small = pd.json_normalize(data_small, record_path =['elements'])
df_small = df_small[['id','type','lon','lat','tags.amenity','tags.name']]
````
... and from the pandas dataframe into a HANA table. Note that hana-ml creates a geometry column in the table and makes a "real point geometry" from Lon/Lat coordinates.
````python
from hana_ml.dataframe import create_dataframe_from_pandas
hdf_pois_small = create_dataframe_from_pandas(
    connection_context=cc,
    pandas_df=df_small,
    schema=schema,
    table_name='POIS_SMALL',
    geo_cols=[("lon", "lat")], srid=4326,
    primary_key=('id'), allow_bigint=True,
    drop_exist_tab=True, force=True
    )
````
Let's see the data in HANA. The collection stores the data in JSON format.
![](images/JSON.png)
The HANA table contains the flattened subset of the POIs.
![](images/TAB.png)

Next we will load the GTFS data. There is a nice [list of available GTFS datasets on Github](https://github.com/MobilityData/mobility-database-catalogs#browsing-and-consuming-the-spreadsheet). You can download the [Adelaide data](https://gtfs.adelaidemetro.com.au/v1/static/latest/google_transit.zip) as zip. This repo also contains a [copy][data/gtfs].
Like above, we are using pandas and hana-ml to bring in the data to HANA.
````python
from hana_ml.dataframe import create_dataframe_from_pandas
hdf_routes = create_dataframe_from_pandas(
    connection_context=cc,
    pandas_df=df_routes,
    schema=schema, drop_exist_tab=True,
    table_name='GTFS_ROUTES', force=True,
    primary_key='route_id'
    )
hdf_stops = create_dataframe_from_pandas(
    connection_context=cc,
    pandas_df=df_stops,
    schema=schema, drop_exist_tab=True,
    table_name='GTFS_STOPS', force=True, allow_bigint=True,
    geo_cols=[("stop_lon", "stop_lat")], srid=4326,
    primary_key='stop_id'
    )
    ...
````
Now we have created 4 tables in HANA: ROUTE, STOPS, TRIPS, SHAPES, and STOPTIMES.
ROUTES contains some masterdata about routes.
![](images/routes.png)
The STOPS have a geolocation.
![](images/stops.png)
The TRIPS run on a ROUTE and are related to SHAPES.
![](images/trips.png)
The SHAPES are an ordered set of points which make up a TRIP.
![](images/shapes.png)
And finally, the STOPTIMES indicate when a TRIP's vehicle arrive and departs at a STOP.
![](images/stoptimes.png)

We can run a query to get all STOP locations of a TRIP. A TRIP relates to its STOPTIMES, which relates to STOPS, which have a geolocation.
````SQL
SELECT TRI."trip_id", ST_UNIONAGGR(STO."SHAPE_28354") AS LINE_OF_STOPS
	FROM "TECHED_USER_000"."GTFS_TRIPS" AS TRI,
    "TECHED_USER_000"."GTFS_STOPTIMES" AS ST,
    "TECHED_USER_000"."GTFS_STOPS" AS STO
	WHERE TRI."trip_id" = ST."trip_id" AND ST."stop_id" = STO."stop_id"
		AND TRI."trip_id" = 606101
	GROUP BY TRI."trip_id";
````
![](images/tripstops.png)



## Exercise 1.2 Sub Exercise 2 Description<a name="subex2"></a>

After completing these steps you will have...

1.	Enter this code.
```abap
DATA(lt_params) = request->get_form_fields(  ).
READ TABLE lt_params REFERENCE INTO DATA(lr_params) WITH KEY name = 'cmd'.
  IF sy-subrc <> 0.
    response->set_status( i_code = 400
                     i_reason = 'Bad request').
    RETURN.
  ENDIF.

```

2.	Click here.
<br>![](/exercises/ex1/images/01_02_0010.png)


## Summary

You've now ...

Continue to - [Exercise 2 - Exercise 2 Description](../ex2/README.md)
