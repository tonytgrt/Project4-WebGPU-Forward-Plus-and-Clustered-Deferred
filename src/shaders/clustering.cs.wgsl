@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterAABBs: array<AABB>;
@group(0) @binding(3) var<storage, read_write> lightGrid: array<LightGridEntry>;
@group(0) @binding(4) var<storage, read_write> globalLightIndexList: array<u32>;

const totalClusters = ${clusterWidth} * ${clusterHeight} * ${clusterDepth};

fn sphereAABBIntersection(sphereCenter: vec3f, sphereRadius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    let closestPoint = clamp(sphereCenter, aabbMin, aabbMax);

    let distance = length(sphereCenter - closestPoint);

    return distance <= sphereRadius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize}, ${clusteringWorkgroupSize}, ${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterX = globalId.x;
    let clusterY = globalId.y;
    let clusterZ = globalId.z;

    if (clusterX >= ${clusterWidth} || clusterY >= ${clusterHeight} || clusterZ >= ${clusterDepth}) {
        return;
    }

    let clusterIdx = clusterX +
                     clusterY * ${clusterWidth} +
                     clusterZ * ${clusterWidth} * ${clusterHeight};

    let screenWidth = cameraUniforms.screenWidth;
    let screenHeight = cameraUniforms.screenHeight;

    // Calculate screen-space tile bounds (in pixels)
    let tileSize = vec2f(
        screenWidth / f32(${clusterWidth}),
        screenHeight / f32(${clusterHeight})
    );

    let minScreen = vec2f(f32(clusterX), f32(clusterY)) * tileSize;
    let maxScreen = minScreen + tileSize;

    // Get depth bounds for this slice using exponential distribution
    let depthBounds = getDepthSliceBounds(clusterZ, cameraUniforms.nearPlane, cameraUniforms.farPlane);
    let nearDepth = depthBounds.x;
    let farDepth = depthBounds.y;

    // Convert screen corners to NDC [-1, 1]
    let minScreenNDC_y = 1.0 - (maxScreen.y / screenHeight) * 2.0;  
    let maxScreenNDC_y = 1.0 - (minScreen.y / screenHeight) * 2.0; 

    let minScreenNDC = vec2f(
        (minScreen.x / screenWidth) * 2.0 - 1.0,
        minScreenNDC_y
    );
    let maxScreenNDC = vec2f(
        (maxScreen.x / screenWidth) * 2.0 - 1.0,
        maxScreenNDC_y
    );

    // Build the 4 corner points at near and far planes (8 points total) in view-space
    let invProj = cameraUniforms.invProjMat;

    var minView = vec3f(1e10, 1e10, 1e10);
    var maxView = vec3f(-1e10, -1e10, -1e10);

    // Test 8 corners of the frustum cluster
    for (var i = 0u; i < 2u; i++) {
        for (var j = 0u; j < 2u; j++) {
            for (var k = 0u; k < 2u; k++) {
                let x = select(minScreenNDC.x, maxScreenNDC.x, i == 1u);
                let y = select(minScreenNDC.y, maxScreenNDC.y, j == 1u);
                let depth = select(nearDepth, farDepth, k == 1u);

                let viewZ = -depth; // View space Z is negative

                // Unproject screen point at this depth
                let ndc = vec4f(x, y, 0.0, 1.0);
                var viewPos = invProj * ndc;
                viewPos = viewPos / viewPos.w;

                // Scale by depth
                let scale = depth / -viewPos.z;
                viewPos = viewPos * scale;

                minView = min(minView, viewPos.xyz);
                maxView = max(maxView, viewPos.xyz);
            }
        }
    }

    clusterAABBs[clusterIdx].minPos = minView;
    clusterAABBs[clusterIdx].maxPos = maxView;

    var lightCount = 0u;
    var lightIndices: array<u32, ${maxLightsPerCluster}>;

    let numLights = lightSet.numLights;
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];

        // Transform light position from world space to view space
        let lightPosView = (cameraUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;

        // Check if light sphere intersects with cluster AABB
        let lightRadius = ${lightRadius};
        if (sphereAABBIntersection(lightPosView, f32(lightRadius), minView, maxView)) {
            if (lightCount < ${maxLightsPerCluster}) {
                lightIndices[lightCount] = lightIdx;
                lightCount++;
            }
        }
    }

    // Calculate offset into global index list
    // Each cluster gets a contiguous block
    let offset = clusterIdx * ${maxLightsPerCluster};

    for (var i = 0u; i < lightCount; i++) {
        globalLightIndexList[offset + i] = lightIndices[i];
    }

    lightGrid[clusterIdx].offset = offset;
    lightGrid[clusterIdx].count = lightCount;
}
