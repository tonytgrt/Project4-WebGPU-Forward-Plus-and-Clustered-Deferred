// TODO-2: implement the light clustering compute shader
@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

// Convert clip space depth to view space depth
fn clipToViewDepth(clipDepth: f32) -> f32 {
    let ndc_z = clipDepth * 2.0 - 1.0;  // [0,1] to [-1,1]
    let viewDepth = cameraUniforms.invProjMat[3][2] / (ndc_z - cameraUniforms.invProjMat[2][2]);
    return -viewDepth;  // Negate because view space looks down -Z
}

// Get the view space position of a cluster corner
fn getClusterCornerViewPos(clusterX: u32, clusterY: u32, clusterZ: u32, cornerX: u32, cornerY: u32, cornerZ: u32) -> vec3f {
    // Calculate NDC coordinates for this corner
    let ndcX = (f32(clusterX + cornerX) / f32(${clusterX})) * 2.0 - 1.0;
    let ndcY = (f32(clusterY + cornerY) / f32(${clusterY})) * 2.0 - 1.0;
    
    // Calculate depth value for this Z slice
    let near = cameraUniforms.nearFar.x;
    let far = cameraUniforms.nearFar.y;
    
    // Use logarithmic depth distribution
    let tZ = f32(clusterZ + cornerZ) / f32(${clusterZ});
    let viewZ = -near * pow(far / near, tZ);  // Negative because view space looks down -Z
    
    // Create a point in NDC space
    let ndcPos = vec4f(ndcX, ndcY, 1.0, 1.0);
    
    // Transform to view space
    let viewPosH = cameraUniforms.invProjMat * ndcPos;
    var viewPos = viewPosH.xyz / viewPosH.w;
    
    // Scale the xy coordinates to match the depth
    viewPos.x = viewPos.x * (-viewZ / viewPos.z);
    viewPos.y = viewPos.y * (-viewZ / viewPos.z);
    viewPos.z = viewZ;
    
    return viewPos;
}

// AABB structure for cluster bounds
struct AABB {
    min: vec3f,
    max: vec3f
}

// Calculate the AABB for a cluster in view space
fn getClusterAABB(clusterX: u32, clusterY: u32, clusterZ: u32) -> AABB {
    var aabb: AABB;
    aabb.min = vec3f(1e10, 1e10, 1e10);
    aabb.max = vec3f(-1e10, -1e10, -1e10);
    
    // Check all 8 corners of the cluster
    for (var cornerX = 0u; cornerX < 2u; cornerX++) {
        for (var cornerY = 0u; cornerY < 2u; cornerY++) {
            for (var cornerZ = 0u; cornerZ < 2u; cornerZ++) {
                let corner = getClusterCornerViewPos(clusterX, clusterY, clusterZ, cornerX, cornerY, cornerZ);
                aabb.min = min(aabb.min, corner);
                aabb.max = max(aabb.max, corner);
            }
        }
    }
    
    return aabb;
}

// Check if a sphere intersects with an AABB
fn sphereAABBIntersection(sphereCenter: vec3f, sphereRadius: f32, aabb: AABB) -> bool {
    // Find the closest point on the AABB to the sphere center
    let closestPoint = clamp(sphereCenter, aabb.min, aabb.max);
    
    // Check if the distance from the sphere center to this closest point is less than the radius
    let distance = length(sphereCenter - closestPoint);
    return distance <= sphereRadius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx = globalIdx.x;
    let totalClusters = u32(${clusterX} * ${clusterY} * ${clusterZ});
    
    if (clusterIdx >= totalClusters) {
        return;
    }
    
    // Calculate 3D cluster coordinates from linear index
    let clusterZ = clusterIdx / u32(${clusterX} * ${clusterY});
    let clusterY = (clusterIdx % u32(${clusterX} * ${clusterY})) / u32(${clusterX});
    let clusterX = clusterIdx % u32(${clusterX});
    
    // Calculate cluster AABB in view space
    let aabb = getClusterAABB(clusterX, clusterY, clusterZ);
    
    // Reset light count for this cluster
    var lightCount = 0u;
    
    // Check each light against this cluster
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        // Transform light position to view space
        let lightWorldPos = lightSet.lights[lightIdx].pos;
        let lightViewPos4 = cameraUniforms.viewMat * vec4f(lightWorldPos, 1.0);
        let lightViewPos = lightViewPos4.xyz;
        
        // Check if light sphere intersects with cluster AABB
        if (sphereAABBIntersection(lightViewPos, ${lightRadius}, aabb)) {
            if (lightCount < u32(${maxLightsPerCluster})) {
                clusterSet.clusters[clusterIdx].lightIndices[lightCount] = lightIdx;
                lightCount++;
            }
        }
    }
    
    // Store the final light count for this cluster
    clusterSet.clusters[clusterIdx].numLights = lightCount;
}