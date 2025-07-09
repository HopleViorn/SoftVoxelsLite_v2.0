/*
====================================================================================================

    Copyright (C) 2023 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.com/copyright-license

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/


vec3 readLPV(ivec3 index) {
    return clamp16F(texelFetch(shadowcolor1, getVoxelPixel(index), 0).rgb);
}
vec3 readLPVOffset(ivec3 mid, ivec3 index) {
    //bool occupied   = getVoxelOccupancy(index);
    //bool midOccupied = getVoxelOccupancy(mid);
    return clamp16F(texelFetch(shadowcolor1, getVoxelPixel(index), 0).rgb);
}

/*
    LPV Interpolation based on Magnificient by Jessie
*/

vec3 getLight(vec3 lpvPosition) {
        lpvPosition      += fract(cameraPosition);
        lpvPosition      += -vec3(0.5,0.5,0.5);
	vec3 lpvPositionFloor = floor(lpvPosition);
	vec3 lpvPositionFloorP1 = lpvPositionFloor + 1.0;

	vec3 x = round(lpvPosition);
    bvec3 xEqual = bvec3(x.x == lpvPositionFloor.x, x.y == lpvPositionFloor.y, x.z == lpvPositionFloor.z);

	vec3 letters[8] = vec3[](
		x,
		vec3(xEqual.x ? lpvPositionFloorP1.x : lpvPositionFloor.x, x.y, x.z),
		vec3(x.x, xEqual.y ? lpvPositionFloorP1.y : lpvPositionFloor.y, x.z),
		vec3(x.x, x.y, xEqual.z ? lpvPositionFloorP1.z : lpvPositionFloor.z),
		vec3(xEqual.x ? lpvPositionFloorP1.x : lpvPositionFloor.x, x.y, xEqual.z ? lpvPositionFloorP1.z : lpvPositionFloor.z),
		vec3(xEqual.x ? lpvPositionFloorP1.x : lpvPositionFloor.x, xEqual.y ? lpvPositionFloorP1.y : lpvPositionFloor.y, x.z),
		vec3(x.x, xEqual.y ? lpvPositionFloorP1.y : lpvPositionFloor.y, xEqual.z ? lpvPositionFloorP1.z : lpvPositionFloor.z),
		vec3(xEqual.x ? lpvPositionFloorP1.x : lpvPositionFloor.x, xEqual.y ? lpvPositionFloorP1.y : lpvPositionFloor.y, xEqual.z ? lpvPositionFloorP1.z : lpvPositionFloor.z)
	);

	bool isLetter[8] = bool[](
		true,
		false,
		false,
		false,
		false,
		false,
		false,
		false
	);

	if(!getVoxelOccupancyScene(letters[1])) {
		isLetter[1] = true;
		if(!getVoxelOccupancyScene(letters[4])) {
			isLetter[4] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
		if(!getVoxelOccupancyScene(letters[5])) {
			isLetter[5] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
	}

	if(!getVoxelOccupancyScene(letters[2])) {
		isLetter[2] = true;
		if(!getVoxelOccupancyScene(letters[5])) {
			isLetter[5] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
		if(!getVoxelOccupancyScene(letters[6])) {
			isLetter[6] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
	}

	if(!getVoxelOccupancyScene(letters[3])) {
		isLetter[3] = true;
		if(!getVoxelOccupancyScene(letters[6])) {
			isLetter[6] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
		if(!getVoxelOccupancyScene(letters[4])) {
			isLetter[4] = true;
			if(!getVoxelOccupancyScene(letters[7])) {
				isLetter[7] = true;
			}
		}
	}

	vec3 lightInterpolated = vec3(0.0);
	for(int n = 0; n < 8; ++n) {
		if(isLetter[n]) {
			vec3 weights = saturate(1.0 - abs(lpvPosition - letters[n]));
			float weight = weights.x * weights.y * weights.z;
			lightInterpolated += readLPV(sceneToVoxelIndexNoCam(letters[n])) * weight;
		}
	}

	return !outsideVoxelVolume(sceneToVoxelIndexNoCam(lpvPosition)) ? lightInterpolated : vec3(0.0);
}