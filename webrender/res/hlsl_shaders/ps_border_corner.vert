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
static float4 vRadii0;
static float4 vRadii1;
static float4 vColorEdgeLine;
static float4 vColor00;
static float4 vColor01;
static float4 vColor10;
static float4 vColor11;
static float2 vClipCenter;
static float2 vClipSign;
static float4 vEdgeDistance;
static float vAlphaSelect;
static float vSDFSelect;
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
    nointerpolation float2 vClipCenter : vClipCenter;
    float3 vClipMaskUv : vClipMaskUv;
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    nointerpolation float2 vClipSign : vClipSign;
    nointerpolation float4 vColor00 : vColor00;
    nointerpolation float4 vColor01 : vColor01;
    nointerpolation float4 vColor10 : vColor10;
    nointerpolation float4 vColor11 : vColor11;
    nointerpolation float4 vColorEdgeLine : vColorEdgeLine;
    nointerpolation float4 vEdgeDistance : vEdgeDistance;
    float2 vLocalPos : vLocalPos;
    nointerpolation float4 vRadii0 : vRadii0;
    nointerpolation float4 vRadii1 : vRadii1;
    nointerpolation float vSDFSelect : vSDFSelect;
    float4 gl_Position : SV_Position;
};

float4 _1322;
int _1719;

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

int selectstyle(int colorselect, float2 fstyle)
{
    int2 style = int2(fstyle);
    bool has_dots;
    bool _1705;
    bool _1694;
    bool _1683;
    switch (colorselect)
    {
        case 0:
        {
            bool _1676 = style.x == 3;
            if (!_1676)
            {
                _1683 = style.y == 3;
            }
            else
            {
                _1683 = _1676;
            }
            has_dots = _1683;
            bool _1687 = style.x == 4;
            if (!_1687)
            {
                _1694 = style.y == 4;
            }
            else
            {
                _1694 = _1687;
            }
            bool has_dashes = _1694;
            bool _1699 = style.x != style.y;
            if (_1699)
            {
                _1705 = has_dots || has_dashes;
            }
            else
            {
                _1705 = _1699;
            }
            if (_1705)
            {
                return 1;
            }
            return style.x;
        }
        case 1:
        {
            return style.x;
        }
        case 2:
        {
            return style.y;
        }
        default:
            return 0;
    }
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
            float4 _1312 = border.widths;
            float4 _1313 = _1312 * 0.5f;
            float4 _1314 = float4(0.5f, 0.5f, 0.5f, 0.5f);
            float4 _1315 = _1314 + _1313;
            float4 _1316 = floor(_1315);
            return _1316;
        }
        case 7:
        {
            float4 _1312 = border.widths;
            float4 _1313 = _1312 * 0.5f;
            float4 _1314 = float4(0.5f, 0.5f, 0.5f, 0.5f);
            float4 _1315 = _1314 + _1313;
            float4 _1316 = floor(_1315);
            return _1316;
        }
        default:
        {
            return border.widths;
        }
    }
}

float2 get_radii(float2 radius, float2 invalid)
{
    if (all(bool2(radius.x > float2(0.0f, 0.0f).x, radius.y > float2(0.0f, 0.0f).y)))
    {
        return radius;
    }
    return invalid;
}

void set_radii(int style, float2 radii, float2 widths, float2 adjusted_widths)
{
    float2 param = radii;
    float2 param_1 = widths * 2.0f;
    float2 _1469 = get_radii(param, param_1);
    vRadii0 = float4(_1469.x, _1469.y, vRadii0.z, vRadii0.w);
    float2 param_2 = radii - widths;
    float2 param_3 = -widths;
    float2 _1479 = get_radii(param_2, param_3);
    vRadii0 = float4(vRadii0.x, vRadii0.y, _1479.x, _1479.y);
    switch (style)
    {
        case 7:
        {
            float2 _1488 = radii;
            float2 _1489 = adjusted_widths;
            float2 _1490 = _1488 - _1489;
            float4 _1491 = vRadii1;
            float4 _1492 = float4(_1490.x, _1490.y, _1491.z, _1491.w);
            vRadii1 = _1492;
            float4 _1495 = vRadii1;
            vRadii1 = float4(_1495.x, _1495.y, float2(-100.0f, -100.0f).x, float2(-100.0f, -100.0f).y);
            break;
        }
        case 6:
        {
            float2 _1488 = radii;
            float2 _1489 = adjusted_widths;
            float2 _1490 = _1488 - _1489;
            float4 _1491 = vRadii1;
            float4 _1492 = float4(_1490.x, _1490.y, _1491.z, _1491.w);
            vRadii1 = _1492;
            float4 _1495 = vRadii1;
            vRadii1 = float4(_1495.x, _1495.y, float2(-100.0f, -100.0f).x, float2(-100.0f, -100.0f).y);
            break;
        }
        case 2:
        {
            float2 param_4 = radii - adjusted_widths;
            float2 param_5 = -widths;
            float2 _1505 = get_radii(param_4, param_5);
            vRadii1 = float4(_1505.x, _1505.y, vRadii1.z, vRadii1.w);
            float2 param_6 = (radii - widths) + adjusted_widths;
            float2 param_7 = -widths;
            float2 _1517 = get_radii(param_6, param_7);
            vRadii1 = float4(vRadii1.x, vRadii1.y, _1517.x, _1517.y);
            break;
        }
        default:
        {
            vRadii1 = float4(float2(-100.0f, -100.0f).x, float2(-100.0f, -100.0f).y, vRadii1.z, vRadii1.w);
            vRadii1 = float4(vRadii1.x, vRadii1.y, float2(-100.0f, -100.0f).x, float2(-100.0f, -100.0f).y);
            break;
        }
    }
}

void set_edge_line(float2 border_width, float2 outer_corner, float2 gradientsign)
{
    float2 gradient = border_width * gradientsign;
    vColorEdgeLine = float4(outer_corner, float2(-gradient.y, gradient.x));
}

void write_color(inout float4 color0, inout float4 color1, int style, float2 delta, int instance_kind)
{
    float4 modulate;
    switch (style)
    {
        case 6:
        {
            modulate = float4(1.0f - (0.300000011920928955078125f * delta.x), 1.0f + (0.300000011920928955078125f * delta.x), 1.0f - (0.300000011920928955078125f * delta.y), 1.0f + (0.300000011920928955078125f * delta.y));
            break;
        }
        case 7:
        {
            modulate = float4(1.0f + (0.300000011920928955078125f * delta.x), 1.0f - (0.300000011920928955078125f * delta.x), 1.0f + (0.300000011920928955078125f * delta.y), 1.0f - (0.300000011920928955078125f * delta.y));
            break;
        }
        default:
        {
            modulate = float4(1.0f, 1.0f, 1.0f, 1.0f);
            break;
        }
    }
    switch (instance_kind)
    {
        case 1:
        {
            color0.w = 0.0f;
            break;
        }
        case 2:
        {
            color1.w = 0.0f;
            break;
        }
    }
    vColor00 = float4(clamp(color0.xyz * modulate.x, float3(0.0f, 0.0f, 0.0f), float3(color0.w, color0.w, color0.w)), color0.w);
    vColor01 = float4(clamp(color0.xyz * modulate.y, float3(0.0f, 0.0f, 0.0f), float3(color0.w, color0.w, color0.w)), color0.w);
    vColor10 = float4(clamp(color1.xyz * modulate.z, float3(0.0f, 0.0f, 0.0f), float3(color1.w, color1.w, color1.w)), color1.w);
    vColor11 = float4(clamp(color1.xyz * modulate.w, float3(0.0f, 0.0f, 0.0f), float3(color1.w, color1.w, color1.w)), color1.w);
}

float2 clamp_rect(float2 _point, RectWithSize rect)
{
    return clamp(_point, rect.p0, rect.p0 + rect.size);
}

float2 computesnap_offset(float2 local_pos, RectWithSize local_clip_rect, Layer layer, inout RectWithSize snap_rect)
{
    float _1033 = 1.0f / uDevicePixelRatio;
    snap_rect.size = max(snap_rect.size, float2(_1033, _1033));
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
    float2 _1136 = computesnap_offset(param_4, param_5, param_6, param_7);
    float2 snap_offset = _1136;
    float4 world_pos = mul(float4(clamped_local_pos, 0.0f, 1.0f), layer.transform);
    float2 device_pos = (world_pos.xy / float2(world_pos.w, world_pos.w)) * uDevicePixelRatio;
    float2 final_pos = ((device_pos + snap_offset) - task.screenspace_origin) + task.render_target_origin;
    gl_Position = mul(float4(final_pos, z, 1.0f), uTransform);
    VertexInfo vi = { clamped_local_pos, device_pos };
    return vi;
}

void write_clip(float2 global_pos, ClipArea area)
{
    uint _1268_dummy_parameter;
    float2 texturesize = float2(int3(SPIRV_Cross_textureSize(sSharedCacheA8, uint(0), _1268_dummy_parameter)).xy);
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
    float2 color_delta = float2(1.0f, 1.0f);
    float2 p0 = corners.tl_outer;
    int style = 0;
    float2 p1 = float2(1.0f, 1.0f);
    float4 edge_distances = float4(0.0f, 0.0f, 0.0f, 0.0f);
    float4 color0 = float4(0.0f, 0.0f, 0.0f, 0.0f);
    float4 color1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
    switch (sub_part)
    {
        case 0:
        {
            p0 = corners.tl_outer;
            p1 = corners.tl_inner;
            color0 = border.colors[0];
            color1 = border.colors[1];
            vClipCenter = corners.tl_outer + border.radii[0].xy;
            vClipSign = float2(1.0f, 1.0f);
            int param_3 = prim.user_data1;
            float2 param_4 = border.style.yx;
            style = selectstyle(param_3, param_4);
            Border param_5 = border;
            int param_6 = style;
            float4 adjusted_widths = get_effective_border_widths(param_5, param_6);
            float4 inv_adjusted_widths = border.widths - adjusted_widths;
            int param_7 = style;
            float2 param_8 = border.radii[0].xy;
            float2 param_9 = border.widths.xy;
            float2 param_10 = adjusted_widths.xy;
            set_radii(param_7, param_8, param_9, param_10);
            float2 param_11 = border.widths.xy;
            float2 param_12 = corners.tl_outer;
            float2 param_13 = float2(1.0f, 1.0f);
            set_edge_line(param_11, param_12, param_13);
            edge_distances = float4(p0 + adjusted_widths.xy, p0 + inv_adjusted_widths.xy);
            color_delta = float2(1.0f, 1.0f);
            break;
        }
        case 1:
        {
            p0 = float2(corners.tr_inner.x, corners.tr_outer.y);
            p1 = float2(corners.tr_outer.x, corners.tr_inner.y);
            color0 = border.colors[1];
            color1 = border.colors[2];
            vClipCenter = corners.tr_outer + float2(-border.radii[0].z, border.radii[0].w);
            vClipSign = float2(-1.0f, 1.0f);
            int param_14 = prim.user_data1;
            float2 param_15 = border.style.zy;
            style = selectstyle(param_14, param_15);
            Border param_16 = border;
            int param_17 = style;
            float4 adjusted_widths_1 = get_effective_border_widths(param_16, param_17);
            float4 inv_adjusted_widths_1 = border.widths - adjusted_widths_1;
            int param_18 = style;
            float2 param_19 = border.radii[0].zw;
            float2 param_20 = border.widths.zy;
            float2 param_21 = adjusted_widths_1.zy;
            set_radii(param_18, param_19, param_20, param_21);
            float2 param_22 = border.widths.zy;
            float2 param_23 = corners.tr_outer;
            float2 param_24 = float2(-1.0f, 1.0f);
            set_edge_line(param_22, param_23, param_24);
            edge_distances = float4(p1.x - adjusted_widths_1.z, p0.y + adjusted_widths_1.y, (p1.x - border.widths.z) + adjusted_widths_1.z, p0.y + inv_adjusted_widths_1.y);
            color_delta = float2(1.0f, -1.0f);
            break;
        }
        case 2:
        {
            p0 = corners.br_inner;
            p1 = corners.br_outer;
            color0 = border.colors[2];
            color1 = border.colors[3];
            vClipCenter = corners.br_outer - border.radii[1].xy;
            vClipSign = float2(-1.0f, -1.0f);
            int param_25 = prim.user_data1;
            float2 param_26 = border.style.wz;
            style = selectstyle(param_25, param_26);
            Border param_27 = border;
            int param_28 = style;
            float4 adjusted_widths_2 = get_effective_border_widths(param_27, param_28);
            float4 inv_adjusted_widths_2 = border.widths - adjusted_widths_2;
            int param_29 = style;
            float2 param_30 = border.radii[1].xy;
            float2 param_31 = border.widths.zw;
            float2 param_32 = adjusted_widths_2.zw;
            set_radii(param_29, param_30, param_31, param_32);
            float2 param_33 = border.widths.zw;
            float2 param_34 = corners.br_outer;
            float2 param_35 = float2(-1.0f, -1.0f);
            set_edge_line(param_33, param_34, param_35);
            edge_distances = float4(p1.x - adjusted_widths_2.z, p1.y - adjusted_widths_2.w, (p1.x - border.widths.z) + adjusted_widths_2.z, (p1.y - border.widths.w) + adjusted_widths_2.w);
            color_delta = float2(-1.0f, -1.0f);
            break;
        }
        case 3:
        {
            p0 = float2(corners.bl_outer.x, corners.bl_inner.y);
            p1 = float2(corners.bl_inner.x, corners.bl_outer.y);
            color0 = border.colors[3];
            color1 = border.colors[0];
            vClipCenter = corners.bl_outer + float2(border.radii[1].z, -border.radii[1].w);
            vClipSign = float2(1.0f, -1.0f);
            int param_36 = prim.user_data1;
            float2 param_37 = border.style.xw;
            style = selectstyle(param_36, param_37);
            Border param_38 = border;
            int param_39 = style;
            float4 adjusted_widths_3 = get_effective_border_widths(param_38, param_39);
            float4 inv_adjusted_widths_3 = border.widths - adjusted_widths_3;
            int param_40 = style;
            float2 param_41 = border.radii[1].zw;
            float2 param_42 = border.widths.xw;
            float2 param_43 = adjusted_widths_3.xw;
            set_radii(param_40, param_41, param_42, param_43);
            float2 param_44 = border.widths.xw;
            float2 param_45 = corners.bl_outer;
            float2 param_46 = float2(1.0f, -1.0f);
            set_edge_line(param_44, param_45, param_46);
            edge_distances = float4(p0.x + adjusted_widths_3.x, p1.y - adjusted_widths_3.w, p0.x + inv_adjusted_widths_3.x, (p1.y - border.widths.w) + adjusted_widths_3.w);
            color_delta = float2(-1.0f, 1.0f);
            break;
        }
    }
    switch (style)
    {
        case 2:
        {
            vEdgeDistance = edge_distances;
            vAlphaSelect = 0.0f;
            vSDFSelect = 0.0f;
            break;
        }
        case 6:
        {
            float4 _2106 = edge_distances;
            float4 _2110 = float4(_2106.xy, 0.0f, 0.0f);
            vEdgeDistance = _2110;
            vAlphaSelect = 1.0f;
            vSDFSelect = 1.0f;
            break;
        }
        case 7:
        {
            float4 _2106 = edge_distances;
            float4 _2110 = float4(_2106.xy, 0.0f, 0.0f);
            vEdgeDistance = _2110;
            vAlphaSelect = 1.0f;
            vSDFSelect = 1.0f;
            break;
        }
        case 3:
        {
            vClipSign = float2(0.0f, 0.0f);
            vEdgeDistance = float4(0.0f, 0.0f, 0.0f, 0.0f);
            vAlphaSelect = 1.0f;
            vSDFSelect = 0.0f;
            break;
        }
        default:
        {
            vEdgeDistance = float4(0.0f, 0.0f, 0.0f, 0.0f);
            vAlphaSelect = 1.0f;
            vSDFSelect = 0.0f;
            break;
        }
    }
    float4 param_47 = color0;
    float4 param_48 = color1;
    int param_49 = style;
    float2 param_50 = color_delta;
    int param_51 = prim.user_data1;
    write_color(param_47, param_48, param_49, param_50, param_51);
    RectWithSize segment_rect;
    segment_rect.p0 = p0;
    segment_rect.size = p1 - p0;
    RectWithSize param_52 = segment_rect;
    RectWithSize param_53 = prim.local_clip_rect;
    float param_54 = prim.z;
    Layer param_55 = prim.layer;
    AlphaBatchTask param_56 = prim.task;
    RectWithSize param_57 = prim.local_rect;
    VertexInfo _2152 = write_vertex(param_52, param_53, param_54, param_55, param_56, param_57);
    VertexInfo vi = _2152;
    vLocalPos = vi.local_pos;
    float2 param_58 = vi.screen_pos;
    ClipArea param_59 = prim.clip_area;
    write_clip(param_58, param_59);
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
    stage_output.vRadii0 = vRadii0;
    stage_output.vRadii1 = vRadii1;
    stage_output.vColorEdgeLine = vColorEdgeLine;
    stage_output.vColor00 = vColor00;
    stage_output.vColor01 = vColor01;
    stage_output.vColor10 = vColor10;
    stage_output.vColor11 = vColor11;
    stage_output.vClipCenter = vClipCenter;
    stage_output.vClipSign = vClipSign;
    stage_output.vEdgeDistance = vEdgeDistance;
    stage_output.vAlphaSelect = vAlphaSelect;
    stage_output.vSDFSelect = vSDFSelect;
    stage_output.vLocalPos = vLocalPos;
    return stage_output;
}
