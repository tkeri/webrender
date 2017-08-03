#line 1
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Edge color transition
LAYOUT(6, flat varying vec4 vColor00);
LAYOUT(7, flat varying vec4 vColor01);
LAYOUT(8, flat varying vec4 vColor10);
LAYOUT(9, flat varying vec4 vColor11);
LAYOUT(10, flat varying vec4 vColorEdgeLine);

// Border radius
LAYOUT(11, flat varying vec2 vClipCenter);
LAYOUT(12, flat varying vec4 vRadii0);
LAYOUT(13, flat varying vec4 vRadii1);
LAYOUT(14, flat varying vec2 vClipSign);
LAYOUT(15, flat varying vec4 vEdgeDistance);
LAYOUT(16, flat varying float vSDFSelect);

// Border style
LAYOUT(17, flat varying float vAlphaSelect);

#ifdef WR_FEATURE_TRANSFORM
LAYOUT(18, varying vec3 vLocalPos);
#else
LAYOUT(18, varying vec2 vLocalPos);
#endif
