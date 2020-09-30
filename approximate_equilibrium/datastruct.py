import pandas as pd
import numpy as np
from collections import defaultdict

class DataStruct(object):

    def __init__(self):
        self.created = True
    
    def add_info(self, devices, datadir, variable_cost):
        self.variable_cost = variable_cost
        self.devices = devices
        self.datadir = datadir

    def read_capacity(self):
        dfs = []
        for f in self.datadir.capacity_files:
            df = pd.read_csv(f, index_col=0)
            dfs.append(df.loc[self.devices, "capacity"])
        self.capacity = pd.concat(dfs, axis=1).T
        self.capacity.index = list(range(self.capacity.shape[0]))

    def read_prices(self):
        dfs = []
        for f in self.datadir.price_files:
            dfs.append(pd.read_csv(f, index_col=0))
        self.price = pd.concat(dfs, axis=1)
        self.price.columns = list(range(self.price.shape[1]))


    def read_dispatch(self):
        self.dispatch = defaultdict(list)
        for f in self.datadir.dispatch_files:
            df = pd.read_csv(f, index_col=0)
            for gen in self.devices:
                self.dispatch[gen].append(pd.DataFrame(df[gen]))
        for gen in self.devices:
            self.dispatch[gen] = pd.concat(self.dispatch[gen], axis=1)

    def calculate_revenue(self):
        self.revenue = []
        for gen in self.devices:
            tmp = ( (self.dispatch[gen].values * self.price.values).sum(axis=0)
                - (self.dispatch[gen].values * self.variable_cost[gen]).sum(axis=0))
            tmp = pd.DataFrame(tmp, columns=[gen])
            self.revenue.append(tmp)
        self.revenue = pd.concat(self.revenue, axis=1)

    def save_capacity(self, file_name):
        self.capacity.to_csv(file_name)

    def save_revenue(self, file_name):
        self.revenue.to_csv(file_name)
        
    def read_aggregated_data(self, ag_data):
        self.devices = ag_data.capacity.columns.values
        self.revenue = ag_data.revenue
        self.capacity = ag_data.capacity

    def tranform_data(self):
        self.t_capacity = self.capacity.values.astype("float32") / self.capacity.max().max()
        self.t_revenue =  1. - self.revenue.values.astype("float32") / self.revenue.max().max()
#         self.t_capacity = (self.capacity/self.capacity.max()).replace(np.nan, 0).values.astype("float32")
#         self.t_revenue = 1 - (self.revenue/ self.revenue.max().max()).replace(np.nan, 0).values.astype("float32")
        
class DataAggregator(object):

    def __init__(self, path_text):
        self.path_text = path_text

    def search_paths(self):
        self.path_array = []
        with open(self.path_text, 'r') as filehandle:
            for line in filehandle:
                currentPlace = line[:-1].replace('"', '')
                self.path_array.append(currentPlace)

    def read_capacity(self):
        dfs = []
        for f in self.path_array:
            df = pd.read_csv(f, index_col=0, usecols=["Capacity", "Category"]).T
            dfs.append(df)
        self.capacity = pd.concat(dfs, axis = 0)
        self.capacity.index = list(range(self.capacity.shape[0]))
        
    def read_regional_capacity(self):
        dfs = []
        for f in self.path_array:
            df = pd.read_csv(f, usecols=["Capacity","Bus", "Category"])
            df["Category"] = df["Category"] +"_"+ df["Bus"]
            df.index = df["Category"]
            df = df.drop(["Bus", "Category"], axis = 1).T
            dfs.append(df)
        self.capacity = pd.concat(dfs, axis = 0)
        self.capacity.index = list(range(self.capacity.shape[0]))

    def read_revenue(self):
        dfs = []
        for f in self.path_array:
            df = pd.read_csv(f, index_col=0, usecols=["Revenue", "Category"]).T
            dfs.append(df)
        self.revenue = pd.concat(dfs, axis = 0)
        self.revenue.index = list(range(self.revenue.shape[0]))

    def read_regional_revenue(self):
        dfs = []
        for f in self.path_array:
            df = pd.read_csv(f, usecols=["Revenue", "Bus", "Category"])
            df["Category"] = df["Category"] +"_"+ df["Bus"]
            df.index = df["Category"]
            df = df.drop(["Bus", "Category"], axis = 1).T
            dfs.append(df)
        self.revenue = pd.concat(dfs, axis = 0)
        self.revenue.index = list(range(self.revenue.shape[0]))
        
    def add_devices(self):
        self.devices = self.capacity.columns.values

    def subtract_capex_cost(self, capex):
        for d in self.devices:
            self.revenue[d] = self.revenue[d] - self.capacity[d] * capex[d]

    def add_capacity_market_rev(self, cap_mrkt):
        for d in self.devices:
            self.revenue[d] = self.revenue[d] + cap_mrkt[d]

    def save_capacity(self, file_name):
        self.capacity.to_csv(file_name)

    def save_revenue(self, file_name):
        self.revenue.to_csv(file_name)
