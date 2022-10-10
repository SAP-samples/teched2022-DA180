# Exercise 6 - Build a ML classification model on multi-model data

In this exercise, we will create...

## Exercise 6.1 Prepare and explore fuel station classification data<a name="subex1"></a>

After completing these steps you will have created...

STEP 1 - Click here.

Text
````Python
# Creating a station price class type label "STATION_CLASS", derived from daily average e5-price
stations_class=conn.sql(
"""
SELECT "station_uuid", E5_AVG, BINNING(VALUE => E5_AVG, BIN_COUNT => 10) OVER () AS STATION_CLASS 
  FROM ( SELECT  "station_uuid",  avg("e5") AS E5_AVG 
         FROM (  SELECT "date", DAY, HOUR, "station_uuid", "e5" 
                 FROM  RAW_DATA.GAS_PRICES_ANALYSIS 
                 WHERE  "e5" > 1.3 AND "e5" < 2.8)
         GROUP BY "station_uuid" 
         HAVING COUNT("e5")>20);
"""
)
stations_class.collect() 

````
<br>![](/exercises/ex6/images/6.1.1-stations_target.png)


Text
````Python
# Create station masterdata HANA dataframe: station_master
stations_hdf = conn.table("GAS_STATIONS")

#print("There are", stations_hdf.count(), "service stations in Germany")
#display(stations_hdf.head(3).collect())

station_master=stations_hdf.select('uuid', 'brand', 'post_code', ('substr("post_code",1,2)', 'post_code2'), 'city')
display(station_master.head(3).collect()) 

````
<br>![](/exercises/ex6/images/6.1.2-stations_master.png)

Text
````Python
# Derive some station-related e5-price indicators in a HANA dataframe: stations_price_indicators
stations_price_indicators=conn.sql(
"""
SELECT "station_uuid", 
        /* Daily E5 change related indicators */
        SUM(CAST("N_E5C_D" as DOUBLE)) AS SUM_E5C, MIN(CAST("N_E5C_D" as DOUBLE)) AS MIN_E5C, MAX(CAST("N_E5C_D" as DOUBLE)) AS MAX_E5C, AVG("N_E5C_D") AS AVG_E5C, 
        STDDEV("N_E5C_D") AS STDEV_E5C, MAX(CAST("N_E5C_D" as DOUBLE))-MIN(CAST("N_E5C_D" as DOUBLE)) AS RANGE_E5C,
        /* Daily E5 price related indicators */
        AVG("VAR_E5_D") AS AVG_E5_VAR,  AVG("STDDEV_E5_D") AS AVG_E5_STD,  AVG("MIN_E5_D") AS AVG_E5_MIN,  
        AVG("MAX_E5_D") AS AVG_E5_MAX, SUM("RANGE_E5_D") AS SUM_E5_RANGE,  AVG("RANGE_E5_D") AS AVG_E5_RANGE 
    FROM (
          SELECT "station_uuid", DAY,  
                /* Daily price analysis indicators */
                count("e5change") AS N_E5C_D, VAR("e5") AS VAR_E5_D,  STDDEV("e5") AS STDDEV_E5_D,  MIN("e5") AS MIN_E5_D, 
                MAX("e5") AS MAX_E5_D, AVG("e5") AS AVG_E5_D, MAX("e5")-MIN("e5") AS RANGE_E5_D
          FROM (
                  SELECT "date", DAY, HOUR, "station_uuid", "e5", "e5change" 
                  FROM  RAW_DATA.GAS_PRICES_ANALYSIS 
                  WHERE  "e5" > 1.3 AND "e5" < 2.8)
          GROUP BY "station_uuid", DAY)
    GROUP BY "station_uuid";
"""
)
stations_price_indicators.head(3).collect() 

````
<br>![](/exercises/ex6/images/6.1.3-stations_price_indicators.png)

Text
````Python
# Evaluate correlation of indicators with AVG(e5) and thus target class

# Join indicator columns with AVG(e5)
stations_num=stations_price_indicators.set_index("station_uuid").join(
             stations_class.drop('STATION_CLASS').set_index("station_uuid"))
#display(stations_num.head(5).collect())

# Avoid usage of intercorrelated indicators, e.g. correlate numerical columns
import matplotlib.pyplot as plt
from hana_ml.visualizers.eda import EDAVisualizer
f = plt.figure(figsize=(15, 8))
ax1 = f.add_subplot(111)
eda = EDAVisualizer(ax1)
ax1, corr = eda.correlation_plot(data=stations_num.drop('station_uuid'), cmap="Blues")
plt.show() 

````
<br>![](/exercises/ex6/images/6.1.4-stations_price_indicators_corr.png)

Text
````Python
# Drop high correlated indicator columns
stations_price_indicators=stations_price_indicators.drop('AVG_E5_MIN').drop('AVG_E5_MAX').drop('SUM_E5C').drop('AVG_E5C')
stations_price_indicators=stations_price_indicators.drop('AVG_E5_STD').drop('SUM_E5_RANGE').drop('AVG_E5_RANGE')
stations_price_indicators.head(3).collect() 

````
<br>![](/exercises/ex6/images/6.1.5-stations_price_indicators_fin.png)





## Exercise 6.2 Enrich fuel station classification data with spatial attributes<a name="subex2"></a>

After completing these steps you will have...

STEP 1 -	Enter this code.
Text
````Python
# Create a station spatial hierarchy HANA dataframe
stations_spatialhierarchy = stations_hdf.select('uuid', 'longitude','latitude','longitude_latitude_GEO')

# Derive spatial hierarchy features from station point location
stations_spatialhierarchy =stations_spatialhierarchy.generate_feature(targets='longitude_latitude_GEO', 
                                                          trans_func='GEOHASH_HIERARCHY', trans_param=range(3,8))

# Rename columns
stations_spatialhierarchy=stations_spatialhierarchy.rename_columns({'GEOHASH_HIERARCHY(longitude_latitude_GEO,3)': 'GEO_H3', 
                                                                    'GEOHASH_HIERARCHY(longitude_latitude_GEO,4)': 'GEO_H4', 
                                                                    'GEOHASH_HIERARCHY(longitude_latitude_GEO,5)': 'GEO_H5',
                                                                    'GEOHASH_HIERARCHY(longitude_latitude_GEO,6)': 'GEO_H6',
                                                                    'GEOHASH_HIERARCHY(longitude_latitude_GEO,7)': 'GEO_H7'}
                                                                      )

stations_spatialhierarchy.head(2).collect() 

````
<br>![](/exercises/ex6/images/6.2.1-stations_patialhierarchy.png)

Text
````Python
# Import station distance to nearest highway and join with spatial hierarchy data
stations_hwaydist_pd = pd.read_csv('./stations_hwaydist.csv', sep=',', header=0, skiprows=1,
                                      names=["idx", "uuid", "HIGHWAY_DISTANCE"],
                                      usecols=["uuid", "HIGHWAY_DISTANCE"])
stations_hwaydist2 = create_dataframe_from_pandas(
        conn,
        stations_hwaydist_pd,
        schema='TECHED_USER_999',
        table_name="GAS_STATION_HWAYDIST",
        force=True,
        replace=True,
        drop_exist_tab=True,
        table_structure={"uuid": "NVARCHAR(5000)", "HIGHWAY_DISTANCE": "DOUBLE"}
    )
display(stations_hwaydist2.head(5).collect())

# Joining distance data with spatial hierachy dataframe 
stations_spatial_attributes=stations_spatialhierarchy.set_index("uuid").join(stations_hwaydist2.set_index("uuid"))
display(stations_spatial_attributes.collect()) 

````
<br>![](/exercises/ex6/images/6.2.2-stations_spatial_distance.png)


Text
````Python
# Create station spatial dataframe joining spatial hierachy and regions attributes
regions_hdf = conn.table("GEO_GERMANY_REGIONS")

# Joins regions and stations via HANA spatial join-function
stations_spatial = stations_spatial_hierarchy.join(regions_hdf.select('lan_name','krs_name','krs_type','SHAPE'), 
       '"longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1')

stations_spatial.drop('SHAPE').head(5).collect() 

````
<br>![](/exercises/ex6/images/6.2.3-stations_spatial_attributes.png)



## Exercise 6.3 Build fuel station classification model and evaluate impact of attributes<a name="subex3"></a>


STEP 1 -	Click here.

Text
````Python
#Save station attributes dataframes to temporary HANA tables
stations_class.drop('E5_AVG').save('#STATION_CLASS', force=True)
station_master.save('#STATION_MASTER', force=True)
stations_price_indicators.save('#STATION_PRICE_INDICATORS', force=True)
stations_spatial.drop('longitude_latitude_GEO').drop('SHAPE').save('#STATION_SPATIAL', force=True) 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
# Build the classification training data HANA dataframe
stations_priceclass=conn.sql(
"""
SELECT M."uuid", "brand", "post_code", "post_code2", "city", 
       "longitude", "latitude", "GEO_H3", "GEO_H4", "GEO_H5", "GEO_H6", "GEO_H7", "lan_name", "krs_name", "krs_type",
       S.HIGHWAY_DISTANCE,
       "MIN_E5C", "MAX_E5C", "STDEV_E5C", "RANGE_E5C", "AVG_E5_VAR",  
       "STATION_CLASS"
   From #STATION_MASTER as M,
        #STATION_SPATIAL as S,
        #STATION_PRICE_INDICATORS as PI,
        #STATION_CLASS as C
    Where M."uuid"=PI."station_uuid" AND 
          M."uuid"=S."uuid" AND
          M."uuid"=C."station_uuid";
"""
)
stations_priceclass.head(3).collect()
#print(stations_priceclass.columns)

````
<br>![](/exercises/ex6/images/6.3.1-price_class_dataset.png )


Text
````Python
# Save station classification dataset to HANA column table
stations_priceclass.save('STATION_PRICECLASSIFICATION', force=True)

gas_station_class_base = conn.table("STATION_PRICECLASSIFICATION", schema="TECHED_USER_999")
gas_station_class_base.head(5).collect() 
#print(gas_station_class_base.columns)
````
<br>![](/exercises/ex6/images/6.3.2-price_class_basetable.png)


Text
````Python
# Split the station classification dataframe into a training and test subset
from hana_ml.algorithms.pal.partition import train_test_val_split
df_train, df_test, _ = train_test_val_split(data=gas_station_class_base, id_column='uuid',
                                            random_seed=2, partition_method='stratified', stratified_column='STATION_CLASS',
                                            training_percentage=0.75,
                                            testing_percentage=0.25,
                                            validation_percentage=0)

df_train.describe().collect()
#print(df_train.describe().select_statement) 

````
<br>![](/exercises/ex6/images/6.3.3-price_train_describe.png)


Text
````Python
# Train the Station classifer model using PAL HybridGradientBoostingTree

from hana_ml.algorithms.pal.unified_classification import UnifiedClassification

# Define the model object 
hgbc = UnifiedClassification(func='HybridGradientBoostingTree',
                            n_estimators = 100, split_threshold=0.1,
                          learning_rate=0.5,
          fold_num=5, max_depth=5,
          evaluation_metric = 'error_rate', ref_metric=['auc'])

# Execute the training of the model
hgbc.fit(data=df_train, key= 'uuid',
         label='STATION_CLASS', ntiles=20, impute=True, build_report=True)

display(hgbc.runtime)

# Explore the feature importance result
display(hgbc.importance_.sort('IMPORTANCE', desc=True).collect().set_index('VARIABLE_NAME')) 

````
<br>![](/exercises/ex6/images/6.3.4-feature_importance.png)


Text
````Python
# Test model generalization using the test data-subset, not used during training
scorepredictions, scorestats, scorecm, scoremetrics = hgbc.score(data=df_test , key= 'uuid', label='STATION_CLASS', 
                                                                 ntiles=20, impute=True)
#display(hgbc.runtime)
display(scorestats.sort('CLASS_NAME').collect())
display(scorecm.filter('COUNT != 0').collect())
display(scoremetrics.collect()) 

````
<br>![](/exercises/ex6/images/6.3.5-score_stats.png)
<br>![](/exercises/ex6/images/6.3.6-score_cm_cummetrics.png)


Text
````Python
# Explore test data-subset predictions applying the trained model
features = df_test.columns
features.remove('STATION_CLASS')
features.remove('uuid')

# Using the predict-method with our model object hgbc
pred_res = hgbc.predict(df_test, key='uuid', features=features, impute=True )

#display(hgbc.runtime)

# Review the predicted results
pd.set_option('max_colwidth', None)
pred_res.select('uuid', 'SCORE', 'CONFIDENCE', 'REASON_CODE', 
                ('json_query("REASON_CODE", \'$[0].attr\')', 'Top1'), 
                ('json_query("REASON_CODE", \'$[0].pct\')', 'PCT_1') ).head(3).collect() 

````
<br>![](/exercises/ex6/images/6.3.7-pred_results.png)


Text
````Python
#  Show the distribution of the impacts each feature has on the model output using Shapley ML explainability values 
import pydotplus
import graphviz
from hana_ml.visualizers.model_debriefing import TreeModelDebriefing

shapley_explainer = TreeModelDebriefing.shapley_explainer(pred_res, df_test, key='uuid', label='STATION_CLASS')
shapley_explainer.summary_plot() 

````
<br>![](/exercises/ex6/images/6.3.8-shapley_global.png)


Text
````Python
# Show the "local" distribution impact of each feature for individual predictions 
shapley_explainer = TreeModelDebriefing.shapley_explainer(pred_res.head(5), df_test.head(5), 
                                                          key='uuid', label='STATION_CLASS')
shapley_explainer.force_plot() 

````
<br>![](/exercises/ex6/images/6.3.9-shapley_local.png)


Text
````Python
# Save Models and Model Quality Information to MLLAB-Sandbox
from hana_ml.model_storage import ModelStorage

MLLAB_models = ModelStorage(connection_context=conn)

hgbc.name = 'STATION PRICE-CLASS CLASSIFIER MODEL' 
hgbc.version = 1

MLLAB_models.save_model(model=hgbc) 

````



Text
````Python
# Retrieve model from ModelStorage location
from hana_ml.model_storage import ModelStorage
MLLAB_models = ModelStorage(connection_context=conn)

list_models = MLLAB_models.list_models()
display(list_models) 

````
<br>![](/exercises/ex6/images/6.3.10-modelstorage_listmodel.png)


Text
````Python
# Reload model from ModelStorage
mymodel = MLLAB_models.load_model('STATION PRICE-CLASS CLASSIFIER MODEL', 1)

# Predict with reloaded model
pred_results=mymodel.predict(data=df_test, key='uuid', features=features, impute=True)

# Build Model Report
from hana_ml.visualizers.unified_report import UnifiedReport
UnifiedReport(mymodel).build().display() 

````
<br>![](/exercises/ex6/images/6.3.11-modelreport_varimportance.png)


Text
````Python
# CleanUp Model Storage
MLLAB_models.delete_models(name='STATION PRICE-CLASS CLASSIFIER MODEL')
MLLAB_models.clean_up() 

````


<br>![](/exercises/ex6/images/02_019_0010.png)

## Reference section - Use OSMNX to import German Highway network and calculate spatial distance btw station and next highway<a name="subex6.4"></a>

OSMnx is a Python package that lets you download geospatial data from OpenStreetMap and model, project, visualize, and analyze real-world street networks and any other geospatial geometries. You can download and model walkable, drivable, or bikeable urban networks with a single line of Python code then easily analyze and visualize them. You can just as easily download and work with other infrastructure types, amenities/points of interest, building footprints, elevation data, street bearings/orientations, and speed/travel time.See https://osmnx.readthedocs.io/en/stable/index.html for reference details.

Text
````Python
%%time
import osmnx as ox
# !!careful, downloading the german highway network via OSMNX takes multiple hours
# If you want to try this out, try out the next step instead download the highway network for a single region

# Use OSMNX-method to download network graph from "place"
ox.config(use_cache=True, log_console=True)
cf = '["highway"~"motorway"]'
#g =  ox.graph_from_place('Germany', network_type = 'drive', custom_filter=cf) 

````

Text
````Python

%%time
import osmnx as ox
hdf_RNK_SHAPE = stations_spatial.filter("\"krs_name\"='Landkreis Rhein-Neckar-Kreis'" ).select('uuid','krs_name', 'SHAPE').head(1)
display(hdf_RNK_SHAPE.drop('SHAPE').collect())

# Create Geopandas Dataframe from the HANA dataframe
gdf_RNK_SHAPE = gpd.GeoDataFrame(hdf_RNK_SHAPE.select('uuid', 'SHAPE').collect(), geometry='SHAPE')
gdf_RNK_SHAPE=gdf_RNK_SHAPE.rename_geometry('geometry')
display(gdf_RNK_SHAPE.head(10))

# Use OSMNX-method to download network graph from polygon
ox.config(use_cache=True, log_console=True)
cf = '["highway"~"motorway"]'
g = ox.graph_from_polygon(polygon = gdf_RNK_SHAPE['geometry'][0], network_type = 'drive',custom_filter=cf)
#fig, ax = ox.plot_graph(g, fig_height=5) 

````
Text
````Python
# Check successful object download
g

# Plot OSMNX highway network graph data
fig, ax = ox.plot_graph(g)

````
<br>![](/exercises/ex6/images/6.2.4-osmx_highway_plot.png)

Text
````Python
# Create geodataframes from network graph
gdf_nodes,gdf_edges = ox.graph_to_gdfs(g, nodes=True, edges=True)
gdf_edges


````
<br>![](/exercises/ex6/images/6.2.5-gdf_edges.png)

Text
````Python
# Convert network arrays to str-column format for the pandas dataframe
gdf_edges['ID'] = np.arange(len(gdf_edges))
gdf_edges['osmid']=gdf_edges['osmid'].astype(str)
gdf_edges['ref']=gdf_edges['ref'].astype(str)
gdf_edges['highway']=gdf_edges['highway'].astype(str)

# Create a pandas dataframe, needed for the HANA dataframe import
pd_edges=pd.DataFrame(gdf_edges, copy=True)[['ID', 'osmid', 'geometry', 'highway','ref']]
pd_edges.head(5)
````
<br>![](/exercises/ex6/images/6.2.6-pd_edges.png)


Text
````Python
# Create a HANA dataframe from the German highway-network edges pandas dataframe 
from hana_ml.dataframe import create_dataframe_from_pandas

hdf = create_dataframe_from_pandas(
    connection_context=conn, replace=True,
    pandas_df=pd_edges,
    geo_cols=["geometry"],
    srid=4326,
    schema='TECHED_USER_999',
    table_name="GEO_GERMANY_HIGHWAYS", primary_key='ID'
    , drop_exist_tab=True, force=True)

german_highways = conn.sql('select * from "TECHED_USER_999"."GEO_GERMANY_HIGHWAYS"')
german_highways.head(3).collect()

````
<br>![](/exercises/ex6/images/6.2.7-german_highway_edges_hdf.png)

Text
````Python
# Prepare a list of all krs_mame values for the distance calculation
df=stations_spatial.distinct('krs_name').collect()
krs=list(set(list(df['krs_name'])))
print(sorted(krs))
````
<br>![](/exercises/ex6/images/6.2.8-german_landkreis_liste.png)


Text
````SQL
/*** SQL **************************************************************************************/
/* Calculate single Highway-Multilinestring from Highway network into temporary table #HWL */
CREATE LOCAL TEMPORARY COLUMN TABLE #HWL ( HIGHWAY NVARCHAR(24), HIGHWAY_LINE ST_GEOMETRY(4326));
--#ALTER TABLE HWAY ALTER (HIGHWAY_LINE ST_GEOMETRY(4326));
INSERT INTO #HWL
	SELECT "highway",  NEW ST_MultiLineString('MultiLineString (' || substring(LSTRING,3) || ')', 4326) AS HIGHWAY_LINE
				FROM (
						SELECT "highway", replace(agg , 'SRID=4326;LINESTRING ', ', ') AS LSTRING
						FROM (
								SELECT "highway",  STRING_AGG("geometry_GEO") AS agg 
								FROM RAW_DATA.GEO_GERMANY_HIGHWAYS 
								WHERE substr("ref",1,1)='A' AND "highway"='motorway'
								GROUP BY "highway"
							)
					);
        
/* Select stations for each (all, batches or single) krs_name, and calculate distance to German Highway-Multilinestring */
CREATE COLUMN TABLE STATION_HWAYDIST ("uuid" NVARCHAR(5000), HIGHWAY_DISTANCE DOUBLE);
INSERT INTO STATION_HWAYDIST 
SELECT "uuid", "STATION_P".ST_SRID(1000004326).ST_DISTANCE(HIGHWAY_LINE.ST_SRID(1000004326), 'meter') AS HIGHWAY_DISTANCE
from
	(SELECT "uuid", "longitude_latitude_GEO".ST_SRID(4326) AS "STATION_P" 
   		FROM 	(SELECT S."uuid", "longitude_latitude_GEO"
         		from TECHED_USER_999.STATION_PRICECLASSIFICATION S, TECHED_USER_999.GAS_STATIONS G
         		WHERE S."krs_name" in (
 'Kreis Borken', 'Kreis Coesfeld', 'Kreis Dithmarschen', 'Kreis Düren', 'Kreis Ennepe-Ruhr-Kreis', 'Kreis Euskirchen', 
 'Kreis Gütersloh', 'Kreis Heinsberg', 'Kreis Herford', 'Kreis Herzogtum Lauenburg', 'Kreis Hochsauerlandkreis', 
  ...
  'Landkreis Würzburg', 'Landkreis Zollernalbkreis', 'Landkreis Zwickau', 'Stadtkreis Baden-Baden', 
  'Stadtkreis Freiburg im Breisgau', 'Stadtkreis Heidelberg', 'Stadtkreis Heilbronn', 'Stadtkreis Karlsruhe', 
  'Stadtkreis Mannheim', 'Stadtkreis Pforzheim', 'Stadtkreis Stuttgart', 'Stadtkreis Ulm'
         		) AND
         		       S."uuid"=G."uuid"
         		) AS P
     ),
     #HWL;
````

Text
````Python
stations_hwaydist=conn.table("STATION_HWAYDIST")
display(stations_hwaydist.head(5).collect())
#6.2.9-german_highwaydist.png

````
<br>![](/exercises/ex6/images/6.2.9-german_highwaydist.png)


Text





## Summary

You've now concluded the last exercise, congratulations! 

