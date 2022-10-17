# Getting Started

This section should give you an understanding of the base scenario and data. Additionally, we will describe the SAP HANA Cloud setup in case you want to run the exercises yourself. As we will process the data using SQL, the SQL editor of SAP HANA Database Explorer (DBX) is sufficient from a tooling perspective. However, for the "full experience" we recommend DBeaver, QGIS (or Esri ArcGIS Pro) for spatial data, Cytoscape for graph visualizations, and Python/Jupyter notebooks to work with the SAP HANA client API for machine learning (hana-ml). At the end of this section, you will find links to additional information on SAP HANA Cloud Multi-Model.

## Base Data & Demo Scenario<a name="subex1"></a>

Graphs describe networks as a set of vertices and edges. The public GTFS data we use in the first exercise describes the public transportation network of Adelaide, Australia. Vehicles are scheduled to go from one stop (a geolocation) to another, departing and arriving at a certain time. Hence, the transportation graph is spatio-temporal. We'll demonstrate some of SAP HANA's Graph engine features to solve routing problems on this graph. Many use cases of other industries are quite similar. Think about production, logistics, utilities, supply chains etc.  

Forecasting and Machine Learning techniques from SAP HANA's Predictive Analysis Library (PAL) will be applied to fuel price- and fuel station data from Germany, where we use multi-model functions like spatial filtering, distance calculation from stations to highway network graph, etc. to enrich the fuel price data to be analyzed and determine potential importance of spatial attributes on price levels.

## SAP HANA Cloud setup<a name="subex2"></a>

Some of the exercises and processing patterns can be run on a free SAP HANA Cloud trial system. To get one, visit [SAP HANA Cloud Trial home](https://www.sap.com/cmp/td/sap-hana-cloud-trial.html). To run the machine learning exercises (5 and 6) and to work with JSON data using the Document Store (ex 1), you will need a full SAP HANA Cloud. Make sure to enable the **Script Server** and **Document Store**. Refer to [SAP HANA Cloud Administration with SAP HANA Cloud Central](https://help.sap.com/viewer/9ae9104a46f74a6583ce5182e7fb20cb/hanacloud/en-US/e379ccd3475643e4895b526296235241.html) for details.

The HANA database user you work with requires some roles and privileges
* Roles `AFL__SYS_AFL_AFLPAL_EXECUTE` and `AFL__SYS_AFL_AFLPAL_EXECUTE_WITH_GRANT_OPTION` to execute PAL algorithms
* System privileges `IMPORT` to run data uploads

## DBeaver, QGIS, GDAL, hana-ml, Cytoscape<a name="subex3"></a>

The SAP HANA Database Explorer provides an SQL editor, table viewer and data analysis tools, and a simple graph viewer. For a "full experience" we recommend the following tools in addition.

**DBeaver**<br>an open source database administration and development tool. You can run the exercise scripts in DBeaver and get simple spatial visualizations. See Mathias Kemeters blog for [installation instructions](https://blogs.sap.com/2020/01/08/good-things-come-together-dbeaver-sap-hana-spatial-beer/).

**QGIS**<br>an open source Geographical Information System (GIS). QGIS can connect to SAP HANA and provides great tools for advanced maps. Again, read Mathias' blog to [get it up and running](https://blogs.sap.com/2021/03/01/creating-a-playground-for-spatial-analytics/).

**GDAL**<br>a translator library for raster and vector spatial data format. If you do a standard installation of QGIS which includes OS4GEO, you got GDAL on your system. See Vitalij's blog [GDAL with SAP HANA driver in OSGeo4W](https://blogs.sap.com/2022/08/04/gdal-with-sap-hana-driver-in-osgeo4w/)

**hana-ml**, Jupyter Notebook<br>we used the python machine learning client for SAP HANA and Jupyter Notebooks to load JSON data into the document store. There is a lot more in hana-ml for the data scientist - see [pypi.org](https://pypi.org/project/hana-ml/) and [hana-ml reference](https://help.sap.com/doc/1d0ebfe5e8dd44d09606814d83308d4b/latest/en-US/index.html). More detailed guidance on the PYthon environment setup is given in [Prepare your Python environment](/exercises/ex9_appendix/README.md#appA-sub1)

**Cytoscape**<br>for advanced graph visualization you can pull data from a Graph Workspace into Cytoscape using an unsupported preview version of the [Cytoscape HANA plug-in](https://blogs.sap.com/2021/09/22/explore-networks-using-sap-hana-and-cytoscape/).


##  Background Material<a name="subex4"></a>

[SAP HANA Spatial Resources](https://blogs.sap.com/2020/11/02/sap-hana-spatial-resources-reloaded/)<br>
[SAP HANA Graph Resources](https://blogs.sap.com/2021/07/21/sap-hana-graph-resources/)<br>
[SAP HANA Machine Learning Resources](https://blogs.sap.com/2021/05/27/sap-hana-machine-learning-resources/)

## Summary

You are all set...

Continue to - [Exercise 1 - Loading and visualizing a public transportation network](../ex1/README.md)
