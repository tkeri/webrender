struct RectWithSize
{
    float2 p0;
    float2 size;
};

struct RectWithEndpoint
{
    float2 p0;
    float2 p1;
};

struct Layer
{
    float4x4 transform;
    float4x4 inv_transform;
    RectWithSize local_clip_rect;
};

struct RenderTaskData
{
    float4 data0;
    float4 data1;
    float4 data2;
};

struct PictureTask
{
    RectWithSize target_rect;
    float render_target_layer_index;
    float2 content_origin;
    float4 color;
};

struct BlurTask
{
    RectWithSize target_rect;
    float render_target_layer_index;
    float blur_radius;
    float4 color;
};

struct AlphaBatchTask
{
    float2 screen_space_origin;
    float2 render_target_origin;
    float2 size;
    float render_target_layer_index;
};

struct ClipArea
{
    float4 task_bounds;
    float4 screen_origin_target_index;
    float4 inner_rect;
};

struct Gradient
{
    float4 start_end_point;
    float4 tile_size_repeat;
    float4 extend_mode;
};

struct GradientStop
{
    float4 color;
    float4 offset;
};

struct RadialGradient
{
    float4 start_end_center;
    float4 start_end_radius_ratio_xy_extend_mode;
    float4 tile_size_repeat;
};

struct Glyph
{
    float2 offset;
};

struct PrimitiveInstance
{
    int prim_address;
    int specific_prim_address;
    int render_task_index;
    int clip_task_index;
    int layer_index;
    int z;
    int user_data0;
    int user_data1;
    int user_data2;
};

struct CompositeInstance
{
    int render_task_index;
    int src_task_index;
    int backdrop_task_index;
    int user_data0;
    int user_data1;
    float z;
};

struct PrimitiveGeometry
{
    RectWithSize local_rect;
    RectWithSize local_clip_rect;
};

struct Primitive
{
    Layer layer;
    ClipArea clip_area;
    AlphaBatchTask task;
    RectWithSize local_rect;
    RectWithSize local_clip_rect;
    int specific_prim_address;
    int user_data0;
    int user_data1;
    int user_data2;
    float z;
};

struct VertexInfo
{
    float2 local_pos;
    float2 screen_pos;
};

struct GlyphResource
{
    float4 uv_rect;
    float layer;
    float2 offset;
    float scale;
};

struct ImageResource
{
    float4 uv_rect;
    float layer;
};

struct Rectangle
{
    float4 color;
};

struct TextRun
{
    float4 color;
    float2 offset;
    int subpx_dir;
};

struct Image
{
    float4 stretch_size_and_tile_spacing;
    float4 sub_rect;
};

cbuffer Locals : register(b0)
{
    row_major float4x4 uTransform : packoffset(c0);
    int uMode : packoffset(c4);
    float uDevicePixelRatio : packoffset(c4.y);
};
Texture2D<float4> sResourceCache : register(t11);
SamplerState sResourceCache_ : register(s11);
Texture2D<float4> sLayers : register(t12);
SamplerState sLayers_ : register(s12);
Texture2D<float4> sRenderTasks : register(t13);
SamplerState sRenderTasks_ : register(s13);
Texture2DArray<float4> sSharedCacheA8 : register(t9);
SamplerState sSharedCacheA8_ : register(s9);
Texture2DArray<float4> sColor0 : register(t3);
SamplerState sColor0_ : register(s3);
Texture2DArray<float4> sColor1 : register(t4);
SamplerState sColor1_ : register(s4);
Texture2DArray<float4> sColor2 : register(t5);
SamplerState sColor2_ : register(s5);
Texture2DArray<float4> sCacheA8 : register(t7);
SamplerState sCacheA8_ : register(s7);
Texture2DArray<float4> sCacheRGBA8 : register(t8);
SamplerState sCacheRGBA8_ : register(s8);
Texture2D<float4> sGradients : register(t10);
SamplerState sGradients_ : register(s10);

static float4 gl_Position;
static int4 aDataA;
static int4 aDataB;
static float3 aPosition;
static float4 vClipMaskUvBounds;
static float3 vClipMaskUv;
static float2 vLocalPos;
static float vLayer;
static float2 vTextureSize;
static float2 vTextureOffset;
static float2 vTileSpacing;
static float2 vStretchSize;
static float4 vStRect;

struct SPIRV_Cross_Input
{
    float3 aPosition : aPosition;
    int4 aDataA : aDataA;
    int4 aDataB : aDataB;
};

struct SPIRV_Cross_Output
{
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    float3 vClipMaskUv : vClipMaskUv;
    nointerpolation float2 vTextureOffset : vTextureOffset;
    nointerpolation float2 vTextureSize : vTextureSize;
    nointerpolation float2 vTileSpacing : vTileSpacing;
    nointerpolation float4 vStRect : vStRect;
    nointerpolation float vLayer : vLayer;
    float2 vLocalPos : vLocalPos;
    nointerpolation float2 vStretchSize : vStretchSize;
    float4 gl_Position : SV_Position;
};

uint3 SPIRV_Cross_textureSize(Texture2DArray<float4> Tex, uint Level, out uint Param)
{
    uint3 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, ret.z, Param);
    return ret;
}

PrimitiveInstance fetch_prim_instance()
{
    PrimitiveInstance pi;
    pi.prim_address = aDataA.x;
    pi.specific_prim_address = pi.prim_address + 2;
    pi.render_task_index = aDataA.y;
    pi.clip_task_index = aDataA.z;
    pi.layer_index = aDataA.w;
    pi.z = aDataB.x;
    pi.user_data0 = aDataB.y;
    pi.user_data1 = aDataB.z;
    pi.user_data2 = aDataB.w;
    return pi;
}

Layer fetch_layer(int index)
{
    int2 uv = int2(9 * (index % 113), index / 113);
    int2 uv0 = int2(uv.x + 0, uv.y);
    int2 uv1 = int2(uv.x + 8, uv.y);
    Layer layer;
    layer.transform[0] = sLayers.Load(int3(uv0, 0), int2(0, 0));
    layer.transform[1] = sLayers.Load(int3(uv0, 0), int2(1, 0));
    layer.transform[2] = sLayers.Load(int3(uv0, 0), int2(2, 0));
    layer.transform[3] = sLayers.Load(int3(uv0, 0), int2(3, 0));
    layer.inv_transform[0] = sLayers.Load(int3(uv0, 0), int2(4, 0));
    layer.inv_transform[1] = sLayers.Load(int3(uv0, 0), int2(5, 0));
    layer.inv_transform[2] = sLayers.Load(int3(uv0, 0), int2(6, 0));
    layer.inv_transform[3] = sLayers.Load(int3(uv0, 0), int2(7, 0));
    float4 clip_rect = sLayers.Load(int3(uv1, 0), int2(0, 0));
    RectWithSize local_clip_rect = {clip_rect.xy, clip_rect.zw};
    layer.local_clip_rect = local_clip_rect;
    return layer;
}

RenderTaskData fetch_render_task(int index)
{
    int2 uv = int2(3 * (index % 341), index / 341);
    RenderTaskData task;
    task.data0 = sRenderTasks.Load(int3(uv, 0), int2(0, 0));
    task.data1 = sRenderTasks.Load(int3(uv, 0), int2(1, 0));
    task.data2 = sRenderTasks.Load(int3(uv, 0), int2(2, 0));
    return task;
}

ClipArea fetch_clip_area(int index)
{
    ClipArea area;
    if (index == 2147483647)
    {
        area.task_bounds = float4(0.0f, 0.0f, 0.0f, 0.0f);
        area.screen_origin_target_index = float4(0.0f, 0.0f, 0.0f, 0.0f);
        area.inner_rect = float4(0.0f, 0.0f, 0.0f, 0.0f);
    }
    else
    {
        int param = index;
        RenderTaskData task = fetch_render_task(param);
        area.task_bounds = task.data0;
        area.screen_origin_target_index = task.data1;
        area.inner_rect = task.data2;
    }
    return area;
}

AlphaBatchTask fetch_alpha_batch_task(int index)
{
    int param = index;
    RenderTaskData data = fetch_render_task(param);
    AlphaBatchTask task;
    task.render_target_origin = data.data0.xy;
    task.size = data.data0.zw;
    task.screen_space_origin = data.data1.xy;
    task.render_target_layer_index = data.data1.z;
    return task;
}

int2 get_resource_cache_uv(int address)
{
    return int2(address % 1024, address / 1024);
}

float2x4 fetch_from_resource_cache_2(int address)
{
    int param = address;
    int2 uv = get_resource_cache_uv(param);
    float2x4 result = { sResourceCache.Load(int3(uv, 0), int2(0, 0)), sResourceCache.Load(int3(uv, 0), int2(1, 0)) };
    return result;
}

PrimitiveGeometry fetch_primitive_geometry(int address)
{
    int param = address;
    float2x4 geom = fetch_from_resource_cache_2(param);
    PrimitiveGeometry result = { { geom[0].xy, geom[0].zw }, { geom[1].xy, geom[1].zw } };
    return result;
}

Primitive load_primitive()
{
    PrimitiveInstance pi = fetch_prim_instance();
    int param = pi.layer_index;
    Primitive prim;
    prim.layer = fetch_layer(param);
    int param_1 = pi.clip_task_index;
    prim.clip_area = fetch_clip_area(param_1);
    int param_2 = pi.render_task_index;
    prim.task = fetch_alpha_batch_task(param_2);
    int param_3 = pi.prim_address;
    PrimitiveGeometry geom = fetch_primitive_geometry(param_3);
    prim.local_rect = geom.local_rect;
    prim.local_clip_rect = geom.local_clip_rect;
    prim.specific_prim_address = pi.specific_prim_address;
    prim.user_data0 = pi.user_data0;
    prim.user_data1 = pi.user_data1;
    prim.user_data2 = pi.user_data2;
    prim.z = float(pi.z);
    return prim;
}

Image fetch_image(int address)
{
    int param = address;
    float2x4 data = fetch_from_resource_cache_2(param);
    Image result = { data[0], data[1] };
    return result;
}

ImageResource fetch_image_resource(int address)
{
    int param = address;
    float2x4 data = fetch_from_resource_cache_2(param);
    ImageResource result = { data[0], data[1].x };
    return result;
}

float2 clamp_rect(float2 _point, RectWithSize rect)
{
    return clamp(_point, rect.p0, rect.p0 + rect.size);
}

float2 compute_snap_offset(float2 local_pos, RectWithSize local_clip_rect, Layer layer, inout RectWithSize snap_rect)
{
    float _985 = 1.0f / uDevicePixelRatio;
    snap_rect.size = max(snap_rect.size, float2(_985, _985));
    float4 world_snap_p0 = mul(float4(snap_rect.p0, 0.0f, 1.0f), layer.transform);
    float4 world_snap_p1 = mul(float4(snap_rect.p0 + snap_rect.size, 0.0f, 1.0f), layer.transform);
    float4 world_snap = (float4(world_snap_p0.xy, world_snap_p1.xy) * uDevicePixelRatio) / float4(world_snap_p0.ww, world_snap_p1.ww);
    float4 snap_offsets = floor(world_snap + float4(0.5f, 0.5f, 0.5f, 0.5f)) - world_snap;
    float2 normalized_snap_pos = (local_pos - snap_rect.p0) / snap_rect.size;
    return lerp(snap_offsets.xy, snap_offsets.zw, normalized_snap_pos);
}

VertexInfo write_vertex(RectWithSize instance_rect, RectWithSize local_clip_rect, float z, Layer layer, AlphaBatchTask task, RectWithSize snap_rect)
{
    float2 local_pos = instance_rect.p0 + (instance_rect.size * aPosition.xy);
    float2 param = local_pos;
    RectWithSize param_1 = local_clip_rect;
    float2 param_2 = clamp_rect(param, param_1);
    RectWithSize param_3 = layer.local_clip_rect;
    float2 clamped_local_pos = clamp_rect(param_2, param_3);
    float2 param_4 = clamped_local_pos;
    RectWithSize param_5 = local_clip_rect;
    Layer param_6 = layer;
    RectWithSize param_7 = snap_rect;
    float2 _1088 = compute_snap_offset(param_4, param_5, param_6, param_7);
    float2 snap_offset = _1088;
    float4 world_pos = mul(float4(clamped_local_pos, 0.0f, 1.0f), layer.transform);
    float2 device_pos = (world_pos.xy / float2(world_pos.w, world_pos.w)) * uDevicePixelRatio;
    float2 final_pos = ((device_pos + snap_offset) - task.screen_space_origin) + task.render_target_origin;
    gl_Position = mul(float4(final_pos, z, 1.0f), uTransform);
    VertexInfo vi = { clamped_local_pos, device_pos };
    return vi;
}

void write_clip(float2 global_pos, ClipArea area)
{
    uint _1220_dummy_parameter;
    float2 texture_size = float2(int3(SPIRV_Cross_textureSize(sSharedCacheA8, uint(0), _1220_dummy_parameter)).xy);
    float2 uv = (global_pos + area.task_bounds.xy) - area.screen_origin_target_index.xy;
    vClipMaskUvBounds = area.task_bounds / texture_size.xyxy;
    vClipMaskUv = float3(uv / texture_size, area.screen_origin_target_index.z);
}

void vert_main()
{
    Primitive prim = load_primitive();
    int param = prim.specific_prim_address;
    Image image = fetch_image(param);
    int param_1 = prim.user_data0;
    ImageResource res = fetch_image_resource(param_1);
    RectWithSize param_2 = prim.local_rect;
    RectWithSize param_3 = prim.local_clip_rect;
    float param_4 = prim.z;
    Layer param_5 = prim.layer;
    AlphaBatchTask param_6 = prim.task;
    RectWithSize param_7 = prim.local_rect;
    VertexInfo _1282 = write_vertex(param_2, param_3, param_4, param_5, param_6, param_7);
    VertexInfo vi = _1282;
    vLocalPos = vi.local_pos - prim.local_rect.p0;
    float2 param_8 = vi.screen_pos;
    ClipArea param_9 = prim.clip_area;
    write_clip(param_8, param_9);
    uint _1301_dummy_parameter;
    float2 texture_size_normalization_factor = float2(float3(int3(SPIRV_Cross_textureSize(sColor0, uint(0), _1301_dummy_parameter))).xy);
    float2 uv1;
    float2 uv0;
    if (image.sub_rect.x < 0.0f)
    {
        uv0 = res.uv_rect.xy;
        uv1 = res.uv_rect.zw;
    }
    else
    {
        uv0 = res.uv_rect.xy + image.sub_rect.xy;
        uv1 = res.uv_rect.xy + image.sub_rect.zw;
    }
    float2 st0 = uv0 / texture_size_normalization_factor;
    float2 st1 = uv1 / texture_size_normalization_factor;
    vLayer = res.layer;
    vTextureSize = st1 - st0;
    vTextureOffset = st0;
    vTileSpacing = image.stretch_size_and_tile_spacing.zw;
    vStretchSize = image.stretch_size_and_tile_spacing.xy;
    float2 half_texel = float2(0.5f, 0.5f) / texture_size_normalization_factor;
    vStRect = float4(min(st0, st1) + half_texel, max(st0, st1) - half_texel);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    aDataA = stage_input.aDataA;
    aDataB = stage_input.aDataB;
    aPosition = stage_input.aPosition;
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.vClipMaskUvBounds = vClipMaskUvBounds;
    stage_output.vClipMaskUv = vClipMaskUv;
    stage_output.vLocalPos = vLocalPos;
    stage_output.vLayer = vLayer;
    stage_output.vTextureSize = vTextureSize;
    stage_output.vTextureOffset = vTextureOffset;
    stage_output.vTileSpacing = vTileSpacing;
    stage_output.vStretchSize = vStretchSize;
    stage_output.vStRect = vStRect;
    return stage_output;
}
