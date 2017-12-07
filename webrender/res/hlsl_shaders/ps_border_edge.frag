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
static float vAxisSelect;
static float2 vEdgeDistance;
static float vAlphaSelect;
static float4 vColor0;
static float4 vColor1;
static float4 vClipParams;
static float vClipSelect;
static float4 Target0;

struct SPIRV_Cross_Input
{
    nointerpolation float vAlphaSelect : TEXCOORD0;
    nointerpolation float vAxisSelect : TEXCOORD1;
    float3 vClipMaskUv : TEXCOORD2;
    nointerpolation float4 vClipMaskUvBounds : TEXCOORD3;
    nointerpolation float4 vClipParams : TEXCOORD4;
    nointerpolation float vClipSelect : TEXCOORD5;
    nointerpolation float4 vColor0 : TEXCOORD6;
    nointerpolation float4 vColor1 : TEXCOORD7;
    nointerpolation float2 vEdgeDistance : TEXCOORD8;
    float2 vLocalPos : TEXCOORD9;
};

struct SPIRV_Cross_Output
{
    float4 Target0 : SV_Target0;
};

float mod(float x, float y)
{
    return x - y * floor(x / y);
}

float2 mod(float2 x, float2 y)
{
    return x - y * floor(x / y);
}

float3 mod(float3 x, float3 y)
{
    return x - y * floor(x / y);
}

float4 mod(float4 x, float4 y)
{
    return x - y * floor(x / y);
}

bool lte(float4 value, float4 comparison)
{
    float _189 = value.x;
    float _191 = comparison.x;
    bool _192 = _189 <= _191;
    bool _218;
    bool _201;
    bool _209;
    if (_192)
    {
        _201 = value.y <= comparison.y;
    }
    else
    {
        _201 = _192;
    }
    if (_201)
    {
        _209 = value.z <= comparison.z;
    }
    else
    {
        _209 = _201;
    }
    if (_209)
    {
        _218 = value.w <= comparison.w;
    }
    else
    {
        _218 = _209;
    }
    return _218;
}

float do_clip()
{
    float4 param = float4(vClipMaskUvBounds.xy, vClipMaskUv.xy);
    float4 param_1 = float4(vClipMaskUv.xy, vClipMaskUvBounds.zw);
    bool inside = lte(param, param_1);
    bool _255 = vClipMaskUvBounds.x == vClipMaskUvBounds.z;
    bool _263;
    if (_255)
    {
        _263 = vClipMaskUvBounds.y == vClipMaskUvBounds.w;
    }
    else
    {
        _263 = _255;
    }
    float _267;
    float _249;
    if (_263)
    {
        _249 = 1.0f;
    }
    else
    {
        if (inside)
        {
            _267 = sSharedCacheA8.SampleLevel(sSharedCacheA8_, vClipMaskUv, 0.0f).x;
        }
        else
        {
            _267 = 0.0f;
        }
        _249 = _267;
    }
    return _249;
}

float compute_aa_range(float2 position)
{
    return 0.3535499870777130126953125f * length(fwidth(position));
}

float distance_aa(float aa_range, float signed_distance)
{
    return 1.0f - smoothstep(-aa_range, aa_range, signed_distance);
}

void frag_main()
{
    float alpha = 1.0f;
    float2 local_pos = vLocalPos;
    alpha *= do_clip();
    float2 param = local_pos;
    float aa_range = compute_aa_range(param);
    float2 pos = lerp(local_pos, local_pos.yx, float2(vAxisSelect, vAxisSelect));
    float d0 = pos.x - vEdgeDistance.x;
    float d1 = vEdgeDistance.y - pos.x;
    float d = min(d0, d1);
    alpha = min(alpha, (d < 0.0f) ? 1.0f : vAlphaSelect);
    bool _379 = (d0 * vEdgeDistance.y) > 0.0f;
    bool4 _381 = bool4(_379, _379, _379, _379);
    float4 color = float4(_381.x ? vColor1.x : vColor0.x, _381.y ? vColor1.y : vColor0.y, _381.z ? vColor1.z : vColor0.z, _381.w ? vColor1.w : vColor0.w);
    float x = mod(pos.y - vClipParams.x, vClipParams.y);
    float dash_alpha = step(x, vClipParams.z);
    float2 dot_relative_pos = float2(x, pos.x) - vClipParams.zw;
    float dot_distance = length(dot_relative_pos) - vClipParams.z;
    float param_1 = aa_range;
    float param_2 = dot_distance;
    float dot_alpha = distance_aa(param_1, param_2);
    alpha = min(alpha, lerp(dash_alpha, dot_alpha, vClipSelect));
    Target0 = color * alpha;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    vClipMaskUvBounds = stage_input.vClipMaskUvBounds;
    vClipMaskUv = stage_input.vClipMaskUv;
    vLocalPos = stage_input.vLocalPos;
    vAxisSelect = stage_input.vAxisSelect;
    vEdgeDistance = stage_input.vEdgeDistance;
    vAlphaSelect = stage_input.vAlphaSelect;
    vColor0 = stage_input.vColor0;
    vColor1 = stage_input.vColor1;
    vClipParams = stage_input.vClipParams;
    vClipSelect = stage_input.vClipSelect;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.Target0 = Target0;
    return stage_output;
}
