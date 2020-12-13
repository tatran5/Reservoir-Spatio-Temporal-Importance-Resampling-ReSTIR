#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class InitLightPlusTemporalPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, InitLightPlusTemporalPass>
{
public:

	bool mTemporalReuse = true;
	bool mInitLightPerPixel = true;
	// Recursive ray tracing can be slow.  Add a toggle to disable, to allow you to manipulate the scene
	bool mDoIndirectGI = true;
	bool mDoCosSampling = true;
	bool mDoDirectShadows = true;

	using SharedPtr = std::shared_ptr<InitLightPlusTemporalPass>;
	using SharedConstPtr = std::shared_ptr<const InitLightPlusTemporalPass>;

	static SharedPtr create() { return SharedPtr(new InitLightPlusTemporalPass()); }
	virtual ~InitLightPlusTemporalPass() = default;

protected:
	InitLightPlusTemporalPass() : ::RenderPass("Intialize & Temporal Reuse", "Intialize Lights and Temporal Reuse Options") {}

	// Implementation of RenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;
	void execute(RenderContext* pRenderContext) override;
	void renderGui(Gui* pGui) override;

	// Override some functions that provide information to the RenderPipeline class
	bool requiresScene() override { return true; }
	bool usesRayTracing() override { return true; }

	// A helper utility to determine if the current scene (if any) has had any camera motion
	bool hasCameraMoved();

	// Rendering state
	RayLaunch::SharedPtr                    mpRays;                 ///< Our wrapper around a DX Raytracing pass
	RtScene::SharedPtr                      mpScene;                ///< Our scene file (passed in from app)  
	mat4                          mpLastCameraMatrix;
	mat4                          mpCurrCameraMatrix;

	// Various internal parameters
	uint32_t                                mFrameCount = 0x1337u;  ///< A frame counter to vary random numbers over time
};
