/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared,ellipse

#ifdef WR_DX11
    struct v2p {
        vec4 Position: SV_Position;
#ifdef WR_FEATURE_ALPHA_PASS
        flat vec4 vClipMaskUvBounds : vClipMaskUvBounds;
        vec3 vClipMaskUv : vClipMaskUv;
#endif //WR_FEATURE_ALPHA_PASS
        flat float vClipMode: vClipMode;
        flat vec4 vClipCenter_Radius_TL: vClipCenter_Radius_TL;
        flat vec4 vClipCenter_Radius_TR: vClipCenter_Radius_TR;
        flat vec4 vClipCenter_Radius_BR: vClipCenter_Radius_BR;
        flat vec4 vClipCenter_Radius_BL: vClipCenter_Radius_BL;
        flat vec4 vLocalRect: vLocalRect;
        vec2 vLocalPos: vLocalPos;
    };
#else
flat varying float vClipMode;
flat varying vec4 vClipCenter_Radius_TL;
flat varying vec4 vClipCenter_Radius_TR;
flat varying vec4 vClipCenter_Radius_BR;
flat varying vec4 vClipCenter_Radius_BL;
flat varying vec4 vLocalRect;
varying vec2 vLocalPos;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER

struct BrushPrimitive {
    float clip_mode;
    vec2 radius_tl;
    vec2 radius_tr;
    vec2 radius_br;
    vec2 radius_bl;
};

BrushPrimitive fetch_brush_primitive(int address) {
    ResourceCacheData3 data = fetch_from_resource_cache_3(address);
    BrushPrimitive brush;
    brush.clip_mode = data.data0.x;
    brush.radius_tl = data.data1.xy;
    brush.radius_tr = data.data1.zw;
    brush.radius_br = data.data2.xy;
    brush.radius_bl = data.data2.zw;
    return brush;
}

void brush_vs(
    int prim_address,
    vec2 local_pos,
    RectWithSize local_rect,
#ifdef WR_DX11
    out float vClipMode,
    out vec4 vClipCenter_Radius_TL,
    out vec4 vClipCenter_Radius_TR,
    out vec4 vClipCenter_Radius_BR,
    out vec4 vClipCenter_Radius_BL,
    out vec4 vLocalRect,
    out vec2 vLocalPos,
#endif //WR_DX11
    ivec2 user_data
) {
    // Load the specific primitive.
    BrushPrimitive prim = fetch_brush_primitive(prim_address);

    // Write clip parameters
    vClipMode = prim.clip_mode;

    // TODO(gw): In the future, when brush primitives may be segment rects
    //           we need to account for that here, and differentiate between
    //           the segment rect (geometry) amd the primitive rect (which
    //           defines where the clip radii are relative to).
    vec4 prim_rect = vec4(local_rect.p0, local_rect.p0 + local_rect.size);

    vClipCenter_Radius_TL = vec4(prim_rect.xy + prim.radius_tl, prim.radius_tl);
    vClipCenter_Radius_TR = vec4(prim_rect.zy + vec2(-prim.radius_tr.x, prim.radius_tr.y), prim.radius_tr);
    vClipCenter_Radius_BR = vec4(prim_rect.zw - prim.radius_br, prim.radius_br);
    vClipCenter_Radius_BL = vec4(prim_rect.xw + vec2(prim.radius_bl.x, -prim.radius_bl.y), prim.radius_bl);

    vLocalRect = prim_rect;
    vLocalPos = local_pos;
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
vec4 brush_fs() {
#else
vec4 brush_fs(in v2p IN) {
    float vClipMode = IN.vClipMode;
    vec4 vClipCenter_Radius_TL = IN.vClipCenter_Radius_TL;
    vec4 vClipCenter_Radius_TR = IN.vClipCenter_Radius_TR;
    vec4 vClipCenter_Radius_BR = IN.vClipCenter_Radius_BR;
    vec4 vClipCenter_Radius_BL = IN.vClipCenter_Radius_BL;
    vec4 vLocalRect = IN.vLocalRect;
    vec2 vLocalPos = IN.vLocalPos;
#endif
    // TODO(gw): The mask code below is super-inefficient. Once we
    // start using primitive segments in brush shaders, this can
    // be made much faster.
    float d = 0.0;
    // Check if in valid clip region.
    if (vLocalPos.x >= vLocalRect.x && vLocalPos.x < vLocalRect.z &&
        vLocalPos.y >= vLocalRect.y && vLocalPos.y < vLocalRect.w) {
        // Apply ellipse clip on each corner.
        d = rounded_rect(vLocalPos,
                         vClipCenter_Radius_TL,
                         vClipCenter_Radius_TR,
                         vClipCenter_Radius_BR,
                         vClipCenter_Radius_BL);
    }

    float m = mix(d, 1.0 - d, vClipMode);
    return vec4(m, m, m, m);
}
#endif

#ifdef WR_VERTEX_SHADER

void brush_vs(
    int prim_address,
    vec2 local_pos,
    RectWithSize local_rect,
#ifdef WR_DX11
    out float vClipMode,
    out vec4 vClipCenter_Radius_TL,
    out vec4 vClipCenter_Radius_TR,
    out vec4 vClipCenter_Radius_BR,
    out vec4 vClipCenter_Radius_BL,
    out vec4 vLocalRect,
    out vec2 vLocalPos,
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
        OUT.vClipMode,
        OUT.vClipCenter_Radius_TL,
        OUT.vClipCenter_Radius_TR,
        OUT.vClipCenter_Radius_BR,
        OUT.vClipCenter_Radius_BL,
        OUT.vLocalRect,
        OUT.vLocalPos,
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
