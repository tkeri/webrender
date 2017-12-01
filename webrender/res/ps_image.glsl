/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
        flat vec4 vClipMaskUvBounds : vClipMaskUvBounds;
        vec3 vClipMaskUv : vClipMaskUv;
        flat vec2 vTextureOffset: vTextureOffset; // Offset of this image into the texture atlas.
        flat vec2 vTextureSize: vTextureSize;   // Size of the image in the texture atlas.
        flat vec2 vTileSpacing: vTileSpacing;   // Amount of space between tiled instances of this image.
        flat vec4 vStRect: vStRect;        // Rectangle of valid texture rect.
        flat float vLayer: vLayer;
        flat vec2 vStretchSize: vStretchSize;

#ifdef WR_FEATURE_TRANSFORM
        vec3 vLocalPos: vLocalPos;
        flat vec4 vLocalRect : vLocalRect;
        flat vec4 vLocalBounds : vLocalBounds;
#else
        vec2 vLocalPos: vLocalPos;
#endif //WR_FEATURE_TRANSFORM
    };
#else

// If this is in WR_FEATURE_TEXTURE_RECT mode, the rect and size use non-normalized
// texture coordinates. Otherwise, it uses normalized texture coordinates. Please
// check GL_TEXTURE_RECTANGLE.
flat varying vec2 vTextureOffset; // Offset of this image into the texture atlas.
flat varying vec2 vTextureSize;   // Size of the image in the texture atlas.
flat varying vec2 vTileSpacing;   // Amount of space between tiled instances of this image.
flat varying vec4 vStRect;        // Rectangle of valid texture rect.
flat varying float vLayer;

#ifdef WR_FEATURE_TRANSFORM
varying vec3 vLocalPos;
flat varying vec4 vLocalRect;
#else
varying vec2 vLocalPos;
#endif //WR_FEATURE_TRANSFORM
flat varying vec2 vStretchSize;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
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
    Image image = fetch_image(prim.specific_prim_address);
    ImageResource res = fetch_image_resource(prim.user_data0);

#ifdef WR_FEATURE_TRANSFORM
    TransformVertexInfo vi = write_transform_vertex(gl_VertexID,
                                                    prim.local_rect,
                                                    prim.local_clip_rect,
                                                    prim.z,
                                                    prim.layer,
                                                    prim.task,
                                                    prim.local_rect
#ifdef WR_DX11
                                                    , OUT.Position
                                                    , OUT.vLocalBounds
#endif //WR_DX11
                                                    );
    SHADER_OUT(vLocalPos, vi.local_pos);
    SHADER_OUT(vLocalRect, vec4(prim.local_rect.p0, prim.local_rect.p0 + prim.local_rect.size));
#else
    VertexInfo vi = write_vertex(aPosition,
                                 prim.local_rect,
                                 prim.local_clip_rect,
                                 prim.z,
                                 prim.layer,
                                 prim.task,
                                 prim.local_rect
#ifdef WR_DX11
                                 , OUT.Position
#endif //WR_DX11
                                 );
    SHADER_OUT(vLocalPos, vi.local_pos - prim.local_rect.p0);
#endif

    write_clip(vi.screen_pos,
               prim.clip_area
#ifdef WR_DX11
               , OUT.vClipMaskUvBounds
               , OUT.vClipMaskUv
#endif //WR_DX11
               );

    // If this is in WR_FEATURE_TEXTURE_RECT mode, the rect and size use
    // non-normalized texture coordinates.
#ifdef WR_FEATURE_TEXTURE_RECT
    vec2 texture_size_normalization_factor = vec2(1, 1);
#else
    vec2 texture_size_normalization_factor = vec2(textureSize(sColor0, 0));
#endif

    vec2 uv0, uv1;

    if (image.sub_rect.x < 0.0) {
        uv0 = res.uv_rect.xy;
        uv1 = res.uv_rect.zw;
    } else {
        uv0 = res.uv_rect.xy + image.sub_rect.xy;
        uv1 = res.uv_rect.xy + image.sub_rect.zw;
    }

    // vUv will contain how many times this image has wrapped around the image size.
    vec2 st0 = uv0 / texture_size_normalization_factor;
    vec2 st1 = uv1 / texture_size_normalization_factor;

    SHADER_OUT(vLayer, res.layer);
    SHADER_OUT(vTextureSize, st1 - st0);
    SHADER_OUT(vTextureOffset, st0);
    SHADER_OUT(vTileSpacing, image.stretch_size_and_tile_spacing.zw);
    SHADER_OUT(vStretchSize, image.stretch_size_and_tile_spacing.xy);

    // We clamp the texture coordinates to the half-pixel offset from the borders
    // in order to avoid sampling outside of the texture area.
    vec2 half_texel = vec2(0.5, 0.5) / texture_size_normalization_factor;
    SHADER_OUT(vStRect, vec4(min(st0, st1) + half_texel, max(st0, st1) - half_texel));
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec4 vClipMaskUvBounds = IN.vClipMaskUvBounds;
    vec3 vClipMaskUv = IN.vClipMaskUv;
    vec2 vTextureOffset = IN.vTextureOffset;
    vec2 vTextureSize = IN.vTextureSize;
    vec2 vTileSpacing = IN.vTileSpacing;
    vec4 vStRect = IN.vStRect;
    float vLayer = IN.vLayer;
    vec2 vStretchSize = IN.vStretchSize;
#endif //WR_DX11
#ifdef WR_FEATURE_TRANSFORM
    float alpha = 0.0;
#ifdef WR_DX11
    vec3 vLocalPos = IN.vLocalPos;
    vec4 vLocalRect = IN.vLocalRect;
    vec4 vLocalBounds = IN.vLocalBounds;
#endif //WR_DX11
    vec2 pos = init_transform_fs(vLocalPos, vLocalBounds, alpha);

    // We clamp the texture coordinate calculation here to the local rectangle boundaries,
    // which makes the edge of the texture stretch instead of repeat.
    vec2 upper_bound_mask = step(vLocalRect.zw, pos);
    vec2 relative_pos_in_rect = clamp(pos, vLocalRect.xy, vLocalRect.zw) - vLocalRect.xy;
#else
    float alpha = 1.0;
#ifdef WR_DX11
    vec2 vLocalPos = IN.vLocalPos;
#endif //WR_DX11
    vec2 relative_pos_in_rect = vLocalPos;
    vec2 upper_bound_mask = vec2(0.0, 0.0);
#endif

    alpha *= do_clip(vClipMaskUvBounds, vClipMaskUv);

    // We calculate the particular tile this fragment belongs to, taking into
    // account the spacing in between tiles. We only paint if our fragment does
    // not fall into that spacing.
    // If the pixel is at the local rectangle upper bound, we force the current
    // tile upper bound in order to avoid wrapping.
    vec2 stretch_tile = vStretchSize + vTileSpacing;
    vec2 position_in_tile = mix(
        mod(relative_pos_in_rect, stretch_tile),
        vStretchSize,
        upper_bound_mask);
    vec2 st = vTextureOffset + ((position_in_tile / vStretchSize) * vTextureSize);
    st = clamp(st, vStRect.xy, vStRect.zw);

    alpha = alpha * float(all(bvec2(step(position_in_tile, vStretchSize))));

    vec4 color = TEX_SAMPLE(sColor0, vec3(st, vLayer));
    SHADER_OUT(Target0, vec4(alpha, alpha, alpha, alpha) * color);
}
#endif
