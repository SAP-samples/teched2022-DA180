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

````
<br>![](/exercises/ex6/images/6.3.2-price_class_basetable.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


Text
````Python
import 

````
<br>![](/exercises/ex6/images/02_019_0010.png)


## Reference info OSMNX import


## Summary

You've now concluded the last exercise, congratulations! 

````SQL
SELECT * FROM "AIS_DEMO"."GDELT_GEG" WHERE "lang" = 'en';
````
