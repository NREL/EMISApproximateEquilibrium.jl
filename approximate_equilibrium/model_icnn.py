from keras.layers import Input, Dense, Concatenate, Add
from keras.activations import relu, linear
from keras.constraints import NonNeg
from keras import Model
from keras.utils import plot_model
from keras.callbacks import EarlyStopping
import glob
import os
import pickle
from collections import defaultdict

import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

from sklearn.model_selection import train_test_split as tts
from sklearn.linear_model import LinearRegression, SGDRegressor, HuberRegressor
from sklearn.neighbors import KNeighborsRegressor
from sklearn.svm import SVR, LinearSVR
from sklearn.gaussian_process import GaussianProcessRegressor, kernels
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.neural_network import MLPRegressor
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import GridSearchCV
from xgboost import XGBRegressor

import time
from copy import deepcopy
from collections import defaultdict
import pickle
import sys

import warnings  
warnings.filterwarnings("ignore")

def icnn_model(input_dim, output_dim, num_layers=3, num_units=256, 
        hidden_activation="relu", output_activation="relu", constraint=NonNeg()):
    """
    Create a ICNN with specified properties, following Section 3 in 
    http://proceedings.mlr.press/v70/amos17b/amos17b.pdf.
    The network structure is that all non-passthrough kernel weights (W_i) are 
    constrained to be non-negative with no bias terms, and pass-through biases 
    and kernel weights   (D_i) as unconstrained.  All activations are "relu" 
    by default.
    Args:
        input_dim: dimension of input tensor
        output_dim: dimension of output tensor
        num_layers:  number of dense layers
        num_units:  number of hidden unites per dense layer
        activation:  activation function used in all layers
        
    Returns:
        model:  ICNN keras model object with specified properties
    """
    
    u = Input(shape=(input_dim,), name="u")

    # Concatenate inputs and pass through first non-negative layer
    z = Dense(num_units, activation=hidden_activation, kernel_constraint=constraint, 
              use_bias=False, name="W_1", kernel_initializer='random_uniform')(u)

    # Additional non-negative layers with pass-through from inputs
    for n in range(num_layers):
        z = Dense(num_units, activation=hidden_activation, kernel_constraint=constraint, 
                use_bias=False, kernel_initializer='random_uniform', name="W_{}".format(n+2))(z)
        z_pass = Dense(num_units, activation=hidden_activation, name="D_{}".format(n+2))(u)
        z = Add(name="z_{}".format(n+2))([z, z_pass])

    # Output layer
    z = Dense(output_dim, activation=output_activation, kernel_constraint=constraint, 
              use_bias=False, kernel_initializer='random_uniform', name="output")(z)

    return Model(inputs=u, outputs=z)


def model_icnn(D):

    xtrain, xtest, ytrain, ytest = tts(D.t_capacity, D.t_revenue, train_size=.75, random_state=42)
    models = np.array([icnn_model(xtrain.shape[1], 1) for x in range(ytrain.shape[1])])
    model_ix = list(range(len(models))) 

    # Training params
    vbs = 0
    opt = "adam"
    loss = "mean_squared_error"
    epochs = 100
    split = 0.25
    cbs = [EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)]

    # Fit each model
    history = []
    for ix, model in enumerate(models[model_ix]):
        tic = time.time()
        print("model {}/{}".format(ix+1, len(model_ix)))
        model.compile(optimizer=opt, loss=loss)
        h = model.fit(xtrain, ytrain[:, ix], verbose=vbs, epochs=epochs,
                    validation_split=split, callbacks=cbs)
        history.append(h)
        models[ix] = model
        print("elapsed: {:1.0f}s".format(time.time() - tic))
    
    return models, (xtrain, xtest, ytrain, ytest), history


def plot_loss(D, models, history):
    # Plot loss curves
    model_ix = list(range(len(models))) 
    fig, ax = plt.subplots()
    for ix in range(len(models[model_ix])):
        _ = plt.plot(history[ix].history["loss"])
    plt.yscale('log')

def calculate_mse_error(D, models, training_data):
    # Evaluate error on test set
    (xtrain, xtest, ytrain, ytest) = training_data
    model_ix = list(range(len(models))) 
    print("MSE on test set")
    for ix, model in enumerate(models[model_ix]):
        print("{}: {:1.4f}".format(D.devices[ix], 
                                np.sqrt(model.evaluate(xtest, ytest[:, ix], verbose=0))))

def plot_errors(D, models, training_data):
    # Visualize the residual errors in test set
    (xtrain, xtest, ytrain, ytest) = training_data
    model_ix = list(range(len(models))) 
    for ix, model in enumerate(models[model_ix]):
        
        # Get predictions on test set
        y_pred = model.predict(xtest)
        y_true = ytest[:, ix].reshape(-1, 1)
        
        # Create figure and params needed for plotting
        fig, ax = plt.subplots(1,2)
        fig.set_size_inches((12, 5))
        ymin = ytest[:, ix].min()
        ymax = ytest[:, ix].max()
        
        # Plot y_test versus y_pred
        ax[0].plot([ymin, ymax], [ymin, ymax], color="r")
        ax[0].scatter(y_true, y_pred, alpha=0.2)
        ax[0].set_title("{}: pred (x) vs true (y)".format(D.devices[ix]))
        
        ax[1].hist((y_true - y_pred), bins=20)
        ax[1].set_title("{}: y_true - y_pred".format(D.devices[ix]))
