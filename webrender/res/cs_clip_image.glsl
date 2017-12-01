/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared,clip_shared

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
        vec3 vPos : vPos;
        flat vec4 vLocalBounds : vLocalBounds;
        vec3 vClipMaskUv : vClipMaskUv;
        flat vec4 vClipMaskUvRect : vClipMaskUvRect;
        flat vec4 vClipMaskUvInnerRect : vClipMaskUvInnerRect;
        flat float vLayer : vLayer;
    };
#else
varying vec3 vPos;
flat varying vec4 vClipMaskUvRect;
flat varying vec4 vClipMaskUvInnerRect;
flat varying float vLayer;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
struct ImageMaskData {
    RectWithSize local_rect;
};

ImageMaskData fetch_mask_data(ivec2 address) {
    vec4 data = fetch_from_resource_cache_1_direct(address);
    RectWithSize rect;
    rect.p0 = data.xy;
    rect.size = data.zw;
    ImageMaskData image_mask_data;
    image_mask_data.local_rect = rect;
    return image_mask_data;
}

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v_clip IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    int aClipRenderTaskAddress = IN.aClipRenderTaskAddress;
    int aClipLayerAddress = IN.aClipLayerAddress;
    int aClipSegment = IN.aClipSegment;
    ivec4 aClipDataResourceAddress = IN.aClipDataResourceAddress;
#endif //WR_DX11
    ClipMaskInstance cmi = fetch_clip_item(aClipRenderTaskAddress,
                                           aClipLayerAddress,
                                           aClipSegment,
                                           aClipDataResourceAddress);
    ClipArea area = fetch_clip_area(cmi.render_task_address);
    Layer layer = fetch_layer(cmi.layer_address);
    ImageMaskData mask = fetch_mask_data(cmi.clip_data_address);
    RectWithSize local_rect = mask.local_rect;
    ImageResource res = fetch_image_resource_direct(cmi.resource_address);

    ClipVertexInfo vi = write_clip_tile_vertex(aPosition,
                                               local_rect,
                                               layer,
                                               area,
                                               cmi.segment
#ifdef WR_DX11
                                               , OUT.Position
                                               , OUT.vLocalBounds
#endif //WR_DX11
                                               );

    SHADER_OUT(vPos, vi.local_pos);
    SHADER_OUT(vLayer, res.layer);

    SHADER_OUT(vClipMaskUv, vec3((vi.local_pos.xy / vi.local_pos.z - local_rect.p0) / local_rect.size, 0.0));
    vec2 texture_size = vec2(textureSize(sColor0, 0));
    SHADER_OUT(vClipMaskUvRect, vec4(res.uv_rect.xy, res.uv_rect.zw - res.uv_rect.xy) / texture_size.xyxy);
    // applying a half-texel offset to the UV boundaries to prevent linear samples from the outside
    vec4 inner_rect = vec4(res.uv_rect.xy, res.uv_rect.zw);
    SHADER_OUT(vClipMaskUvInnerRect, (inner_rect + vec4(0.5, 0.5, -0.5, -0.5)) / texture_size.xyxy);
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec3 vPos = IN.vPos;
    vec4 vLocalBounds = IN.vLocalBounds;
    vec3 vClipMaskUv = IN.vClipMaskUv;
    vec4 vClipMaskUvRect = IN.vClipMaskUvRect;
    vec4 vClipMaskUvInnerRect = IN.vClipMaskUvInnerRect;
    float vLayer = IN.vLayer;
#endif //WR_DX11
    float alpha = 1.f;
    vec2 local_pos = init_transform_fs(vPos, vLocalBounds, alpha);

    bool repeat_mask = false; //TODO
    vec2 clamped_mask_uv = repeat_mask ? fract(vClipMaskUv.xy) :
        clamp(vClipMaskUv.xy, vec2(0.0, 0.0), vec2(1.0, 1.0));
    vec2 source_uv = clamp(clamped_mask_uv * vClipMaskUvRect.zw + vClipMaskUvRect.xy,
        vClipMaskUvInnerRect.xy, vClipMaskUvInnerRect.zw);
    float clip_alpha = texture(sColor0, vec3(source_uv, vLayer)).r; //careful: texture has type A8

    SHADER_OUT(Target0, vec4(alpha * clip_alpha, 1.0, 1.0, 1.0));
}
#endif
