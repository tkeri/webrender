/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

LAYOUT(6, flat varying vec4 vColor);
LAYOUT(7, varying vec2 vUv);
LAYOUT(8, flat varying vec4 vUvBorder);

#ifdef WR_FEATURE_TRANSFORM
LAYOUT(9, varying vec3 vLocalPos);
#endif
