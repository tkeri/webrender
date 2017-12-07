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

struct Border
{
    float4 style;
    float4 widths;
    float4 colors[4];
    float4 radii[2];
};

struct BorderCorners
{
    float2 tl_outer;
    float2 tl_inner;
    float2 tr_outer;
    float2 tr_inner;
    float2 br_outer;
    float2 br_inner;
    float2 bl_outer;
    float2 bl_inner;
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
static float2 vEdgeDistance;
static float vAxisSelect;
static float vAlphaSelect;
static float4 vColor0;
static float4 vColor1;
static float4 vClipParams;
static float vClipSelect;
static float2 vLocalPos;

struct SPIRV_Cross_Input
{
    int4 aDataA : aDataA;
    int4 aDataB : aDataB;
    float3 aPosition : aPosition;
};

struct SPIRV_Cross_Output
{
    nointerpolation float vAlphaSelect : vAlphaSelect;
    nointerpolation float vAxisSelect : vAxisSelect;
    float3 vClipMaskUv : vClipMaskUv;
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    nointerpolation float4 vClipParams : vClipParams;
    nointerpolation float vClipSelect : vClipSelect;
    nointerpolation float4 vColor0 : vColor0;
    nointerpolation float4 vColor1 : vColor1;
    nointerpolation float2 vEdgeDistance : vEdgeDistance;
    float2 vLocalPos : vLocalPos;
    float4 gl_Position : SV_Position;
};

float4 _1324;

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

Border fetch_from_resource_cache_8(int address)
{
    int param = address;
    int2 uv = get_resource_cache_uv(param);
    Border border;
    border.style = sResourceCache.Load(int3(uv, 0), int2(0, 0));
    border.widths = sResourceCache.Load(int3(uv, 0), int2(1, 0));
    float4 colors[4] = { sResourceCache.Load(int3(uv, 0), int2(2, 0)), sResourceCache.Load(int3(uv, 0), int2(3, 0)), sResourceCache.Load(int3(uv, 0), int2(4, 0)), sResourceCache.Load(int3(uv, 0), int2(5, 0)) };
    border.colors = colors;
    float4 radii[2] = { sResourceCache.Load(int3(uv, 0), int2(6, 0)), sResourceCache.Load(int3(uv, 0), int2(7, 0)) };
    border.radii = radii;
    return border;
}

Border fetch_border(int address)
{
    int param = address;
    float4 data[8] = fetch_from_resource_cache_8(param);
    Border result =  { data[0], data[1], { data[2], data[3], data[4], data[5] }, { data[6], data[7] } };
    return result;
}

BorderCorners get_border_corners(Border border, RectWithSize local_rect)
{
    float2 tl_outer = local_rect.p0;
    float2 tl_inner = tl_outer + float2(max(border.radii[0].x, border.widths.x), max(border.radii[0].y, border.widths.y));
    float2 tr_outer = float2(local_rect.p0.x + local_rect.size.x, local_rect.p0.y);
    float2 tr_inner = tr_outer + float2(-max(border.radii[0].z, border.widths.z), max(border.radii[0].w, border.widths.y));
    float2 br_outer = float2(local_rect.p0.x + local_rect.size.x, local_rect.p0.y + local_rect.size.y);
    float2 br_inner = br_outer - float2(max(border.radii[1].x, border.widths.z), max(border.radii[1].y, border.widths.w));
    float2 bl_outer = float2(local_rect.p0.x, local_rect.p0.y + local_rect.size.y);
    float2 bl_inner = bl_outer + float2(max(border.radii[1].z, border.widths.x), -max(border.radii[1].w, border.widths.w));
    BorderCorners result = { tl_outer, tl_inner, tr_outer, tr_inner, br_outer, br_inner, bl_outer, bl_inner };
    return result;
}

float4 get_effective_border_widths(Border border, int style)
{
    switch (style)
    {
        case 2:
        {
            return floor(float4(0.5f, 0.5f, 0.5f, 0.5f) + (border.widths / float4(3.0f, 3.0f, 3.0f, 3.0f)));
        }
        case 6:
        {
            float4 _1314 = border.widths;
            float4 _1315 = _1314 * 0.5f;
            float4 _1316 = float4(0.5f, 0.5f, 0.5f, 0.5f);
            float4 _1317 = _1316 + _1315;
            float4 _1318 = floor(_1317);
            return _1318;
        }
        case 7:
        {
            float4 _1314 = border.widths;
            float4 _1315 = _1314 * 0.5f;
            float4 _1316 = float4(0.5f, 0.5f, 0.5f, 0.5f);
            float4 _1317 = _1316 + _1315;
            float4 _1318 = floor(_1317);
            return _1318;
        }
        default:
        {
            return border.widths;
        }
    }
}

void write_edge_distance(float p0, float original_width, float adjusted_width, float style, float axisselect, float sign_adjust)
{
    switch (int(style))
    {
        case 2:
        {
            vEdgeDistance = float2(p0 + adjusted_width, (p0 + original_width) - adjusted_width);
            break;
        }
        case 6:
        {
            float _1471 = p0;
            float _1472 = adjusted_width;
            float _1473 = _1471 + _1472;
            float _1474 = sign_adjust;
            float2 _1475 = float2(_1473, _1474);
            vEdgeDistance = _1475;
            break;
        }
        case 7:
        {
            float _1471 = p0;
            float _1472 = adjusted_width;
            float _1473 = _1471 + _1472;
            float _1474 = sign_adjust;
            float2 _1475 = float2(_1473, _1474);
            vEdgeDistance = _1475;
            break;
        }
        default:
        {
            vEdgeDistance = float2(0.0f, 0.0f);
            break;
        }
    }
    vAxisSelect = axisselect;
}

void write_clip_params(float style, float border_width, float edge_length, float edge_offset, float center_line)
{
    switch (int(style))
    {
        case 4:
        {
            float desired_dash_length = border_width * 3.0f;
            float dash_count = ceil((0.5f * edge_length) / desired_dash_length);
            float dash_length = (0.5f * edge_length) / dash_count;
            vClipParams = float4(edge_offset - (0.5f * dash_length), 2.0f * dash_length, dash_length, 0.0f);
            vClipSelect = 0.0f;
            break;
        }
        case 3:
        {
            float diameter = border_width;
            float radius = 0.5f * diameter;
            float dot_count = ceil((0.5f * edge_length) / diameter);
            float emptyspace = edge_length - (dot_count * diameter);
            float distance_between_centers = diameter + (emptyspace / dot_count);
            vClipParams = float4(edge_offset - radius, distance_between_centers, radius, center_line);
            vClipSelect = 1.0f;
            break;
        }
        default:
        {
            vClipParams = float4(1.0f, 1.0f, 1.0f, 1.0f);
            vClipSelect = 0.0f;
            break;
        }
    }
}

void write_alphaselect(float style)
{
    switch (int(style))
    {
        case 2:
        {
            vAlphaSelect = 0.0f;
            break;
        }
        default:
        {
            vAlphaSelect = 1.0f;
            break;
        }
    }
}

void write_color0(float4 color, float style, bool flip)
{
    float2 modulate;
    float2 _1510;
    switch (int(style))
    {
        case 6:
        {
            float2 _1499;
            if (flip)
            {
                _1499 = float2(1.2999999523162841796875f, 0.699999988079071044921875f);
            }
            else
            {
                _1499 = float2(0.699999988079071044921875f, 1.2999999523162841796875f);
            }
            modulate = _1499;
            break;
        }
        case 7:
        {
            if (flip)
            {
                _1510 = float2(0.699999988079071044921875f, 1.2999999523162841796875f);
            }
            else
            {
                _1510 = float2(1.2999999523162841796875f, 0.699999988079071044921875f);
            }
            modulate = _1510;
            break;
        }
        default:
        {
            modulate = float2(1.0f, 1.0f);
            break;
        }
    }
    vColor0 = float4(min(color.xyz * modulate.x, float3(color.w, color.w, color.w)), color.w);
}

void write_color1(float4 color, float style, bool flip)
{
    float2 _1550;
    float2 modulate;
    switch (int(style))
    {
        case 6:
        {
            float2 _1543;
            if (flip)
            {
                _1543 = float2(1.2999999523162841796875f, 0.699999988079071044921875f);
            }
            else
            {
                _1543 = float2(0.699999988079071044921875f, 1.2999999523162841796875f);
            }
            modulate = _1543;
            break;
        }
        case 7:
        {
            if (flip)
            {
                _1550 = float2(0.699999988079071044921875f, 1.2999999523162841796875f);
            }
            else
            {
                _1550 = float2(1.2999999523162841796875f, 0.699999988079071044921875f);
            }
            modulate = _1550;
            break;
        }
        default:
        {
            modulate = float2(1.0f, 1.0f);
            break;
        }
    }
    vColor1 = float4(min(color.xyz * modulate.y, float3(color.w, color.w, color.w)), color.w);
}

float2 clamp_rect(float2 _point, RectWithSize rect)
{
    return clamp(_point, rect.p0, rect.p0 + rect.size);
}

float2 computesnap_offset(float2 local_pos, RectWithSize local_clip_rect, Layer layer, inout RectWithSize snap_rect)
{
    float _1035 = 1.0f / uDevicePixelRatio;
    snap_rect.size = max(snap_rect.size, float2(_1035, _1035));
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
    float2 _1138 = computesnap_offset(param_4, param_5, param_6, param_7);
    float2 snap_offset = _1138;
    float4 world_pos = mul(float4(clamped_local_pos, 0.0f, 1.0f), layer.transform);
    float2 device_pos = (world_pos.xy / float2(world_pos.w, world_pos.w)) * uDevicePixelRatio;
    float2 final_pos = ((device_pos + snap_offset) - task.screenspace_origin) + task.render_target_origin;
    gl_Position = mul(float4(final_pos, z, 1.0f), uTransform);
    VertexInfo vi = { clamped_local_pos, device_pos };
    return vi;
}

void write_clip(float2 global_pos, ClipArea area)
{
    uint _1270_dummy_parameter;
    float2 texturesize = float2(int3(SPIRV_Cross_textureSize(sSharedCacheA8, uint(0), _1270_dummy_parameter)).xy);
    float2 uv = (global_pos + area.task_bounds.xy) - area.screen_origin_target_index.xy;
    vClipMaskUvBounds = area.task_bounds / texturesize.xyxy;
    vClipMaskUv = float3(uv / texturesize, area.screen_origin_target_index.z);
}

void vert_main()
{
    Primitive prim = load_primitive();
    int param = prim.specific_prim_address;
    Border border = fetch_border(param);
    int sub_part = prim.user_data0;
    Border param_1 = border;
    RectWithSize param_2 = prim.local_rect;
    BorderCorners corners = get_border_corners(param_1, param_2);
    float4 color = border.colors[sub_part];
    bool color_flip = false;
    float style = border.style.x;
    RectWithSize segment_rect;
    segment_rect.p0 = float2(corners.tl_outer.x, corners.tl_inner.y);
    segment_rect.size = float2(border.widths.x, corners.bl_inner.y - corners.tl_inner.y);
    switch (sub_part)
    {
        case 0:
        {
            segment_rect.p0 = float2(corners.tl_outer.x, corners.tl_inner.y);
            segment_rect.size = float2(border.widths.x, corners.bl_inner.y - corners.tl_inner.y);
            Border param_3 = border;
            int param_4 = int(border.style.x);
            float4 adjusted_widths = get_effective_border_widths(param_3, param_4);
            float param_5 = segment_rect.p0.x;
            float param_6 = border.widths.x;
            float param_7 = adjusted_widths.x;
            float param_8 = border.style.x;
            float param_9 = 0.0f;
            float param_10 = 1.0f;
            write_edge_distance(param_5, param_6, param_7, param_8, param_9, param_10);
            style = border.style.x;
            color_flip = false;
            float param_11 = border.style.x;
            float param_12 = border.widths.x;
            float param_13 = segment_rect.size.y;
            float param_14 = segment_rect.p0.y;
            float param_15 = segment_rect.p0.x + (0.5f * segment_rect.size.x);
            write_clip_params(param_11, param_12, param_13, param_14, param_15);
            break;
        }
        case 1:
        {
            segment_rect.p0 = float2(corners.tl_inner.x, corners.tl_outer.y);
            segment_rect.size = float2(corners.tr_inner.x - corners.tl_inner.x, border.widths.y);
            Border param_16 = border;
            int param_17 = int(border.style.y);
            float4 adjusted_widths_1 = get_effective_border_widths(param_16, param_17);
            float param_18 = segment_rect.p0.y;
            float param_19 = border.widths.y;
            float param_20 = adjusted_widths_1.y;
            float param_21 = border.style.y;
            float param_22 = 1.0f;
            float param_23 = 1.0f;
            write_edge_distance(param_18, param_19, param_20, param_21, param_22, param_23);
            style = border.style.y;
            color_flip = false;
            float param_24 = border.style.y;
            float param_25 = border.widths.y;
            float param_26 = segment_rect.size.x;
            float param_27 = segment_rect.p0.x;
            float param_28 = segment_rect.p0.y + (0.5f * segment_rect.size.y);
            write_clip_params(param_24, param_25, param_26, param_27, param_28);
            break;
        }
        case 2:
        {
            segment_rect.p0 = float2(corners.tr_outer.x - border.widths.z, corners.tr_inner.y);
            segment_rect.size = float2(border.widths.z, corners.br_inner.y - corners.tr_inner.y);
            Border param_29 = border;
            int param_30 = int(border.style.z);
            float4 adjusted_widths_2 = get_effective_border_widths(param_29, param_30);
            float param_31 = segment_rect.p0.x;
            float param_32 = border.widths.z;
            float param_33 = adjusted_widths_2.z;
            float param_34 = border.style.z;
            float param_35 = 0.0f;
            float param_36 = -1.0f;
            write_edge_distance(param_31, param_32, param_33, param_34, param_35, param_36);
            style = border.style.z;
            color_flip = true;
            float param_37 = border.style.z;
            float param_38 = border.widths.z;
            float param_39 = segment_rect.size.y;
            float param_40 = segment_rect.p0.y;
            float param_41 = segment_rect.p0.x + (0.5f * segment_rect.size.x);
            write_clip_params(param_37, param_38, param_39, param_40, param_41);
            break;
        }
        case 3:
        {
            segment_rect.p0 = float2(corners.bl_inner.x, corners.bl_outer.y - border.widths.w);
            segment_rect.size = float2(corners.br_inner.x - corners.bl_inner.x, border.widths.w);
            Border param_42 = border;
            int param_43 = int(border.style.w);
            float4 adjusted_widths_3 = get_effective_border_widths(param_42, param_43);
            float param_44 = segment_rect.p0.y;
            float param_45 = border.widths.w;
            float param_46 = adjusted_widths_3.w;
            float param_47 = border.style.w;
            float param_48 = 1.0f;
            float param_49 = -1.0f;
            write_edge_distance(param_44, param_45, param_46, param_47, param_48, param_49);
            style = border.style.w;
            color_flip = true;
            float param_50 = border.style.w;
            float param_51 = border.widths.w;
            float param_52 = segment_rect.size.x;
            float param_53 = segment_rect.p0.x;
            float param_54 = segment_rect.p0.y + (0.5f * segment_rect.size.y);
            write_clip_params(param_50, param_51, param_52, param_53, param_54);
            break;
        }
    }
    float param_55 = style;
    write_alphaselect(param_55);
    float4 param_56 = color;
    float param_57 = style;
    bool param_58 = color_flip;
    write_color0(param_56, param_57, param_58);
    float4 param_59 = color;
    float param_60 = style;
    bool param_61 = color_flip;
    write_color1(param_59, param_60, param_61);
    RectWithSize param_62 = segment_rect;
    RectWithSize param_63 = prim.local_clip_rect;
    float param_64 = prim.z;
    Layer param_65 = prim.layer;
    AlphaBatchTask param_66 = prim.task;
    RectWithSize param_67 = prim.local_rect;
    VertexInfo _1960 = write_vertex(param_62, param_63, param_64, param_65, param_66, param_67);
    VertexInfo vi = _1960;
    vLocalPos = vi.local_pos;
    float2 param_68 = vi.screen_pos;
    ClipArea param_69 = prim.clip_area;
    write_clip(param_68, param_69);
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
    stage_output.vEdgeDistance = vEdgeDistance;
    stage_output.vAxisSelect = vAxisSelect;
    stage_output.vAlphaSelect = vAlphaSelect;
    stage_output.vColor0 = vColor0;
    stage_output.vColor1 = vColor1;
    stage_output.vClipParams = vClipParams;
    stage_output.vClipSelect = vClipSelect;
    stage_output.vLocalPos = vLocalPos;
    return stage_output;
}
