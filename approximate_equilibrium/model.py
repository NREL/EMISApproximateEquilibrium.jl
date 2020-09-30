import glob
import os
import pickle
from collections import defaultdict

import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import math
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


def scale(xtrain, xtest, scaler=MinMaxScaler):
    if np.ndim(xtrain) == 1:
        xtrain = xtrain.reshape(len(xtrain), 1)
        xtest = xtest.reshape(len(xtest), 1)
    scaler = scaler()
    xtrain = scaler.fit_transform(xtrain)
    xtest = scaler.transform(xtest)
    return xtrain, xtest, scaler

def model_fit(D):
    # Configure plot
    fig, ax = plt.subplots(2, math.ceil(len(D.devices)/2))
    fig.set_size_inches(16, 10)
    axf = ax.flatten()
    models = []

    for gen_idx in range(len(D.devices)):
        # Create Data Sets for Training and Testing
        y = D.revenue.values[:, gen_idx]
        y = y.reshape(len(y), 1)
        xtrain, xtest, ytrain, ytest = tts(D.capacity.values, y, train_size=.75, random_state=42)
        print(xtrain.shape, xtest.shape, ytrain.shape, ytest.shape)

        # Pick a Model

        model = XGBRegressor(objective="reg:squarederror", booster="gbtree",
                                max_depth=5, n_estimators=300, learning_rate=0.1)
        
        # model = tuned_model(xgb_model, xtrain, ytrain)

        # Train/Fit the model to the data provided
        model.fit(xtrain, ytrain)
        models.append(model)

        ytest_pred = model.predict(xtest).reshape(-1, 1)
        ytrain_pred = model.predict(xtrain).reshape(-1, 1)

        test_err = np.linalg.norm(ytest-ytest_pred)/np.linalg.norm(ytest)
        train_err = np.linalg.norm(ytrain-ytrain_pred)/np.linalg.norm(ytrain)
        print("train err: {:1.3e}, test err: {:1.3e}".format(train_err, test_err))

        axf[gen_idx].scatter(x=ytest_pred, y=ytest, color="b", alpha=0.5)
        axf[gen_idx].scatter(x=ytrain_pred, y=ytrain, color="r", alpha=0.1)
        axf[gen_idx].plot(ytrain, ytrain, color="k", linewidth=.5)

        axf[gen_idx].title.set_text("{}: test rel err = {:1.3e}".format(D.devices[gen_idx], test_err))
        axf[gen_idx].set_xlabel("predicted profit / mw")
        axf[gen_idx].set_ylabel("true profit / mw")

    return models

def plot_capacity_vs_revenue(D, models):
    fig, ax = plt.subplots(1, 2)
    fig.set_size_inches((16, 4))
    _ = ax[0].scatter(x=D.capacity.sum(axis=1), y=D.revenue.sum(axis=1), alpha=.5)
    ax[0].title.set_text("Actual Revenue vs Capacity")
    ax[0].set_xlabel("Total Capacity (MW)")
    ax[0].set_ylabel("Total Revenue ($)")

    _ = ax[1].scatter(x=D.capacity.sum(axis=1), y=sum([ models[i].predict(D.capacity.values) for i in range(len(D.devices))]), alpha=.5)
    ax[1].title.set_text("Predicted Revenue vs Capacity")
    ax[1].set_xlabel("Total Capacity (MW)")
    ax[1].set_ylabel("Total Revenue ($)")


def plot_revenue_per_capacity(D, models):
    fig, ax = plt.subplots(2, math.ceil(len(D.devices)/2))
    fig.set_size_inches(16, 10)
    axf = ax.flatten()
    for i in range(len(D.devices)):
        ypred = models[i].predict(D.capacity.values)
        axf[i].scatter(x= D.capacity.iloc[:, i], y= ypred * D.capacity.iloc[:,i], marker=".")
        axf[i].title.set_text("{}".format(D.devices[i]))
        axf[i].set_xlabel("Capacity (MW)")
        axf[i].set_ylabel("Predicted Revenue ($)")
    fig.tight_layout()
    

def save_models(models, file_name):
    with open(file_name, "wb") as f:
        pickle.dump(models, f)


def tuned_model(xgb_model, xtrain, ytrain):
    tuning_dict = {'max_depth': [5, 6, 8],
                    'n_estimators': [300],
                    'learning_rate': [0.05, 0.1],
                    'min_child_weight':[1, 2, 3],
                    'subsample': [0.8]}

    model = GridSearchCV(xgb_model, tuning_dict)

    model.fit(xtrain, ytrain)
    print(model.best_score_)
    print(model.best_params_)
    return model.best_estimator_

