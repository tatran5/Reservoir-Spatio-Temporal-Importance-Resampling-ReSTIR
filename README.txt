This directory contains Chris Wyman's shader tutorials from the SIGGRAPH 2018 Course 
"Introduction to DirectX Raytracing."   Please visit the course webpage (http://intro-to-dxr.cwyman.org)
or Chris' webpage (http://cwyman.org) to get more details, updated code, more descriptive
code walkthroughs, prebuilt tutorial binaries, course presentations, and other information 
about the course.

Please read this document carefully before running our tutorials.  Given DirectX Raytracing is 
still new, with slowly improving drivers and tools, building code that relies on it is still
somewhat complex and can fail in surprising ways.  We have tried to specify all requirements
and caveats, to avoid pain in getting started, and we will update this tutorial code as 
requirements change.  Please contact Chris if you run into unexpected troubles not covered below.

Also note:  None of these tutorials are intended to demonstrate best practices for highly
optimized ray tracing performance.  These samples are optimized to provide an easy starting point, 
clarity, and general code readability (rather than performance).

Note:  The sample for Pete Shirley's "Ray Tracing In One Weekend" renderer has not yet been 
ported to Windows 10 RS5.  (That used a quick hack for custom intersection shaders; Falcor
will eventually have first class support for custom intersection shaders, after which I will
redo that example.)

----------------------------------------------------------------------------------------------
 Requirements:
----------------------------------------------------------------------------------------------

1) Windows 10 RS5 or later.
     * If you run "winver.exe" you should have Version 1809 (OS Build 17763)
     * The tutorials do *not* run on Win 10 RS4 or earlier
     * If you have Windows 10 RS4, please see my webpage for code that builds & runs there.

2) Microsoft Visual Studio 2017
     * The free Community Edition has been tested to work.

3) Windows 10 SDK 10.0.17763.0
     * Download here: https://developer.microsoft.com/en-us/windows/downloads/sdk-archive
     * Note: Later SDK versions *probably* work, but you would need to change each Visual  
       Studio project to look for the SDK you download, rather than 10.0.17763.0.  (Do this
       under Project -> Properties -> Config Properties -> General -> Window SDK Version)
     * Earlier versions of the SDK *will not* work (and will give lots of errors about 
       missing functions related to ray tracing).

4) A graphics card supporting DirectX Raytracing
     * I have tested on GeForce RTX cards, and a Titan V should work.
     * Due to time constraints, I have not had a chance to test use of the fallback layer

5) A driver that natively supports DirectX Raytracing
     * For NVIDIA, use 416.xx or later drivers (in theory any NVIDIA driver for RS5 should work)

----------------------------------------------------------------------------------------------
Getting started:
----------------------------------------------------------------------------------------------

Satisfying the requirements above, you're ready to get started.  

You should be able to unzip the tutorials directory almost anywhere.  The RS4 version had issues
installing in directories with spaces.  I have not had a chance to test.  For now, I suggest 
avoiding installing into directories with spaces.

This set of code includes Falcor 3.1.0 from https://github.com/NVIDIAGameWorks/Falcor inside
the Falcor/ directory.  I did modify a couple build scripts in Falcor/Framework/BuildScripts/
to move all my demo files into the Bin directory; otherwise Falcor is unmodified.

Before compiling, you need to download the other Falcor dependencies.  When you compile in
Visual Studio the first time, this should happen for you.  If you run into errors with 
dependencies (glm, glfw, assimp, imgui, etc.), you may want to run the "update_dependencies.bat"
file (in the "Falcor/" directory) manually. 

Open the Visual Studio solution "DirectXRaytracingTutorials.sln", and build.

Most tutorials load a default scene (the "modern living room" from Benedikt Bitterli's page).
We also include one other simple scene in directory "Falcor/Media/Arcade/".  Additional, more complex 
scenes can be downloaded from the Open Research Content Archive: 
     * https://developer.nvidia.com/orca 
     * https://developer.nvidia.com/orca/amazon-lumberyard-bistro
     * https://developer.nvidia.com/orca/nvidia-emerald-square
     * https://developer.nvidia.com/ue4-sun-temple

----------------------------------------------------------------------------------------------
Troubleshooting:
----------------------------------------------------------------------------------------------

A) Visual Studio gives "Error MSB3073" when building.  This is an issue with the pre-build 
   step, and we've seen it in the following cases:
   * The installation directory name (or parent directories) contains a space.
   * You ran a parallel build; our pre-build script gets called for each tutorial and fails 
     on all except the first.  This is usually a one-time error and rebuilding solves the problem.
   * There are installation problems with the dependencies.  Remove the "Falcor/Media/" directory
     and all links (but not real directories) in "Falcor/Framework/Externals/" and then rerun the 
     "update_dependencies.bat" in the "Falcor/" directory.


----------------------------------------------------------------------------------------------
Acknowledgements:
----------------------------------------------------------------------------------------------

The desert HDR environment map (MonValley Dirtroad) is provided from the sIBL Archive under a 
Creative Commons license (CC BY-NC-SA 3.0 US). See
    http://www.hdrlabs.com/sibl/archive.html 

The included "pink_room" scene is named 'The Modern Living Room' by Wig42 on Benedikt Bitterli's
webpage (https://benedikt-bitterli.me/resources/).  It has been modified to match the Falcor 
material system.  This scene was released under a CC-BY license.  It may be copied, modified and 
used commercially without permission, as long as: Appropriate credit is given to the original author
The original scene file may be obtained here: 
    http://www.blendswap.com/blends/view/75692