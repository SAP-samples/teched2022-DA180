# Reference - Prepare your Python environment <a name="appA-sub1"></a>

You require to have a __Python Notebook environment__ prepared, see [Jupyter Notebook](https://jupyter.org/install), [Anaconda Python environment](https://www.anaconda.com/products/distribution) or [Jupyter Notebook in VS Code](https://code.visualstudio.com/docs/datascience/jupyter-notebooks) as exemplary guidance installing a Jupyter Notebook environment

If you are working on a __MAC with Apple M1 chip__, see this blog for further install guidance [Running hdbcli on an Apple M1 Chip | SAP Blogs](https://blogs.sap.com/2022/04/25/running-hdbcli-on-an-apple-m1-chip/)

The following __python packages and versions__ are required to work through the exercises  

protobuf==3.20.1  
gtfs-realtime-bindings==0.0.7  
requests
protobuf3_to_dict  
shapely  
pipwin  
gdal  
fiona  
rtree==1.0.1
pygeos==0.13
pandas==1.1.2  
numpy==1.19.5  
matplotlib==3.5.3  
pydotplus==2.0.2  
geopandas==0.10.2  
osmnx==0.16.0  
hdbcli==2.14.18  
hana-ml==2.14.22101400

Important note: the geopandas package (and thus the required gdal and fiona packages) are only required for some parts of the exercise 5 and 6, thus can be omitted if you focus on exercises 1-4.

Prepare installation of required python packages in your Python envrionment using this [requirements.txt](https://github.com/SAP-samples/teched2022-DA180/blob/main/exercises/ex9_appendix/requirements.txt) and the following python install command
````Python
pip install -r requirements.txt
import hana_ml

````
If you experience challenges with installing the required packages, it is recommended to the following packages from the Python Notebook before you start using the following command 
````Python

!pip install protobuf==3.20.1
!pip install gtfs-realtime-bindings==0.0.7
!pip install requests
!pip install protobuf3_to_dict
!pip install pandas==1.1.2
!pip install numpy==1.19.5
!pip install matplotlib==3.5.3
!pip install pydotplus==2.0.2
!pip install shapely  
!pip install pipwin  
!pipwin install gdal  
!pipwin install fiona  
!pip install rtree==1.0.1
!pip install pygeos==0.13
!pip install geopandas==0.10.2
!pip install osmnx==0.16.0
!pip install hdbcli==2.14.18
!pip install hana-ml==2.14.22101400
````
Further note regarding the  geopandas, gdal and fiona package install
If your python envrionment is a anaconda envrionment, one recommended approach to install geopandas is to use conda install from conda-forge, then you don't require explicit gdal and fiona install. The conda install would look like:
- conda config --env --add channels conda-forge
- conda install geopandas
