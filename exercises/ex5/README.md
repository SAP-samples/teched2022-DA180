# Exercise 5 - Apply Forecasting to multi-model data

In this exercise, we will create...

assumption ./datasets is your local path where you have downloaded project file to

Prepare
````Python

pip install -r requirements_importet.txt
import hana_ml



````


## Exercise 5.1 Load, prepare and explore fuel station datasets<a name="subex1"></a>

After completing these steps you will have created...  
Download stations.csv file from [here](https://dev.azure.com/tankerkoenig/_git/tankerkoenig-data?path=/stations/stations.csv) or for your convevience, find a copy in this github ./data/fuelprice/stations.csv.

1. Execute the following Python step to import the stations.csv-file into your HANA system.  
Note, replace TECHED_USER_### with your specific / assinged HANA system userid or schema.
````Python
# load gas station data from csv
stations_pd = pd.read_csv('./datasets/stations.csv', sep=',', header=None, skiprows=1,
                          names=["uuid","name", "brand", "street","house_number",
                                  "post_code", "city", "latitude", "longitude"])

# create hana dataframe/DB table from pandas dataframe
stations_hdf = create_dataframe_from_pandas(
        conn,
        stations_pd,
        schema='TECHED_USER_###',
        table_name="GAS_STATIONS",
        force=True,
        replace=True,
        drop_exist_tab=False,
        geo_cols=[("longitude", "latitude")], srid=4326
    )

print("There are", stations_hdf.count(), "service stations in Germany", "\n")

stations_hdf.head(2).collect()
````

The following result will be presented
<br>![](/exercises/ex5/images/5.1.1-loadstations.png)


2.	Execute the following lines of python code to import the Germany regional "Landkreise" areas shapefile.  
Download georef-germany-kreis.zip file from [here](https://data.opendatasoft.com/explore/dataset/georef-germany-kreis%40public/export/?disjunctive.lan_code&disjunctive.lan_name&disjunctive.krs_code&disjunctive.krs_name&disjunctive.krs_name_short!%5Bimage.png%5D(attachment:image.png)&disjunctive.krs_name_short) or for your convevience, find a copy in this github ./data/fuelprice/georef-germany-kreis.zip.  
Note, replace TECHED_USER_### with your specific / assinged HANA system userid or schema.
````Python
# create dataframe from shapefile for german regions "Landreise"
regions_hdf = create_dataframe_from_shapefile(
  connection_context=conn,
  shp_file='./datasets/georef-germany-kreis.zip',
  srid=25832,
  schema='TECHED_USER_###',
  table_name="GEO_GERMANY_REGIONS")

regions_hdf.drop('year').head(5).collect()

````
The following result will be presented
<br>![](/exercises/ex5/images/5.1.2-loadshapefileresults.png)

 3. Use SAP HANA spatial intersection to filter the fuel stations in Germany to those close to SAP Headquarters regions "Rhein-Neckar-Kreis", Mannheim and Heidelberg.

````Python
# filter service stations in Germany using SAP HANA spatial intersect
stations_rnk_hdf = stations_hdf.join(regions_hdf, 
  '"longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1').filter(
  "\"krs_name\"='Landkreis Rhein-Neckar-Kreis' or \"krs_name\"='Stadtkreis Heidelberg' or \"krs_name\"='Stadtkreis Mannheim'"
  )

# Show the SQL statement for the HANA dataframe "stations_rnk_hdf"
print(stations_rnk_hdf.select_statement, "\n")

# Show the number of service stations in selected spatial area
print("Number of Serice Stations in the Rhein-Neckar area", stations_rnk_hdf.count())

````
The following result will be presented
<br>![](/exercises/ex5/images/5.1.3-spatialfilterstations_res.png)

4. Visualize stations on map in Python.

````Python
# filter service stations in Germany to those NOT within the "Rhein-Neckar-Kreis"-region
stations_GER_hdf = stations_hdf.join(regions_hdf, 
 '"longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1').filter(
 "\"krs_name\"!='Landkreis Rhein-Neckar-Kreis' AND \"krs_name\"!='Stadtkreis Heidelberg' AND \"krs_name\"!='Stadtkreis Mannheim'"
 )

# number of service stations in Germany, excluding the ones selected around the SAP Headquarters and area
print("Number of Service Stations in Germany, excluding the one in 'Rhein-Neckar-Kreis'-region",stations_GER_hdf.count()) 

````
The following result will be presented
<br>![](/exercises/ex5/images/5.1.4-stationsGER_res.png)

````Python
# Collecting the HANA dataframe fuel stations point location spatial data for visualization into geopandas dataframes
stations_rnk_pd = stations_rnk_hdf.collect()
stations_rnk_geopands = gpd.GeoDataFrame(
    stations_rnk_pd, geometry=gpd.points_from_xy(stations_rnk_pd.longitude, stations_rnk_pd.latitude))

stations_GER_pd = stations_GER_hdf.collect()
stations_GER_geopands = gpd.GeoDataFrame(
    stations_GER_pd, geometry=gpd.points_from_xy(stations_GER_pd.longitude, stations_GER_pd.latitude))

# Collecting the HANA dataframe Germany region sspatial data for visualization into a geopandas dataframe
regions_pd = regions_hdf.collect()
regions_geopands = gpd.GeoDataFrame(regions_pd, geometry='SHAPE') 

````

````Python
#Plot gepandas dataframes 
fig, ax = plt.subplots(figsize=(12,12))
ax.set_xlim((5,16))
ax.set_ylim((47,55.5))

regions_geopands.plot(ax=ax, facecolor='Grey', edgecolor='k')
stations_GER_geopands.plot(ax=ax, marker='.',  color='blue', markersize=4, label='fuel stations in Germany ')
stations_rnk_geopands.plot(ax=ax, marker='.',  color='red', markersize=4, label='fuel stations near SAP HQ region')

ax.legend()
ax.set_title('Fuel Service Stations in Germany', pad=20)
fig = ax.get_figure()
fig.tight_layout()

````
The following result will be presented
<br>![](/exercises/ex5/images/5.1.5-stationsGER_plot.png)

## Exercise 5.2 Load, prepare and explore fuel price datasets<a name="subex2"></a>

After completing these steps you will have...
Download September fuel price data from [here](https://dev.azure.com/tankerkoenig/_git/tankerkoenig-data?path=/prices/2022/09) or or for your convevience, find a copy in this github ./data/fuelprice/  
Use ZIP-download like  and then extract the ZIP-file to your local ./datasets/-directory
<br>![](/exercises/ex5/images/5.2.0-download_fuelpricedata.png)

1.	Use this ...
````Python
# retrieve hana fuel price csv-file name into a Python list
mypath='./datasets/09/09'
from os import listdir
from os.path import isfile, join
pricefiles = [f for f in listdir(mypath) if isfile(join(mypath, f))]
#pricefiles

# load fuel price data for the 
gp_tmp_pd = {}
for file in pricefiles:
    gp_tmp_pd[file] = pd.read_csv('./datasets/09/09/{}'.format(file), sep=',', header=0, skiprows=1,
                                      names=["date", "station_uuid", "diesel", "e5", "e10", "dieselchange", "e5change", "e10change"],
                                      usecols=["date", "station_uuid", "diesel", "e5", "e10", "dieselchange", "e5change", "e10change"])
    gasprices_hdf = create_dataframe_from_pandas(
        conn, gp_tmp_pd[file],
        schema='TECHED_USER_###', table_name="GAS_PRICES",
        append=True)
    
# Show row count for uploaded fuel price data
gasprices_hdf.count()
````
<br>![](/exercises/ex5/images/5.2.1-priceupload_info.png)
<br>![](/exercises/ex5/images/5.2.2-price_rowcount.png)


2.	Analyse and explore the fuel price data from Python

````Python
# create hana dataframe including all gas prices in Germany in 2022 uploaded
fuelprice_all_hdf = conn.sql('select * from "GAS_PRICES"')

print("There are", fuelprice_all_hdf.count(), "records in the dataset", "\n")

fuelprice_all_hdf.sort('date', desc=True).head(3).collect()

````
<br>![](/exercises/ex5/images/5.2.3-pricedata_loaded.png)

````Python
# Selecting columns in focus
fuelprice_all_hdf=fuelprice_all_hdf.select('date', 'station_uuid', 'e5')
#display(fuelprice_all_hdf.head(3).collect())

# Count the price changes per fuel service station
display(fuelprice_all_hdf.agg([('count', 'e5', 'N')], group_by='station_uuid').collect())

````
<br>![](/exercises/ex5/images/5.2.4-pricechange_station.png)

````Python
# Show e5 value distribution to identify outlier data ranges

# Distribution Histogram (incl. binnning)
from hana_ml.visualizers.eda import EDAVisualizer
f = plt.figure(figsize=(8,3))
ax1 = f.add_subplot(111)

eda = EDAVisualizer(ax1)
ax, dist_data = eda.distribution_plot( data=fuelprice_all_hdf, column="e5", bins=50, 
                                      title="Distribution of E5 prices", debrief=False)
plt.show()

````
<br>![](/exercises/ex5/images/5.2.5-price_dist_plot.png)

````Python
# Filter outliers
fuelprice_all_hdf=fuelprice_all_hdf.filter('"e5" > 1.3 and "e5"< 2.8')

# Distribution Histogram (incl. binnning)
from hana_ml.visualizers.eda import EDAVisualizer
f = plt.figure(figsize=(8,3))
ax1 = f.add_subplot(111)

eda = EDAVisualizer(ax1)
ax, dist_data = eda.distribution_plot( data=fuelprice_all_hdf, column="e5", bins=30, 
                                      title="Distribution of E5 prices", debrief=False)
plt.show()

````
<br>![](/exercises/ex5/images/5.2.6-price_dist_plot2.png)

````Python
# M4 sampling and time series plot
%matplotlib inline
from hana_ml.visualizers.m4_sampling import m4_sampling
fuelprice_sample=m4_sampling(fuelprice_all_hdf.select('date', 'e5'), 200)
#fuelprice_sample.head(6).collect()

fuelprice_sample_pd=fuelprice_sample.collect()
fuelprice_sample_pd.set_index(fuelprice_sample_pd.columns[0], inplace=True)
fuelprice_sample_pd.sort_index(inplace=True)
fuelprice_sample_pd=fuelprice_sample_pd.astype(float)
#ax.set_ylim((1.3,2.8))
ax = fuelprice_sample_pd.plot(figsize=(20,8))

````
<br>![](/exercises/ex5/images/5.2.7-price_timeseries_plot.png)

````Python
# timeseries_box_plot
from hana_ml.visualizers.eda import timeseries_box_plot
f = plt.figure(figsize=(20, 6))
timeseries_box_plot(data=fuelprice_sample, col="e5", key="date", cycle="MONTH")

````
<br>![](/exercises/ex5/images/5.2.8-price_timeseries_boxplot.png)

## Exercise 5.3 Forecast fuel prices<a name="subex3"></a>

Step 1 - Select price data for local region

````Python
# Refelect number of service stations in local regrion close to SAP HQ
print("Number of Serice Stations in the Rhein-Neckar area", stations_rnk_hdf.count(), "\n")

# Create a fuel price data HANA dataframe, filtering to local area stations using HANA spatial intersect-filtering
fuelprice_rnk_hdf=conn.sql(
"""
select "date", "station_uuid", "e5" 
    from "GAS_PRICES" 
    WHERE "station_uuid" 
         IN (SELECT "uuid" 
              FROM (SELECT * FROM "GAS_STATIONS") AS S, 
                   (SELECT * FROM "GEO_GERMANY_REGIONS" 
                    WHERE "krs_name"=\'Landkreis Rhein-Neckar-Kreis\' or "krs_name"=\'Stadtkreis Heidelberg\' 
                          or "krs_name"=\'Stadtkreis Mannheim\' ) AS G 
              WHERE "longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1);
"""
)
display(fuelprice_rnk_hdf.collect()) 

````
<br>![](/exercises/ex5/images/5.3.1-price_data_region_rnk.png)

````Python
print( "The dataset covers the time period starting from: ")
print( fuelprice_rnk_hdf.sort('date').select('date').head(1).collect(), "\n")
print( "... and ends at: ")
print( fuelprice_rnk_hdf.sort('date', desc=True).select('date').head(1).collect()) 

````
<br>![](/exercises/ex5/images/5.3.2-price_fc_timeperiod.png)

````Python
# in order to predict the last 7 days, we restict our training data to be earlier than 2022-09-23
train_rnk_hdf  = fuelprice_rnk_hdf.filter('"date" < \'2022-09-23 00:00:00.000\'')

# ground truth
test_groundtruth_rnk_hdf  = fuelprice_rnk_hdf.filter('"date" >= \'2022-09-23 00:00:00.000\'')

# create test dataset, same as ground truth only target column values set to 0
test_rnk_hdf = test_groundtruth_rnk_hdf.drop(['e5'])
test_rnk_hdf = test_rnk_hdf.add_constant('e5', 0)
test_rnk_hdf = test_rnk_hdf.cast('e5', 'DOUBLE')

#test_groundtruth_rnk_hdf.sort('date').head(3).collect()
print('Number of forecast training rows', train_rnk_hdf.count())
print('Number of forecast testing rows', test_rnk_hdf.count()) 

````
<br>![](/exercises/ex5/images/5.3.3-price_fc_rows.png)


Step 2 - Model fuel price forecast

````Python
# Prepare holiday data table (for simplicity an empty table) for the forecast model function
conn.create_table(
    table='PAL_ADDITIVE_MODEL_ANALYSIS_HOLIDAY',
    schema='TECHED_USER_999',
    table_structure={'GROUP_IDXXX': 'INTEGER', 'ts': 'TIMESTAMP', 'NAME': 'VARCHAR(255)', 
                     'LOWER_WINDOW': 'INTEGER', 'UPPER_WINDOW': 'INTEGER'})
holiday_data_hdf = conn.sql('select * from "TECHED_USER_999"."PAL_ADDITIVE_MODEL_ANALYSIS_HOLIDAY"')
````
<br>![](/exercises/ex5/images/02_02_0010.png)

````Python
# Build a forecast model per station in parallel using PAL Additive Model Forecast (aka Prophet)-forecasting function
from hana_ml.algorithms.pal.tsa.additive_model_forecast import AdditiveModelForecast

amf = AdditiveModelForecast(massive=True,growth='linear',
                                changepoint_prior_scale=0.06,
                                weekly_seasonality='True',
                                daily_seasonality='True'
                                )

amf.fit(data=train_rnk_hdf, key="date", group_key="station_uuid", holiday=holiday_data_hdf)

amf.runtime 

````
<br>![](/exercises/ex5/images/5.3.4-fit_runtime.png)

````Python
# Which SQL statement was actually executed in SAP HANA?

#print(conn.last_execute_statement)
print(amf.get_fit_execute_statement()) 

````
<br>![](/exercises/ex5/images/5.3.5-fit_SQLstatement.png)

````Python
# How do the AdditiveModelAnalysis segmented model look like?
pd.set_option('max_colwidth', None)
df=amf.model_.head(5).collect()

display(df.style.set_properties(**{'text-align': 'left'})) 

````
<br>![](/exercises/ex5/images/5.3.6-fitted_models.png)

````Python
# Filter errornous test data
test_rnk_hdf=test_rnk_hdf.filter('"station_uuid" not in (\'3ec1e50e-aba5-436c-960a-423b2b8a37ed\', \'51d4b58a-a095-1aa0-e100-80009459e03a\')')

# predict returns an array of three dataframes. The first contains the forecasted values
fc_result, fc_decomp, fc_error = amf.predict(data=test_rnk_hdf, key="date", group_key="station_uuid")

#print(amf.get_predict_execute_statement())

# look at forecast result data
display(fc_result.head(3).collect(), "\n")

# Look the time series decomposition result data
fc_decomp.head(3).collect()

# Check for errors in any of the station_uuids
fc_error.head(3).collect() 

````
<br>![](/exercises/ex5/images/5.3.7-forecast_prediction.png)
<br>![](/exercises/ex5/images/5.3.8-forecast_pred_decomp.png)
<br>![](/exercises/ex5/images/5.3.9-forecast_pred_error.png)

Step 3 - Analyse Forecast Accuracy

````Python
import 

````
<br>![](/exercises/ex5/images/02_02_0010.png)

````Python
import 

````
<br>![](/exercises/ex5/images/02_02_0010.png)

## Summary

You've now ...

Continue to - [Exercise 6 - Excercise 6 ](../ex6/README.md)
