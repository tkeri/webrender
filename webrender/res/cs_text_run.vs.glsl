/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Draw a text run to a cache target. These are always
// drawn un-transformed. These are used for effects such
// as text-shadow.

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v_clip IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    ivec4 aDataA = IN.data0;
    ivec4 aDataB = IN.data1;
#endif //WR_DX11

    Primitive prim = load_primitive(aDataA, aDataB);
    TextRun text = fetch_text_run(prim.specific_prim_address);

    int glyph_index = prim.user_data0;
    int resource_address = prim.user_data1;
    int text_shadow_address = prim.user_data2;

    // Fetch the parent text-shadow for this primitive. This allows the code
    // below to normalize the glyph offsets relative to the original text
    // shadow rect, which is the union of all elements that make up this
    // text shadow. This allows the text shadow to be rendered at an
    // arbitrary location in a render target (provided by the render
    // task render_target_origin field).
    PrimitiveGeometry shadow_geom = fetch_primitive_geometry(text_shadow_address);
    TextShadow shadow = fetch_text_shadow(text_shadow_address + VECS_PER_PRIM_HEADER);

    Glyph glyph = fetch_glyph(prim.specific_prim_address,
                              glyph_index,
                              text.subpx_dir);

    GlyphResource res = fetch_glyph_resource(resource_address);

    // Glyphs size is already in device-pixels.
    // The render task origin is in device-pixels. Offset that by
    // the glyph offset, relative to its primitive bounding rect.
    vec2 size = res.uv_rect.zw - res.uv_rect.xy;
    vec2 local_pos = glyph.offset + vec2(res.offset.x, -res.offset.y) / uDevicePixelRatio;
    vec2 origin = prim.task.render_target_origin +
                  uDevicePixelRatio * (local_pos + shadow.offset - shadow_geom.local_rect.p0);
    vec4 local_rect = vec4(origin, size);

    vec2 texture_size = vec2(textureSize(sColor0, 0));
    vec2 st0 = res.uv_rect.xy / texture_size;
    vec2 st1 = res.uv_rect.zw / texture_size;

    vec2 pos = mix(local_rect.xy,
                   local_rect.xy + local_rect.zw,
                   aPosition.xy);

    SHADER_OUT(vUv, vec3(mix(st0, st1, aPosition.xy), res.layer));
    SHADER_OUT(vColor, shadow.color);

    SHADER_OUT(gl_Position, mul(vec4(pos, 0.0, 1.0), uTransform));
}
