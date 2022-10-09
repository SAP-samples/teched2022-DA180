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
