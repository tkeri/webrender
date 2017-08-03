/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

LAYOUT(6, flat varying vec4 vColor0);
LAYOUT(7, flat varying vec4 vColor1);
LAYOUT(8, flat varying vec2 vEdgeDistance);
LAYOUT(9, flat varying float vAxisSelect);
LAYOUT(10, flat varying float vAlphaSelect);
LAYOUT(11, flat varying vec4 vClipParams);
LAYOUT(12, flat varying float vClipSelect);

#ifdef WR_FEATURE_TRANSFORM
LAYOUT(13, varying vec3 vLocalPos);
#else
LAYOUT(13, varying vec2 vLocalPos);
#endif
