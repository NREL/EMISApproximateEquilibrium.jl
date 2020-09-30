import pandas as pd
import numpy as np
from collections import defaultdict
import seaborn as sns
from approximate_equilibrium.optimize import de_optimizer, objective_function, brute_force_optimizer, objective_function_iccn, gradient_optimizer

class DiagonalizedSolver(object):
    
    def __init__(self, capcosts, caplimits, nodes, models, model_names, datastruct,
                 action_increment=np.inf, regularize=False, alpha=1.):
        self.capcosts = capcosts
        self.caplimits = caplimits
        self.nodes = nodes
        self.num_agents = capcosts.shape[0]
        self.num_gens = capcosts.shape[1]
        self.action_increment = action_increment
        self.regularize = regularize
        self.alpha = alpha
        self.models = models
        self.model_names = model_names
        self.gradient_based = False
        self.datastruct = datastruct
        self.reset()
    
    def update_count(self):
        self.iteration_count += 1
        
    def reset(self):
        self.X = np.zeros((self.num_agents, self.num_gens))
        self.agents = {i: defaultdict(list) for i in range(self.num_agents)}
        self.iteration_count = 0
        
    def set_starting_cap(self, caps):
        self.X = caps

    def set_gradient_based(self):
        self.gradient_based = True
        
#     def set_inverse_transform(self):
#         self.x_inv_trans = self.datastruct.capacity.max().max()
#         self.y_inv_trans = self.datastruct.revenue.max().max()
        
    def step(self):
        try:
            for i in range(self.num_agents):
                if self.gradient_based:
                    x, f = gradient_optimizer(self.X, i, self.nodes, self.capcosts[i, :], 
                                        self.caplimits[i, :], self.datastruct, self.models, self.iteration_count, self.action_increment,
                                        regularize=self.regularize, alpha=self.alpha)
                else:
                    x, f = de_optimizer(self.X, i, self.nodes, self.capcosts[i, :], 
                                        self.caplimits[i, :], self.datastruct, self.models, self.iteration_count, self.action_increment,
                                        regularize=self.regularize, alpha=self.alpha)
                self.agents[i]["x"].append(x)
                self.agents[i]["f"].append(f)
                self.X[i, :] = x.squeeze()
            self.update_count()
        except KeyboardInterrupt:
            raise("interrupted")
            
            
    def iterate(self, num_steps):
        for n in range(num_steps):
            print("round {}/{}, total capacity = {:1.3e}".format(n+1, num_steps, self.X.sum()))
            self.step()
            
    def get_agent_decisions(self):
        return {i: np.vstack(self.agents[i]["x"]).squeeze() for i in self.agents}

    def plot_convergence(self):
        for i in range(solver.num_agents):
            plt.plot(solver.agents[i]['f'],)
        plt.title("Agents Objective function vs Iterations")
        plt.ylabel("Capacity (p.u)")
        plt.xlabel("Iterations")
        
        
    def plot_convergence_techonology(self):
        fig, ax = plt.subplots(2, math.ceil(len(self.num_gens)/2))
        fig.set_size_inches(16, 10)
        axf = ax.flatten()
        for i in range(len(self.num_gens)):
            for a_i in range(len(self.num_agents)):
                axf[i].plot([a[i] for a in solver.agents[a_i]['x']])
            axf[i].title.set_text("{}".format(self.model_names[i]))
            axf[i].set_ylabel("Capacity (p.u)")
            axf[i].set_xlabel("Iterations")
