/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#define PRIMITIVE_HAS_PICTURE_TASK

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 gl_Position : SV_Position;
        vec3 vUv : vUv;
        flat vec4 vColor : vColor;
    };
#else
varying vec3 vUv;
flat varying vec4 vColor;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
// Draw a text run to a cache target. These are always
// drawn un-transformed. These are used for effects such
// as text-shadow.

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    ivec4 aDataA = IN.data0;
    ivec4 aDataB = IN.data1;
#endif //WR_DX11
    Primitive prim = load_primitive(aDataA, aDataB);
    TextRun text = fetch_text_run(prim.specific_prim_address);

    int glyph_index = prim.user_data0;
    int resource_address = prim.user_data1;

    Glyph glyph = fetch_glyph(prim.specific_prim_address,
                              glyph_index,
                              text.subpx_dir);

    GlyphResource res = fetch_glyph_resource(resource_address);

    // Glyphs size is already in device-pixels.
    // The render task origin is in device-pixels. Offset that by
    // the glyph offset, relative to its primitive bounding rect.
    vec2 size = (res.uv_rect.zw - res.uv_rect.xy) * res.scale;
    vec2 local_pos = glyph.offset + vec2(res.offset.x, -res.offset.y) / uDevicePixelRatio;
    vec2 origin = prim.task.target_rect.p0 +
                  uDevicePixelRatio * (local_pos - prim.task.content_origin);
    vec4 local_rect = vec4(origin, size);

    vec2 texture_size = vec2(textureSize(sColor0, 0));
    vec2 st0 = res.uv_rect.xy / texture_size;
    vec2 st1 = res.uv_rect.zw / texture_size;

    vec2 pos = mix(local_rect.xy,
                   local_rect.xy + local_rect.zw,
                   aPosition.xy);

    SHADER_OUT(vUv, vec3(mix(st0, st1, aPosition.xy), res.layer));
    SHADER_OUT(vColor, prim.task.color);

    SHADER_OUT(gl_Position, mul(vec4(pos, 0.0, 1.0), uTransform));
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec3 vUv = IN.vUv;
    vec4 vColor = IN.vColor;
#endif //WR_DX11
    float a = texture(sColor0, vUv).a;
    SHADER_OUT(Target0, vec4(vColor.rgb, vColor.a * a));
}
#endif
