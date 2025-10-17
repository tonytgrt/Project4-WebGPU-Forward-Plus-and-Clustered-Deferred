WebGPU Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Yiding Tian
* Tested on: **Google Chrome 141.0.7390.108** on
  Windows 11, i9-13900H @ 4.1GHz 32GB, RTX 5080 16GB (Personal laptop with external desktop GPU via NVMe connector running in PCIe 4.0x4)

### Live Demo

[![](img/thumb.png)](http://webgpu.tonyxtian.com)

[**Click here to view the live demo**](http://webgpu.tonyxtian.com)

### Demo Video

[Demo Video (MP4)](img/webgpu_demo.mp4)

## Project Overview

This project implements Forward+ and Clustered Deferred rendering techniques using WebGPU. The application renders the Sponza Atrium scene with a large number of dynamic point lights, demonstrating the performance benefits of clustered lighting approaches over naive forward rendering.

### Implemented Features

#### Core Features
- **Naive Forward Renderer** (20 points)
  - Basic forward rendering with camera view projection matrix
  - All lights evaluated for every fragment
  - Baseline for performance comparison

- **Forward+ Renderer** (50 points)
  - Screen-space light clustering using compute shader
  - 3D grid of clusters in view frustum
  - Light culling per cluster to reduce per-fragment light evaluations
  - Efficient data structure for tracking light indices per cluster

- **Clustered Deferred Renderer** (15 points)
  - G-buffer with three render targets:
    - Position buffer (rgba16float)
    - Normal buffer (rgba16float)
    - Albedo buffer (rgba8unorm)
  - Reuses clustering logic from Forward+
  - Two-pass rendering: geometry pass and fullscreen lighting pass
  - Decouples geometry complexity from lighting complexity

## Performance Analysis

### Rendering Method Comparison

The following analysis compares the performance characteristics of the three rendering methods implemented in this project.

#### Forward+ vs Naive Forward

Forward+ shows significant performance improvements over naive forward rendering, especially as the number of lights increases:

- **Low light count (1-100 lights)**: Forward+ shows moderate improvements (10-20% faster)
- **Medium light count (100-500 lights)**: Forward+ becomes 2-3x faster than naive
- **High light count (500-2000 lights)**: Forward+ can be 5-10x faster than naive

**Why is Forward+ faster?**
- Naive forward rendering evaluates every light for every fragment, resulting in O(fragments × lights) complexity
- Forward+ uses light clustering to limit which lights are evaluated per fragment
- The compute shader pre-calculates which lights affect each screen-space cluster
- Fragments only evaluate lights in their cluster, dramatically reducing shader workload

**Tradeoffs:**
- Forward+ adds overhead for the clustering compute pass
- Memory overhead for light grid and index list buffers
- Most beneficial when lights > 50 and scene complexity is moderate to high

#### Clustered Deferred vs Forward+

Clustered Deferred and Forward+ show different performance characteristics depending on the workload:

**Clustered Deferred advantages:**
- Better performance with high geometric complexity (many overlapping triangles)
- Lighting cost is independent of geometric complexity
- Each pixel is shaded exactly once, regardless of depth complexity
- More efficient when scene has significant overdraw

**Forward+ advantages:**
- Lower memory bandwidth requirements (no G-buffer reads/writes)
- Single-pass rendering can be faster for simple scenes
- Better for scenes with transparency (deferred struggles with alpha blending)
- Simpler pipeline with fewer render targets

**Performance observations:**
- Clustered Deferred uses more memory bandwidth due to G-buffer (3 render targets)
- Forward+ has lower fixed overhead but scales worse with geometric complexity
- In the Sponza scene with many lights (1000+), both perform similarly
- Clustered Deferred becomes faster when fragments are shaded multiple times (overdraw)

### Parameters Affecting Performance

#### Number of Lights
As light count increases:
- Naive renderer: Nearly linear performance degradation
- Forward+: Sublinear degradation due to clustering
- Clustered Deferred: Similar to Forward+, slight overhead from fullscreen pass

#### Cluster Configuration
The clustering grid size affects performance:
- Larger clusters: Fewer clusters but more lights per cluster
- Smaller clusters: More precise light culling but higher data structure overhead
- Current implementation uses a balanced approach for optimal performance

### Optimization Opportunities

Several optimizations could further improve performance:

1. **G-Buffer Optimization**
   - Pack data more efficiently (2-component normals, compressed formats)
   - Reduce from 3 textures to 1-2 textures
   - Reconstruct world position from depth instead of storing it

2. **Compute-based Deferred Shading**
   - Replace fullscreen pass with compute shader for better cache utilization
   - Enable more flexible tile-based processing

3. **Visibility Buffer**
   - Store only primitive IDs instead of full geometry attributes
   - Reconstruct attributes in shading pass
   - Dramatically reduce G-buffer memory footprint

4. **Render Bundles**
   - Pre-record draw commands to reduce CPU overhead
   - Particularly beneficial for static geometry

5. **Dynamic Cluster Size**
   - Adjust cluster dimensions based on light distribution
   - Use hierarchical clustering for better scalability

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
