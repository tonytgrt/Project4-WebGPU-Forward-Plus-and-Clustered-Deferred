// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

fn getClusterIndex(fragPos: vec4f) -> u32 {
    let ndc = fragPos.xyz / fragPos.w;
    
    let screenPos = (ndc.xy + 1.0) * 0.5;
    
    let clusterX = u32(screenPos.x * f32(${clusterX}));
    let clusterY = u32(screenPos.y * f32(${clusterY}));
    
    let linearDepth = fragPos.w;
    let near = cameraUniforms.nearFar.x;
    let far = cameraUniforms.nearFar.y;

    let logDepth = log(linearDepth / near) / log(far / near);
    let clusterZ = u32(clamp(logDepth * f32(${clusterZ}), 0.0, f32(${clusterZ}) - 1.0));

    return clusterX + clusterY * ${clusterX} + clusterZ * ${clusterX} * ${clusterY};
}


@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let clusterIdx = getClusterIndex(in.fragPos);
    
    let cluster = clusterSet.clusters[clusterIdx];
    
    // Initialize a variable to accumulate the total light contribution for the fragment
    var totalLightContrib = vec3f(0, 0, 0);
    
    for (var i = 0u; i < cluster.numLights; i++) {
        let lightIdx = cluster.lightIndices[i];
        let light = lightSet.lights[lightIdx];

        let lightContrib = calculateLightContrib(light, in.pos, normalize(in.nor));

        totalLightContrib += lightContrib;
    }
    
    var finalColor = diffuseColor.rgb * totalLightContrib;
    
    return vec4(finalColor, 1);
}