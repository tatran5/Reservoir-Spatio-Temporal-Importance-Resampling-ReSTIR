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
}

// Input and out textures that need to be set by the C++ code
Texture2D<float4>   gPos;           // G-buffer world-space position
Texture2D<float4>   gNorm;          // G-buffer world-space normal
Texture2D<float4>   gDiffuseMatl;   // G-buffer diffuse material (RGB) and opacity (A)
RWTexture2D<float4> gReservoir;			// For ReSTIR - need to be read-write because it is also updated in the shader as well
RWTexture2D<float4> gOutput;        // Output to store shaded result

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

		float4 prev_reservoir = gReservoir[launchIndex];
		float4 reservoir = float4(0.f);
		float p_hat;

		// initialize previous reservoir if this is the first iteraation
		if (gInitLight) { prev_reservoir = float4(0.f); }

		// ----------------------------------------------------------------------------------------------
		// -----------------------------Initial candidates generation BEGIN -----------------------------
		// ----------------------------------------------------------------------------------------------

		// Generate Initial Candidates - Algorithm 3 of ReSTIR paper
		for (int i = 0; i < 32; i++) {
			lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
			getLightData(lightToSample, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term

			// p_hat of the light is f * Le * G / pdf
			p_hat = length(difMatlColor.xyz * lightIntensity * LdotN / (distToLight * distToLight)); // technically p_hat is divided by pdf, but point light pdf is 1
			reservoir = updateReservoir(reservoir, lightToSample, p_hat, randSeed);
		}

		// ----------------------------------------------------------------------------------------------
		// -----------------------------Initial candidates generation END -------------------------------
		// ----------------------------------------------------------------------------------------------

		// Evaluate visibility for initial candidate and set r.W value
		lightToSample = reservoir.y;
		getLightData(lightToSample, worldPos.xyz, toLight, lightIntensity, distToLight);
		LdotN = saturate(dot(worldNorm.xyz, toLight));
		p_hat = length(difMatlColor.xyz * lightIntensity * LdotN / (distToLight * distToLight));
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
			getLightData(reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term
			p_hat = length(difMatlColor.xyz * lightIntensity * LdotN / (distToLight * distToLight));
			temporal_reservoir = updateReservoir(temporal_reservoir, reservoir.y, p_hat * reservoir.w * reservoir.z, randSeed);

			// combine previous reservoir
			getLightData(prev_reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight)); // lambertian term
			p_hat = length(difMatlColor.xyz * lightIntensity * LdotN / (distToLight * distToLight));
			prev_reservoir.z = min(prev_reservoir.z, 20.f * reservoir.z); // clamp r.M value if it is too large
			temporal_reservoir = updateReservoir(temporal_reservoir, prev_reservoir.y, p_hat * prev_reservoir.w * prev_reservoir.z, randSeed);

			// set M value
			temporal_reservoir.z = reservoir.z + prev_reservoir.z;

			// set W value
			getLightData(temporal_reservoir.y, worldPos.xyz, toLight, lightIntensity, distToLight);
			LdotN = saturate(dot(worldNorm.xyz, toLight));
			p_hat = length(difMatlColor.xyz * lightIntensity * LdotN / (distToLight * distToLight));
			temporal_reservoir.w = (1.f / max(p_hat, 0.0001f)) * (temporal_reservoir.x / max(temporal_reservoir.z, 0.0001f));

			// set current reservoir to the combined temporal reservoir
			reservoir = temporal_reservoir;
		}

		// ----------------------------------------------------------------------------------------------
		// ----------------------------------- Temporal reuse END ---------------------------------------
		// ----------------------------------------------------------------------------------------------

		// Shoot our ray.  Since we're randomly sampling lights, divide by the probability of sampling
		//    (we're uniformly sampling, so this probability is: 1 / #lights) 
		float shadowMult = float(gLightsCount) * shadowRayVisibility(worldPos.xyz, toLight, gMinT, distToLight);

		if (shadowMult < 0.001f) {
			reservoir.w = 0.f;
		}

		gReservoir[launchIndex] = reservoir;

		// Compute our Lambertian shading color using the physically based Lambertian term (albedo / pi)
		shadeColor = shadowMult * reservoir.w * LdotN * lightIntensity * difMatlColor.rgb / 3.141592f;
	}

	// Save out our final shaded
	gOutput[launchIndex] = float4(shadeColor, 1.0f);
}
