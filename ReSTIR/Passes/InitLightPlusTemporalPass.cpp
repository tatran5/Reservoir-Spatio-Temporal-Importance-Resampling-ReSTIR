#include "InitLightPlusTemporalPass.h"

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kFileRayTrace = "Tutorial11\\initLightPlusTemporal.rt.hlsl";

	// What are the entry points in that shader for various ray tracing shaders?
	const char* kEntryPointRayGen = "LambertShadowsRayGen";
	const char* kEntryPointMiss0 = "ShadowMiss";
	const char* kEntryShadowAnyHit = "ShadowAnyHit";
	const char* kEntryShadowClosestHit = "ShadowClosestHit";

	const char* kEntryPointMiss1 = "IndirectMiss";
	const char* kEntryIndirectAnyHit = "IndirectAnyHit";
	const char* kEntryIndirectClosestHit = "IndirectClosestHit";
};

bool InitLightPlusTemporalPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse", "ReservoirPrev",
											"ReservoirCurr", "IndirectOutput" });	
	mpResManager->requestTextureResource(ResourceManager::kOutputChannel);
	mpResManager->requestTextureResource(ResourceManager::kEnvironmentMap);

	// mpResManager->updateEnvironmentMap("Data/BackgroundImages/MonValley_G_DirtRoad_3k.hdr");
	mpResManager->setDefaultSceneName("Data/Scenes/forest/forest80.fscene");

	// Create our wrapper around a ray tracing pass.  Tell it where our ray generation shader and ray-specific shaders are
	mpRays = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);

	// Add ray type #0 (shadow rays)
	mpRays->addMissShader(kFileRayTrace, kEntryPointMiss0);
	mpRays->addHitShader(kFileRayTrace, kEntryShadowClosestHit, kEntryShadowAnyHit);

	// Add ray type #1 (indirect GI rays)
	mpRays->addMissShader(kFileRayTrace, kEntryPointMiss1);
	mpRays->addHitShader(kFileRayTrace, kEntryIndirectClosestHit, kEntryIndirectAnyHit);

	// Now that we've passed all our shaders in, compile and (if available) setup the scene
	mpRays->compileRayProgram();
	if (mpScene) mpRays->setScene(mpScene);
	return true;
}

void InitLightPlusTemporalPass::renderGui(Gui* pGui)
{
	// Add a toggle to turn on/off shooting of indirect GI rays
	int dirty = 0;
	dirty |= (int)pGui->addCheckBox(mDoDirectShadows ? "Shooting direct shadow rays" : "No direct shadow rays", mDoDirectShadows);
	dirty |= (int)pGui->addCheckBox(mDoIndirectGI ? "Shooting global illumination rays" : "Skipping global illumination",
		mDoIndirectGI);
	dirty |= (int)pGui->addCheckBox(mDoCosSampling ? "Use cosine sampling" : "Use uniform sampling", mDoCosSampling);
	dirty |= (int)pGui->addCheckBox(mTemporalReuse ? "Temporal Reuse ON" : "Temporal Reuse OFF", mTemporalReuse);
	if (dirty) setRefreshFlag();
}

bool InitLightPlusTemporalPass::hasCameraMoved()
{
	// Has our camera moved?
	return mpScene &&                      // No scene?  Then the answer is no
		mpScene->getActiveCamera() &&   // No camera in our scene?  Then the answer is no
		(mpLastCameraMatrix != mpScene->getActiveCamera()->getViewProjMatrix());   // Compare the current matrix with the last one
}

void InitLightPlusTemporalPass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene)
{
	// Stash a copy of the scene and pass it to our ray tracer (if initialized)
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);

	// Grab a copy of the current scene's camera matrix (if it exists)
	if (mpScene && mpScene->getActiveCamera()) {
		mpLastCameraMatrix = mpScene->getActiveCamera()->getViewProjMatrix();
		mpCurrCameraMatrix = mpScene->getActiveCamera()->getViewProjMatrix();
	}

	if (mpRays) mpRays->setScene(mpScene);
}

void InitLightPlusTemporalPass::execute(RenderContext* pRenderContext)
{
	// Get the output buffer we're writing into; clear it to black.
	Texture::SharedPtr pDstTex = mpResManager->getClearedTexture(ResourceManager::kOutputChannel, vec4(0.0f, 0.0f, 0.0f, 0.0f));

	// Do we have all the resources we need to render?  If not, return
	if (!pDstTex || !mpRays || !mpRays->readyToRender()) return;

	// If the camera in our current scene has moved, we want to reset mInitLightPerPixel
	if (hasCameraMoved())
	{
		mpLastCameraMatrix = mpCurrCameraMatrix;
		mpCurrCameraMatrix = mpScene->getActiveCamera()->getViewProjMatrix();
	}

	// Set our ray tracing shader variables 
	auto rayGenVars = mpRays->getRayGenVars();
	rayGenVars["RayGenCB"]["gMinT"]       = mpResManager->getMinTDist();
	rayGenVars["RayGenCB"]["gFrameCount"] = mFrameCount++;
	// For ReSTIR - update the toggle in the shader
	rayGenVars["RayGenCB"]["gInitLight"]  = mInitLightPerPixel; 
	rayGenVars["RayGenCB"]["gTemporalReuse"] = mTemporalReuse;
	rayGenVars["RayGenCB"]["gDoIndirectGI"] = mDoIndirectGI;
	rayGenVars["RayGenCB"]["gCosSampling"] = mDoCosSampling;
	rayGenVars["RayGenCB"]["gDirectShadow"] = mDoDirectShadows;
	rayGenVars["RayGenCB"]["gLastCameraMatrix"] = mpLastCameraMatrix;

	// Pass our G-buffer textures down to the HLSL so we can shade
	rayGenVars["gPos"]         = mpResManager->getTexture("WorldPosition");
	rayGenVars["gNorm"]        = mpResManager->getTexture("WorldNormal");
	rayGenVars["gDiffuseMatl"] = mpResManager->getTexture("MaterialDiffuse");

	// For ReSTIR - update the buffer storing reservoir (weight sum, chosen light index, number of candidates seen) 
	rayGenVars["gReservoirPrev"] = mpResManager->getTexture("ReservoirPrev");
	rayGenVars["gReservoirCurr"] = mpResManager->getTexture("ReservoirCurr");
	rayGenVars["gIndirectOutput"] = mpResManager->getTexture("IndirectOutput");

	// Set our environment map texture for indirect rays that miss geometry 
	auto missVars = mpRays->getMissVars(1);       // Remember, indirect rays are ray type #1
	missVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);

	// Shoot our rays and shade our primary hit points
	mpRays->execute( pRenderContext, mpResManager->getScreenSize() );

	// For ReSTIR - toggle to false so we only sample a random candidate for the first frame
	mInitLightPerPixel = false;
}


