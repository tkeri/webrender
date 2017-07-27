/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// If this is in WR_FEATURE_TEXTURE_RECT mode, the rect and size use non-normalized
// texture coordinates. Otherwise, it uses normalized texture coordinates. Please
// check GL_TEXTURE_RECTANGLE.
layout(location = 6) flat varying vec2 vTextureOffsetY; // Offset of the y plane into the texture atlas.
layout(location = 7) flat varying vec2 vTextureOffsetU; // Offset of the u plane into the texture atlas.
layout(location = 8) flat varying vec2 vTextureOffsetV; // Offset of the v plane into the texture atlas.
layout(location = 9) flat varying vec2 vTextureSizeY;   // Size of the y plane in the texture atlas.
layout(location = 10) flat varying vec2 vTextureSizeUv;  // Size of the u and v planes in the texture atlas.
layout(location = 11) flat varying vec2 vStretchSize;
layout(location = 12) flat varying vec2 vHalfTexelY;     // Normalized length of the half of a Y texel.
layout(location = 13) flat varying vec2 vHalfTexelUv;    // Normalized length of the half of u and v texels.

#ifdef WR_FEATURE_TRANSFORM
layout(location = 14) varying vec3 vLocalPos;
#else
layout(location = 14) varying vec2 vLocalPos;
#endif
