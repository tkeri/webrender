//#line 1
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifdef WR_VERTEX_SHADER

#define SEGMENT_ALL         0
#define SEGMENT_CORNER_TL   1
#define SEGMENT_CORNER_TR   2
#define SEGMENT_CORNER_BL   3
#define SEGMENT_CORNER_BR   4

#ifdef WR_DX11
struct a2v {
    vec3 pos : aPosition;
    int aClipRenderTaskIndex : aClipRenderTaskIndex;
    int aClipLayerIndex : aClipLayerIndex;
    int aClipDataIndex : aClipDataIndex;
    int aClipSegmentIndex : aClipSegmentIndex;
    int aClipResourceAddress : aClipResourceAddress;
};
#else
in int aClipRenderTaskIndex;
in int aClipLayerIndex;
in int aClipDataIndex;
in int aClipSegmentIndex;
in int aClipResourceAddress;
#endif //WR_DX11

struct CacheClipInstance {
    int render_task_index;
    int layer_index;
    int data_index;
    int segment_index;
    int resource_address;
};

CacheClipInstance fetch_clip_item(int aClipRenderTaskIndex,
                                  int aClipLayerIndex,
                                  int aClipDataIndex,
                                  int aClipSegmentIndex,
                                  int aClipResourceAddress) {
    CacheClipInstance cci;

    cci.render_task_index = aClipRenderTaskIndex;
    cci.layer_index = aClipLayerIndex;
    cci.data_index = aClipDataIndex;
    cci.segment_index = aClipSegmentIndex;
    cci.resource_address = aClipResourceAddress;

    return cci;
}

struct ClipVertexInfo {
    vec3 local_pos;
    vec2 screen_pos;
    RectWithSize clipped_local_rect;
};

// The transformed vertex function that always covers the whole clip area,
// which is the intersection of all clip instances of a given primitive
ClipVertexInfo write_clip_tile_vertex(vec3 aPosition,
                                      RectWithSize local_clip_rect,
                                      Layer layer,
                                      ClipArea area,
                                      int segment_index
#ifdef WR_DX11
                                      , out vec4 vPosition
                                      , out vec4 vLocalBounds
#endif //WR_DX11
                                      ) {

    RectWithSize clipped_local_rect = intersect_rect(local_clip_rect,
                                                     layer.local_clip_rect);

    vec2 outer_p0 = area.screen_origin_target_index.xy;
    vec2 outer_p1 = outer_p0 + area.task_bounds.zw - area.task_bounds.xy;
    vec2 inner_p0 = area.inner_rect.xy;
    vec2 inner_p1 = area.inner_rect.zw;

    vec2 p0, p1;
    switch (segment_index) {
        case SEGMENT_ALL:
            p0 = outer_p0;
            p1 = outer_p1;
            break;
        case SEGMENT_CORNER_TL:
            p0 = outer_p0;
            p1 = inner_p0;
            break;
        case SEGMENT_CORNER_BL:
            p0 = vec2(outer_p0.x, outer_p1.y);
            p1 = vec2(inner_p0.x, inner_p1.y);
            break;
        case SEGMENT_CORNER_TR:
            p0 = vec2(outer_p1.x, outer_p1.y);
            p1 = vec2(inner_p1.x, inner_p1.y);
            break;
        case SEGMENT_CORNER_BR:
            p0 = vec2(outer_p1.x, outer_p0.y);
            p1 = vec2(inner_p1.x, inner_p0.y);
            break;
        default:
            p0 = outer_p0;
            p1 = outer_p1;
            break;
    }

    vec2 actual_pos = mix(p0, p1, aPosition.xy);

    vec4 layer_pos = get_layer_pos(actual_pos / uDevicePixelRatio, layer);

    // compute the point position in side the layer, in CSS space
    vec2 vertex_pos = actual_pos + area.task_bounds.xy - area.screen_origin_target_index.xy;

#ifdef WR_DX11
    // In DX11 the z is between 0 and 1
    float4x4 transform = float4x4(
        float4(1.0, 0.0, 0.0, 0.0),
        float4(0.0, 1.0, 0.0, 0.0),
        float4(0.0, 0.0, 0.5, 0.5),
        float4(0.0, 0.0, 0.0, 1.0)
    );
    vec4 out_pos = mul(transform, mul(uTransform, vec4(vertex_pos, 0.0, 1.0)));
    vPosition = out_pos / out_pos.w;
#else
    gl_Position = uTransform * vec4(vertex_pos, 0.0, 1.0);
#endif //WR_DX11

    vLocalBounds = vec4(clipped_local_rect.p0, clipped_local_rect.p0 + clipped_local_rect.size);
    ClipVertexInfo cvi;
    cvi.local_pos = layer_pos.xyw;
    cvi.screen_pos = actual_pos;
    cvi.clipped_local_rect = clipped_local_rect;
    return cvi;
}

#endif //WR_VERTEX_SHADER
