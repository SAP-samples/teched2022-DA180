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
stations_price_indicators.head(3).collect() 

````
<br>![](/exercises/ex6/images/6.1.5-stations_price_indicators_fin.png)

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




## Exercise 6.2 Enrich fuel station classification data with spatial attributes<a name="subex2"></a>

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
<br>![](/exercises/ex6/images/02_02_0010.png)

## Exercise 6.3 Build fuel station classification model and evaluate impact of attributes<a name="subex3"></a>

## Summary

You've now concluded the last exercise, congratulations! 

````SQL
SELECT * FROM "AIS_DEMO"."GDELT_GEG" WHERE "lang" = 'en';
````
