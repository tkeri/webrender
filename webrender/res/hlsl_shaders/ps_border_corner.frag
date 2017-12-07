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

Texture2D<float4> sResourceCache;
SamplerState sResourceCache_;
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

static float4 vClipMaskUvBounds;
static float3 vClipMaskUv;
static float2 vLocalPos;
static float2 vClipSign;
static float2 vClipCenter;
static float4 vRadii0;
static float4 vRadii1;
static float vSDFSelect;
static float4 vEdgeDistance;
static float vAlphaSelect;
static float4 vColor00;
static float4 vColor01;
static float4 vColor10;
static float4 vColor11;
static float4 vColorEdgeLine;
static float4 Target0;

struct SPIRV_Cross_Input
{
    nointerpolation float vAlphaSelect : TEXCOORD0;
    nointerpolation float2 vClipCenter : TEXCOORD1;
    float3 vClipMaskUv : TEXCOORD2;
    nointerpolation float4 vClipMaskUvBounds : TEXCOORD3;
    nointerpolation float2 vClipSign : TEXCOORD4;
    nointerpolation float4 vColor00 : TEXCOORD5;
    nointerpolation float4 vColor01 : TEXCOORD6;
    nointerpolation float4 vColor10 : TEXCOORD7;
    nointerpolation float4 vColor11 : TEXCOORD8;
    nointerpolation float4 vColorEdgeLine : TEXCOORD9;
    nointerpolation float4 vEdgeDistance : TEXCOORD10;
    float2 vLocalPos : TEXCOORD11;
    nointerpolation float4 vRadii0 : TEXCOORD12;
    nointerpolation float4 vRadii1 : TEXCOORD13;
    nointerpolation float vSDFSelect : TEXCOORD14;
};

struct SPIRV_Cross_Output
{
    float4 Target0 : SV_Target0;
};

float _612;

bool lte(float4 value, float4 comparison)
{
    float _213 = value.x;
    float _215 = comparison.x;
    bool _216 = _213 <= _215;
    bool _225;
    bool _242;
    bool _233;
    if (_216)
    {
        _225 = value.y <= comparison.y;
    }
    else
    {
        _225 = _216;
    }
    if (_225)
    {
        _233 = value.z <= comparison.z;
    }
    else
    {
        _233 = _225;
    }
    if (_233)
    {
        _242 = value.w <= comparison.w;
    }
    else
    {
        _242 = _233;
    }
    return _242;
}

float do_clip()
{
    float4 param = float4(vClipMaskUvBounds.xy, vClipMaskUv.xy);
    float4 param_1 = float4(vClipMaskUv.xy, vClipMaskUvBounds.zw);
    bool inside = lte(param, param_1);
    bool _279 = vClipMaskUvBounds.x == vClipMaskUvBounds.z;
    bool _287;
    if (_279)
    {
        _287 = vClipMaskUvBounds.y == vClipMaskUvBounds.w;
    }
    else
    {
        _287 = _279;
    }
    float _291;
    float _273;
    if (_287)
    {
        _273 = 1.0f;
    }
    else
    {
        if (inside)
        {
            _291 = sSharedCacheA8.SampleLevel(sSharedCacheA8_, vClipMaskUv, 0.0f).x;
        }
        else
        {
            _291 = 0.0f;
        }
        _273 = _291;
    }
    return _273;
}

float compute_aa_range(float2 position)
{
    return 0.3535499870777130126953125f * length(fwidth(position));
}

float sdEllipse(inout float2 p, inout float2 ab)
{
    p = abs(p);
    if (p.x > p.y)
    {
        p = p.yx;
        ab = ab.yx;
    }
    float l = (ab.y * ab.y) - (ab.x * ab.x);
    float m = (ab.x * p.x) / l;
    float n = (ab.y * p.y) / l;
    float m2 = m * m;
    float n2 = n * n;
    float c = ((m2 + n2) - 1.0f) / 3.0f;
    float c3 = (c * c) * c;
    float q = c3 + ((m2 * n2) * 2.0f);
    float d = c3 + (m2 * n2);
    float g = m + (m * n2);
    float co;
    if (d < 0.0f)
    {
        float p_1 = acos(q / c3) / 3.0f;
        float s = cos(p_1);
        float t = sin(p_1) * 1.73205077648162841796875f;
        float rx = sqrt(((-c) * ((s + t) + 2.0f)) + m2);
        float ry = sqrt(((-c) * ((s - t) + 2.0f)) + m2);
        co = (((ry + (sign(l) * rx)) + (abs(g) / (rx * ry))) - m) / 2.0f;
    }
    else
    {
        float h = ((2.0f * m) * n) * sqrt(d);
        float s_1 = sign(q + h) * pow(abs(q + h), 0.3333333432674407958984375f);
        float u = sign(q - h) * pow(abs(q - h), 0.3333333432674407958984375f);
        float rx_1 = (((-s_1) - u) - (c * 4.0f)) + (2.0f * m2);
        float ry_1 = (s_1 - u) * 1.73205077648162841796875f;
        float rm = sqrt((rx_1 * rx_1) + (ry_1 * ry_1));
        float p_2 = ry_1 / sqrt(rm - rx_1);
        co = ((p_2 + ((2.0f * g) / rm)) - m) / 2.0f;
    }
    float si = sqrt(1.0f - (co * co));
    float2 r = float2(ab.x * co, ab.y * si);
    return length(r - p) * sign(p.y - r.y);
}

float distance_to_ellipse(float2 p, float2 radii)
{
    if (radii.x == radii.y)
    {
        return length(p) - radii.x;
    }
    else
    {
        float2 param = p;
        float2 param_1 = radii;
        float _610 = sdEllipse(param, param_1);
        return _610;
    }
}

float distance_aa(float aa_range, float signed_distance)
{
    return 1.0f - smoothstep(-aa_range, aa_range, signed_distance);
}

float distance_to_line(float2 p0, float2 perp_dir, float2 p)
{
    float2 dir_to_p0 = p0 - p;
    return dot(normalize(perp_dir), dir_to_p0);
}

void frag_main()
{
    float alpha = 1.0f;
    float2 local_pos = vLocalPos;
    alpha *= do_clip();
    float2 param = local_pos;
    float aa_range = compute_aa_range(param);
    float2 _702 = local_pos * vClipSign;
    float2 _706 = vClipCenter * vClipSign;
    float color_mix_factor;
    if (all(bool2(_702.x < _706.x, _702.y < _706.y)))
    {
        float2 p = local_pos - vClipCenter;
        float2 param_1 = p;
        float2 param_2 = vRadii0.xy;
        float d0 = distance_to_ellipse(param_1, param_2);
        float2 param_3 = p;
        float2 param_4 = vRadii0.zw;
        float d1 = distance_to_ellipse(param_3, param_4);
        float2 param_5 = p;
        float2 param_6 = vRadii1.xy;
        float d2 = distance_to_ellipse(param_5, param_6);
        float2 param_7 = p;
        float2 param_8 = vRadii1.zw;
        float d3 = distance_to_ellipse(param_7, param_8);
        float d_main = max(d0, -d1);
        float d_inner = max(d2, -d3);
        float d = lerp(max(d_main, -d_inner), d_main, vSDFSelect);
        float param_9 = aa_range;
        float param_10 = d;
        alpha = min(alpha, distance_aa(param_9, param_10));
        float param_11 = aa_range;
        float param_12 = d2;
        color_mix_factor = distance_aa(param_11, param_12);
    }
    else
    {
        float2 d0_1 = vClipSign.xx * (local_pos.xx - vEdgeDistance.xz);
        float2 d1_1 = vClipSign.yy * (local_pos.yy - vEdgeDistance.yw);
        float da = min(d0_1.x, d1_1.x);
        float db = max(-d0_1.y, -d1_1.y);
        float d_1 = min(da, db);
        alpha = min(alpha, (d_1 < 0.0f) ? 1.0f : vAlphaSelect);
        color_mix_factor = float(da > 0.0f);
    }
    float4 color0 = lerp(vColor00, vColor01, float4(color_mix_factor, color_mix_factor, color_mix_factor, color_mix_factor));
    float4 color1 = lerp(vColor10, vColor11, float4(color_mix_factor, color_mix_factor, color_mix_factor, color_mix_factor));
    float2 param_13 = vColorEdgeLine.xy;
    float2 param_14 = vColorEdgeLine.zw;
    float2 param_15 = local_pos;
    float ld = distance_to_line(param_13, param_14, param_15);
    float param_16 = aa_range;
    float param_17 = -ld;
    float m = distance_aa(param_16, param_17);
    float4 color = lerp(color0, color1, float4(m, m, m, m));
    Target0 = color * alpha;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    vClipMaskUvBounds = stage_input.vClipMaskUvBounds;
    vClipMaskUv = stage_input.vClipMaskUv;
    vLocalPos = stage_input.vLocalPos;
    vClipSign = stage_input.vClipSign;
    vClipCenter = stage_input.vClipCenter;
    vRadii0 = stage_input.vRadii0;
    vRadii1 = stage_input.vRadii1;
    vSDFSelect = stage_input.vSDFSelect;
    vEdgeDistance = stage_input.vEdgeDistance;
    vAlphaSelect = stage_input.vAlphaSelect;
    vColor00 = stage_input.vColor00;
    vColor01 = stage_input.vColor01;
    vColor10 = stage_input.vColor10;
    vColor11 = stage_input.vColor11;
    vColorEdgeLine = stage_input.vColorEdgeLine;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.Target0 = Target0;
    return stage_output;
}
