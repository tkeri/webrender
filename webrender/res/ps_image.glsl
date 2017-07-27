/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// If this is in WR_FEATURE_TEXTURE_RECT mode, the rect and size use non-normalized
// texture coordinates. Otherwise, it uses normalized texture coordinates. Please
// check GL_TEXTURE_RECTANGLE.
layout(location = 6) flat varying vec2 vTextureOffset; // Offset of this image into the texture atlas.
layout(location = 7) flat varying vec2 vTextureSize;   // Size of the image in the texture atlas.
layout(location = 8) flat varying vec2 vTileSpacing;   // Amount of space between tiled instances of this image.
layout(location = 9) flat varying vec4 vStRect;        // Rectangle of valid texture rect.

#ifdef WR_FEATURE_TRANSFORM
layout(location = 10) varying vec3 vLocalPos;
#else
layout(location = 10) varying vec2 vLocalPos;
#endif
layout(location = 11) flat varying vec2 vStretchSize;
