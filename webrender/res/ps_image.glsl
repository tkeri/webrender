/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// If this is in WR_FEATURE_TEXTURE_RECT mode, the rect and size use non-normalized
// texture coordinates. Otherwise, it uses normalized texture coordinates. Please
// check GL_TEXTURE_RECTANGLE.
LAYOUT(6, flat varying vec2 vTextureOffset); // Offset of this image into the texture atlas.
LAYOUT(7, flat varying vec2 vTextureSize);   // Size of the image in the texture atlas.
LAYOUT(8, flat varying vec2 vTileSpacing);   // Amount of space between tiled instances of this image.
LAYOUT(9, flat varying vec4 vStRect);        // Rectangle of valid texture rect.

#ifdef WR_FEATURE_TRANSFORM
LAYOUT(10, varying vec3 vLocalPos);
#else
LAYOUT(10, varying vec2 vLocalPos);
#endif
LAYOUT(11, flat varying vec2 vStretchSize);
