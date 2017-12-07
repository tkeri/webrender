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
static float3 vUv;
static float4 vUvBorder;
static float4 Target0;
static float4 vColor;

struct SPIRV_Cross_Input
{
    float3 vClipMaskUv : vClipMaskUv;
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    nointerpolation float4 vColor : vColor;
    float3 vUv : vUv;
    nointerpolation float4 vUvBorder : vUvBorder;
};

struct SPIRV_Cross_Output
{
    float4 Target0 : SV_Target0;
};

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

void frag_main()
{
    float3 tc = float3(clamp(vUv.xy, vUvBorder.xy, vUvBorder.zw), vUv.z);
    float4 color = sColor0.Sample(sColor0_, tc);
    float alpha = 1.0f;
    alpha *= do_clip();
    Target0 = (color * vColor) * alpha;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    vClipMaskUvBounds = stage_input.vClipMaskUvBounds;
    vClipMaskUv = stage_input.vClipMaskUv;
    vUv = stage_input.vUv;
    vUvBorder = stage_input.vUvBorder;
    vColor = stage_input.vColor;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.Target0 = Target0;
    return stage_output;
}
