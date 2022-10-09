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

````Python
import 

````

After completing these steps you will have...

1.	Enter this code.
```abap
DATA(lt_params) = request->get_form_fields(  ).
READ TABLE lt_params REFERENCE INTO DATA(lr_params) WITH KEY name = 'cmd'.
  IF sy-subrc = 0.
    response->set_status( i_code = 200
                     i_reason = 'Everything is fine').
    RETURN.
  ENDIF.

```

2.	Click here.
<br>![](/exercises/ex5/images/02_02_0010.png)


## Exercise 5.3 Forecast fuel prices<a name="subex3"></a>

## Summary

You've now ...

Continue to - [Exercise 6 - Excercise 6 ](../ex6/README.md)
