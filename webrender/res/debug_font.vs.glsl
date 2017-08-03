/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

LAYOUT(0, in vec4 aColor);
LAYOUT(1, in vec4 aColorTexCoord);

LAYOUT(0, out vec2 vColorTexCoord);
LAYOUT(1, out vec4 vColor);

void main(void)
{
    vColor = aColor;
    vColorTexCoord = aColorTexCoord.xy;
    vec4 pos = vec4(aPosition, 1.0);
    pos.xy = floor(pos.xy * uDevicePixelRatio + 0.5) / uDevicePixelRatio;
    gl_Position = uTransform * pos;
}
