/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
        flat vec4 vClipMaskUvBounds : vClipMaskUvBounds;
        vec3 vClipMaskUv : vClipMaskUv;
        flat vec4 vColor : vColor;
        vec3 vUv: vUv;
        flat vec4 vUvBorder: vUvBorder;
#ifdef WR_FEATURE_TRANSFORM
        vec3 vLocalPos : vLocalPos;
        flat vec4 vLocalBounds : vLocalBounds;
#endif //WR_FEATURE_TRANSFORM
    };
#else

flat varying vec4 vColor;
varying vec3 vUv;
flat varying vec4 vUvBorder;

#ifdef WR_FEATURE_TRANSFORM
varying vec3 vLocalPos;
#endif //WR_FEATURE_TRANSFORM
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER

#define MODE_ALPHA          0
#define MODE_SUBPX_PASS0    1
#define MODE_SUBPX_PASS1    2
#define MODE_COLOR_BITMAP   3

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    ivec4 aDataA = IN.data0;
    ivec4 aDataB = IN.data1;
    int gl_VertexID = IN.vertexId;
#endif //WR_DX11
    Primitive prim = load_primitive(aDataA, aDataB);
    TextRun text = fetch_text_run(prim.specific_prim_address);

    int glyph_index = prim.user_data0;
    int resource_address = prim.user_data1;

    Glyph glyph = fetch_glyph(prim.specific_prim_address,
                              glyph_index,
                              text.subpx_dir);
    GlyphResource res = fetch_glyph_resource(resource_address);

    vec2 local_pos = glyph.offset +
                     text.offset +
                     vec2(res.offset.x, -res.offset.y) / uDevicePixelRatio;

    RectWithSize local_rect;
    local_rect.p0 = local_pos;
    local_rect.size = (res.uv_rect.zw - res.uv_rect.xy) * res.scale / uDevicePixelRatio;

#ifdef WR_FEATURE_TRANSFORM
    TransformVertexInfo vi = write_transform_vertex(gl_VertexID,
                                                    local_rect,
                                                    prim.local_clip_rect,
                                                    prim.z,
                                                    prim.layer,
                                                    prim.task,
                                                    local_rect
#ifdef WR_DX11
                                                    , OUT.Position
                                                    , OUT.vLocalBounds
#endif //WR_DX11
                                                    );
    SHADER_OUT(vLocalPos, vi.local_pos);
    vec2 f = (vi.local_pos.xy / vi.local_pos.z - local_rect.p0) / local_rect.size;
#else
    VertexInfo vi = write_vertex(aPosition,
                                 local_rect,
                                 prim.local_clip_rect,
                                 prim.z,
                                 prim.layer,
                                 prim.task,
                                 local_rect
#ifdef WR_DX11
                                 , OUT.Position
#endif //WR_DX11
                                 );
    vec2 f = (vi.local_pos - local_rect.p0) / local_rect.size;
#endif

    write_clip(vi.screen_pos,
               prim.clip_area
#ifdef WR_DX11
               , OUT.vClipMaskUvBounds
               , OUT.vClipMaskUv
#endif //WR_DX11
               );

    switch (uMode) {
        case MODE_ALPHA:
        case MODE_SUBPX_PASS1:
            SHADER_OUT(vColor, text.color);
            break;
        case MODE_SUBPX_PASS0:
        case MODE_COLOR_BITMAP:
            SHADER_OUT(vColor, vec4(text.color.a, text.color.a, text.color.a, text.color.a));
            break;
    }

    vec2 texture_size = vec2(textureSize(sColor0, 0));
    vec2 st0 = res.uv_rect.xy / texture_size;
    vec2 st1 = res.uv_rect.zw / texture_size;

    SHADER_OUT(vUv, vec3(mix(st0, st1, f), res.layer));
    SHADER_OUT(vUvBorder, (res.uv_rect + vec4(0.5, 0.5, -0.5, -0.5)) / texture_size.xyxy);
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec4 vClipMaskUvBounds = IN.vClipMaskUvBounds;
    vec3 vClipMaskUv = IN.vClipMaskUv;
    vec4 vColor = IN.vColor;
    vec3 vUv = IN.vUv;
    vec4 vUvBorder = IN.vUvBorder;
#ifdef WR_FEATURE_TRANSFORM
    vec3 vLocalPos = IN.vLocalPos;
    vec4 vLocalBounds = IN.vLocalBounds;
#endif
#endif //WR_DX11
    vec3 tc = vec3(clamp(vUv.xy, vUvBorder.xy, vUvBorder.zw), vUv.z);
    vec4 color = texture(sColor0, tc);

    float alpha = 1.0;
#ifdef WR_FEATURE_TRANSFORM
    init_transform_fs(vLocalPos, vLocalBounds, alpha);
#endif
    alpha *= do_clip(vClipMaskUvBounds, vClipMaskUv);

    SHADER_OUT(Target0, color * vColor * alpha);
}
#endif
