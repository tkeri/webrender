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

Texture2D<float4> sResourceCache : register(t11);
SamplerState sResourceCache_ : register(s11);
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

static float4 vClipMaskUvBounds;
static float3 vClipMaskUv;
static float2 vLocalPos;
static float2 vStretchSize;
static float2 vTileSpacing;
static float2 vTextureOffset;
static float2 vTextureSize;
static float4 vStRect;
static float4 Target0;
static float vLayer;

struct SPIRV_Cross_Input
{
    nointerpolation float4 vClipMaskUvBounds : TEXCOORD1;
    float3 vClipMaskUv : TEXCOORD2;
    nointerpolation float2 vTextureOffset : TEXCOORD6;
    nointerpolation float2 vTextureSize : TEXCOORD7;
    nointerpolation float2 vTileSpacing : TEXCOORD8;
    nointerpolation float4 vStRect : TEXCOORD9;
    nointerpolation float vLayer : TEXCOORD10;
    float2 vLocalPos : TEXCOORD11;
    nointerpolation float2 vStretchSize : TEXCOORD12;
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

void frag_main()
{
    float alpha = 1.0f;
    float2 relative_pos_in_rect = vLocalPos;
    float2 upper_bound_mask = float2(0.0f, 0.0f);
    alpha *= do_clip();
    float2 position_in_tile = lerp(mod(relative_pos_in_rect, vStretchSize + vTileSpacing), vStretchSize, upper_bound_mask);
    float2 st = vTextureOffset + ((position_in_tile / vStretchSize) * vTextureSize);
    st = clamp(st, vStRect.xy, vStRect.zw);
    float2 _367 = step(position_in_tile, vStretchSize);
    alpha *= float(all(bool2(_367.x != float2(0.0f, 0.0f).x, _367.y != float2(0.0f, 0.0f).y)));
    Target0 = float4(alpha, alpha, alpha, alpha) * sColor0.SampleLevel(sColor0_, float3(st, vLayer), 0.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    vClipMaskUvBounds = stage_input.vClipMaskUvBounds;
    vClipMaskUv = stage_input.vClipMaskUv;
    vLocalPos = stage_input.vLocalPos;
    vStretchSize = stage_input.vStretchSize;
    vTileSpacing = stage_input.vTileSpacing;
    vTextureOffset = stage_input.vTextureOffset;
    vTextureSize = stage_input.vTextureSize;
    vStRect = stage_input.vStRect;
    vLayer = stage_input.vLayer;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.Target0 = Target0;
    return stage_output;
}
