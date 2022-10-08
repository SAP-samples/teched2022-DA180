# Exercise 6 - Build a ML classification model on multi-model data

In this exercise, we will create...

## Exercise 6.1 Sub Exercise 1 Description<a name="subex1"></a>

After completing these steps you will have created...

1. Click here.
<br>![](/exercises/ex6/images/02_01_0010.png)

2.	Insert this line of code.
```abap
response->set_text( |Hello ABAP World! | ). 
```

````Python

import hana_ml
from hana_ml.docstore import create_collection_from_elements

respGEG = requests.get('http://data.gdeltproject.org/gdeltv3/geg_gcnlapi/20211108120300.geg-gcnlapi.json.gz')

with gzip.open(BytesIO(respGEG.content), 'rt', encoding='utf-8') as f:
    content = f.read().splitlines()


````
Once stored in a HANA collection, we can query the data using SQL.

````SQL
SELECT * FROM "AIS_DEMO"."GDELT_GEG" WHERE "lang" = 'en';
````

![](images/c02_01_0010.png)

## Exercise 6.2 Sub Exercise 2 Description<a name="subex2"></a>

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

## Summary

You've now concluded the last exercise, congratulations! 

