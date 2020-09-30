import glob
import os

class DataDir(object):

    def __init__(self, file_path, output_dir):
        self.file_path = file_path
        self.output_dir = output_dir

    def populate(self):
        self.dispatch_files = glob.glob(os.path.join(self.file_path, self.output_dir+"/*/dispatch.csv"))
        self.price_files = glob.glob(os.path.join(self.file_path, self.output_dir+"/*/energyprices.csv"))
        self.capacity_files = glob.glob(os.path.join(self.file_path, self.output_dir+"/*/generators.csv"))
        
    def populate_rts(self):
        self.training_files = glob.glob(os.path.join(self.file_path, 
             "sample_configuration_R*/sample_R*/*/results/training_data.csv"))


