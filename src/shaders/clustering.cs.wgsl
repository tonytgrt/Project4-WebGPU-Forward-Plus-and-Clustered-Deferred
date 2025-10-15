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

fn clipToViewDepth(clipDepth: f32) -> f32 {
    let ndc_z = clipDepth * 2.0 - 1.0;
    let viewDepth = cameraUniforms.invProjMat[3][2] / (ndc_z - cameraUniforms.invProjMat[2][2]);
    return -viewDepth;
}

fn getClusterCornerViewPos(clusterX: u32, clusterY: u32, clusterZ: u32, cornerX: u32, cornerY: u32, cornerZ: u32) -> vec3f {
    let ndcX = (f32(clusterX + cornerX) / f32(${clusterX})) * 2.0 - 1.0;
    let ndcY = (f32(clusterY + cornerY) / f32(${clusterY})) * 2.0 - 1.0;

    let near = cameraUniforms.nearFar.x;
    let far = cameraUniforms.nearFar.y;

    let tZ = f32(clusterZ + cornerZ) / f32(${clusterZ});
    let viewZ = -near * pow(far / near, tZ);

    let clipPos = vec4f(ndcX, ndcY, 0.0, 1.0);

    let viewPosH = cameraUniforms.invProjMat * clipPos;
    var viewPos = viewPosH.xyz / viewPosH.w;

    viewPos.x *= -viewZ / viewPos.z;
    viewPos.y *= -viewZ / viewPos.z;
    viewPos.z = viewZ;

    return viewPos;
}

struct AABB {
    min: vec3f,
    max: vec3f
}

fn getClusterAABB(clusterX: u32, clusterY: u32, clusterZ: u32) -> AABB {
    var aabb: AABB;
    aabb.min = vec3f(1e10, 1e10, 1e10);
    aabb.max = vec3f(-1e10, -1e10, -1e10);

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

fn sphereAABBIntersection(sphereCenter: vec3f, sphereRadius: f32, aabb: AABB) -> bool {
    let closestPoint = clamp(sphereCenter, aabb.min, aabb.max);

    let distance = length(sphereCenter - closestPoint);
    return distance <= sphereRadius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx = globalIdx.x;
    let totalClusters = ${clusterX} * ${clusterY} * ${clusterZ};

    if (clusterIdx >= u32(totalClusters)) {
        return;
    }

    let clusterZ = clusterIdx / (${clusterX} * ${clusterY});
    let clusterY = (clusterIdx % (${clusterX} * ${clusterY})) / ${clusterX};
    let clusterX = clusterIdx % ${clusterX};

    let aabb = getClusterAABB(clusterX, clusterY, clusterZ);

    var lightCount = 0u;

    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let lightWorldPos = lightSet.lights[lightIdx].pos;
        let lightViewPos4 = cameraUniforms.viewMat * vec4f(lightWorldPos, 1.0);
        let lightViewPos = lightViewPos4.xyz;

        if (sphereAABBIntersection(lightViewPos, ${lightRadius}, aabb)) {
            if (lightCount < ${maxLightsPerCluster}) {
                clusterSet.clusters[clusterIdx].lightIndices[lightCount] = lightIdx;
                lightCount++;
            }
        }
    }

    clusterSet.clusters[clusterIdx].numLights = lightCount;
}
