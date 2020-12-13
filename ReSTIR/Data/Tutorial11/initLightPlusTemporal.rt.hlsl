/**********************************************************************************************************************
# Copyright (c) 2018, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
# following conditions are met:
#  * Redistributions of code must retain the copyright notice, this list of conditions and the following disclaimer.
#  * Neither the name of NVIDIA CORPORATION nor the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT
# SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********************************************************************************************************************/

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
	bool  gInitLight;		// For ReSTIR - to choose an arbitrary light for this pixel after choosing 32 random light candidates
	bool  gTemporalReuse;

	//For GI
	bool  gDoIndirectGI;   // A boolean determining if we should shoot indirect GI rays
	bool  gCosSampling;    // Use cosine sampling (true) or uniform sampling (false)
	bool  gDirectShadow;   // Should we shoot shadow rays from our first hit point?

	matrix <float, 4, 4> gLastCameraMatrix;
}


// The payload used for our indirect global illumination rays
struct IndirectRayPayload
{
	float3 color;    // The (returned) color in the ray's direction
	uint   rndSeed;  // Our random seed, so we pick uncorrelated RNGs along our ray
};


// Input and out textures that need to be set by the C++ code
Texture2D<float4>   gPos;           // G-buffer world-space position
Texture2D<float4>   gNorm;          // G-buffer world-space normal
Texture2D<float4>   gDiffuseMatl;   // G-buffer diffuse material (RGB) and opacity (A)
RWTexture2D<float4> gReservoirPrev;		// For ReSTIR - need to be read-write because it is also updated in the shader as well
RWTexture2D<float4> gReservoirCurr;		// For ReSTIR - need to be read-write because it is also updated in the shader as wellRWTexture2D<float4> gOutput;        // Output to store shaded result
RWTexture2D<float4> gIndirectOutput; //For output from indirect illumination 

// Our environment map, used for the miss shader for indirect rays
Texture2D<float4> gEnvMap;

// What code is executed when our ray misses all geometry?
[shader("miss")]
void IndirectMiss(inout IndirectRayPayload rayData)
{
	// Load some information about our lightprobe texture
	float2 dims;
	gEnvMap.GetDimensions(dims.x, dims.y);

	// Convert our ray direction to a (u,v) coordinate
	float2 uv = wsVectorToLatLong(WorldRayDirection());

	// Load our background color, then store it into our ray payload
	rayData.color = gEnvMap[uint2(uv * dims)].rgb;
}

// What code is executed when our ray hits a potentially transparent surface?
[shader("anyhit")]
void IndirectAnyHit(inout IndirectRayPayload rayData, BuiltInTriangleIntersectionAttributes attribs)
{
	// Is this a transparent part of the surface?  If so, ignore this hit
	if (alphaTestFails(attribs))
		IgnoreHit();
}

// What code is executed when we have a new closest hitpoint?   Well, pick a random light,
//    shoot a shadow ray to that light, and shade using diffuse shading.
[shader("closesthit")]
void IndirectClosestHit(inout IndirectRayPayload rayData, BuiltInTriangleIntersectionAttributes attribs)
{
	// Run a helper functions to extract Falcor scene data for shading
	ShadingData shadeData = getHitShadingData(attribs);

	// Pick a random light from our scene to shoot a shadow ray towards	
	int lightToSample = min(int(nextRand(rayData.rndSeed) * gLightsCount), gLightsCount - 1);

	// Query the scene to find info about the randomly selected light
	float distToLight;
	float3 lightIntensity;
	float3 toLight;
	getLightData(lightToSample, shadeData.posW, toLight, lightIntensity, distToLight);

	// Compute our lambertion term (L dot N)
	float LdotN = saturate(dot(shadeData.N, toLight));

	// Shoot our shadow ray to our randomly selected light
	float shadowMult = float(gLightsCount) * shadowRayVisibility(shadeData.posW, toLight, RayTMin(), distToLight);

	// Return the Lambertian shading color using the physically based Lambertian term (albedo / pi)
	rayData.color = shadowMult * LdotN * lightIntensity * shadeData.diffuse / M_PI;
}

// A utility function to trace an idirect ray and return the color it sees.
//    -> Note:  This assumes the indirect hit programs and miss programs are index 1!
float3 shootIndirectRay(float3 rayOrigin, float3 rayDir, float minT, uint seed)
{
	// Setup shadow ray
	RayDesc rayColor;
	rayColor.Origin = rayOrigin;  // Where does it start?
	rayColor.Direction = rayDir;  // What direction do we shoot it?
	rayColor.TMin = minT;         // The closest distance we'll count as a hit
	rayColor.TMax = 1.0e38f;      // The farthest distance we'll count as a hit

	// Initialize the ray's payload data with black return color and the current rng seed
	IndirectRayPayload payload;
	payload.color = float3(0, 0, 0);
	payload.rndSeed = seed;

	// Trace our ray to get a color in the indirect direction.  Use hit group #1 and miss shader #1
	TraceRay(gRtScene, 0, 0xFF, 1, hitProgramCount, 1, rayColor, payload);

	// Return the color we got from our ray
	return payload.color;
}


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
		// Pick a random light from our scene to sample
		int lightToSample;

		// We need to query our scene to find info about the current light
		float distToLight;      // How far away is it?
		float3 lightIntensity;  // What color is it?
		float3 toLight;         // What direction is it from our current pixel?
		float LdotN;			// Lambert term

		float4 prev_reservoir = float4(0.f); // initialize previous reservoir

		// if not first time fill with previous frame reservoir
		if (!gInitLight) {
			float4 screen_space = mul(worldPos, gLastCameraMatrix);
			screen_space /= screen_space.w;
			uint2 prevIndex = launchIndex;
			prevIndex.x = ((screen_space.x + 1.f) / 2.f) * (float)launchDim.x;
			prevIndex.y = ((1.f - screen_space.y) / 2.f) * (float)launchDim.y;

			if (prevIndex.x >= 0 && prevIndex.x < launchDim.x && prevIndex.y >= 0 && prevIndex.y < launchDim.y) {
				prev_reservoir = gReservoirPrev[prevIndex];
			}
		}

		float4 reservoir = float4(0.f);
		float p_hat;

		// initialize previous reservoir if this is the first iteraation
		if (gInitLight) { prev_reservoir = float4(0.f); }

		// ----------------------------------------------------------------------------------------------
		// -----------------------------Initial candidates generation BEGIN -----------------------------
		// ----------------------------------------------------------------------------------------------

		// Generate Initial Candidates - Algorithm 3 of ReSTIR paper
		for (int i = 0; i < min(gLightsCount, 32); i++) {
			lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
			getLightData(lightToSample, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term

			// p_hat of the light is f * Le * G / pdf
			p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight)); // technically p_hat is divided by pdf, but point light pdf is 1
			reservoir = updateReservoir(reservoir, lightToSample, p_hat, randSeed);
		}

		// ----------------------------------------------------------------------------------------------
		// -----------------------------Initial candidates generation END -------------------------------
		// ----------------------------------------------------------------------------------------------

		// Evaluate visibility for initial candidate and set r.W value
		lightToSample = reservoir.y;
		getLightData(lightToSample, worldPos.xyz, toLight, lightIntensity, distToLight);
		LdotN = saturate(dot(worldNorm.xyz, toLight));
		p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));
		reservoir.w = (1.f / max(p_hat, 0.0001f)) * (reservoir.x / max(reservoir.z, 0.0001f));

		if (shadowRayVisibility(worldPos.xyz, toLight, gMinT, distToLight) < 0.001f) {
			reservoir.w = 0.f;
		}

		// ----------------------------------------------------------------------------------------------
		// ----------------------------------- Temporal reuse BEGIN -------------------------------------
		// ----------------------------------------------------------------------------------------------
		if (gTemporalReuse) {
			float4 temporal_reservoir = float4(0.f);

			// combine current reservoir
			temporal_reservoir = updateReservoir(temporal_reservoir, reservoir.y, p_hat * reservoir.w * reservoir.z, randSeed);

			// combine previous reservoir
			getLightData(prev_reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight));
			p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));
			prev_reservoir.z = min(20.f * reservoir.z, prev_reservoir.z);
			temporal_reservoir = updateReservoir(temporal_reservoir, prev_reservoir.y, p_hat * prev_reservoir.w * prev_reservoir.z, randSeed);

			// set M value
			temporal_reservoir.z = reservoir.z + prev_reservoir.z;

			// set W value
			getLightData(temporal_reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight));
			p_hat = length(difMatlColor.xyz / M_PI * lightIntensity * LdotN / (distToLight * distToLight));
			temporal_reservoir.w = (1.f / max(p_hat, 0.0001f)) * (temporal_reservoir.x / max(temporal_reservoir.z, 0.0001f));

			// set current reservoir to the combined temporal reservoir
			reservoir = temporal_reservoir;
		}

		// ----------------------------------------------------------------------------------------------
		// ----------------------------------- Temporal reuse END ---------------------------------------
		// ----------------------------------------------------------------------------------------------

		// ----------------------------------------------------------------------------------------------
		//----------------------------------- Global Illumination BEGIN----------------------------------
		// ----------------------------------------------------------------------------------------------

		//For Indirect Illumination 
		float3 bounceColor;
		float ID_NdotL;
		float sampleProb;

		// Indirect illumination
		if (gDoIndirectGI)
		{
			// Select a random direction for our diffuse interreflection ray.
			float3 bounceDir;
			if (gCosSampling)
				bounceDir = getCosHemisphereSample(randSeed, worldNorm.xyz);      // Use cosine sampling
			else
				bounceDir = getUniformHemisphereSample(randSeed, worldNorm.xyz);  // Use uniform random samples

			// Get NdotL for our selected ray direction
			ID_NdotL = saturate(dot(worldNorm.xyz, bounceDir));

			// Shoot our indirect global illumination ray
			bounceColor = shootIndirectRay(worldPos.xyz, bounceDir, gMinT, randSeed);

			//bounceColor = (ID_NdotL > 0.50f) ? float3(0, 0, 0) : bounceColor;

			// Probability of selecting this ray ( cos/pi for cosine sampling, 1/2pi for uniform sampling )
			sampleProb = gCosSampling ? (ID_NdotL / M_PI) : (1.0f / (2.0f * M_PI));
		}

		// ----------------------------------------------------------------------------------------------
		// ---------------------------------- Global Illumination END------------------------------------
		// ----------------------------------------------------------------------------------------------

		// Save the computed reserrvoir back into the buffer
		gReservoirCurr[launchIndex] = reservoir;
		gIndirectOutput[launchIndex] = float4(0.f); //Intialize to 0 
		if (gDoIndirectGI)
		{
			gIndirectOutput[launchIndex] = float4((ID_NdotL * bounceColor* difMatlColor.rgb / M_PI / sampleProb), 1.0);
		}
		
	}

	// Save out our final shaded
	//gOutput[launchIndex] = float4(shadeColor, 1.0f);
	
}
