/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,prim_shared

#ifdef WR_DX11
    struct v2p {
        vec4 Position : SV_Position;
        vec3 vUv : vUv;
        flat vec4 vUvBounds : vUvBounds;
    };
#else
varying vec3 vUv;
flat varying vec4 vUvBounds;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in a2v IN, out v2p OUT) {
    vec3 aPosition = IN.pos;
    ivec4 aDataA = IN.data0;
    ivec4 aDataB = IN.data1;
#endif //WR_DX11
    CompositeInstance ci = fetch_composite_instance(aDataA, aDataB);
    AlphaBatchTask dest_task = fetch_alpha_batch_task(ci.render_task_index);
    AlphaBatchTask src_task = fetch_alpha_batch_task(ci.src_task_index);

    vec2 dest_origin = dest_task.render_target_origin -
                       dest_task.screen_space_origin +
                       vec2(ci.user_data0, ci.user_data1);

    vec2 local_pos = mix(dest_origin,
                         dest_origin + src_task.size,
                         aPosition.xy);

    vec2 texture_size = vec2(textureSize(sCacheRGBA8, 0));
    vec2 st0 = src_task.render_target_origin;
    vec2 st1 = src_task.render_target_origin + src_task.size;
    SHADER_OUT(vUv, vec3(mix(st0, st1, aPosition.xy) / texture_size, src_task.render_target_layer_index));
    SHADER_OUT(vUvBounds, vec4(st0 + 0.5, st1 - 0.5) / texture_size.xyxy);

    #ifdef WR_DX11
        OUT.Position = mul(vec4(local_pos, ci.z, 1.0), uTransform);
    #else
        gl_Position = uTransform * vec4(local_pos, ci.z, 1.0);
    #endif //WR_DX11
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec3 vUv = IN.vUv;
    vec4 vUvBounds = IN.vUvBounds;
#endif //WR_DX11
    vec2 uv = clamp(vUv.xy, vUvBounds.xy, vUvBounds.zw);
#ifdef WR_DX11
        uv.y = 1.0 - uv.y;
#endif //WR_DX11
    SHADER_OUT(Target0, texture(sCacheRGBA8, vec3(uv, vUv.z)));
}
#endif
