# Exercise 6 - Build a ML classification model on multi-model data

In this exercise, we want to apply SAP HANA Cloud multi-model processing techniques to prepare and assemble geo-located information about fuel stations in Germany, and make use of __Machine Learning classification__ techniques from the [Predictive Analysis Library (PAL)](https://help.sap.com/docs/HANA_CLOUD_DATABASE/319d36de4fd64ac3afbf91b1fb3ce8de/c9eeed704f3f4ec39441434db8a874ad.html?locale=en-US) to model price-class categories for the fuels stations and deduct influence of station attributes (incl. spatial attributes) and their impact explaining the price-classes.

This exercise builds on top of exercise 5, hence the exercise 5 tasks need to be completed before starting with this section.

The __objective and goals__ for this exercise are
- in ex 6.1 to build a fuel station price-class label variable based on average e5 fuel-price levels and then define a station master data- and price-indicator attribute dataframe
- in ex 6.2 to define an additional station attribute dataframe with multiple geo-location derived attributes
- in ex 6.3 to build a station price-class classification model, review feature influence (esp. of spatial features) on the price-class labels.

As an extra and optional exercise, the [add-on section](/exercises/ex6/README.md#subexAddOn) describes how to evaluate, store and debrief the classifier model in more detail. Furthermore  an add-on exercise describes how to download German-highway network data and calculate the spatial distance between stations and the next highway.

You can approach the exercises by copy & paste of the Python code snippets from this document or open the Jupyter Notebook file provided [here](/exercises/ex6/DA180-Exercise6-Build%20a%20ML%20classification%20model%20on%20multi-model%20data-Student.ipynb).

## Exercise 6.1 Prepare and explore fuel station classification data<a name="subex1"></a>

__Step 1 - Create the classification label-column__  
Using an advanced SQL statement, we define a HANA dataframe with the __STATION\_CLASS target column__, deriving a station's fuel price-class level using a  __binning-function over the average of all daily-average e5 prices__.

````Python
# Creating a station price class type label "STATION_CLASS", derived from daily average e5-price
stations_class=conn.sql(
"""
SELECT "station_uuid", E5_AVG, BINNING(VALUE => E5_AVG, BIN_COUNT => 10) OVER () AS STATION_CLASS 
  FROM ( SELECT  "station_uuid",  avg("e5") AS E5_AVG 
         FROM (  SELECT "station_uuid", "date", 
	                      EXTRACT(DAY FROM "date")||'-'||EXTRACT(MONTH FROM "date")||'-'||EXTRACT(YEAR FROM "date") AS "DAY", 
	                      HOUR("date") as HOUR, 
                          "e5", "e5change"
                 FROM  GAS_PRICES 
                 WHERE  "e5" > 1.3 AND "e5" < 2.8)
         GROUP BY "station_uuid" 
         HAVING COUNT("e5")>20);  
"""
)
stations_class.collect() 

````
![](/exercises/ex6/images/6.1.1-stations_target.png)
<br>  

__Step 2 - Create the station master attribute dataframe__  
Create a HANA dataframe, with the __key master station attributes__ of potential interest and relation to the price-level classification. 
- As the five digit postal code might be too detailed feature, we are abstracting it to the first two and three digits of the postal code, indicating a more regional than local aspect.
- We leverage __dataframe select-method__, which allows us to use __SQL expressions to define new columns__

````Python
# Create station masterdata HANA dataframe: station_master
stations_hdf = conn.table("GAS_STATIONS")

station_master=stations_hdf.select('uuid', 'brand', ('substr("post_code",1,2)', 'post_code2'), 
                                   ('substr("post_code",1,3)', 'post_code3'), 'city')
display(station_master.head(3).collect())
````
![](/exercises/ex6/images/6.1.2-stations_master.png)  

<br>

__Step 3 - Create the station price-level indicator attributes dataframe__  
In this dataframe, based on a complex SQL statement, we __derive some station-related e5-price indicator attributes__ like
- *_E5C_D as daily "e5change"-count derived indicators (sum, min, ....), e.g. SUM_E5C = Sum of all daily counts of e5-price changes
- *_E5_D as aggregates (AVG, SUM) over aggregated (VAR, STDDEV, MIN, ..) daily e5-values, e.g. AVG_E5_MIN = Average across all daily minimal e5-price values
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
                  SELECT "station_uuid", "date", 
	                      EXTRACT(DAY FROM "date")||'-'||EXTRACT(MONTH FROM "date")||'-'||EXTRACT(YEAR FROM "date") AS "DAY", 
	                      HOUR("date") as HOUR, 
                          "e5", "e5change"
                  FROM  "GAS_PRICES"  
                  WHERE  "e5" > 1.3 AND "e5" < 2.8)
          GROUP BY "station_uuid", DAY)
    GROUP BY "station_uuid";
"""
)
stations_price_indicators.head(3).collect() 
````
![](/exercises/ex6/images/6.1.3-stations_price_indicators.png)



<br>  

If any of the __indicators show a too high correlation with the target column__ price_class (which has been derived from average price-class levels), there is the risk of information leakage from indicators to the model target. Therefore we want evaluate the __numeric feature correlations__ with the HANA ML __correlation plot__.

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
![](/exercises/ex6/images/6.1.4-stations_price_indicators_corr.png)
<br>  

Now, due to the __high correlation__ with the "E5_AVG" column and intercorrelations (values higher than 0.5) detected, we will __exclude__ a number of features from the price indicators_dataframe.

````Python
# Drop high correlated indicator columns
stations_price_indicators=stations_price_indicators.drop('AVG_E5_MIN').drop('AVG_E5_MAX').drop('SUM_E5C').drop('AVG_E5C')
stations_price_indicators=stations_price_indicators.drop('AVG_E5_STD').drop('SUM_E5_RANGE').drop('AVG_E5_RANGE')
stations_price_indicators.head(3).collect() 
````
![](/exercises/ex6/images/6.1.5-stations_price_indicators_fin.png)  
<br>



## Exercise 6.2 Enrich fuel station classification data with spatial attributes<a name="subex2"></a>

At first, we will define a __data-driven spatial hierarchy__ from the stations point locations using its geohashes. 
- __Geohashes__ are unique hash-values derived from geo-locations, by ommitting trailing values from the 20 character hash-string. Simply a rectangle represented by the first 5 characters of the geohash, is guaranteed to contain any rectangle / point represented by the same first 5 + n characters geohash.
- The __generated_feature__ dataframe-function allows to generate a hierarchy geohash features.
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
![](/exercises/ex6/images/6.2.1-stations_patialhierarchy.png)  
<br>  

Next, each __stations closest distance to the network of highways__ in Germany as been pre-calcualted and can be imported from the file stations_hwaydist.csv
- Note, in the [add-on exercise OMNX import section](/exercises/ex6/README.md#subexADDON_OMNX) it is described, how the Germany __highway network can be imported__ using the OpenStreetMap network Python interface __OSMNX__, imported as a HANA graph, how a multilinestring is build for the complete highway network and the spatial distance is calculated.

````Python
# Import station distance to nearest highway and join with spatial hierarchy data
stations_hwaydist_pd = pd.read_csv('./data/fuelprice/stations_hwaydist.csv', sep=',', header=0, skiprows=1,
                                      names=["idx", "uuid", "HIGHWAY_DISTANCE"],
                                      usecols=["uuid", "HIGHWAY_DISTANCE"])
stations_hwaydist2 = create_dataframe_from_pandas(
        conn,
        stations_hwaydist_pd,
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
![](/exercises/ex6/images/6.2.2-stations_spatial_distance.png)  
<br>

Finally, we __spatially join__ the stations spatial attributes dataframe with the German-region "Landkreise" shapes and select __relevant regional attributes__.
````Python
# Create station spatial dataframe joining spatial hierachy and regions attributes
regions_hdf = conn.table("GEO_GERMANY_REGIONS")

# Joins regions and stations via HANA spatial join-function
stations_spatial = stations_spatial_hierarchy.join(regions_hdf.select('lan_name','krs_name','krs_type','SHAPE'), 
       '"longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1')

stations_spatial.drop('SHAPE').head(5).collect() 
````
![](/exercises/ex6/images/6.2.3-stations_spatial_attributes.png)   
<br>



## Exercise 6.3 Build fuel station classification model and evaluate impact of attributes<a name="subex3"></a>

__Step 1 - Create the station classification HANA dataframe__  
For conveniance, we first __save__ all the station __dataframes as local temporary tables__ in SAP HANA.

````Python
#Save station attributes dataframes to temporary HANA tables
stations_class.drop('E5_AVG').save('#STATION_CLASS', force=True)
station_master.save('#STATION_MASTER', force=True)
stations_price_indicators.save('#STATION_PRICE_INDICATORS', force=True)
stations_spatial.drop('longitude_latitude_GEO').drop('SHAPE').save('#STATION_SPATIAL', force=True) 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Using an advanced join SQL statement of all the attributes temporary table, we then create the __stations priceclass dataframe__.
````Python
# Build the classification training data HANA dataframe
stations_priceclass=conn.sql(
"""
SELECT M."uuid", "brand", "post_code2", "post_code3", "city", 
       "longitude", "latitude", "GEO_H3", "GEO_H4", "GEO_H5", "lan_name", "krs_name", "krs_type",
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
````
<br>![](/exercises/ex6/images/6.3.1-price_class_dataset.png )  


For convenience, we __save the dataframe to a table__ as our __model development base dataset__.
````Python
# Save station classification dataset to HANA column table
stations_priceclass.save('STATION_PRICECLASSIFICATION', force=True)

gas_station_class_base = conn.table("STATION_PRICECLASSIFICATION")
gas_station_class_base.head(5).collect() 
````
<br>![](/exercises/ex6/images/6.3.2-price_class_basetable.png)


__Step 2 - Splitting up our model development base dataset__  
In order to __validate our classification model__ throughout training iterations and neutrally __test__ it after the training efforts have been completed, we __split up or base data set__ into train-, validation- and test-subset using the __train_test_val_split-method__.
````Python
# Split the station classification dataframe into a training and test subset
from hana_ml.algorithms.pal.partition import train_test_val_split
df_train, df_test, , df_val = train_test_val_split(data=gas_station_class_base, id_column='uuid',
                                            random_seed=2, partition_method='stratified', stratified_column='STATION_CLASS',
                                            training_percentage=0.70,
                                            testing_percentage=0.15,
                                            validation_percentage=0.15)

df_train.describe().collect() 
````
![](/exercises/ex6/images/6.3.3-price_train_describe.png)
As the describe column report of our training subset shows, some of the columns contains __null values__ (brand, post_code*). During model training, we will take care of this.   
  
<br>

In order to __validate the classification__ thoughout the training interations, we union the train- and validation subsets so we can __pass both subsets__ to the training step. The subsets beeing indicated by the __TRAIN\_VAL\_INDICATOR__ column.
````Python
 # Union train and validation data into one set
df_trainval=df_train.select('*', ('1', 'TRAIN_VAL_INDICATOR' )).union(df_val.select('*', ('2', 'TRAIN_VAL_INDICATOR' )))

display(df_trainval.head(5).collect())

```` 
<br>![](/exercises/ex6/images/6.3.4-###.png)

__Step 3 - Train the station price-class classification model__  
We now use the [PAL Unified Classification method](https://help.sap.com/doc/1d0ebfe5e8dd44d09606814d83308d4b/latest/en-US/hana_ml.algorithms.pal_algorithm.html?highlight=unified%20classification#module-hana_ml.algorithms.pal.unified_classification), to train a [HybridGradientBoostingTree](https://help.sap.com/docs/HANA_CLOUD_DATABASE/319d36de4fd64ac3afbf91b1fb3ce8de/ca5106cbd88f4ac69e7538bbc6a059ea.html?locale=en-US) classifier model. The python method allows us to specify
- all algoritm parameters like _n_estimators max_depths, ...
- re-sampling and cross validation details like metrics used
- missing value data handling details like impute
- input data columns roles like label, key, sub-partition purpose, ...
- classification model report generation
````Python
# Train the Station classifer model using PAL HybridGradientBoostingTree
from hana_ml.algorithms.pal.unified_classification import UnifiedClassification

# Define the model object 
hgbc = UnifiedClassification(func='HybridGradientBoostingTree',
                            n_estimators = 101, split_threshold=0.1,
                          learning_rate=0.5, max_depth=5,
          resampling_method='cv', fold_num=5, 
          evaluation_metric = 'error_rate', ref_metric=['auc'],
                            thread_ratio=1.0)

# Execute the training of the model
hgbc.fit(data=df_trainval, key= 'uuid',
         label='STATION_CLASS', categorical_variable='STATION_CLASS',
         impute=True, strategy='most_frequent-mean',
         ntiles=20,  build_report=True,
         partition_method='user_defined', purpose='TRAIN_VAL_INDICATOR' )

display(hgbc.runtime)
````
![](/exercises/ex6/images/6.3.4-feature_importanceXYZ.png)  

<br>

__Step 4 - Explore the model report and attribute importance__  
We now build the __classification model report__, so we can explore training and validation model performance statistics, confusion matrix, explore feature importance and classification metric reports like ROC, gain or lift charts.
````Python
# Build Model Report
from hana_ml.visualizers.unified_report import UnifiedReport
UnifiedReport(hgbc).build().display()
````
![](/exercises/ex6/images/6.3.4-model_report1.png)  
  
  <br>

Looking the __feature importance__-section of the report specifically, the relative importance of all attributes explaining and contributing to the models global classification performance is reported
- __geo-location derived attributes__ like highway distance, are amongst the __top__ influencing attributes
![](/exercises/ex6/images/6.3.11-modelreport_varimportance.png)  

<br>


Applying the __model PREDICT-method__ to station data (e.g from our test-data subset), beside the models predicted classification for a station, we can review a __station's attributes value importance with respect to the predicted classification__ (local feature importance or explainability) in the REASON_CODE column output.
````Python
# Explore test data-subset predictions applying the trained model
features = df_test.columns
features.remove('STATION_CLASS')
features.remove('uuid')

# Using the predict-method with our model object hgbc
pred_res = hgbc.predict(df_test.head(1000), key='uuid', features=features, impute=True )

# Review the predicted results
pd.set_option('max_colwidth', None)
pred_res.select('uuid', 'SCORE', 'CONFIDENCE', 'REASON_CODE', 
                ('json_query("REASON_CODE", \'$[0].attr\')', 'Top1'), 
                ('json_query("REASON_CODE", \'$[0].pct\')', 'PCT_1') ).head(3).collect() 

````
![](/exercises/ex6/images/6.3.7-pred_results.png)  

<br>
 


## Summary

You've now concluded the last exercise, congratulations! 


  

<br>

## Optional Add-on exercises<a name="subexAddOn"></a>

## Score and debrief model
Using the __Unified Classification-SCORE method__, we can __benchmark and test our models generalization__ against data completely unseen during model development.
````Python
# Test model generalization using the test data-subset, not used during training
scorepredictions, scorestats, scorecm, scoremetrics = hgbc.score(data=.fillna('missing').head(100) , key= 'uuid', label='STATION_CLASS', 
                                                                 ntiles=20, impute=True)
 
display(scorestats.sort('CLASS_NAME').collect())
display(scorecm.filter('COUNT != 0').collect())
display(scoremetrics.collect()) 
````
<br>![](/exercises/ex6/images/6.3.5-score_stats.png)
<br>![](/exercises/ex6/images/6.3.6-score_cm_cummetrics.png)







## Store and retrieve stored models as well as model reports
Using the __ModelStorage methods__, we can store and retrieve models and model performance reports from a given storage schema.
- Note, using the schema=-option in the ModelStorage definition, it can be determined on where to save the models. Here, adjust the schema to your  connection database userid.
````Python
# Initiate ModelStorage location
from hana_ml.model_storage import ModelStorage
MLLAB_models = ModelStorage(connection_context=conn, schema="TECHED_USER_###")

#Describe and save current model
hgbc.name = 'STATION PRICE-CLASS CLASSIFIER MODEL' 
hgbc.version = 1
MLLAB_models.save_model(model=hgbc) 

````


````Python
# List stored models
list_models = MLLAB_models.list_models()
display(list_models) 
````
![](/exercises/ex6/images/6.3.10-modelstorage_listmodel.png)  
<br>


At a later point in time, we can reconnect to the ModelStorage schema, __retrieve stored models and revisit model reports__.
````Python
# Retrieve model from ModelStorage location
from hana_ml.model_storage import ModelStorage
MLLAB_models = ModelStorage(connection_context=conn, schema="TECHED_USER_###")

# Reload model from ModelStorage
mymodel = MLLAB_models.load_model('STATION PRICE-CLASS CLASSIFIER MODEL', 1)

# Predict with reloaded model
pred_results=mymodel.predict(data=df_test.head(10), key='uuid', features=features, impute=True)

# Build Model Report
from hana_ml.visualizers.unified_report import UnifiedReport
UnifiedReport(mymodel).build().display() 

````
<br>![](/exercises/ex6/images/6.3.11-modelreport.png)


As needed, models and the complete model storage can be deleted as needed and database authorizations allow for.
````Python
# CleanUp Model Storage
MLLAB_models.delete_models(name='STATION PRICE-CLASS CLASSIFIER MODEL')
MLLAB_models.clean_up() 
````
  
  <br>  




## Use OSMNX to import German Highway network and calculate spatial distance btw station and next highway<a name="subexADDON_OMNX"></a>

__OSMNX__ is a Python package that lets you __download geospatial data from OpenStreetMap and model, project, visualize, and analyze real-world street networks and any other geospatial geometries__. You can download and model walkable, drivable, or bikeable urban networks with a single line of Python code then easily analyze and visualize them. You can just as easily download and work with other infrastructure types, amenities/points of interest, building footprints, elevation data, street bearings/orientations, and speed/travel time.See https://osmnx.readthedocs.io/en/stable/index.html for reference details.

There are multiple methods to download street network data, like  __"graph from place"__ or __"graph from polygon"__.  
__! Be careful__, downloading the german highway network via OSMNX takes multiple hours.  
! Therefore, if you seek to explore this section, try out the next step and download only the highway network for a single region instead.
````Python
%%time
import osmnx as ox

# Use OSMNX-method to download network graph from "place"
ox.config(use_cache=True, log_console=True)
cf = '["highway"~"motorway"]'

#! Be careful, downloading the german highway network via OSMNX takes multiple hours.  
#! Therefore, if you seek to explore this section, try out the next step and download only the highway network for a single region instead.

#g =  ox.graph_from_place('Germany', network_type = 'drive', custom_filter=cf) 
````

Use OSMNX to download only the __highway network for a single region-shape__.
````Python
# Collect the SHAPE of the region into geopandas dataframe
hdf_RNK_SHAPE = stations_spatial.filter("\"krs_name\"='Landkreis Rhein-Neckar-Kreis'" ).select('uuid','krs_name', 'SHAPE').head(1)
display(hdf_RNK_SHAPE.drop('SHAPE').collect())

gdf_RNK_SHAPE = gpd.GeoDataFrame(hdf_RNK_SHAPE.select('uuid', 'SHAPE').collect(), geometry='SHAPE')
gdf_RNK_SHAPE=gdf_RNK_SHAPE.rename_geometry('geometry')
display(gdf_RNK_SHAPE.head(10))
````

````Python
# Use OSMNX-method to download network graph from polygon
import osmnx as ox
ox.config(use_cache=True, log_console=True)

cf = '["highway"~"motorway"]'
g = ox.graph_from_polygon(polygon = gdf_RNK_SHAPE['geometry'][0], network_type = 'drive',custom_filter=cf)
````

Check if the network graph object has been successfully downloaded and stored as dataframe "g" and __plot the graph__
````Python
# Check successful object download
g

# Plot OSMNX highway network graph data
fig, ax = ox.plot_graph(g)
````
![](/exercises/ex6/images/6.2.4-osmx_highway_plot.png)

Load graph nodes and __edges into geopandas dataframes__
````Python
# Create geodataframes from network graph
gdf_nodes,gdf_edges = ox.graph_to_gdfs(g, nodes=True, edges=True)
gdf_edges
````
<br>![](/exercises/ex6/images/6.2.5-gdf_edges.png)  

<br>

In order to load the graph dataframes into SAP HANA, the __network arrays__ from the geopandas dataframe __require to be str-column converted__ into pandas dataframes
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
![](/exercises/ex6/images/6.2.6-pd_edges.png)  

<br>


Create the HANA dataframe for the __street network edges__
````Python
# Create a HANA dataframe from the German highway-network edges pandas dataframe 
from hana_ml.dataframe import create_dataframe_from_pandas

hdf = create_dataframe_from_pandas(
    connection_context=conn, replace=True,
    pandas_df=pd_edges,
    geo_cols=["geometry"],
    srid=4326,
    table_name="GEO_GERMANY_HIGHWAYS", primary_key='ID'
    , drop_exist_tab=True, force=True)

german_highways = conn.sql('select * from "GEO_GERMANY_HIGHWAYS"')
german_highways.head(3).collect()
````
![](/exercises/ex6/images/6.2.7-german_highway_edges_hdf.png)  
<br>

In order to calculate the distance btw station and Germany highway network, we create a __list of the German region "Landkreis" areas__, so we can calculate the distance in batches of stations within a regional area.
````Python
# Prepare a list of all krs_mame values for the distance calculation
df=stations_spatial.distinct('krs_name').collect()
krs=list(set(list(df['krs_name'])))
print(sorted(krs))
````
<br>![](/exercises/ex6/images/6.2.8-german_landkreis_liste.png)


Using this advanced SQL statement block
- we precalculate a __single multilinestring__ for the complete German highway network
- then __calculate the spatial distance__ between the multilinestring and the station points using the HANA spatial function __ST_DISTANCE__, we select the stations in batches of "Landkreis" regions
- store the calculated disctance to a table
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
								FROM GEO_GERMANY_HIGHWAYS 
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
         		from STATION_PRICECLASSIFICATION S, GAS_STATIONS G
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

Finally, we can review the station-highway distances.
````Python
stations_hwaydist=conn.table("STATION_HWAYDIST")
display(stations_hwaydist.head(5).collect())

````
![](/exercises/ex6/images/6.2.9-german_highwaydist.png)

<br>








