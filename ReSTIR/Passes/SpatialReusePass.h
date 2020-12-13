#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class SpatialReusePass : public ::RenderPass, inherit_shared_from_this<::RenderPass, SpatialReusePass>
{
public:
	bool mSpatialReuse = true;

	using SharedPtr = std::shared_ptr<SpatialReusePass>;
	using SharedConstPtr = std::shared_ptr<const SpatialReusePass>;

	static SharedPtr create() { return SharedPtr(new SpatialReusePass()); }
	virtual ~SpatialReusePass() = default;

protected:
	SpatialReusePass() : ::RenderPass("Spatial Reuse", "Spatial Reuse Options") {}

	// Implementation of RenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;
	void execute(RenderContext* pRenderContext) override;
	void renderGui(Gui* pGui);

	// Override some functions that provide information to the RenderPipeline class
	bool requiresScene() override { return true; }
	bool usesRayTracing() override { return true; }

	// Rendering stateW
	RayLaunch::SharedPtr                    mpRays;                 ///< Our wrapper around a DX Raytracing pass
	RtScene::SharedPtr                      mpScene;                ///< Our scene file (passed in from app)  

	// Various internal parameters
	uint32_t                                mFrameCount = 0x1337u;  ///< A frame counter to vary random numbers over time
};
