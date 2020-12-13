# Reservoir Spatio Temporal Importance Resampling (ReSTIR)

* Sydney Miller: [LinkedIn](https://www.linkedin.com/in/sydney-miller-upenn/), [portfolio](https://youtu.be/8jFfHmBhf7Y), [email](millersy@seas.upenn.edu)
* Sireesha Putcha: [LinkedIn](https://www.linkedin.com/in/sireesha-putcha/), [portfolio](https://sites.google.com/view/sireeshaputcha/home), [email](psireesha98@gmail.com)
* Thy Tran: [LinkedIn](https://www.linkedin.com/in/thy-tran-97a30b148/), [portfolio](https://tatran5.github.io/demo-reel.html), [email](tatran@seas.upenn.edu)

## Outlines
* [Introduction](#introduction)
* [ReSTIR explained](#restir-explained)
* [Results](#results)
    * [Final results](#final-results)
    * [Candidates generation results](#candidates-generation-results)
    * [Temporal results](#temporal-results)
    * [Spatial results](#spatial-results)
    * [Global illumination](#global-illumination)
* [Runtime analysis](#runtime-analysis)

## Introduction

This is a team project implementing ReSTIR based on the [research paper](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf) with the same title, published by NVIDIA in 2020. Briefly, the purpose of ReSTIR is to help rendering scenes with a lot of lights but make it much less noisy than the basic path tracing algorithm. This is a result of continuously finding and updating the most ideal light for a pixel based on its surrounding neighbor pixels and its light in previous frames.

## ReSTIR explained
*Please let us know if you find any errors in our understandings of the paper.*

### Overview
For each pixel:
1. Select 1 light from randomly 32 chosen lights
2. Shoot a shadow ray from the light to the pixel. If it is obscured, discard the chosen light.
3. Compare the light used in the last iteration to the light from step 2 and choose one.
4. Compare the lights from random adjacent pixels to light from step 3 and choose one.
5. Shoot a shadow ray to light from step 4 and shade the pixel.

This uses a combination of Weighted Reservoir Sampling and Resampled Importance Sampling to select and compare lights. 

### Details
The way to execute each of the step is elaborated in algorithm 5, 4, 3, 2 and 1 in the paper, so we would not dig into those details here. However, there were some variables or details that made us scratch our head for a bit, so we would explain those as below. 

#### Reservoir
We uses a data structure called reservoir for each pixel that holds the current light and sum of all weights seen for the light. A reservoir holds four values: weight sum of all light candidates seen so far, number of light candidates seen so far, index of the chosen light, and the adjusted weight based on weight sum and the number of light candidates seen.

#### Weight calculation per light candidate
Each light candidate has a weight corresponding to their chance of being chosen as the current sampled light per pixel.

* <img src="https://latex.codecogs.com/svg.latex?weight=w(x)=\frac{\rho(x)*L_e(x)*G(x)}{p(x)}" title="w(x)" />
    
    * <img src="https://latex.codecogs.com/svg.latex?\rho(x)" title="rho(x)" /> : the BSDF of the current point, which is the material color given the incident and outgoing light ray.
    
    * <img src="https://latex.codecogs.com/svg.latex?L_e(x)" title="le(x)" /> : light emmitance from a chosen point on the light to the current point.
    
    * <img src="https://latex.codecogs.com/svg.latex?G(x)=\frac{(\vec{n}\cdot\vec{w})(\vec{n'}\cdot\vec{w'})}{\|x-x'\|^{2}}" title="G(x)" /> : the solid angle term, where <img src="https://latex.codecogs.com/svg.latex?\vec{n}" title="n" /> is the normal vector at the current point, <img src="https://latex.codecogs.com/svg.latex?\vec{w}" title="w" /> is the direction from the current point to a chosen point on the light, while <img src="https://latex.codecogs.com/svg.latex?\vec{n'}" title="n'" /> is the normal at the chosen point on the light, and <img src="https://latex.codecogs.com/svg.latex?\vec{w'}" title="w'" /> is the vector from the chosen point to the current point. <img src="https://latex.codecogs.com/svg.latex?x" title="x" /> and <img src="https://latex.codecogs.com/svg.latex?x'" title="x'" /> respectively are the current point and the chosen point on the light. In the case that the light itself is a point light, the numerator is reduced to the dot product of the normal vector at the current point and the ray direction from the point to the light over the denominator.
    
#### Temporal reuse

When doing temporal reuse, the paper advises to clamp the number of candidates M contribution to the pixel (otherwise, this can go unbounded.) We clamp the previous frame's M to at most 20x of the current frame's reservoir's M. Without this, objects in the scene might become black, a problem we encountered.
    
## Final results

## Results

### Final results

### Candidates generation results

### Temporal results

### Spatial results

### Global illumination

## Runtime analysis
