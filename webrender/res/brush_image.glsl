/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
#ifdef WR_FEATURE_ALPHA_PASS
        flat vec4 vClipMaskUvBounds : vClipMaskUvBounds;
        vec3 vClipMaskUv : vClipMaskUv;
#endif //WR_FEATURE_ALPHA_PASS
        vec3 vUv: vUv;
        flat vec4 vUvBounds: vUvBounds;
#ifdef WR_FEATURE_ALPHA_TARGET
        flat vec4 vColor: vColor;
#endif //WR_FEATURE_ALPHA_TARGET
    };

#else
varying vec3 vUv;
flat varying vec4 vUvBounds;

#ifdef WR_FEATURE_ALPHA_TARGET
flat varying vec4 vColor;
#endif
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
void brush_vs(
    int prim_address,
    vec2 local_pos,
    RectWithSize local_rect,
#ifdef WR_DX11
    out vec3 vUv,
#ifdef WR_FEATURE_ALPHA_TARGET
    out vec4 vColor,
#endif //WR_FEATURE_ALPHA_TARGET
    out vec4 vUvBounds,
#endif //WR_DX11
    ivec2 user_data
) {
    // TODO(gw): For now, this brush_image shader is only
    //           being used to draw items from the intermediate
    //           surface cache (render tasks). In the future
    //           we can expand this to support items from
    //           the normal texture cache and unify this
    //           with the normal image shader.
    BlurTask task = fetch_blur_task(user_data.x);
    vUv.z = task.render_target_layer_index;

#ifdef WR_FEATURE_COLOR_TARGET
    vec2 texture_size = vec2(textureSize(sColor0, 0).xy);
#else
    vec2 texture_size = vec2(textureSize(sColor1, 0).xy);
    vColor = task.color;
#endif

    vec2 uv0 = task.target_rect.p0;
    vec2 uv1 = (task.target_rect.p0 + task.target_rect.size);

    vec2 f = (local_pos - local_rect.p0) / local_rect.size;

    vUv.xy = mix(uv0 / texture_size,
                 uv1 / texture_size,
                 f);

    vUvBounds = vec4(uv0 + vec2(0.5, 0.5), uv1 - vec2(0.5, 0.5)) / texture_size.xyxy;
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
vec4 brush_fs() {
#else
vec4 brush_fs(in v2p IN) {
    vec3 vUv = IN.vUv;
    vec4 vUvBounds = IN.vUvBounds;
#ifdef WR_FEATURE_ALPHA_TARGET
    vec4 vColor = IN.vColor;
#endif //WR_FEATURE_ALPHA_TARGET
#endif //WR_DX11
    vec2 uv = clamp(vUv.xy, vUvBounds.xy, vUvBounds.zw);

#ifdef WR_FEATURE_COLOR_TARGET
    vec4 color = texture(sColor0, vec3(uv, vUv.z));
#else
    vec4 color = vColor * texture(sColor1, vec3(uv, vUv.z)).r;
#endif

    return color;
}
#endif

#ifdef WR_VERTEX_SHADER

void brush_vs(
    int prim_address,
    vec2 local_pos,
    RectWithSize local_rect,
#ifdef WR_DX11
    out vec3 vUv,
#ifdef WR_FEATURE_ALPHA_TARGET
    out vec4 vColor,
#endif //WR_FEATURE_ALPHA_TARGET
    out vec4 vUvBounds,
#endif //WR_DX11
    ivec2 user_data
);

// Whether this brush is being drawn on a Picture
// task (new) or an alpha batch task (legacy).
// Can be removed once everything uses pictures.
#define BRUSH_FLAG_USES_PICTURE     (1 << 0)

struct BrushInstance {
    int picture_address;
    int prim_address;
    int layer_address;
    int clip_address;
    int z;
    int flags;
    ivec2 user_data;
};

BrushInstance load_brush(ivec4 aDataA, ivec4 aDataB) {
    BrushInstance bi;

    bi.picture_address = aDataA.x;
    bi.prim_address = aDataA.y;
    bi.layer_address = aDataA.z;
    bi.clip_address = aDataA.w;
    bi.z = aDataB.x;
    bi.flags = aDataB.y;
    bi.user_data = aDataB.zw;

    return bi;
}

#ifndef WR_DX11
void main(void) {
#else
void main(in a2v IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    ivec4 aDataA = IN.data0;
    ivec4 aDataB = IN.data1;
#endif //WR_DX11
    // Load the brush instance from vertex attributes.
    BrushInstance brush = load_brush(aDataA, aDataB);

    // Load the geometry for this brush. For now, this is simply the
    // local rect of the primitive. In the future, this will support
    // loading segment rects, and other rect formats (glyphs).
    PrimitiveGeometry geom = fetch_primitive_geometry(brush.prim_address);

    vec2 device_pos, local_pos;
    RectWithSize local_rect = geom.local_rect;

    if ((brush.flags & BRUSH_FLAG_USES_PICTURE) != 0) {
        // Fetch the dynamic picture that we are drawing on.
        PictureTask pic_task = fetch_picture_task(brush.picture_address);

        // Right now - pictures only support local positions. In the future, this
        // will be expanded to support transform picture types (the common kind).
        device_pos = pic_task.target_rect.p0 + aPosition.xy * pic_task.target_rect.size;
        local_pos = aPosition.xy * pic_task.target_rect.size / uDevicePixelRatio;

        // Write the final position transformed by the orthographic device-pixel projection.
#ifdef WR_DX11
        OUT.Position = mul(vec4(device_pos, 0.0, 1.0), uTransform);
#else
        gl_Position = uTransform * vec4(device_pos, 0.0, 1.0);
#endif
    } else {
        AlphaBatchTask alpha_task = fetch_alpha_batch_task(brush.picture_address);
        Layer layer = fetch_layer(brush.layer_address);
        ClipArea clip_area = fetch_clip_area(brush.clip_address);

        // Write the normal vertex information out.
        // TODO(gw): Support transform types in brushes. For now,
        //           the old cache image shader didn't support
        //           them yet anyway, so we're not losing any
        //           existing functionality.
        VertexInfo vi = write_vertex(
            aPosition,
            geom.local_rect,
            geom.local_clip_rect,
            float(brush.z),
            layer,
            alpha_task,
            geom.local_rect
#ifdef WR_DX11
            , OUT.Position
#endif //WR_DX11
        );

        local_pos = vi.local_pos;

        // For brush instances in the alpha pass, always write
        // out clip information.
        // TODO(gw): It's possible that we might want alpha
        //           shaders that don't clip in the future,
        //           but it's reasonable to assume that one
        //           implies the other, for now.
#ifdef WR_FEATURE_ALPHA_PASS
        write_clip(
            vi.screen_pos,
            clip_area
#ifdef WR_DX11
            , OUT.vClipMaskUvBounds
            , OUT.vClipMaskUv
#endif //WR_DX11
        );
#endif
    }

    // Run the specific brush VS code to write interpolators.
    brush_vs(
        brush.prim_address + VECS_PER_PRIM_HEADER,
        local_pos,
        local_rect,
#ifdef WR_DX11
        OUT.vUv,
#ifdef WR_FEATURE_ALPHA_TARGET
        OUT.vColor,
#endif //WR_FEATURE_ALPHA_TARGET
        OUT.vUvBounds,
#endif //WR_DX11
        brush.user_data
    );
}
#endif

#ifdef WR_FRAGMENT_SHADER

#ifdef WR_DX11
vec4 brush_fs(in v2p IN);
#else
vec4 brush_fs();
#endif

#ifndef WR_DX11
void main(void) {
    // Run the specific brush FS code to output the color.
    vec4 color = brush_fs();
#else
void main(in v2p IN, out p2f OUT) {
#ifdef WR_FEATURE_ALPHA_PASS
    vec4 vClipMaskUvBounds = IN.vClipMaskUvBounds;
    vec3 vClipMaskUv = IN.vClipMaskUv;
#endif //WR_FEATURE_ALPHA_PASS
    // Run the specific brush FS code to output the color.
    vec4 color = brush_fs(IN);
#endif // WR_DX11

#ifdef WR_FEATURE_ALPHA_PASS
    // Apply the clip mask
    color *= do_clip(vClipMaskUvBounds, vClipMaskUv);
#endif

    // TODO(gw): Handle pre-multiply common code here as required.
    SHADER_OUT(Target0, color);
}
#endif
