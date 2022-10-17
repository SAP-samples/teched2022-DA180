# Exercise 5 - Apply Forecasting to multi-model data

In this exercise, we want to apply SAP HANA Cloud multi-model processing techniques to prepare and assemble geo-located fuel station data of Germany. We then apply segmented forecasting techniques using the [Predictive Analysis Library (PAL)](https://help.sap.com/docs/HANA_CLOUD_DATABASE/319d36de4fd64ac3afbf91b1fb3ce8de/c9eeed704f3f4ec39441434db8a874ad.html?locale=en-US) to build and apply forecast models for each station's "e5" car fuel price.

The exercise is composed from the perspective of a Data Scientist working in a Python (Juypter Notebook) environment, leveraging the [Python Machine Learning client for SAP HANA](https://help.sap.com/doc/1d0ebfe5e8dd44d09606814d83308d4b/latest/en-US/index.html). For reference information regarding the setup and configuration of your Python environment see [Python environment preparation](/exercises/ex9_appendix/README.md).

The __objective and goal__ for this exercise is
- in ex 5.1 to download the stations and regions geo-data, save them in SAP HANA CLoud, apply HANA-spatial filtering to the data and visualize it
- in ex 5.2 to download the fuel price data, save it to SAP HANA Cloud and explore the time series data visually
- in ex 5.3 to build e5 price forecast models on the spatially filtered stations and visualize the predicted fuel price data.

As an extra and optional exercise, the [add-on section](/exercises/ex5/README.md#subexADDON) describes how to evaluate the forecast model accuracy for each stations forecast model.

You can approach the exercises by  copy & paste of the Python code snippets from this document or open the Jupyter Notebook file provided [here](/exercises/ex5/DA180-Exercise5-Apply%20Forecasting%20to%20multi-model%20data-Student.ipynb).

## Preparation steps in your Python Jupyter Notebook
Import the required python packages
````Python
# Import HANA-ML package and check version (should be 2.14.22101400 or newer)
import hdbcli
import hana_ml
from hana_ml import dataframe
from hana_ml.dataframe import create_dataframe_from_pandas, create_dataframe_from_shapefile

# Import additional packages
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import geopandas as gpd
from shapely.geometry import Point, Polygon

print(hana_ml.__version__)
````

Connect to the SAP HANA Cloud database
````Python
# Provide your SAP HANA Cloud connection details
host = '[YourHostName]'
port = 443
user = '[YourUser]'
passwd = '[YourUserPassword]'
````
````Python
# Establish the SAP HANA Cloud connection as "conn"
conn= dataframe.ConnectionContext(address=host, port=port, user=user, password=passwd,
                               encrypt='true' ,sslValidateCertificate='false')
````

## Exercise 5.1 - Load, prepare and explore fuel station datasets<a name="subex1"></a>



__Preparation Step - file downloads__  
Note, the data used along with the exercises is thereas used only for the purpose of your personal education, for details about the use case data sources and licenses see the [data reference section](/exercises/ex5/README.md#subexDATAREF)  

Download the following files to your project directory ./teched2022-DA180/data/fuelprice
- Germany Landkreise regions shapefile from [here](https://data.opendatasoft.com/explore/dataset/georef-germany-kreis@public/download/?format=shp&timezone=Europe/Berlin&lang=en) and save it to ./data/fuelprice/
- Germany fuel station data set from [here](https://dev.azure.com/tankerkoenig/_git/tankerkoenig-data?path=/stations/stations.csv) and save it to ./data/fuelprice/
- Germany fuel price September 2022 data (or multiple months) from [here](https://dev.azure.com/tankerkoenig/_git/tankerkoenig-data?path=/prices/2022/09) as ZIP-download and extract the ZIP-file to a subfolder per month like ./data/fuelprice/09  
![](/exercises/ex5/images/5.2.0-download_fuelpricedata.png)
<br>

Your project data directory would look like
````Python
#!ls data/fuelprice
!dir data\\fuelprice
````
![](/exercises/ex5/images/5.0.1-downloaded-files.png)  
<br>


__Step 1 - Import the fuel stations data__  
Execute the following Python code to import the stations.csv-file into your HANA system.  

Note, any __uploaded data will be uploaded to the schema of your SAP HANA Cloud connection database userid__. Thus here in this workshop, it would for example be a user like __TECHED_USER_###__ (where ### would need to be replaced with the 3-digits of your specific / assinged HANA system userid or schema).
- During data upload and dataframe creation using the __create_dataframe_from_pandas__-method, you can use the schema=-option if you seek to save the table to a different schema than the default user schema.
````Python
# load gas station data from csv
stations_pd = pd.read_csv('./data/fuelprice/stations.csv', sep=',', header=None, skiprows=1,
                          names=["uuid","name", "brand", "street","house_number",
                                  "post_code", "city", "latitude", "longitude"])

# create hana dataframe/DB table from pandas dataframe
stations_hdf = create_dataframe_from_pandas(
        conn,
        stations_pd,
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
![](/exercises/ex5/images/5.1.1-loadstations.png)
<br>
<br>

__Step 2 - Import the Germany "Landkreise"-regions shapefile__  
Execute the following lines of python code to import the Germany "Landkreise" regional areas-shapefile.  

````Python
# create dataframe from shapefile for german regions "Landreise"
regions_hdf = create_dataframe_from_shapefile(
  connection_context=conn,
  shp_file='./data/fuelprice/georef-germany-kreis.zip',
  srid=25832,
  table_name="GEO_GERMANY_REGIONS")

regions_hdf.drop('year').head(5).collect()
````
The following result will be presented
![](/exercises/ex5/images/5.1.2-loadshapefileresults.png)
<br>
<br>
 __Step 3 - Use SAP HANA spatial operations to filter stations__  
 Use SAP HANA spatial intersection-function to filter the fuel stations in Germany to those close to SAP Headquarters "Landkreise"-regions of "Rhein-Neckar-Kreis", Mannheim and Heidelberg.

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
![](/exercises/ex5/images/5.1.3-spatialfilterstations_res.png)
<br>
<br>
__Step 4 - Visualize the stations on a map in Python__  
First we spatially filter the remaining fuel stations into another HANA dataframe.
````Python
# filter service stations in Germany to those NOT within the "Rhein-Neckar-Kreis"-region
stations_GER_hdf = stations_hdf.join(regions_hdf, 
 '"longitude_latitude_GEO".ST_SRID(25832).st_transform(25832).st_intersects(SHAPE)=1').filter(
 "\"krs_name\"!='Landkreis Rhein-Neckar-Kreis' AND \"krs_name\"!='Stadtkreis Heidelberg' AND \"krs_name\"!='Stadtkreis Mannheim'"
 )

# Count the number of service stations in Germany, excluding the ones selected around the SAP Headquarters and area
print("Number of Service Stations in Germany, excluding the one in 'Rhein-Neckar-Kreis'-region",stations_GER_hdf.count()) 
````
The following result will be presented
![](/exercises/ex5/images/5.1.4-stationsGER_res.png)
<br>

Then for the visualization, we collect the regions-shape and fuel station point data into __geopandas__ dataframes. This step may run for more than a minute.
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

<br>
We can now create a map plot of stations and regions with this Python code  

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
The following map will be shown
![](/exercises/ex5/images/5.1.5-stationsGER_plot.png)
<br>
<br>

## Exercise 5.2 - Load, prepare and explore fuel price datasets<a name="subex2"></a>
__Step 1 - Import fuel price csv-files__  
With the following step, you can import all csv-files from a local folder into a single HANA table represented by a HANA dataframe using the __createcreate_dataframe_from_pandas__-method.   
Here it is assumed that each months data is located in one folder. 

Note, the demo screenshots in exercise 5 and 6 may show results based on downloaded data for multiple months in 2022 and thus may differ, if you had only downloaded the September 2022 data.

````Python
# Retrieve hana fuel price csv-file name into a Python list
mypath='./data/fuelprice/09/09'
from os import listdir
from os.path import isfile, join
pricefiles = [f for f in listdir(mypath) if isfile(join(mypath, f))]
#pricefiles

# load fuel price data into a HANA table and create hana dataframe
gp_tmp_pd = {}
for file in pricefiles:
    gp_tmp_pd[file] = pd.read_csv('./data/fuelprice/09/09/{}'.format(file), sep=',', header=0, skiprows=1,
                                      names=["date", "station_uuid", "diesel", "e5", "e10", "dieselchange", "e5change", "e10change"],
                                      usecols=["date", "station_uuid", "diesel", "e5", "e10", "dieselchange", "e5change", "e10change"])
    fuelprices_hdf = create_dataframe_from_pandas(
        conn, gp_tmp_pd[file],
        table_name="GAS_PRICES",
        append=True,
        table_structure={"date": "TIMESTAMP", "station_uuid": "NVARCHAR(5000)", 
                         "diesel": "DOUBLE", "e5": "DOUBLE", "e10": "DOUBLE",
                         "dieselchange" : "INTEGER","e5change" : "INTEGER","e10change" : "INTEGER"})
````
Shows the following output
![](/exercises/ex5/images/5.2.1-priceupload_info.png)

<br>

__Step 2 - Analyse and explore the fuel price data__  
Use HANA dataframe methods to display and count the number of rows in the HANA table.

````Python
# Count the rows and show top3 rows of the hana dataframe
print("There are", fuelprices_hdf.count(), "records in the dataset", "\n")

fuelprice_all_hdf.sort('date', desc=True).head(3).collect()

````
![](/exercises/ex5/images/5.2.3-pricedata_loaded.png)
Note, the rowcount output for September would be 10.575.771, or at 90.931.410 if January-September data was loaded.
<br>
<br>
Now, lets focus on the __analysis of the E5 car fuel data__.  
E5 petrol is the standard car fuel in Europe, made up of 95% unleaded petrol plus 5% ethanol.
````Python
# Selecting columns in focus, creating a derived dataframe "fuelprice_all_hdf"
fuelprice_all_hdf=fuelprices_hdf.select('date', 'station_uuid', 'e5')

# Count the price changes per fuel service station using HANA dataframe group-by aggregation method
display(fuelprice_all_hdf.agg([('count', 'e5', 'N')], group_by='station_uuid').collect())
````
![](/exercises/ex5/images/5.2.4-pricechange_station.png)
Note, the row counts shown are derived from 7 months of fuel price data.

<br>

Next we want to visually __explore the e5 price data using a distribution histogram__, allowing us to identify outlier data ranges.
````Python
# Plot a HANA-ML Distribution Histogram (incl. value binnning)
from hana_ml.visualizers.eda import EDAVisualizer
f = plt.figure(figsize=(8,3))
ax1 = f.add_subplot(111)

eda = EDAVisualizer(ax1)
ax, dist_data = eda.distribution_plot( data=fuelprice_all_hdf, column="e5", bins=50, 
                                      title="Distribution of E5 prices", debrief=False)
plt.show()

````
![](/exercises/ex5/images/5.2.5-price_dist_plot.png)
It appears as if there is price data ranging from near 0€ until up to 5€ per liter.  
Thus let's filter the price data using the HANA dataframe-filter method.
<br>

````Python
# Filter outliers
fuelprice_all_hdf=fuelprice_all_hdf.filter('"e5" > 1.3 and "e5"< 2.8')

# Re-run Distribution Histogram (incl. binnning)
from hana_ml.visualizers.eda import EDAVisualizer
f = plt.figure(figsize=(8,3))
ax1 = f.add_subplot(111)

eda = EDAVisualizer(ax1)
ax, dist_data = eda.distribution_plot( data=fuelprice_all_hdf, column="e5", bins=30, 
                                      title="Distribution of E5 prices", debrief=False)
plt.show()
````
The distribution plot now shows a more focused plot of the price data.![](/exercises/ex5/images/5.2.6-price_dist_plot2.png)


<br>

Now, in order the visualize the original time series data itself and in order to not pull the millions of data points to python, we use the __m4_sampling__ method of hana_ml. M4 is a visualization-oriented time series data aggregation method. The M4 width parameter (here 200) is an indicator to how many pixels wide the visualization plot will be and thus the datapoints to be reduced respectively.
````Python
# M4 sampling and time series plot
from hana_ml.visualizers.m4_sampling import m4_sampling

fuelprice_sample=m4_sampling(fuelprice_all_hdf.select('date', 'e5'), 200)

fuelprice_sample_pd=fuelprice_sample.collect()
fuelprice_sample_pd.set_index(fuelprice_sample_pd.columns[0], inplace=True)
fuelprice_sample_pd.sort_index(inplace=True)
fuelprice_sample_pd=fuelprice_sample_pd.astype(float)
 
ax = fuelprice_sample_pd.plot(figsize=(20,8))
````
![](/exercises/ex5/images/5.2.7-price_timeseries_plot.png)
<br>

Another time series aggregation plot is the monthly box-plot
````Python
# timeseries_box_plot
from hana_ml.visualizers.eda import timeseries_box_plot
f = plt.figure(figsize=(20, 6))
timeseries_box_plot(data=fuelprice_sample, col="e5", key="date", cycle="MONTH")
````
![](/exercises/ex5/images/5.2.8-price_timeseries_boxplot.png)
<br>
<br>
<br>

## Exercise 5.3 - Forecast the fuel prices per station <a name="subex3"></a>
In this section we now want to model a specific fuel price forecast for each gas station in parallel, also known as __segmented forecasting__ approach. As the fuel price time series is not a simple auto-regressive time series, but is dependent on external factors (e.g. holidays) and other (incl. irregular) changepoints we will apply the Additive-Model-Analysis (aka prophet) forecasting method from the [Predictive Analysis Library (PAL)](https://help.sap.com/docs/HANA_CLOUD_DATABASE/319d36de4fd64ac3afbf91b1fb3ce8de/7e78d06c0e504789bcc32256d3f7f871.html?locale=en-US). This forecast method can be applied in massive-mode, invoking the segmented execution approach (build forecast models by gas station in parallel).

__Step 1 - Select the price data for the local region and time range__  
For a more focused analysis, we want to model the forecasts only for the 171 gas stations in the regional area around the SAP headquarters.

````Python
# Reflect number of service stations in local regrion close to SAP HQ
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
![](/exercises/ex5/images/5.3.1-price_data_region_rnk.png)
<br>

Next, we want to sample the last week period of our time series fuel price data to be our time series test data, to evaluate the forecast quality.
````Python
# Identifying the first and last data of our time series
print( "The dataset covers the time period starting from: ")
print( fuelprice_rnk_hdf.sort('date').select('date').head(1).collect(), "\n")
print( "... and ends at: ")
print( fuelprice_rnk_hdf.sort('date', desc=True).select('date').head(1).collect()) 
````
![](/exercises/ex5/images/5.3.2-price_fc_timeperiod.png)
<br>

Based on the time series range, we now create 3 time series dataframes
- __train_rnk_hdf__ containing all price values up until the 2nd last week of the series
- __test_groundtruth_rnk_hdf__ containing the price values of the last week
- __test_rnk_hdf__ containing empty price values for our test series time values
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
![](/exercises/ex5/images/5.3.3-price_fc_rows.png)
<br>  


__Step 2 - Model the fuel price forecast__  
The Additive-Model-Analysis (aka prophet) forecasting method allows to add external factor and changepoint information as input to the analysis. Hence it requires us to pass-in a respective table or dataframe with the analysis. We use the dataframe create_table-method, to create the empty holiday-data needed.
- During table creation using the dataframe-connection __create_table__-method, you can use the schema=-option if you seek to save the table to a different schema than the default user schema.
````Python
# Prepare holiday data table (for simplicity an empty table) for the forecast model function
conn.create_table(
    table='PAL_ADDITIVE_MODEL_ANALYSIS_HOLIDAY',
    table_structure={'GROUP_IDXXX': 'INTEGER', 'ts': 'TIMESTAMP', 'NAME': 'VARCHAR(255)', 
                     'LOWER_WINDOW': 'INTEGER', 'UPPER_WINDOW': 'INTEGER'})
holiday_data_hdf = conn.sql('select * from "PAL_ADDITIVE_MODEL_ANALYSIS_HOLIDAY"')
````
<br>

Now we instantiate and execute the actual Additive-Model-Analysis forecast training (fit) method, in parallel for each station using the "massive=True" parameter.
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
![](/exercises/ex5/images/5.3.4-fit_runtime.png)
The forecast model training for all 171-gas station forecast models.  
<br>  
  
Which SQL statement was actually executed in SAP HANA? The AdditiveModelForecast method, like any other PAL function in the Python Machine Learning clients, provides methods (here: get_fit_execute_statement) to retrieve information about the executed statements, parameters and objects involved.
````Python
print(amf.get_fit_execute_statement()) 
````
![](/exercises/ex5/images/5.3.5-fit_SQLstatement.png)  
<br>  

How do the AdditiveModelAnalysis segmented models look like for each station?  
We can collect the returned "model_"-dataframe from the forecast-fit call.
````Python
# How do the AdditiveModelAnalysis segmented model look like?
pd.set_option('max_colwidth', None)
df=amf.model_.head(5).collect()

display(df.style.set_properties(**{'text-align': 'left'})) 
````
![](/exercises/ex5/images/5.3.6-fitted_models.png)  
<br>
  



__Step 3 - Forecast prediction and visualization__  
We now want to apply the trained forecast models for each station and __predict price values for the test period__ and visualize it all.  The AdditiveModelForecast-predict method applies station-specific forecast model to the test_rnk_hdf-dataframe. 
````Python
# The AdditiveModelForecast-PREDICT method returns an array of three dataframes.
fc_result, fc_decomp, fc_error = amf.predict(data=test_rnk_hdf, key="date", group_key="station_uuid")

# Look at forecast result data
display(fc_result.head(3).collect(), "\n")

# Look the time series decomposition result data
fc_decomp.head(3).collect()

# Check for errors in any of the station_uuids
fc_error.head(3).collect() 
````
![](/exercises/ex5/images/5.3.7-forecast_prediction.png)
![](/exercises/ex5/images/5.3.8-forecast_pred_decomp.png)
![](/exercises/ex5/images/5.3.9-forecast_pred_error.png)
Note a warning message might be given if there is no predict input-data for selected stations (group-ids).   
You could apply the print(amf.get_predict_execute_statement())-call to review the execute SQL statement for the predict call.  
<br>
Now, we want to __visualize the forecast data__ for a selected station
````Python
#Set a station variable for data filtering
station='018e8f3e-ae2f-40bc-89c1-bc3fe20eb462'

# Filter forecast train data (actuals) for station
act_train_1s=train_rnk_hdf.filter('"station_uuid" = \'{}\''.format(station)).sort('date', desc=False)
act_train_1s=act_train_1s.drop('station_uuid').rename_columns({'e5': 'ACTUAL'})

# Filter test data ground thruth (actuals) for station
act_gt_1s=test_groundtruth_rnk_hdf.filter('"station_uuid" = \'{}\''.format(station)).sort('date', desc=False)
act_gt_1s=act_gt_1s.drop('station_uuid').rename_columns({'e5': 'E5_ACTUAL'})

# Union actuals into one set
actual_1s=act_train_1s.union(act_gt_1s).sort('date')
display(actual_1s.head(10).collect())

# Filter forecast predictions
forecast_1s=fc_result.filter('"GROUP_ID" = \'{}\''.format(station)).sort('date', desc=False)
forecast_1s=forecast_1s.select('date', 'YHAT', 'YHAT_LOWER', 'YHAT_UPPER').rename_columns({'YHAT': 'PREDICTED'})
display(forecast_1s.head(2).collect()) 

````
The input data for the visualization as we just prepared it looks like
![](/exercises/ex5/images/5.3.13-fc_plot_input.png)
<br>  


Using the hana-ml Forecast-Lineplot visualization for the complete time period of data
````Python
# Forecast-Lineplot 
from hana_ml.visualizers.visualizer_base import forecast_line_plot
ax = forecast_line_plot(actual_data=actual_1s.set_index("date"),
                        pred_data=forecast_1s.set_index("date"),                
                    confidence=("YHAT_LOWER", "YHAT_UPPER"),
                    max_xticklabels=10, figsize=(15, 7))

ax.set_title('Fuel Price Actual and Forecast', pad=20)
plt.ylabel('Gas Price e5 [€]')
plt.show() 
````
The forecast visualization for the e5 price data shows several unusual changepoints in the time series.
![](/exercises/ex5/images/5.3.14-fc_plot_all.png)
<br>  


Let's plot another forecast visualization, more focused on the weeks at the end of the time series.
````Python
# Forecast-Lineplot for the last 3 weeks of data
from hana_ml.visualizers.visualizer_base import forecast_line_plot
ax = forecast_line_plot(pred_data=forecast_1s.set_index("date"),
                    actual_data=actual_1s.filter('"date" >= \'2022-09-07 00:00:00.000\'').set_index("date"),
                    confidence=("YHAT_LOWER", "YHAT_UPPER"),
                    max_xticklabels=10, figsize=(15, 5))

ax.set_title('Fuel Price Actual and Forecast', pad=20)
plt.ylabel('Gas Price e5 [€]')
plt.show() 
````
![](/exercises/ex5/images/5.3.15-fc_plot_last.png)  

<br>


## Summary

You've now concluded exercise 5 and successfully loaded station- and region-geo data, used spatial filtering and applied forecasting to fuel price data over a large number of fuel stations.

Continue now with [Exercise 6](../ex6/README.md) or you may extend with evaluating the forecast accurary in the following section first.

## Add-on section (optional) - Evaluate Forecast Accuracy<a name="subexADDON"></a>

In order to evaluate the forecast accuracy for each stations's model, we need to compare predicted forecast values (from the predict-results) with the actual ground-truth e5-values of the test data time period.
````Python
# Prepare a dataframe with the forecast predictions
fc_allgroups=fc_result.select('date', 'GROUP_ID', 'YHAT', 'YHAT_LOWER', 'YHAT_UPPER').rename_columns({'YHAT': 'PREDICTED'})

# Prepare a dataframe with the actual groundtruth values
act_allgroups=test_groundtruth_rnk_hdf.sort('date', desc=True).rename_columns({'e5': 'ACTUAL'})

# Join actual and predicted values in a new dataframe
testacc_allgroups=act_allgroups.alias('A').join(fc_allgroups.alias('F'), 
          'A."station_uuid"=F."GROUP_ID" and A."date" = F."date"',
          select=['station_uuid', ('A."date"', 'DATE'), 'ACTUAL', 'PREDICTED']).sort('DATE')
testacc_allgroups=testacc_allgroups.sort('DATE')

display(testacc_allgroups.head(10).collect()) 
````
![](/exercises/ex5/images/5.3.11-fc_acc_inputdata.png)
<br>


In order to store the forecast accuracy values for each station, we are preparing a table to store the data.
````Python
# Create a Forecast accuracy-measures table
conn.create_table(table='FORECAST_ACCURACY', 
                 table_structure={'station_uuid': 'NVARCHAR(5000)', 'STAT_NAME': 'NVARCHAR(10)', 'STAT_VALUE': 'DOUBLE'})
fc_acc=conn.table('FORECAST_ACCURACY')
````
<br>  

Finally, we caculate the forecast accuracy measures, iterating over each of the 171 gas stations and appending the values to the table previously created.
````Python
# Get alls stations uuids into a Python list "stations_all"
df=testacc_allgroups.distinct('station_uuid').collect()
stations_all=list(set(list(df['station_uuid'])))

# Calculate Forecast Accuracy Measure for each station 
from hana_ml.algorithms.pal.tsa.accuracy_measure import accuracy_measure
amres = {}
for station in stations_all:
    amres[station] = accuracy_measure(data=testacc_allgroups.filter('"station_uuid"=\'{}\''.format(station)
                                                                   ).select(['ACTUAL', 'PREDICTED']),
                                      evaluation_metric=['mse', 'rmse', 'mpe', 'et',
                                                         'mad', 'mase', 'wmape', 'smape',
                                                         'mape', 'mae'])
   
    amres[station]=amres[station].select(('\'{}\''.format(station),'station_uuid'), 'STAT_NAME', 'STAT_VALUE')
    amres[station].save('FORECAST_ACCURACY', append=True)

# Show the forecast accuracy table data    
fc_acc.collect() 

````
![](/exercises/ex5/images/5.3.12-fc_acc_results.png)

## Reference<a name="subexDATAREF"></a>

The __gas station and fuel price data__ is published on the public website [Tankerkönig](http://www.tankerkoenig.de/). This dataset contains the gas prices of all gas stations in Germany from 2014 until today as csv files. A record contains the station id, the datetime, prices for diesel, e5 and e10 and a change indicator. In a separate csv the data of the service stations including its geolocation is provided.

The data used along with the exercises is thereas used only for the purpose of your personal education. For non-commercial use the data is availble with the following license agreement https://creativecommons.org/licenses/by-nc-sa/4.0/.

The __German "Landkreise"-regional geo data__ is shared and can be downloaded from [data.opendatasoft.com/georef-germany-kreis](https://data.opendatasoft.com/explore/dataset/georef-germany-kreis%40public/export/?disjunctive.lan_code&disjunctive.lan_name&disjunctive.krs_code&disjunctive.krs_name&disjunctive.krs_name_short!%5Bimage.png%5D(attachment:image.png)&disjunctive.krs_name_short). This dataset is licensed under the "Data licence Germany – attribution – version 2.0", see https://www.govdata.de/dl-de/by-2-0 and allowed for commercial and non-commercial use under reference of the license.