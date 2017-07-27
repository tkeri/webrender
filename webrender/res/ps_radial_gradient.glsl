/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

layout(location = 6) flat varying int vGradientAddress;
layout(location = 7) flat varying float vGradientRepeat;

layout(location = 8) flat varying vec2 vStartCenter;
layout(location = 9) flat varying vec2 vEndCenter;
layout(location = 10) flat varying float vStartRadius;
layout(location = 11) flat varying float vEndRadius;

layout(location = 12) flat varying vec2 vTileSize;
layout(location = 13) flat varying vec2 vTileRepeat;

layout(location = 14) varying vec2 vPos;
