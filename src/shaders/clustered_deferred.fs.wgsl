// Clustered Deferred G-buffer fragment shader
// This shader stores geometry information (position, normal, albedo) into G-buffers
// No lighting calculations are performed here

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct GBufferOutput
{
    @location(0) position: vec4f,
    @location(1) normal: vec4f,
    @location(2) albedo: vec4f
}

@fragment
fn main(in: FragmentInput) -> GBufferOutput
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);

    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var output: GBufferOutput;

    output.position = vec4f(in.pos, in.fragCoord.z);

    output.normal = vec4f(normalize(in.nor), 0.0);

    output.albedo = vec4f(diffuseColor.rgb, 1.0);

    return output;
}
