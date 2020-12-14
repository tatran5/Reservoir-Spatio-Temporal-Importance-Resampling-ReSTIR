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
	bool  gSpatialReuse;
}

// Input and out textures that need to be set by the C++ code
Texture2D<float4>   gPos;           // G-buffer world-space position
Texture2D<float4>   gNorm;          // G-buffer world-space normal
Texture2D<float4>   gDiffuseMatl;   // G-buffer diffuse material (RGB) and opacity (A)

RWTexture2D<float4> gReservoirCurr;			// For ReSTIR - need to be read-write because it is also updated in the shader as well
RWTexture2D<float4> gReservoirSpatial;		// For ReSTIR - need to be read-write because it is also updated in the shader as well

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

	float4 reservoirNew = float4(0.f);

	// Our camera sees the background if worldPos.w is 0, only do diffuse shading elsewhere
	if (worldPos.w != 0.0f && gSpatialReuse)
	{
		// We need to query our scene to find info about the current light
		float distToLight;      // How far away is it?
		float3 lightIntensity;  // What color is it?
		float3 toLight;         // What direction is it from our current pixel?
		float LdotN;						// Lambert term

		// Additional variables for ReSTIR
		float p_hat;

		// ----------------------------------------------------------------------------------------------
		// ----------------------------------- Algorithm 5 - Spatial reuse BEGIN ------------------------
		// ----------------------------------------------------------------------------------------------
		uint2 neighborOffset;
		uint2	neighborIndex;
		float4 neighborReservoir;

		int neighborsCount = 15;
		int neighborsRange = 5; // Want to sample neighbors within [-neighborsRange, neighborsRange] offset

		// Combine with reservoir at current pixel -------------------------------------------------------
		float4 reservoir = gReservoirCurr[launchIndex];
		getLightData(reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
		LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term
		p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));

		reservoirNew = updateReservoir(reservoirNew, reservoir.y, p_hat * reservoir.w * reservoir.z, randSeed);

		float lightSamplesCount = reservoir.z;
		// Combined logic of picking random neighbor and combine reservoirs
		for (int i = 0; i < neighborsCount; i++) {
			// Reservoir reminder:
			// .x: weight sum
			// .y: chosen light for the pixel
			// .z: the number of samples seen for this current light
			// .w: the final adjusted weight for the current pixel following the formula in algorithm 3 (r.W)

			// Generate a random number from range [0, 2 * neighborsRange] then offset in negative direction 
			// by spatialNeighborCount to get range [-neighborsRange, neighborsRange]. 
			// Need to take care of out of bound case hence the max and min
			neighborOffset.x = int(nextRand(randSeed) * neighborsRange * 2.f) - neighborsRange;
			neighborOffset.y = int(nextRand(randSeed) * neighborsRange * 2.f) - neighborsRange;

			neighborIndex.x = max(0, min(launchDim.x - 1, launchIndex.x + neighborOffset.x));
			neighborIndex.y = max(0, min(launchDim.y - 1, launchIndex.y + neighborOffset.y));

			neighborReservoir = gReservoirCurr[neighborIndex];

			getLightData(neighborReservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term
			p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));

			reservoirNew = updateReservoir(reservoirNew, neighborReservoir.y, p_hat * neighborReservoir.w * neighborReservoir.z, randSeed);

			lightSamplesCount += neighborReservoir.z;
		}

		// Update the correct number of candidates considered for this pixel
		reservoirNew.z = lightSamplesCount;

		// Update the adjusted final weight of the current reservoir ------------------------------------
		getLightData(reservoirNew.y, worldPos.xyz, toLight, lightIntensity, distToLight);
		LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term
		p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));

		reservoirNew.w = (1.f / max(p_hat, 0.0001f)) * (reservoirNew.x / max(reservoirNew.z, 0.0001f));
	}

	gReservoirSpatial[launchIndex] = reservoirNew;
}
