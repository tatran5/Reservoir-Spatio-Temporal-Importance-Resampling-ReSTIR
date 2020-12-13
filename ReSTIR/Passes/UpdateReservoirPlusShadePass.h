#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/RayLaunch.h"

class UpdateReservoirPlusShadePass : public ::RenderPass, inherit_shared_from_this<::RenderPass, UpdateReservoirPlusShadePass>
{
public:
	using SharedPtr = std::shared_ptr<UpdateReservoirPlusShadePass>;
	using SharedConstPtr = std::shared_ptr<const UpdateReservoirPlusShadePass>;

	static SharedPtr create() { return SharedPtr(new UpdateReservoirPlusShadePass()); }
	virtual ~UpdateReservoirPlusShadePass() = default;

protected:
	UpdateReservoirPlusShadePass() : ::RenderPass("Update Reservoir and Shade Pass", "Update Reservoir Options") {}

	// Implementation of RenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;
	void execute(RenderContext* pRenderContext) override;

	// Override some functions that provide information to the RenderPipeline class
	bool requiresScene() override { return true; }
	bool usesRayTracing() override { return true; }

	// Rendering state
	RayLaunch::SharedPtr                    mpRays;                 ///< Our wrapper around a DX Raytracing pass
	RtScene::SharedPtr                      mpScene;                ///< Our scene file (passed in from app)  
};
