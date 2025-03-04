## Deprecation Notice

This public repository is read-only and no longer maintained.

![](https://img.shields.io/badge/STATUS-NOT%20CURRENTLY%20MAINTAINED-red.svg?longCache=true&style=flat)

---
[![REUSE status](https://api.reuse.software/badge/github.com/SAP-samples/teched2022-DA180)](https://api.reuse.software/info/github.com/SAP-samples/teched2022-DA180)

# DA180 - Getting Started with Multi-Model Capabilities in SAP HANA Cloud

## Description

This repository contains the material for the SAP TechEd 2022 session called DA180 - Getting Started with Multi-Model Capabilities in SAP HANA Cloud.  

## Overview

This session introduces attendees to the **multi-model** capabilities in SAP HANA Cloud. In the first part we will mainly work with General Transit Feed Specification ([GTFS](https://gtfs.org/)) data, which describes the **public transportation** of Adelaide, Australia. We 'll show how to do routing in a temporal graph, solving problems like "which bus takes me to the nearest pub?". Next, we'll show some tricks for importing/exporting spatial and graph data. In the second half of this workshop, we will analyze **fuel price** data from Germany, doing forecasts and classification on spatially enriched data.</br>

## Requirements

Most of the spatial and graph related exercises can be run on an SAP HANA Cloud trial instance, but for the use of the Predictive Analysis Library (PAL) and the JSON Document Store related capabilities you currently would need to work with a "full" SAP HANA Cloud system. Since there is some focus on 3rd party integration when it comes to data import/export, you'd need to install these tools to run the exercises on your own: QGIS, GDAL, DBeaver, Cytoscape.

## Exercises

- [Getting Started](exercises/ex0/)
    - [Base Data & Demo Scenario](exercises/ex0/README.md#subex1)
    - [SAP HANA Cloud setup](exercises/ex0/README.md#subex2)
    - [DBeaver, QGIS/GDAL, hana-ml, and Cytoscape](exercises/ex0/README.md#subex3)
    - [Background Material](exercises/ex0/README.md#subex4)
- [Exercise 1 - Loading and visualizing a public transportation network](exercises/ex1/)
    - [Exercise 1.1 - Importing Points of Interest from OpenStreetMaps and General Transit Feed Specification data](exercises/ex1/README.md#subex1)
    - [Exercise 1.2 - Understanding the GTFS datamodel](exercises/ex1/README.md#subex2)
    - [Exercise 1.3 - Polling for real-time vehicle positions](exercises/ex1/README.md#subex3)
- [Exercise 2 - Routing on a Spatio-Temporal Graph](exercises/ex2/)
    - [Exercise 2.1 - Transform GTFS data and create a Graph Workspace](exercises/ex2/README.md#subex1)
    - [Exercise 2.2 - Shortest paths and traverse dijkstra](exercises/ex2/README.md#subex2)
- [Exercise 3 - Import and export spatial vector and raster data, spatial clustering](exercises/ex3/)
    - [Exercise 3.1 - Import and export spatial vector data](exercises/ex3/README.md#subex1)
    - [Exercise 3.2 - Convert raster data using GDAL](exercises/ex3/README.md#subex2)
    - [Exercise 3.2 - Spatial clustering](exercises/ex3/README.md#subex3)
- [Exercise 4 - Export and import graphs](exercises/ex4/)
- [Exercise 5 - Apply Forecasting to multi-model data](exercises/ex5/)
    - [Exercise 5.1 - Load, prepare and explore fuel station datasets](exercises/ex5/README.md#subex1)
    - [Exercise 5.2 - Load, prepare and explore fuel price datasets](/exercises/ex5/README.md#subex2)
    - [Exercise 5.3 - Forecast fuel prices](/exercises/ex5/README.md#subex3)
- [Exercise 6 - Build a ML classification model on multi-model data](exercises/ex6/)
    - [Exercise 6.1 - Prepare and explore fuel station classification data](exercises/ex6/README.md#subex1)
    - [Exercise 6.2 - Enrich fuel station classification data with spatial attributes](exercises/ex6/README.md#subex2)
    - [Exercise 6.3 - Build fuel station classification model and evaluate impact of attributes](exercises/ex6/README.md#subex3)
- [Appendix - Reference section](exercises/ex9_appendix/)
    - [Prepare your Python environment](exercises/ex9_appendix/README.md#appA-sub1)


## How to obtain support

Support for the content in this repository is available during the actual time of the online session for which this content has been designed. Otherwise, you may request support via the [Issues](../../issues) tab.

## License
Copyright (c) 2022 SAP SE or an SAP affiliate company. All rights reserved. This project is licensed under the Apache Software License, version 2.0 except as noted otherwise in the [LICENSE](LICENSES/Apache-2.0.txt) file.
