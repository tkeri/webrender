/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared,clip_shared,ellipse

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
        vec3 vPos : vPos;
        flat vec4 vLocalBounds : vLocalBounds;
        flat float vClipMode : vClipMode;
        flat vec4 vClipCenter_Radius_TL : vClipCenter_Radius_TL;
        flat vec4 vClipCenter_Radius_TR : vClipCenter_Radius_TR;
        flat vec4 vClipCenter_Radius_BL : vClipCenter_Radius_BL;
        flat vec4 vClipCenter_Radius_BR : vClipCenter_Radius_BR;
    };
#else
varying vec3 vPos;
flat varying float vClipMode;
flat varying vec4 vClipCenter_Radius_TL;
flat varying vec4 vClipCenter_Radius_TR;
flat varying vec4 vClipCenter_Radius_BL;
flat varying vec4 vClipCenter_Radius_BR;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
struct ClipRect {
    RectWithSize rect;
    vec4 mode;
};

ClipRect fetch_clip_rect(ivec2 address) {
    ResourceCacheData2 data = fetch_from_resource_cache_2_direct(address);
    RectWithSize rect;
    rect.p0 = data.data0.xy;
    rect.size = data.data0.zw;
    ClipRect clip_rect;
    clip_rect.rect = rect;
    clip_rect.mode = data.data1;
    return clip_rect;
}

struct ClipCorner {
    RectWithSize rect;
    vec4 outer_inner_radius;
};

// index is of type float instead of int because using an int led to shader
// miscompilations with a macOS 10.12 Intel driver.
ClipCorner fetch_clip_corner(ivec2 address, float index) {
    address += ivec2(2 + 2 * index, 0);
    ResourceCacheData2 data = fetch_from_resource_cache_2_direct(address);
    RectWithSize rect;
    rect.p0 = data.data0.xy;
    rect.size = data.data0.zw;
    ClipCorner clip_corner;
    clip_corner.rect = rect;
    clip_corner.outer_inner_radius = data.data1;
    return clip_corner;
}

struct ClipData {
    ClipRect rect;
    ClipCorner top_left;
    ClipCorner top_right;
    ClipCorner bottom_left;
    ClipCorner bottom_right;
};

ClipData fetch_clip(ivec2 address) {
    ClipData clip;

    clip.rect = fetch_clip_rect(address);
    clip.top_left = fetch_clip_corner(address, 0.0);
    clip.top_right = fetch_clip_corner(address, 1.0);
    clip.bottom_left = fetch_clip_corner(address, 2.0);
    clip.bottom_right = fetch_clip_corner(address, 3.0);

    return clip;
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
    ClipData clip = fetch_clip(cmi.clip_data_address);
    RectWithSize local_rect = clip.rect.rect;

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

    SHADER_OUT(vClipMode, clip.rect.mode.x);

    RectWithEndpoint clip_rect = to_rect_with_endpoint(local_rect);

    vec2 r_tl = clip.top_left.outer_inner_radius.xy;
    vec2 r_tr = clip.top_right.outer_inner_radius.xy;
    vec2 r_br = clip.bottom_right.outer_inner_radius.xy;
    vec2 r_bl = clip.bottom_left.outer_inner_radius.xy;

    SHADER_OUT(vClipCenter_Radius_TL, vec4(clip_rect.p0 + r_tl, r_tl));

    SHADER_OUT(vClipCenter_Radius_TR, vec4(clip_rect.p1.x - r_tr.x,
                                           clip_rect.p0.y + r_tr.y,
                                           r_tr));

    SHADER_OUT(vClipCenter_Radius_BR, vec4(clip_rect.p1 - r_br, r_br));

    SHADER_OUT(vClipCenter_Radius_BL, vec4(clip_rect.p0.x + r_bl.x,
                                           clip_rect.p1.y - r_bl.y,
                                           r_bl));
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec3 vPos = IN.vPos;
    vec4 vLocalBounds = IN.vLocalBounds;
    float vClipMode = IN.vClipMode;
    vec4 vClipCenter_Radius_TL = IN.vClipCenter_Radius_TL;
    vec4 vClipCenter_Radius_TR = IN.vClipCenter_Radius_TR;
    vec4 vClipCenter_Radius_BL = IN.vClipCenter_Radius_BL;
    vec4 vClipCenter_Radius_BR = IN.vClipCenter_Radius_BR;
#endif //WR_DX11
    float alpha = 1.f;
    vec2 local_pos = init_transform_fs(vPos, vLocalBounds, alpha);

    float clip_alpha = rounded_rect(local_pos,
                                    vClipCenter_Radius_TL,
                                    vClipCenter_Radius_TR,
                                    vClipCenter_Radius_BR,
                                    vClipCenter_Radius_BL);

    float combined_alpha = alpha * clip_alpha;

    // Select alpha or inverse alpha depending on clip in/out.
    float final_alpha = mix(combined_alpha, 1.0 - combined_alpha, vClipMode);

    SHADER_OUT(Target0, vec4(final_alpha, 0.0, 0.0, 1.0));
}
#endif
