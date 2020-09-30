import os
import glob
from collections import defaultdict
import pickle

from mpl_toolkits.mplot3d import Axes3D
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

from scipy.optimize import Bounds, minimize, differential_evolution, brute, fmin
from scipy.stats import uniform
import keras.backend as K
import xgboost as XGB


def objective_function(x_i, x_i_prev, x_ineg, capcosts, MODELS, regularize=False, alpha=1.):
    x_i = x_i.reshape(-1, len(capcosts))   # investor
    x_tot = (x_i + x_ineg).reshape(-1, len(capcosts))
    y = 0.
    for ix, model in enumerate(MODELS):
        if x_tot[0, ix] == 0.0:
            continue
        net_rev = model.predict(x_tot).squeeze() * (x_i[0, ix]/x_tot[0, ix])
        total_cost = capcosts[ix].squeeze() * x_i[0, ix].squeeze()
        y += total_cost - net_rev
    if regularize is True:
        y += alpha * np.linalg.norm(x_i - x_i_prev)**2
    return y


def objective_function_iccn(u, x_ineg, capcosts, datastruct, models, g):
    """
    Returns the value of the ICNN and gradient of output w.r.t. input 
    evaluated at a given input tensor
    """
    # Generate output
    y =0.
    x_tot = (u + x_ineg).reshape(1,len(capcosts))
    grad = np.zeros((1,len(capcosts)), dtype=float)
    for ix, m in enumerate(models):
        y += m.predict(x_tot).squeeze()
        # Get gradient of output w.r.t. inputs.  
        sess = K.get_session()
        _grad = sess.run(g[ix], feed_dict={m.inputs[0]: x_tot})[0].squeeze()
        if (x_tot == np.zeros((1,len(capcosts)))).all():
            grad +=  _grad
        else:
            grad +=  +_grad*(u/x_tot) + ((x_tot-u)/x_tot**2) * m.predict(x_tot).squeeze()

    return np.float(y), grad.reshape(len(capcosts))


def de_optimizer(x, i, nodes, capcosts, caplimits, datastruct,
                models, iteration_count, action_incr=np.inf, num_x0=5,
                regularize=False, alpha=1.):
    """Optimize for agent i"""
    
    # Get total upper and lower bounds
    nodes = np.array(nodes)
    lower_bound_tot = nodes.min(axis=0)
    upper_bound_tot = nodes.max(axis=0)
    
    # Get upper and lower bounds for agent based on other agents' decisions
    ineg = [x for x in range(x.shape[0]) if x != i]
    x_ineg = x[ineg, :].sum(axis=0)
    lower_bound = np.zeros_like(lower_bound_tot)
    upper_bound = np.clip(upper_bound_tot - x_ineg, 0, upper_bound_tot)
    upper_bound = np.minimum(upper_bound, x[i, :] + action_incr)
    upper_bound = np.minimum(upper_bound, caplimits)
    bounds = Bounds(lower_bound, upper_bound)
    print("i: {}, ineg: {}".format(i, ineg))
    print("   lower_bound: {}".format(lower_bound))
    print("   upper_bound: {}".format(upper_bound))

    # Solve over random starting points
    fs= []; xs = []
    for j in range(num_x0):
        res = differential_evolution(objective_function, 
                                     bounds=bounds,
                                     args=(x[i, :], x_ineg, capcosts, models, regularize, alpha),
                                     popsize=100,
                                     mutation=0.5,
                                     recombination=0.9,
                                     init="latinhypercube")
        fs.append(res["fun"])
        xs.append(res["x"])
    

    # Find the best solution
    fs = -1 * np.array(fs)
    max_idx = np.argmax(fs)

    xs = np.array(xs)

    xopt = xs[max_idx]
    fopt = fs[max_idx]

    print("  xopt: {}".format(xopt))
    print("  fopt: {}".format(fopt))
    
    return xopt, fopt

def brute_force_optimizer(x, i, nodes, capcosts, caplimits, datastruct,
                            models, iteration_count, action_incr=np.inf, num_x0=10, 
                            regularize=False, alpha=1.):

    # Get total upper and lower bounds
    nodes = np.array(nodes)
    lower_bound_tot = nodes.min(axis=0)
    upper_bound_tot = nodes.max(axis=0)
    
    # Get upper and lower bounds for agent based on other agents' decisions
    ineg = [x for x in range(x.shape[0]) if x != i]
    x_ineg = x[ineg, :].sum(axis=0)
    lower_bound = np.zeros_like(lower_bound_tot)
#     lower_bound = np.clip(lower_bound_tot, 0, upper_bound_tot)
    upper_bound = np.clip(upper_bound_tot, 0, upper_bound_tot)
    upper_bound = np.minimum(upper_bound, x[i, :] + action_incr)
    upper_bound = np.maximum(upper_bound, caplimits)
    bounds = Bounds(lower_bound, upper_bound)
    print("i: {}, ineg: {}".format(i, ineg))
    print("   lower_bound: {}".format(lower_bound))
    print("   upper_bound: {}".format(upper_bound))
    print(x[i, :])
    split_array = [3, 4, 2, 3, 0.5, 4, 4]
    ranges = tuple([slice(lower_bound[i], upper_bound[i], split_array[i]) for i in range(0,7)])
    xv, f, _, _ = brute(objective_function, ranges=ranges,  
                    args=(x[i, :], x_ineg, capcosts, models, 
                            regularize, alpha), 
                    finish=None, full_output=True)
    print(" BFO xopt: ",(xv))
    print(" BFO fopt: ",(f))
    return xv, f


def gradient_optimizer(x, i, nodes, capcosts, caplimits, datastruct,
                models, iteration_count, action_incr=np.inf, num_x0=3,
                regularize=False, alpha=1.):
    """Optimize for agent i"""
    
    # Get total upper and lower bounds
    nodes = np.array(nodes)
    x_scaler = datastruct.capacity.max().max()
    lower_bound_tot = (nodes.min(axis=0)/x_scaler)
    upper_bound_tot = (nodes.max(axis=0)/x_scaler)
    # Get upper and lower bounds for agent based on other agents' decisions
    ineg = [x for x in range(x.shape[0]) if x != i]
    x_ineg = x[ineg, :].sum(axis=0)
    lower_bound =  lower_bound_tot/1.8
    lower_bound = np.zeros(lower_bound_tot.shape)
    lower_bound = np.clip(lower_bound_tot - x_ineg, 0, lower_bound)
    upper_bound = np.clip(upper_bound_tot - x_ineg, 0, upper_bound_tot)
    bounds = Bounds(lower_bound, upper_bound)
    grads = [K.gradients(model.output, model.inputs) for model in models]
    print("i: {}, ineg: {}".format(i, ineg))
    print("   lower_bound: {}".format(lower_bound))
    print("   upper_bound: {}".format(upper_bound))
    # Solve over random starting points
    fs= []; xs = []
    for j in range(num_x0):
        if all(x[i, :] == 0.0):
            int_start = np.random.rand(len(lower_bound))*np.array([1, 1, 1, 1, 1e-5, 1, 1])
        else:
            int_start = x[i, :] + np.random.rand(len(lower_bound))*np.array([0.1, 0.1, 0.1, 0.1, 0.0, 0.1, 0.1])/iteration_count
        res = minimize(objective_function_iccn,
                        x0=int_start,
                        bounds=bounds,
                        args=(x_ineg, capcosts, datastruct, models, grads),
                        method="trust-constr",
                        jac=True, 
                        options={ 'disp': False, 'maxiter': 10000}, tol=1e-6)
        fs.append(res["fun"])
        xs.append(res["x"])
    

    # Find the best solution
    fs = np.array(fs)
    max_idx = np.argmin(fs)

    xs = np.array(xs)

    xopt = xs[max_idx]
    fopt = fs[max_idx]

    print("  xopt: {}".format(xopt))
    print("  fopt: {}".format(fopt))
    
    return xopt, fopt