# Reservoir Spatio Temporal Importance Resampling (ReSTIR)

* Sydney Miller: [LinkedIn](), [porfolio](), [email]()
* Sireesha Putcha: [LinkedIn](), [porfolio](), [email]()
* Thy Tran: [LinkedIn](), [porfolio](), [email]()

## Outlines
1. [Introduction](#introduction)
2. [Requirements](#requirements)
3. [ReSTIR explained](#restir-explained)
4. [Results](results)
5. [Performance analysis](#performance-analysis)
6. [Progress](progress)
7. [Credits and resources](#credits-and-resources)
8. [Final words](#final-words)

## Introduction

This is a team project implementing ReSTIR based on the [research paper](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf) with the same title, published by NVIDIA in 2020. Briefly, the purpose of ReSTIR is to help rendering scenes with a lot of lights but make it much less noisy than the basic path tracing algorithm. This is a result of continuously finding and updating the most ideal light for a pixel based on its surrounding neighbor pixels and its light in previous frames.

## Requirements
*Please let me know if you run into any problems building and running the code. I would be happy to assist, and it would be useful for me to know so I can update this section.*
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

We uses a data structure called reservoir for each pixel that holds the current light and sum of all weights seen for the light. Each light candidate has a weight corresponding to their chance of being chosen as the current sampled light per pixel.

<img src="https://latex.codecogs.com/svg.latex?weight_i=w_i=\frac{\hat{p}(x)}{p(x)}"=\frac{\rho(x)*L_e(x)*G(x)}{p(x)}" />
    * <img src="https://latex.codecogs.com/svg.latex?\Large&space;x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" title="\Large x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" />
    * <img src="https://latex.codecogs.com/svg.latex?\Large&space;x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" title="\Large x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" />
    * <img src="https://latex.codecogs.com/svg.latex?\Large&space;x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" title="\Large x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}" />

## Results
*Final images of our implementation and images at crucial steps of our implementation.*

## Performance analysis
*Analysis of visual aspects and runtime comparisons*

## Potential improvements

## Progress
*This serves as our "diary" of problems we ran into and our solutions to those.*

### Requirement hurdles

#### Hardware
Our team did not all Windows computer, and we ended up having to remotely connect to an available computer at our college. However, Developer Mode was not enabled on any of those computers, so there was some communication with the school IT, and they quickly helped us with setting up some computers at a lab with Developer Mode with DXR-fallback graphics cards. We also had asked for admin access to those computers in case we would to make changes that requires admin acess just like switching to Developer Mode, but we understandably did not have the permission. We still couldn't get our base code to run on those computers despite Developer Mode turned on, and after some digging, we found that Falcor library does not support DXR fallback, so another conversation with the school IT happened. 

This whole process took place in 2 weeks. We tried to have other options available to us because we were on time crunch and worried of facing more problems with school computers due to restricted access on any computer. Other options on the table includes Amazon Web Services and using someone's PC. However, the AWS Educate program, which is free for students, did not allow us to have access to a GPU with DXR, and the normal AWS account would cost quite a bit. We went ahead and set things up with a normal account anyway, and also borrowed someone's computer with the specifications but limited time access per day as the back up plan for AWS and to potentially cut cost if we have to use AWS account. 

Fortunately, in the end, our school IT helped us set things up at a lab that had computers with graphics cards that met our requirements. 

#### Restrictions on remote computers
We still could not build the project on the provided computers by our school. We narrowed down that a .bat file to update dependencies for Falcor library for some reasons could not run. After some debugging effort, we realized that the .bat file needs to run some PowerShell files, but the school computers do not allow us to run .ps1 files that are not digitally signed by the school itself. There went another exchange with our school IT. They ended up configuring on I configured the PowerShell Execution Policy on those machines to allow .ps1 files to run and added us to the Local Administrators Group so that we could make changes to the machines as needed. We did run into the problems where VS threw error for missing [pybind11 library](https://pybind11.readthedocs.io/en/stable/installing.html), and we were able to resolved by installing it.

## Credits and resources
* [Jilin Liu](https://www.linkedin.com/in/jilin-liu97/), [Li Zheng](https://www.linkedin.com/in/li-zheng-1955ba169/) and [Keyi Yu](https://www.linkedin.com/in/keyi-linda-yu-8b1178137/) who were also implementing ReSTIR in DirectX as a team. They helped us with clarifying parts of the paper and providing feedback on our project.
* A Gentle Introduction To DirectX Raytracing - [tutorials and base code](http://cwyman.org/code/dxrTutors/dxr_tutors.md.html)
* NVIDIA Falcor [library](https://developer.nvidia.com/falcor)
* ReSTIR [research paper](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf)
* NVDIA GTC 2020 [presentation](https://www.nvidia.com/en-us/gtc/session-catalog/?search.language=1594320459782001LCjF&tab.catalogtabfields=1600209910618002Tlxt&search=restir#/session/1596757976864001iz1p) provides a clear high level concept and results of ReSTIR
* Wojciech Jarosz, one of the authors, also has some [presentation](https://cs.dartmouth.edu/wjarosz/publications/bitterli20spatiotemporal.html) in SIGGRAPH 2020 that helps with understanding ReSTIR in a deeper level


## Final words
