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
    float2 screenspace_origin;
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
    float4 tilesize_repeat;
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
    float4 tilesize_repeat;
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
    float4 stretchsize_and_tilespacing;
    float4 sub_rect;
};

cbuffer Locals
{
    row_major float4x4 uTransform : packoffset(c0);
    int uMode : packoffset(c4);
    float uDevicePixelRatio : packoffset(c4.y);
};
Texture2D<float4> sResourceCache;
SamplerState sResourceCache_;
Texture2D<float4> sLayers;
SamplerState sLayers_;
Texture2D<float4> sRenderTasks;
SamplerState sRenderTasks_;
Texture2DArray<float4> sSharedCacheA8;
SamplerState sSharedCacheA8_;
Texture2DArray<float4> sColor0;
SamplerState sColor0_;
Texture2DArray<float4> sColor1;
SamplerState sColor1_;
Texture2DArray<float4> sColor2;
SamplerState sColor2_;
Texture2DArray<float4> sCacheA8;
SamplerState sCacheA8_;
Texture2DArray<float4> sCacheRGBA8;
SamplerState sCacheRGBA8_;
Texture2D<float4> sGradients;
SamplerState sGradients_;

static float4 gl_Position;
static int4 aDataA;
static int4 aDataB;
static float3 aPosition;
static float4 vClipMaskUvBounds;
static float3 vClipMaskUv;
static float2 vPos;
static float4 vColor;

struct SPIRV_Cross_Input
{
    int4 aDataA : aDataA;
    int4 aDataB : aDataB;
    float3 aPosition : aPosition;
};

struct SPIRV_Cross_Output
{
    float3 vClipMaskUv : vClipMaskUv;
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    float4 vColor : vColor;
    float2 vPos : vPos;
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
    task.screenspace_origin = data.data1.xy;
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

float3x4 fetch_from_resource_cache_3(int address)
{
    int param = address;
    int2 uv = get_resource_cache_uv(param);
    float3x4 result = { sResourceCache.Load(int3(uv, 0), int2(0, 0)), sResourceCache.Load(int3(uv, 0), int2(1, 0)), sResourceCache.Load(int3(uv, 0), int2(2, 0)) };
    return result;
}

Gradient fetch_gradient(int address)
{
    int param = address;
    float3x4 data = fetch_from_resource_cache_3(param);
    Gradient result = { data[0], data[1], data[2] };
    return result;
}

GradientStop fetch_gradientstop(int address)
{
    int param = address;
    float2x4 data = fetch_from_resource_cache_2(param);
    GradientStop result = { data[0], data[1] };
    return result;
}

float2 clamp_rect(float2 _point, RectWithSize rect)
{
    return clamp(_point, rect.p0, rect.p0 + rect.size);
}

float2 computesnap_offset(float2 local_pos, RectWithSize local_clip_rect, Layer layer, inout RectWithSize snap_rect)
{
    float _985 = 1.0f / uDevicePixelRatio;
    snap_rect.size = max(snap_rect.size, float2(_985, _985));
    float4 worldsnap_p0 = mul(float4(snap_rect.p0, 0.0f, 1.0f), layer.transform);
    float4 worldsnap_p1 = mul(float4(snap_rect.p0 + snap_rect.size, 0.0f, 1.0f), layer.transform);
    float4 worldsnap = (float4(worldsnap_p0.xy, worldsnap_p1.xy) * uDevicePixelRatio) / float4(worldsnap_p0.ww, worldsnap_p1.ww);
    float4 snap_offsets = floor(worldsnap + float4(0.5f, 0.5f, 0.5f, 0.5f)) - worldsnap;
    float2 normalizedsnap_pos = (local_pos - snap_rect.p0) / snap_rect.size;
    return lerp(snap_offsets.xy, snap_offsets.zw, normalizedsnap_pos);
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
    float2 _1088 = computesnap_offset(param_4, param_5, param_6, param_7);
    float2 snap_offset = _1088;
    float4 world_pos = mul(float4(clamped_local_pos, 0.0f, 1.0f), layer.transform);
    float2 device_pos = (world_pos.xy / float2(world_pos.w, world_pos.w)) * uDevicePixelRatio;
    float2 final_pos = ((device_pos + snap_offset) - task.screenspace_origin) + task.render_target_origin;
    gl_Position = mul(float4(final_pos, z, 1.0f), uTransform);
    VertexInfo vi = { clamped_local_pos, device_pos };
    return vi;
}

void write_clip(float2 global_pos, ClipArea area)
{
    uint _1220_dummy_parameter;
    float2 texturesize = float2(int3(SPIRV_Cross_textureSize(sSharedCacheA8, uint(0), _1220_dummy_parameter)).xy);
    float2 uv = (global_pos + area.task_bounds.xy) - area.screen_origin_target_index.xy;
    vClipMaskUvBounds = area.task_bounds / texturesize.xyxy;
    vClipMaskUv = float3(uv / texturesize, area.screen_origin_target_index.z);
}

void vert_main()
{
    Primitive prim = load_primitive();
    int param = prim.specific_prim_address;
    Gradient gradient = fetch_gradient(param);
    float4 absstart_end_point = gradient.start_end_point + prim.local_rect.p0.xyxy;
    int stop_address = (prim.specific_prim_address + 3) + (2 * prim.user_data0);
    int param_1 = stop_address;
    GradientStop g0 = fetch_gradientstop(param_1);
    int param_2 = stop_address + 2;
    GradientStop g1 = fetch_gradientstop(param_2);
    float4 adjusted_color_g0 = g0.color;
    float4 adjusted_color_g1 = g1.color;
    RectWithSize segment_rect;
    float2 axis;
    if (absstart_end_point.y == absstart_end_point.w)
    {
        float2 g01_x = lerp(absstart_end_point.xx, absstart_end_point.zz, float2(g0.offset.x, g1.offset.x));
        float2 g01_x_clamped = clamp(g01_x, prim.local_rect.p0.xx, prim.local_rect.p0.xx + prim.local_rect.size.xx);
        segment_rect.p0 = float2(g01_x_clamped.x, prim.local_rect.p0.y);
        segment_rect.size = float2(g01_x_clamped.y - g01_x_clamped.x, prim.local_rect.size.y);
        axis = float2(1.0f, 0.0f);
        float _1346 = g01_x.y - g01_x.x;
        float2 adjusted_offset = (g01_x_clamped - g01_x.xx) / float2(_1346, _1346);
        adjusted_color_g0 = lerp(g0.color, g1.color, float4(adjusted_offset.x, adjusted_offset.x, adjusted_offset.x, adjusted_offset.x));
        adjusted_color_g1 = lerp(g0.color, g1.color, float4(adjusted_offset.y, adjusted_offset.y, adjusted_offset.y, adjusted_offset.y));
    }
    else
    {
        float2 g01_y = lerp(absstart_end_point.yy, absstart_end_point.ww, float2(g0.offset.x, g1.offset.x));
        float2 g01_y_clamped = clamp(g01_y, prim.local_rect.p0.yy, prim.local_rect.p0.yy + prim.local_rect.size.yy);
        segment_rect.p0 = float2(prim.local_rect.p0.x, g01_y_clamped.x);
        segment_rect.size = float2(prim.local_rect.size.x, g01_y_clamped.y - g01_y_clamped.x);
        axis = float2(0.0f, 1.0f);
        float _1415 = g01_y.y - g01_y.x;
        float2 adjusted_offset_1 = (g01_y_clamped - g01_y.xx) / float2(_1415, _1415);
        adjusted_color_g0 = lerp(g0.color, g1.color, float4(adjusted_offset_1.x, adjusted_offset_1.x, adjusted_offset_1.x, adjusted_offset_1.x));
        adjusted_color_g1 = lerp(g0.color, g1.color, float4(adjusted_offset_1.y, adjusted_offset_1.y, adjusted_offset_1.y, adjusted_offset_1.y));
    }
    RectWithSize param_3 = segment_rect;
    RectWithSize param_4 = prim.local_clip_rect;
    float param_5 = prim.z;
    Layer param_6 = prim.layer;
    AlphaBatchTask param_7 = prim.task;
    RectWithSize param_8 = prim.local_rect;
    VertexInfo _1452 = write_vertex(param_3, param_4, param_5, param_6, param_7, param_8);
    VertexInfo vi = _1452;
    float2 f = (vi.local_pos - segment_rect.p0) / segment_rect.size;
    vPos = vi.local_pos;
    float2 param_9 = vi.screen_pos;
    ClipArea param_10 = prim.clip_area;
    write_clip(param_9, param_10);
    float _1478 = dot(f, axis);
    vColor = lerp(adjusted_color_g0, adjusted_color_g1, float4(_1478, _1478, _1478, _1478));
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
    stage_output.vPos = vPos;
    stage_output.vColor = vColor;
    return stage_output;
}
