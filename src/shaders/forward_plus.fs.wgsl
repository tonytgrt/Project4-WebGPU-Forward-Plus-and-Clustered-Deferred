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

fn getClusterIndex(fragPos: vec4f, worldPos: vec3f) -> u32 {
    // fragPos.xy is in viewport coordinates [0, width] x [0, height]
    // Convert to screen space [0, 1]
    let screenPos = fragPos.xy / cameraUniforms.screenDimensions;
    
    // Calculate cluster coordinates  
    let clusterX = min(u32(screenPos.x * f32(${clusterX})), u32(${clusterX} - 1));
    let clusterY = min(u32(screenPos.y * f32(${clusterY})), u32(${clusterY} - 1));
    
    // Calculate depth cluster using the view space position
    // worldPos is in world space, so we need to convert to view space
    let viewPos = cameraUniforms.viewMat * vec4f(worldPos, 1.0);
    let viewZ = -viewPos.z; // Negate because view space looks down -Z
    
    // Clamp view Z to valid range
    let near = cameraUniforms.nearFar.x;
    let far = cameraUniforms.nearFar.y;
    let clampedZ = clamp(viewZ, near, far);
    
    // Logarithmic depth slicing for better distribution
    let logDepth = log(clampedZ / near) / log(far / near);
    let clusterZ = min(u32(clamp(logDepth * f32(${clusterZ}), 0.0, f32(${clusterZ}) - 1.0)), u32(${clusterZ} - 1));
    
    // Convert 3D cluster coordinate to 1D index
    return clusterX + clusterY * u32(${clusterX}) + clusterZ * u32(${clusterX}) * u32(${clusterY});
}



@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster contains the current fragment.
    let clusterIdx = getClusterIndex(in.fragPos, in.pos);
    
    // Retrieve the cluster data
    let cluster = clusterSet.clusters[clusterIdx];
    
    // Debug: Visualize cluster light count
    // Uncomment these lines to debug clustering (and comment out the rest of the function):
    // let lightCountNorm = f32(cluster.numLights) / 10.0; // Normalize to 0-10 lights
    // return vec4(lightCountNorm, lightCountNorm * 0.5, 0.0, 1.0);
    
    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);
    
    // Add a small ambient term to prevent completely black screen
    totalLightContrib += vec3f(0.2, 0.2, 0.2);  // Increased ambient for visibility
    
    // For each light in the cluster:
    for (var i = 0u; i < cluster.numLights; i++) {
        // Access the light's properties using its index.
        let lightIdx = cluster.lightIndices[i];
        
        // Safety check to prevent out of bounds access
        if (lightIdx >= lightSet.numLights) {
            continue;
        }
        
        let light = lightSet.lights[lightIdx];
        
        // Calculate the contribution of the light based on its position, the fragment's position, and the surface normal.
        let lightContrib = calculateLightContrib(light, in.pos, normalize(in.nor));
        
        // Add the calculated contribution to the total light accumulation.
        totalLightContrib += lightContrib;
    }
    
    // Multiply the fragment's diffuse color by the accumulated light contribution.
    var finalColor = diffuseColor.rgb * totalLightContrib;
    
    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(finalColor, 1);
}