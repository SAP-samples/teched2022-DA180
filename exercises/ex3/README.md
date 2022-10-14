# Exercise 3 - Import and export spatial vector and raster data, spatial clustering

In this exercise, we will deal with spatial vector and raster data. You can think of vector data as real geometries, e.g. polygons, and there are many file formats for vector data. Probably the most common format is Esri shapefiles. Spatial raster data are images. For each pixel in a spatial image, there is a specific spatial measure, e.g. the elevation or the land use class. Relational databases are not suitable to store images, but there are ways to convert a raster to a vector file.
First we will upload some spatial vector data. We'll start with an Esri shapefile and use SAP HANA Database Explorer to pull the data into a table. Next we will use QGIS to ingest a kml file.
We will then vectorize a raster file which contains information about population density and upload the data using GDAL.
Finally, we will show some spatial clustering techniques.

## Exercise 3.1 - Import and export spatial vector data<a name="subex1"></a>

There is some public data describing the [land use in Australia](https://data.sa.gov.au/data/dataset/land-use-generalised/resource/797444b1-633f-47ed-804d-fcbbeafca352). Since this file is pretty large, we "clipped" it. This clipped, downsized version of the land use data is the [data folder](../../data/vector).

Open the SAP HANA Database Explorer, right click on the T22 system, and choose "import data". A new screen opens, choose "import Esri shapefile".

![](images/dbx1.png)

In the next step, choose the zip file which contains the shapefiles.

![](images/dbx2.png)

Then choose the database schema.

![](images/dbx3.png)

We need to provide the spatial reference system ID, which is 4326, and hit import.

![](images/dbx4.png)

The imported data looks like this. There are polygons and land use descriptions.

![](images/landuse1.png)

We can use QGIS for a more colorful visualization.

![](images/landuse2.png)

kml

[![Watch the video](images/landuse2.png)](images/importkml.mp4)




## Exercise 3.2 Sub Exercise 2 Description<a name="subex2"></a>

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
<br>![](/exercises/ex3/images/02_02_0010.png)

## Summary

You've now ...

Continue to - [Exercise 4 - Excercise 4 ](../ex3/README.md)
