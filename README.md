# Addressing Fairness in Prediction Models by Improving Subpopulation Calibration

This repository accompanies the study whose title is in the heading.

The algorithm in this repository is an adaptation of a variant of the algorithm that appears in [Hébert-Johnson et al. (2017)](https://arxiv.org/abs/1711.08513)

The algorithm is coded in julia (version 1.0.1).
It requires inputs in a very specific structure. Specifically, membership in subpopulation X is determined by the boolean vector located in index X of a containing vector.
The rest is pretty straightfoward.
