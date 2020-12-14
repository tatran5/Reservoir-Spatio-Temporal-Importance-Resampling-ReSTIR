#include "UpdateReservoirPlusShadePass.h"

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kFileRayTrace = "Tutorial11\\updateReservoirPlusShade.rt.hlsl";

	// What are the entry points in that shader for various ray tracing shaders?
	const char* kEntryPointRayGen  = "LambertShadowsRayGen";
	const char* kEntryPointMiss0   = "ShadowMiss";
	const char* kEntryAoAnyHit     = "ShadowAnyHit";
	const char* kEntryAoClosestHit = "ShadowClosestHit";
};

bool UpdateReservoirPlusShadePass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse",
											"ReservoirPrev", "ReservoirSpatial", "IndirectOutput" });	
	mpResManager->requestTextureResource(ResourceManager::kOutputChannel);

	// Create our wrapper around a ray tracing pass.  Tell it where our ray generation shader and ray-specific shaders are
	mpRays = RayLaunch::create(kFileRayTrace, kEntryPointRayGen);
	mpRays->addMissShader(kFileRayTrace, kEntryPointMiss0);
	mpRays->addHitShader(kFileRayTrace, kEntryAoClosestHit, kEntryAoAnyHit);
	mpRays->compileRayProgram();
	if (mpScene) mpRays->setScene(mpScene);
    return true;
}

void UpdateReservoirPlusShadePass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene)
{
	// Stash a copy of the scene and pass it to our ray tracer (if initialized)
    mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
	if (mpRays) mpRays->setScene(mpScene);
}

void UpdateReservoirPlusShadePass::execute(RenderContext* pRenderContext)
{
	// Get the output buffer we're writing into; clear it to black.
	Texture::SharedPtr pDstTex = mpResManager->getClearedTexture(ResourceManager::kOutputChannel, vec4(0.0f, 0.0f, 0.0f, 0.0f));

	// Do we have all the resources we need to render?  If not, return
	if (!pDstTex || !mpRays || !mpRays->readyToRender()) return;

	// Set our ray tracing shader variables 
	auto rayGenVars = mpRays->getRayGenVars();
	rayGenVars["RayGenCB"]["gMinT"]       = mpResManager->getMinTDist();

	// Pass our G-buffer textures down to the HLSL so we can shade
	rayGenVars["gPos"]         = mpResManager->getTexture("WorldPosition");
	rayGenVars["gNorm"]        = mpResManager->getTexture("WorldNormal");
	rayGenVars["gDiffuseMatl"] = mpResManager->getTexture("MaterialDiffuse");

	// For ReSTIR - update the buffer storing reservoir (weight sum, chosen light index, number of candidates seen) 
	rayGenVars["gReservoirPrev"] = mpResManager->getTexture("ReservoirPrev");
	rayGenVars["gReservoirSpatial"] = mpResManager->getTexture("ReservoirSpatial");
	rayGenVars["gIndirectOutput"] = mpResManager->getTexture("IndirectOutput");

	rayGenVars["gOutput"]      = pDstTex;


	// Shoot our rays and shade our primary hit points
	mpRays->execute( pRenderContext, mpResManager->getScreenSize() );
}


