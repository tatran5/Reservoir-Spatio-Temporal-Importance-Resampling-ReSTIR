// Some shared Falcor stuff for talking between CPU and GPU code
#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h"           

// Include and import common Falcor utilities and data structures
import Raytracing;                   // Shared ray tracing specific functions & data
import ShaderCommon;                 // Shared shading data structures
import Shading;                      // Shading functions, etc     
import Lights;                       // Light structures for our current scene

// A separate file with some simple utility functions: getPerpendicularVector(), initRand(), nextRand()
#include "restirUtils.hlsli"

// Include shader entries, data structures, and utility function to spawn shadow rays
#include "standardShadowRay.hlsli"

// A constant buffer we'll populate from our C++ code 
cbuffer RayGenCB
{
	float gMinT;        // Min distance to start a ray to avoid self-occlusion
	uint  gFrameCount;  // Frame counter, used to perturb random seed each frame
	
}

// Input and out textures that need to be set by the C++ code
Texture2D<float4>   gPos;           // G-buffer world-space position
Texture2D<float4>   gNorm;          // G-buffer world-space normal
Texture2D<float4>   gDiffuseMatl;   // G-buffer diffuse material (RGB) and opacity (A)

RWTexture2D<float4> gReservoir;			// For ReSTIR - need to be read-write because it is also updated in the shader as well
RWTexture2D<float4> gReservoir2;			// For ReSTIR - need to be read-write because it is also updated in the shader as well

// How do we shade our g-buffer and generate shadow rays?
[shader("raygeneration")]
void LambertShadowsRayGen()
{
	// Get our pixel's position on the screen
	uint2 launchIndex = DispatchRaysIndex().xy;
	uint2 launchDim = DispatchRaysDimensions().xy;

	// Load g-buffer data:  world-space position, normal, and diffuse color
	float4 worldPos = gPos[launchIndex];
	float4 worldNorm = gNorm[launchIndex];
	float4 difMatlColor = gDiffuseMatl[launchIndex];

	// If we don't hit any geometry, our difuse material contains our background color.
	float3 shadeColor = difMatlColor.rgb;

	// Initialize our random number generator
	uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, gFrameCount, 16);

	// Our camera sees the background if worldPos.w is 0, only do diffuse shading elsewhere
	if (worldPos.w != 0.0f)
	{
		
	}
	gReservoir2[launchIndex] = gReservoir[launchIndex];
}
