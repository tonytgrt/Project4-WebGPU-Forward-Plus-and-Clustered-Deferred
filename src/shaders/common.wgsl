// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

// Clustering structures
struct AABB {
    minPos: vec3f,
    maxPos: vec3f
}

struct Cluster {
    minBounds: vec3f,
    maxBounds: vec3f,
    lightCount: u32,
    lightIndices: array<u32, ${maxLightsPerCluster}>
}

// Light grid entry for each cluster
struct LightGridEntry {
    offset: u32,   // offset into global light index list
    count: u32     // number of lights in this cluster
}

struct CameraUniforms {
    viewProjMat: mat4x4f,
    invProjMat: mat4x4f,
    viewMat: mat4x4f,
    screenWidth: f32,
    screenHeight: f32,
    nearPlane: f32,
    farPlane: f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

// Clustering utility functions
fn screenToView(screenCoord: vec2f, depth: f32, invProj: mat4x4f) -> vec3f {
    let ndc = vec4f(screenCoord.x, screenCoord.y, depth, 1.0);

    var viewPos = invProj * ndc;
    viewPos = viewPos / viewPos.w;

    return viewPos.xyz;
}

fn getClusterIndex(fragCoord: vec4f, viewZ: f32, screenWidth: f32, screenHeight: f32, nearPlane: f32, farPlane: f32) -> u32 {
    let clusterX = u32(floor(fragCoord.x / (screenWidth / f32(${clusterWidth}))));
    let clusterY = u32(floor(fragCoord.y / (screenHeight / f32(${clusterHeight}))));

    let zNear = nearPlane;
    let zFar = farPlane;
    let viewDepth = -viewZ; // view space Z is negative

    // Exponential depth slicing: slice = log(z/near) / log(far/near) * numSlices
    let clusterZ = u32(floor(log(viewDepth / zNear) / log(zFar / zNear) * f32(${clusterDepth})));
    let clusterZClamped = clamp(clusterZ, 0u, ${clusterDepth} - 1u);

    let clusterIdx = clusterX +
                     clusterY * ${clusterWidth} +
                     clusterZClamped * ${clusterWidth} * ${clusterHeight};

    return clusterIdx;
}

fn getDepthSliceBounds(sliceIdx: u32, nearPlane: f32, farPlane: f32) -> vec2f {
    // Exponential depth distribution
    let zNear = nearPlane;
    let zFar = farPlane;
    let ratio = zFar / zNear;

    let near = zNear * pow(ratio, f32(sliceIdx) / f32(${clusterDepth}));
    let far = zNear * pow(ratio, f32(sliceIdx + 1u) / f32(${clusterDepth}));

    return vec2f(near, far);
}
