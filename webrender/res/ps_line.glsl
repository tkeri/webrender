/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

LAYOUT(6, varying vec4 vColor);
LAYOUT(7, flat varying int vStyle);
LAYOUT(8, flat varying float vAxisSelect);
LAYOUT(9, flat varying vec4 vParams);
LAYOUT(10, flat varying vec2 vLocalOrigin);

#ifdef WR_FEATURE_TRANSFORM
LAYOUT(11, varying vec3 vLocalPos);
#else
LAYOUT(11, varying vec2 vLocalPos);
#endif
