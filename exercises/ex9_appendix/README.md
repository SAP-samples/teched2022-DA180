# Reference - Prepare your Python environment <a name="appA-sub1"></a>

You require to have your __Python Notebook environment__ ready
- see [Jupyter Notebook](https://jupyter.org/install), [Jupyter Notebook in VS Code]([https://jupyter.org/install](https://code.visualstudio.com/docs/datascience/jupyter-notebooks))as exemplary guidance installing a Jupyter Notebook environment

If you are working on a __MAC with Apple M1 chip__, see this blog for further install guidance [Running hdbcli on an Apple M1 Chip | SAP Blogs](https://blogs.sap.com/2022/04/25/running-hdbcli-on-an-apple-m1-chip/)

The following __python packages and versions__ are required to work through the exercises  

protobuf==3.20.1  
gtfs-realtime-bindings==0.0.7  
requests
protobuf3_to_dict
pandas==1.1.2  
numpy==1.19.5  
matplotlib==3.5.3  
graphviz==0.1  
pydotplus==2.0.2  
geopandas==0.10.2  
osmnx==0.16.0  
hdbcli==2.14.18  
hana-ml==2.14.22101400

Prepare installation of required python packages in your Python envrionment using this [requirements.txt](https://github.com/SAP-samples/teched2022-DA180/blob/main/exercises/ex9_appendix/requirements.txt) and the following python install command
````Python
pip install -r requirements.txt
import hana_ml

````

