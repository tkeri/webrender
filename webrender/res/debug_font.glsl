/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include shared,shared_other

#ifdef WR_DX11
struct v2p {
    vec4 gl_Position : SV_Position;
    vec4 vColor : vColor;
    vec2 vColorTexCoord : vColorTexCoord;
};
#else
varying vec2 vColorTexCoord;
varying vec4 vColor;
#endif //WR_DX11

#ifdef WR_VERTEX_SHADER
#ifdef WR_DX11
struct a2vDebug {
    vec4 aColor : aColor;
    vec4 aColorTexCoord : aColorTexCoord;
    vec3 aPosition : aPosition;
};
#else
in vec4 aColor;
in vec4 aColorTexCoord;
#endif //WR_DX11

#ifndef WR_DX11
void main(void) {
#else
void main(in a2vDebug IN, out v2p OUT) {
    vec4 aColor = IN.aColor;
    vec4 aColorTexCoord = IN.aColorTexCoord;
    vec3 aPosition = IN.aPosition;
#endif //WR_DX11
    SHADER_OUT(vColor, aColor);
    SHADER_OUT(vColorTexCoord, vec2(aColorTexCoord.xy));
    vec4 pos = vec4(aPosition, 1.0);
    pos.xy = floor(pos.xy * uDevicePixelRatio + 0.5) / uDevicePixelRatio;
    SHADER_OUT(gl_Position, mul(pos, uTransform));
}
#endif

#ifdef WR_FRAGMENT_SHADER
#ifndef WR_DX11
void main(void) {
#else
void main(in v2p IN, out p2f OUT) {
    vec4 vColor = IN.vColor;
    vec2 vColorTexCoord = IN.vColorTexCoord;
#endif //WR_DX11
    float alpha = texture(sColor0, vec3(vColorTexCoord.xy, 0.0)).r;
    SHADER_OUT(Target0, vec4(vColor.xyz, vColor.w * alpha));
}
#endif
