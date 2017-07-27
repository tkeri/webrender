/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

layout(location = 6) flat varying vec4 vColor0;
layout(location = 7) flat varying vec4 vColor1;
layout(location = 8) flat varying vec2 vEdgeDistance;
layout(location = 9) flat varying float vAxisSelect;
layout(location = 10) flat varying float vAlphaSelect;
layout(location = 11) flat varying vec4 vClipParams;
layout(location = 12) flat varying float vClipSelect;

#ifdef WR_FEATURE_TRANSFORM
layout(location = 13) varying vec3 vLocalPos;
#else
layout(location = 13) varying vec2 vLocalPos;
#endif
