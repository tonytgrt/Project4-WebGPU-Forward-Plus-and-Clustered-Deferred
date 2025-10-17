@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> lightGrid: array<LightGridEntry>;
@group(${bindGroup_scene}) @binding(3) var<storage, read> globalLightIndexList: array<u32>;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster this fragment belongs to
    // Transform world position to view space
    let viewPos = cameraUniforms.viewMat * vec4f(in.pos, 1.0);
    let viewZ = viewPos.z;

    let clusterIdx = getClusterIndex(
        in.fragPos,
        viewZ,
        cameraUniforms.screenWidth,
        cameraUniforms.screenHeight,
        cameraUniforms.nearPlane,
        cameraUniforms.farPlane
    );

    let gridEntry = lightGrid[clusterIdx];
    let lightCount = gridEntry.count;
    let lightOffset = gridEntry.offset;

    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    for (var i = 0u; i < lightCount; i++) {
        let lightIdx = globalLightIndexList[lightOffset + i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
}
