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

// This render pass updates the "RayTracedGBufferPass" from Tutorial #4 to include both camera 
//      jitter (as in Tutorial #7) as well as a thin-lens camera approximation.  This allows the
//      viewer to specify a focal length and f-number (which is a photographic method of setting
//      the camera aperature size).  When combined with temporal accumulation, this allows 
//      rendering of antialiased images with variable, user-controllable depth-of-field.

#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"
#include <random>

class ThinLensGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, ThinLensGBufferPass>
{
public:
    using SharedPtr = std::shared_ptr<ThinLensGBufferPass>;
    using SharedConstPtr = std::shared_ptr<const ThinLensGBufferPass>;

    static SharedPtr create() { return SharedPtr(new ThinLensGBufferPass()); }
    virtual ~ThinLensGBufferPass() = default;

protected:
	ThinLensGBufferPass() : ::RenderPass("Thin Lens Camera", "Thin Lens G-Buffer Options") {}

    // Implementation of RenderPass interface
    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void execute(RenderContext* pRenderContext) override;
	void renderGui(Gui* pGui) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

	// The RenderPass class defines various methods we can override to specify this pass' properties. 
	bool requiresScene() override { return true; }
	bool usesRayTracing() override { return true; }

	// Internal pass state
	RayLaunch::SharedPtr        mpRays;            ///< Our wrapper around a DX Raytracing pass
	RtScene::SharedPtr          mpScene;           ///< A copy of our scene

	// Thin lens parameters
	bool      mUseThinLens = false;                ///< Use a thin lens approximation (or only a standard pinhole camera)?
	float     mFNumber = 32.0f;                    ///< What is the f-number we should use?
	float     mFocalLength = 1.0f;                 ///< What is out camera's focal length?
	float     mLensRadius;                         ///< The camera aperature.  Computed from focal length and f-numbers

	// State for our camera jitter and random number generator (if we're doing randomized samples)
	bool      mUseJitter = false;
	bool      mUseRandomJitter = false;
	std::uniform_real_distribution<float> mRngDist;     ///< We're going to want random #'s in [0...1] (the default distribution)
	std::mt19937 mRng;                                  ///< Our random number generate.  Set up in initialize()

	// A texture containing our environment map
	vec3      mBgColor = vec3(0.5f, 0.5f, 1.0f);

	// A counter to initialize our thin-lens random numbers each frame; incremented by 1 each frame
	uint32_t   mFrameCount = 0xdeadbeef;    // Should use a different start value than other passes
};
