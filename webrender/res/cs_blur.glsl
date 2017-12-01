/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 gl_Position : SV_Position;
        vec3 vUv: vUv;
        flat vec4 vUvRect : vUvRect;
        flat vec2 vOffsetScale : vOffsetScale;
        flat float vSigma : vSigma;
        flat int vBlurRadius : vBlurRadius;
    };
#else
varying vec3 vUv;
flat varying vec4 vUvRect;
flat varying vec2 vOffsetScale;
flat varying float vSigma;
flat varying int vBlurRadius;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
// Applies a separable gaussian blur in one direction, as specified
// by the dir field in the blur command.

#define DIR_HORIZONTAL  0
#define DIR_VERTICAL    1

#ifdef WR_DX11
    struct a2v_cs {
        vec3 pos : aPosition;
        int aBlurRenderTaskAddress : aBlurRenderTaskAddress;
        int aBlurSourceTaskAddress : aBlurSourceTaskAddress;
        int aBlurDirection : aBlurDirection;
        vec4 aBlurRegion : aBlurRegion;
    };
#else
in int aBlurRenderTaskAddress;
in int aBlurSourceTaskAddress;
in int aBlurDirection;
in vec4 aBlurRegion;
#endif

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v_cs IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    int aBlurRenderTaskAddress = IN.aBlurRenderTaskAddress;
    int aBlurSourceTaskAddress = IN.aBlurSourceTaskAddress;
    int aBlurDirection = IN.aBlurDirection;
    vec4 aBlurRegion = IN.aBlurRegion;
#endif //WR_DX11
    RenderTaskData task = fetch_render_task(aBlurRenderTaskAddress);
    RenderTaskData src_task = fetch_render_task(aBlurSourceTaskAddress);

    vec4 src_rect = src_task.data0;
    vec4 target_rect = task.data0;

#if defined WR_FEATURE_COLOR_TARGET
    vec2 texture_size = vec2(textureSize(sCacheRGBA8, 0).xy);
#else
    vec2 texture_size = vec2(textureSize(sCacheA8, 0).xy);
#endif
    SHADER_OUT(vUv.z, src_task.data1.x);
    SHADER_OUT(vBlurRadius, int(3.0 * task.data1.y));
    SHADER_OUT(vSigma, task.data1.y);

    switch (aBlurDirection) {
        case DIR_HORIZONTAL:
            SHADER_OUT(vOffsetScale, vec2(1.0 / texture_size.x, 0.0));
            break;
        case DIR_VERTICAL:
            SHADER_OUT(vOffsetScale, vec2(0.0, 1.0 / texture_size.y));
            break;
    }

    vec4 uv_rect = vec4(src_rect.xy + vec2(0.5, 0.5),
                        src_rect.xy + src_rect.zw - vec2(0.5, 0.5));
    SHADER_OUT(vUvRect, uv_rect / texture_size.xyxy);
    if (aBlurRegion.z > 0.0) {
        vec4 blur_region = aBlurRegion * uDevicePixelRatio;
        src_rect = vec4(src_rect.xy + blur_region.xy, blur_region.zw);
        target_rect = vec4(target_rect.xy + blur_region.xy, blur_region.zw);
    }

    vec2 pos = target_rect.xy + target_rect.zw * aPosition.xy;

    vec2 uv0 = src_rect.xy / texture_size;
    vec2 uv1 = (src_rect.xy + src_rect.zw) / texture_size;
    SHADER_OUT(vUv.xy, mix(uv0, uv1, aPosition.xy));

    SHADER_OUT(gl_Position, mul(vec4(pos, 0.0, 1.0), uTransform));
}
#endif

#ifdef WR_FRAGMENT_SHADER

#if defined WR_FEATURE_COLOR_TARGET
#define SAMPLE_TYPE vec4
#define SAMPLE_TEXTURE(uv)  texture(sCacheRGBA8, uv)
#else
#define SAMPLE_TYPE float
#define SAMPLE_TEXTURE(uv)  texture(sCacheA8, uv).r
#endif

// TODO(gw): Write a fast path blur that handles smaller blur radii
//           with a offset / weight uniform table and a constant
//           loop iteration count!

// TODO(gw): Make use of the bilinear sampling trick to reduce
//           the number of texture fetches needed for a gaussian blur.

#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec3 vUv = IN.vUv;
    vec4 vUvRect = IN.vUvRect;
    vec2 vOffsetScale = IN.vOffsetScale;
    float vSigma = IN.vSigma;
    int vBlurRadius = IN.vBlurRadius;
    vec4 gl_FragCoord = IN.gl_Position;
#endif //WR_DX11
    SAMPLE_TYPE original_color = SAMPLE_TEXTURE(vUv);

    // TODO(gw): The gauss function gets NaNs when blur radius
    //           is zero. In the future, detect this earlier
    //           and skip the blur passes completely.
    if (vBlurRadius == 0) {
#if defined WR_FEATURE_COLOR_TARGET
    vec4 color = vec4(original_color);
#else
    vec4 color = vec4(original_color, original_color, original_color, original_color);
#endif
        SHADER_OUT(Target0, color);
        return;
    }

    // Incremental Gaussian Coefficent Calculation (See GPU Gems 3 pp. 877 - 889)
    vec3 gauss_coefficient;
    gauss_coefficient.x = 1.0 / (sqrt(2.0 * 3.14159265) * vSigma);
    gauss_coefficient.y = exp(-0.5 / (vSigma * vSigma));
    gauss_coefficient.z = gauss_coefficient.y * gauss_coefficient.y;

    float gauss_coefficient_sum = 0.0;
    SAMPLE_TYPE avg_color = original_color * gauss_coefficient.x;
    gauss_coefficient_sum += gauss_coefficient.x;
    gauss_coefficient.xy *= gauss_coefficient.yz;

    for (int i=1 ; i <= vBlurRadius ; ++i) {
        vec2 offset = vOffsetScale * vec2(float(i), float(i));

        vec2 st0 = clamp(vUv.xy - offset, vUvRect.xy, vUvRect.zw);
        avg_color += SAMPLE_TEXTURE(vec3(st0, vUv.z)) * gauss_coefficient.x;

        vec2 st1 = clamp(vUv.xy + offset, vUvRect.xy, vUvRect.zw);
        avg_color += SAMPLE_TEXTURE(vec3(st1, vUv.z)) * gauss_coefficient.x;

        gauss_coefficient_sum += 2.0 * gauss_coefficient.x;
        gauss_coefficient.xy *= gauss_coefficient.yz;
    }
#if defined WR_FEATURE_COLOR_TARGET
    vec4 color = vec4(avg_color);
#else
    vec4 color = vec4(avg_color, avg_color, avg_color, avg_color);
#endif
    SHADER_OUT(Target0, color / gauss_coefficient_sum);
}
#endif
