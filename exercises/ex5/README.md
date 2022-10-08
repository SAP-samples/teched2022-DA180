# Exercise 5 - Apply Forecasting to multi-model data

In this exercise, we will create...

## Exercise 5.1 Sub Exercise 1 Description<a name="subex1"></a>

After completing these steps you will have created...

1. Click here.
<br>![](/exercises/ex5/images/02_01_0010.png)

2.	Insert this line of code.
```abap
response->set_text( |Hello ABAP World! | ). 
```



## Exercise 5.2 Sub Exercise 2 Description<a name="subex2"></a>

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

## Summary

You've now ...

Continue to - [Exercise 6 - Excercise 6 ](../ex6/README.md)
