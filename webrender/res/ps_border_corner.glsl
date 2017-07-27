#line 1
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Edge color transition
layout(location = 6) flat varying vec4 vColor00;
layout(location = 7) flat varying vec4 vColor01;
layout(location = 8) flat varying vec4 vColor10;
layout(location = 9) flat varying vec4 vColor11;
layout(location = 10) flat varying vec4 vColorEdgeLine;

// Border radius
layout(location = 11) flat varying vec2 vClipCenter;
layout(location = 12) flat varying vec4 vRadii0;
layout(location = 13) flat varying vec4 vRadii1;
layout(location = 14) flat varying vec2 vClipSign;
layout(location = 15) flat varying vec4 vEdgeDistance;
layout(location = 16) flat varying float vSDFSelect;

// Border style
layout(location = 17) flat varying float vAlphaSelect;

#ifdef WR_FEATURE_TRANSFORM
layout(location = 18) varying vec3 vLocalPos;
#else
layout(location = 18) varying vec2 vLocalPos;
#endif
