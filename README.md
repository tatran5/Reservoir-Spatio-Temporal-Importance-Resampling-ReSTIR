# Reservoir Spatio Temporal Importance Resampling (ReSTIR)

* Sydney Miller: [LinkedIn](https://www.linkedin.com/in/sydney-miller-upenn/), [portfolio](https://youtu.be/8jFfHmBhf7Y), [email](millersy@seas.upenn.edu)
* Sireesha Putcha: [LinkedIn](https://www.linkedin.com/in/sireesha-putcha/), [portfolio](https://sites.google.com/view/sireeshaputcha/home), [email](psireesha98@gmail.com)
* Thy Tran: [LinkedIn](https://www.linkedin.com/in/thy-tran-97a30b148/), [portfolio](https://tatran5.github.io/demo-reel.html), [email](tatran@seas.upenn.edu)

* Tested on Windows 10, i7-8750H @ 2.20GHz 22GB, GTX 1070

![](Images/final/forest_final.gif)

## Outlines
* [Introduction](#introduction)
* [ReSTIR explained](#restir-explained)
* [Results](#results)
    * [Final results](#final-results)
    * [Intermediate results](#intermediate-results)
        * [Candidates generation results](#candidates-generation-results)
        * [Temporal results](#temporal-results)
        * [Spatial results](#spatial-results)
        * [Global illumination](#global-illumination)
* [Runtime analysis](#runtime-analysis)
* [Potential improvements](#potential-improvements)
* [Build and run](#build-and-run)
* [Credits and resources](#credits-and-resources)

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

## Results

### Final results

#### Forest scene (80 lights)

![](Images/forest/forest_restir2.png)

|ReSTIR (after 14 iterations)|
|---|
|![](Images/forest/forest_restir_frame14.png)|

|One random light (after 14 iterations)|
|---|
|![](Images/forest/forest_base_frame14.png)|

ReSTIR outputs a more converged render at the same iteration as the base method of randomly sample one light. This is clearly seen when zooming into many parts of the renders above.

|ReSTIR (after 14 iterations)|One random light (after 14 iterations)|
|---|---|
|![](Images/forest/forest_restir_frame14_upperRight.png)|![](Images/forest/forest_base_frame14_upperRight.png)|
|![](Images/forest/forest_restir_frame14_lowerLeft.png)|![](Images/forest/forest_base_frame14_lowerLeft.png)|

#### Purple bedroom scene (15 lights)

|ReSTIR (after 44 iterations)|
|---|
|![](Images/purpleBedroom/purple_bedroom_frame44_restir.png)|

|One random light (after 44 iterations)|
|---|
|![](Images/purpleBedroom/purple_bedroom_oneRandomLight_frame44.png)|

Overall, we find that the ReSTIR image is slightly more converged than using the basic method of randomly selecting one light in the scene. Examples of areas that are much more converged can be seen below, including pillow, blanket, chair and table. We expect that the diffference of convergence between these two rendering methods would be larger if there are many more lights in the scene.

|ReSTIR (44th frame)|One random light (44th frame)|
|---|---|
|![](Images/purpleBedroom/purple_bedroom_frame44_restir_blanket.png)|![](Images/purpleBedroom/purple_bedroom_oneRandomLight_frame44_blanket.png)|
|![](Images/purpleBedroom/purple_bedroom_frame44_restir_chair.png)|![](Images/purpleBedroom/purple_bedroom_oneRandomLight_frame44_chair.png)|

However, ReSTIR spatial reuse also makes some part of the scene looks somewhat fuzzier than the basic method.
|ReSTIR (44th frame)|One random light (44th frame)|
|---|---|
|![](Images/purpleBedroom/purple_bedroom_frame44_restir_leftWall.png)|![](Images/purpleBedroom/purple_bedroom_oneRandomLight_frame44_leftWall.png)|

#### Bistro scene 

![](Images/final/bistro_final.gif)

|||
|---|---|
|![](Images/final/bistro_final_1.png)|![](Images/final/bistro_final_2.png)|
|![](Images/final/bistro_final_3.png)|![](Images/final/bistro_final_4.png)|

### Intermediate results

#### Candidates generation results

With only ReSTIR candidates generation, we eliminate a lot of shadows that are not visible in the converged images. The method helps to brighten up the scene more quickly.

|Ground truth | Candidates generation (first frame) | One random light (first frame)
|---|---|---|
|![](Images/pinkRoom/base_multiple_frames_sofa_pillow_shadow.png)|![](Images/pinkRoom/restir_generate_candidates_sofa_pillow_shadow.png)|![](Images/pinkRoom/base_first_frame_sofa_pillow_shadow.png)|
|![](Images/pinkRoom/base_multiple_frames_side_table_shadow.png)|![](Images/pinkRoom/restir_generate_candidates_side_table_shadow.png)|![](Images/pinkRoom/base_first_frame_side_table_shadow.png)|

#### Temporal results
Temporal results also help to brighten our renders more quickly than the base method of randomly sample one light. As mentioned, the paper advises having a clamped number of candidates seen for previous reservoir to max of k * currentReservoirWeight. Here are the effects of changing parameter k.

|k = 5|k = 20 (recommended)|k = 50|
|---|---|---|
|![](Images/pinkRoom/pinkRoom_5xCurWeight_topSofa.png)|![](Images/pinkRoom/pinkRoom_20xCurWeight_topSofa.png)|![](Images/pinkRoom/pinkRoom_50xCurWeight_topSofa.png)|

Even though the scene is brighted up as k increases, especially at the top of the sofa or at edge of sofa seats, there is also more noise in the renders. 

#### Spatial results
As expected, having more candidates help renders converge more quickly. At the 61th frame, we have these renders of our forest scene.

|1 sampled neighbors (radius 30)|30 sampled neighbors (radius 30)|
|---|---|
|![](Images/forest/forest_spatial_n1r30.png)|![](Images/forest/forest_spatial_n30r30.png)|

#### Global illumination

We have incorporated global illumination into Restir algorithm. Our approach basically adds indirect lighting to the current spatiotemporal output. We shoot 2 types of rays: Shadow ray and Indirect bounce ray. When we shoot our indirect ray and it hits a surface, we perform a simple lambertian shading at that point. To save cost, we are currently only shooting one shadow ray from each hit. 

In `initLightPlusTemporal.rt.hlsl`, We have a flag gDoIndirectGI which allows us to toggle Indirect illumination. We first sample a random direction for our diffuse interreflected ray by using either cosine hemisphere sampling or uniform hemishphere sampling. We calculate the lambertian term for this randomly selected direction and then shoot out indirect ray to calculate the bounce color. We finally do a monte carlo intergration of the rendering equation for just the indirect component by multiplying the bounce color and lambertian term to the albedo and dividing this by the pdf based on the sampling technique used. We have added a new buffer to hold the output of indirect illumination called "gIndirectOutput" to store the output from indirect illumination and pass it on to the `updateReservoirPlusShade` pass. 

Output: 

![Global Illum (Pink Room Scene gif )](Images/Recordings/pink_room_gi.gif)

Converged Images:

|With Global Illumination | Without Global Illumination |
|---|---|
![Global Illum (Pink Room Scene GI )](Images/pinkRoom/pink_room_gi_converged.png)| ![Global Illum (Pink Room Scene NO GI )](Images/pinkRoom/pink_room_no_gi_converged.png)
![Global Illum (Purple Room Scene GI )](Images/purpleBedroom/purple_room_gi_converged.png)| ![Global Illum (Purple Room Scene NO GI )](Images/purpleBedroom/purple_room_no_gi_converged.png)

Global illumination helps with lighting up some scenes and creating color bleeding effect, as seen with the red carpet reflecting light at the bottom of the white sofa in one of the scens above. It can help certain scenes look significantly better as the one below.

|With Global Illumination | Without Global Illumination |
|---|---|
|![](Images/bistro/bistro_with_gi.png)|![](Images/bistro/bistro_without_gi.png)|

However, as expected, the effect of global illumination is more apparent for scenes where objects are close to each other as above and less apparent for scenes where objects are further apart. In the scene below, the brightening and color-bleeding effects are barely or not noticeable at all. 

|With Global Illumination | Without Global Illumination |
|---|---|
![Global Illum (Forest GI )](Images/forest/forest_restir_GI.png)| ![Global Illum (Forest NO GI )](Images/forest/forest_restir_noGI.png)

The only apparent difference is a leaf of one pine tree in the scene is brighter
|With Global Illumination | Without Global Illumination |
|---|---|
![Global Illum (Forest GI )](Images/forest/forest_pine_withGI.png)| ![Global Illum (Forest NO GI )](Images/forest/forest_pine_noGI.png)

The Bistro scene lights up very well upon adding global illumination since we are also casting indirect rays in order to accumulate color. Using Direct Lighting alone leaves the scene 
pretty dark since it is a very huge environment and not all areas receive direct lighting. 

|With Global Illumination | Without Global Illumination |
|---|---|
![Global Illum (Bistro Scene GI )](Images/bistro/bistro_with_gi.png)| ![Global Illum (Bistro Scene no GI )](Images/bistro/bistro_without_gi.png)


## Runtime analysis
The below are results from our forest scene.

![](Images/Graphs/fps.png)

As expected ReSTIR has a lower FPS compared with the method of only sampling one random light. This might be due to many buffers used for ReSTIR, so the time accumulated by passing in the buffer data as well as reading from and writing into buffers increase drastically. There are also a lot of branching in various shaders for ReSTIR, which can significantly slow down the method and result in low FPS. Another factor is that we are using more passes than the other method, which also lead to the lower FPS in methods involved with ReSTIR in the graph above. 

![](Images/Graphs/timeToConverge.png)

Due to the inefficiencies mentioned above, the time for ReSTIR to converge are also high. However, there might be a drastic difference when there are a lot more lights in the scene (thousands or millions), which are not displayed here, that show ReSTIR with a better convergence time. 

## Potential improvements

### Complex light handling
Currently, we are only handling static point lights. Having dynamic lights and area or mesh lights might show off more benefits of ReSTIR.

### Candidate generation
The paper and presentations also suggests ways to better sample light candidates for the first step - candidates generation per reservoir - by storing emissive triangles based on their power. We have yet to incorporated this into our implementation (since we are not dealing with complex lights here)

### Pass reduction
We may be able to reduce at least one pass by refactoring and moving our implementation of global illumination to the last pass, and by using the buffers in a better way as well.

## Build and run

* **Windows 10 RS5 or later**
    * If you run "winver.exe" you should have Version 1809 (OS Build 17763.)
    * This project does not run on Windows 10 RS4 or earlier.
* **Graphics card**
    * Must support [DirectX Raytracing (DXR)](https://www.nvidia.com/en-us/geforce/news/geforce-gtx-dxr-ray-tracing-available-now/) (**not** fallback layer) due to Falcor library (which does not support fallback layer.)
* **A driver that natively supports DirectX Raytracing**
     * For NVIDIA, use 416.xx or later drivers (in theory any NVIDIA driver for RS5 should work)
* **Visual Studio**
    * Visual Studio 2019. If you have multiple Visual Studio versions, right click on the solution and choose to open the project in Visual Studio 2019.
    * Windows 10 SDK 10.0.17763.0
    * If Visual Studio prompts to upgrade the SDK and version when first opening the solution, hit "cancel".
    * If Visual Studio complains about Falcor library, run ./Falcor/update_dependencies.bat, then go back to Visual Studio to build the solution.
    * If Visual Studio complains about some inaccessible pybind11, try installing [pybind11 library](https://pybind11.readthedocs.io/en/stable/installing.html)
* **Others**
    * Developer Mode must be enabled
    * Permission to run PowerShell files that are not digitally signed

## Credits and resources
* [Jilin Liu](https://www.linkedin.com/in/jilin-liu97/), [Li Zheng](https://www.linkedin.com/in/li-zheng-1955ba169/) and [Keyi Yu](https://www.linkedin.com/in/keyi-linda-yu-8b1178137/) who were also implementing ReSTIR in DirectX as a team. They helped us with clarifying parts of the paper and providing feedback on our project.
* [Eric Haines](https://www.linkedin.com/in/erichaines3d/) for pointing out some missing pieces in our explantation.
* A Gentle Introduction To DirectX Raytracing - [tutorials and base code](http://cwyman.org/code/dxrTutors/dxr_tutors.md.html)
* NVIDIA Falcor [library](https://developer.nvidia.com/falcor)
* ReSTIR [research paper](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf)
* NVDIA GTC 2020 [presentation](https://www.nvidia.com/en-us/gtc/session-catalog/?search.language=1594320459782001LCjF&tab.catalogtabfields=1600209910618002Tlxt&search=restir#/session/1596757976864001iz1p) provides a clear high level concept and results of ReSTIR
* Wojciech Jarosz, one of the authors, also has some [presentation](https://cs.dartmouth.edu/wjarosz/publications/bitterli20spatiotemporal.html) in SIGGRAPH 2020 that helps with understanding ReSTIR in a deeper level
