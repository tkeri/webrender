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
static float4 Target0;
static float4 vColor;

struct SPIRV_Cross_Input
{
    nointerpolation float4 vClipMaskUvBounds : vClipMaskUvBounds;
    float3 vClipMaskUv : vClipMaskUv;
    float4 vColor : vColor;
};

struct SPIRV_Cross_Output
{
    float4 Target0 : SV_Target0;
};

void frag_main()
{
    float alpha = 1.0f;
    Target0 = vColor * alpha;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    vClipMaskUvBounds = stage_input.vClipMaskUvBounds;
    vClipMaskUv = stage_input.vClipMaskUv;
    vColor = stage_input.vColor;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.Target0 = Target0;
    return stage_output;
}
