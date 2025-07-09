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

vec3 decodeVoxelTint(vec4 voxel) {
    vec4 albedo = vec4(unpack2x8(voxel.x), unpack2x8(voxel.y));

    return unpack4x4(voxel.a).x > 0.5 ? albedo.rgb : vec3(1.0);
}


bool IntersectAABox(vec3 rayPos, vec3 invRayDir, vec3 minBounds, vec3 maxBounds, inout float dist) {
	// This will not intersect backfaces, or in other words this will not intersect the box from inside it.
	// You should use the version that rakes in radii instead of min & max bounds if you can, as it will be faster.
	vec3 minBoundsDist = (minBounds - rayPos) * invRayDir;
	vec3 maxBoundsDist = (maxBounds - rayPos) * invRayDir;

	vec3 minDists = min(minBoundsDist, maxBoundsDist);
	vec3 maxDists = max(minBoundsDist, maxBoundsDist);

	float maxOfMin = maxOf(minDists); // distance to frontfaces
	float minOfMax = minOf(maxDists); // distance to backfaces

	dist = maxOfMin; // Distance to intersection (if the box was intersected)

	// Check for intersection & return whether or not we intersected
	return dist > 0.0 && maxOfMin <= minOfMax;
}
bool IntersectAABox(vec3 rayPos, vec3 invRayDir, vec3 minBounds, vec3 maxBounds, out float dist, inout vec3 hitNormal) {
	// This will not intersect backfaces, or in other words this will not intersect the box from inside it.
	// You should use the version that rakes in radii instead of min & max bounds if you can, as it will be faster.
	vec3 minBoundsDist = (minBounds - rayPos) * invRayDir;
	vec3 maxBoundsDist = (maxBounds - rayPos) * invRayDir;

	vec3 minDists = min(minBoundsDist, maxBoundsDist);
	vec3 maxDists = max(minBoundsDist, maxBoundsDist);

	float maxOfMin = maxOf(minDists); // distance to frontfaces
	float minOfMax = minOf(maxDists); // distance to backfaces

	dist = maxOfMin; // Distance to intersection (if the box was intersected)

	// Determine normal
	if (dist == minDists.x) {
		hitNormal = vec3(invRayDir.x < 0.0 ? 1.0 : -1.0, 0.0, 0.0);
	} else if (dist == minDists.y) {
		hitNormal = vec3(0.0, invRayDir.y < 0.0 ? 1.0 : -1.0, 0.0);
	} else {
		hitNormal = vec3(0.0, 0.0, invRayDir.z < 0.0 ? 1.0 : -1.0);
	}

	// Check for intersection & return whether or not we intersected
	return dist > 0.0 && maxOfMin <= minOfMax;
}
/*
bool IntersectAABox(vec3 rayPos, vec3 invRayDir, vec3 boxRadii, out float dist, inout vec3 hitNormal) {
	// This one will not intersect backfaces, or in other words this will not intersect the box from inside it.
	vec3 scaledRayPos = rayPos * invRayDir;
	vec3 minDists = -boxRadii * abs(invRayDir) - scaledRayPos; // distance to each frontfacing plane
	vec3 maxDists =  boxRadii * abs(invRayDir) - scaledRayPos; // distance to each backfacing plane

	float maxOfMin = maxOf(minDists); // distance to the frontfaces
	float minOfMax = minOf(maxDists); // distance to the backfaces

	dist = maxOfMin; // Distance to intersection (if the box was intersected)

	// Determine normal
	if (dist == minDists.x) {
		hitNormal = vec3(invRayDir.x < 0.0 ? 1.0 : -1.0, 0.0, 0.0);
	} else if (dist == minDists.y) {
		hitNormal = vec3(0.0, invRayDir.y < 0.0 ? 1.0 : -1.0, 0.0);
	} else {
		hitNormal = vec3(0.0, 0.0, invRayDir.z < 0.0 ? 1.0 : -1.0);
	}

	// Check for intersection & return whether or not we intersected
	return dist > 0.0 && maxOfMin <= minOfMax;
}*/

bool intersectVoxel(vec3 relOrigin, vec3 dir, inout float hitDist) {
    vec3 invDir     = 1.0 / dir;

    vec3 minBounds  = vec3(0);
    vec3 maxBounds  = vec3(1);
    bool intersected = IntersectAABox(relOrigin, invDir, minBounds, maxBounds, hitDist);

    return intersected;
}
bool intersectVoxel(vec3 relOrigin, vec3 dir, inout float hitDist, inout vec3 hitNormal) {
    vec3 invDir     = 1.0 / dir;

    vec3 minBounds  = vec3(0);
    vec3 maxBounds  = vec3(1);
    bool intersected = IntersectAABox(relOrigin, invDir, minBounds, maxBounds, hitDist, hitNormal);

    return intersected;
}

bool IntersectSphere(vec3 relOrigin, vec3 dir, float radius, out float hitDist, inout vec3 hitNormal) {
	vec3 s0 = vec3(0.5, 0.45, 0.5); // Sphere center relative to voxel

    float a = dot(dir, dir);
    vec3 s0_r0 = relOrigin - s0;
    float b = 2.0 * dot(dir, s0_r0);
    float c = dot(s0_r0, s0_r0) - (radius * radius);

    if (b*b - 4.0*a*c < 0.0) {
        return false;
    }

    hitDist = (-b - sqrt((b*b) - 4.0*a*c))/(2.0*a);

    hitNormal = -normalizeSafe(s0_r0);

	return true;
}

// From VXPT by Zombye because typing this shit out is honestly taking too long and is boring kek
const vec3 StairBounds0[24][2] = vec3[24][2](
    // Stairs (straight)
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),

    // Stairs (outer corner)
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),

    // Stairs (inner corner)
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      1     ))
);
const vec3 StairBounds1[24][2] = vec3[24][2](
    // Stairs (straight)
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      0.5   )),
    vec3[2](vec3(0,      0.5,    0.5   ), vec3(1,      1,      1     )),
    vec3[2](vec3(0.5,    0.5,    0     ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(0.5,    1,      1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    0.5   )),
    vec3[2](vec3(0,      0,      0.5   ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0.5,    0,      0     ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(0.5,    0.5,    1     )),

    // Stairs (outer corner)
    vec3[2](vec3(0.5,    0.5,    0     ), vec3(1,      1,      0.5   )),
    vec3[2](vec3(0.5,    0.5,    0.5   ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(0.5,    1,      0.5   )),
    vec3[2](vec3(0,      0.5,    0.5   ), vec3(0.5,    1,      1     )),
    vec3[2](vec3(0.5,    0,      0     ), vec3(1,      0.5,    0.5   )),
    vec3[2](vec3(0.5,    0,      0.5   ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(0.5,    0.5,    0.5   )),
    vec3[2](vec3(0,      0,      0.5   ), vec3(0.5,    0.5,    1     )),

    // Stairs (inner corner)
    vec3[2](vec3(0,      0.5,    0     ), vec3(1,      1,      0.5   )),
    vec3[2](vec3(0,      0.5,    0.5   ), vec3(1,      1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(0.5,    1,      1     )),
    vec3[2](vec3(0,      0.5,    0     ), vec3(0.5,    1,      1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(1,      0.5,    0.5   )),
    vec3[2](vec3(0,      0,      0.5   ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(0.5,    0.5,    1     )),
    vec3[2](vec3(0,      0,      0     ), vec3(0.5,    0.5,    1     ))
);
const vec3 StairBounds2[8][2] = vec3[8][2](
    vec3[2](vec3(0.5,    0.5,    0.5   ), vec3(1,      1,      1     )),
    vec3[2](vec3(0.5,    0.5,    0     ), vec3(1,      1,      0.5   )),
    vec3[2](vec3(0.5,    0.5,    0     ), vec3(1,      1,      0.5   )),
    vec3[2](vec3(0.5,    0.5,    0.5   ), vec3(1,      1,      1     )),
    vec3[2](vec3(0.5,    0,      0.5   ), vec3(1,      0.5,    1     )),
    vec3[2](vec3(0.5,    0,      0     ), vec3(1,      0.5,    0.5   )),
    vec3[2](vec3(0.5,    0,      0     ), vec3(1,      0.5,    0.5   )),
    vec3[2](vec3(0.5,    0,      0.5   ), vec3(1,      0.5,    1     ))
);

bool IntersectStairs(int ID, vec3 rayPos, vec3 invRayDir, inout float dist, inout vec3 hitNormal) {
    int StairID     = ID - 60;
    int StairCornerID = ID - 76;

    vec3 Bounds0[2] = StairBounds0[StairID];
    vec3 Bounds1[2] = StairBounds1[StairID];

    bool intersected = IntersectAABox(rayPos, invRayDir, Bounds0[0], Bounds0[1], dist, hitNormal);

    float tempDist;
    vec3 tempNormal;

    if (IntersectAABox(rayPos, invRayDir, Bounds1[0], Bounds1[1], tempDist, tempNormal)) {
        if (!intersected || tempDist < dist) {
            dist = tempDist;
            hitNormal = tempNormal;
            intersected = true;
        }
    }

    if (StairCornerID >= 0) {
        vec3 Bounds2[2] = StairBounds2[StairCornerID];

        if (IntersectAABox(rayPos, invRayDir, Bounds2[0], Bounds2[1], tempDist, tempNormal)) {
            if (!intersected || tempDist < dist) {
                dist = tempDist;
                hitNormal = tempNormal;
                intersected = true;
            }
        }
    }

    return intersected;
}
bool intersectVoxel(vec3 relOrigin, vec3 dir, int ID, inout float hitDist, inout vec3 hitNormal) {
    vec3 invDir     = 1.0 / dir;

    vec3 minBounds  = vec3(0);
    vec3 maxBounds  = vec3(1);

    if (ID == 2) {
        return IntersectSphere(relOrigin, dir, 0.35, hitDist, hitNormal);
    } else if (ID == 4) {
        minBounds  = vec3(0.0, 0.0, 0.0);
        maxBounds  = vec3(1.0, 0.5, 1.0);
    } else if (ID == 5) {
        minBounds  = vec3(0.0, 0.5, 0.0);
        maxBounds  = vec3(1.0, 1.0, 1.0);
    } else if (ID == 8) {
        minBounds  = vec3(0.0, 0.0, 0.0);
        maxBounds  = vec3(1.0, 0.9375, 1.0);
    } else if (ID == 9) {
        minBounds  = vec3(0.06, 0.0, 0.06);
        maxBounds  = vec3(0.94, 1.0, 0.94);
    } else if (ID == 10) {      //torches
        minBounds  = vec3(0.4, 0.125, 0.4);
        maxBounds  = vec3(0.6, 0.625, 0.6);
    } else if (ID == 11) {      // Small Emitters
        minBounds  = vec3(0.35, 0.2, 0.35);
        maxBounds  = vec3(0.65, 0.6, 0.65);
    } else if (ID == 20) {      //End Rod Up-Down
        minBounds  = vec3(0.45, 0.05, 0.45);
        maxBounds  = vec3(0.55, 0.95, 0.55);
    } else if (ID == 21) {      //End Rod East-West
        minBounds  = vec3(0.05, 0.45, 0.45);
        maxBounds  = vec3(0.95, 0.55, 0.55);
    } else if (ID == 22) {      //End Rod North-South
        minBounds  = vec3(0.45, 0.45, 0.05);
        maxBounds  = vec3(0.55, 0.55, 0.95);
    } else if (ID == 23) {      // Trapdoor Bottom
        minBounds  = vec3(0.0, 0.0, 0.0);
        maxBounds  = vec3(1.0, 0.15, 1.0);
    } else if (ID == 24) {      // Door East Closed
        minBounds  = vec3(0.0, 0.0, 0.0);
        maxBounds  = vec3(0.15, 1.0, 1.0);
    } else if (ID == 25) {      // Door West Closed
        minBounds  = vec3(0.85, 0.0, 0.0);
        maxBounds  = vec3(1.0, 1.0, 1.0);
    } else if (ID == 26) {      // Door South Closed
        minBounds  = vec3(0.0, 0.0, 0.0);
        maxBounds  = vec3(1.0, 1.0, 0.15);
    } else if (ID == 27) {      // Door North Closed
        minBounds  = vec3(0.0, 0.0, 0.85);
        maxBounds  = vec3(1.0, 1.0, 1.0);
    } else if (ID == 28) {      // Trapdoor Top
        minBounds  = vec3(0.0, 0.85, 0.0);
        maxBounds  = vec3(1.0, 1.0, 1.0);
    } else if (ID >= 60 && ID <=83) {
        return IntersectStairs(ID, relOrigin, invDir, hitDist, hitNormal);
    } else {
        return true;
    }

    return IntersectAABox(relOrigin, invDir, minBounds, maxBounds, hitDist, hitNormal);
}


bool marchVoxel(vec3 pos, ivec3 index, vec3 dir, const int maxDistance, out vec3 hitPos, out vec3 hitNormal, out ivec3 hitIndex) {
    if (outsideVoxelVolume(index)) return false;

    ivec3 startIndex = index;

	vec3 nextT;
	vec3 deltaDist = 1.0 / abs(dir);
	ivec3 deltaSign;

    hitIndex = ivec3(-1);

	for (int axis = 0; axis < 3; ++axis) {
		if (dir[axis] < 0.0) {
			deltaSign[axis] = -1;
			nextT[axis] = (pos[axis] - index[axis]) * deltaDist[axis];
		} else if (dir[axis] > 0.0) {
			deltaSign[axis] = 1;
			nextT[axis] = (index[axis] - pos[axis]) * deltaDist[axis] + deltaDist[axis];
		} else {
			deltaSign[axis] = 0;
			nextT[axis] = uintBitsToFloat(0x7f800000u);// = infinity
		}
	}

	if (deltaSign.x == 0 && deltaSign.y == 0 && deltaSign.z == 0) { return false; }

	bool hit = false;
    int i       = 0;
	do {
        float hitDist;

		float minComp = minOf(nextT);
		if (nextT.x == minComp) {
			hitDist   = nextT.x;
			hitNormal = vec3(-deltaSign.x, 0.0, 0.0);

			index.x   += deltaSign.x;
			nextT.x += deltaDist.x;
		}
		if (nextT.y == minComp) {
			hitDist   = nextT.y;
			hitNormal = vec3(0.0, -deltaSign.y, 0.0);

			index.y   += deltaSign.y;
			nextT.y += deltaDist.y;
		}
		if (nextT.z == minComp) {
			hitDist   = nextT.z;
			hitNormal = vec3(0.0, 0.0, -deltaSign.z);

			index.z   += deltaSign.z;
			nextT.z += deltaDist.z;
		}

		if (outsideVoxelVolume(index)) break;

		hit = getVoxelOccupancy(index);

        if (hit) {
            hit     = intersectVoxel(pos - index, dir, hitDist, hitNormal);
            hitPos  = pos + hitDist * dir;
            hitIndex = index;
        }

	} while (++i < maxDistance && !hit);

    return hit;
}

bool marchVoxel(vec3 pos, ivec3 index, vec3 endPos, ivec3 endIndex, inout vec3 hitPos, inout vec3 hitNormal, out ivec3 hitIndex) {
    if (outsideVoxelVolume(index)) return false;
    //if (distance(index, endIndex) < 0.1) return false;

    vec3 dir    = normalize(endPos - pos);

    ivec3 startIndex = index;
    float endDistance = distance(index, endIndex) + 1.0;

	vec3 nextT;
	vec3 deltaDist = 1.0 / abs(dir);
	ivec3 deltaSign;

    hitIndex = ivec3(-1);

	for (int axis = 0; axis < 3; ++axis) {
		if (dir[axis] < 0.0) {
			deltaSign[axis] = -1;
			nextT[axis] = (pos[axis] - index[axis]) * deltaDist[axis];
		} else if (dir[axis] > 0.0) {
			deltaSign[axis] = 1;
			nextT[axis] = (index[axis] - pos[axis]) * deltaDist[axis] + deltaDist[axis];
		} else {
			deltaSign[axis] = 0;
			nextT[axis] = uintBitsToFloat(0x7f800000u);// = infinity
		}
	}

	if (deltaSign.x == 0 && deltaSign.y == 0 && deltaSign.z == 0) { return false; }

	bool hit = false;
    int i       = 0;
	do {
        float hitDist;

		float minComp = minOf(nextT);
		if (nextT.x == minComp) {
			hitDist   = nextT.x;
			hitNormal = vec3(-deltaSign.x, 0.0, 0.0);

			index.x   += deltaSign.x;
			nextT.x += deltaDist.x;
		}
		if (nextT.y == minComp) {
			hitDist   = nextT.y;
			hitNormal = vec3(0.0, -deltaSign.y, 0.0);

			index.y   += deltaSign.y;
			nextT.y += deltaDist.y;
		}
		if (nextT.z == minComp) {
			hitDist   = nextT.z;
			hitNormal = vec3(0.0, 0.0, -deltaSign.z);

			index.z   += deltaSign.z;
			nextT.z += deltaDist.z;
		}

		if (outsideVoxelVolume(index)) break;

        if (distance(startIndex, index) > endDistance) break;

        //if (index == startIndex) continue;

		hit = getVoxelOccupancy(index);

        if (hit) {
            hit     = intersectVoxel(pos - index, dir, hitDist, hitNormal);
            hitPos  = pos + hitDist * dir;
            hitIndex = index;
        }

	} while (++i < 64 && !hit);

    return hit;
}


ivec3 scaleIndex(ivec3 index, int targetLod) {
    vec3 x  = vec3(index) / float(targetLod);

    return ivec3(floor(x));
}

bool marchBVH(vec3 pos, ivec3 index, vec3 dir, out vec3 hitPos, out vec3 hitNormal, out ivec3 hitIndex, inout vec4 voxel, inout vec3 absorption) {
    if (outsideVoxelVolume(index)) return false;

    ivec3 deltaSign     = ivec3(sign(dir));

    if(all(equal(deltaSign, ivec3(0)))) return false;

    ivec3 positiveDir   = max(deltaSign, ivec3(0));
    ivec3 negativeDir   = min(deltaSign, ivec3(0));

    vec3 deltaT         = 1.0 / abs(dir);

    const int maxLevel  = OCTREE_LEVELS - 1;

    vec3 steps          = (index - pos) * deltaSign + positiveDir - 1;

    int level           = 0;

    while(level++ < maxLevel && !getVoxelOccupancy(index, level));

    --level;

    bool hit            = false;
    int iterations      = 0;

    do {
        float minT;
        bvec3 isMinComp;

        bool potentialHit   = false;
        int octreeIterations = 0;

        if (outsideVoxelVolume(index)) break;

        do {
            int size        = int(pow(2, level));
            ivec3 plane     = (scaleIndex(index, size) + positiveDir) * size;
            vec3 planeT     = abs(plane - pos) * deltaT;

            minT            = minOf(planeT);

            if (minT > 256.0) break;

            isMinComp       = bvec3(planeT.x == minT, planeT.y == minT, planeT.z == minT);

            ivec3 prevIndex = index;

            ivec3 stepsToNext = ivec3(minT * abs(dir) - steps + 0.5 * vec3(isMinComp));
                steps      += stepsToNext;
                index      += stepsToNext * deltaSign;

            if (outsideVoxelVolume(index)) break;

            int levelAbove  = level + 1;
            int sizeAbove   = int(pow(2, levelAbove));

            bool stepUp     = scaleIndex(prevIndex, sizeAbove) != scaleIndex(index, sizeAbove);
                level       = min(stepUp ? levelAbove : level, maxLevel);

            bool blocked    = getVoxelOccupancy(index, level, voxel);

            while (blocked && level > 0) {
                blocked     = getVoxelOccupancy(index, --level, voxel);
            }

            potentialHit    = blocked && level == 0;
        } while(++octreeIterations < 64 && !potentialHit);

        if (potentialHit) {
            hitNormal       = vec3(isMinComp) * -deltaSign;

            float hitDist   = minT;

            ivec2 voxelID   = unpack2x8I(voxel.z);

            #ifdef RPASS
            if (voxelID.y == 40) continue;
            #endif

            hit             = intersectVoxel(pos - index, dir, voxelID.y, hitDist, hitNormal);
            hitPos          = pos + hitDist * dir;

            hitIndex        = index;

            if (voxelID.y == 3 || voxelID.y == 40) {
                hit     = false;
                absorption *= decodeVoxelTint(voxel);
            }
        }

    } while (++iterations < 64 && !hit);

    return hit;
}

bool marchBVH(vec3 pos, ivec3 index, vec3 dir, out vec3 hitPos, out vec3 hitNormal, out ivec3 hitIndex, inout vec4 voxel, inout vec3 absorption, inout bool OutsideVolume) {
    if (outsideVoxelVolume(index)) {
        OutsideVolume = true;
        return false;
    }

    ivec3 deltaSign     = ivec3(sign(dir));

    if(all(equal(deltaSign, ivec3(0)))) return false;

    ivec3 positiveDir   = max(deltaSign, ivec3(0));
    ivec3 negativeDir   = min(deltaSign, ivec3(0));

    vec3 deltaT         = 1.0 / abs(dir);

    const int maxLevel  = OCTREE_LEVELS - 1;

    vec3 steps          = (index - pos) * deltaSign + positiveDir - 1;

    int level           = 0;

    while(level++ < maxLevel && !getVoxelOccupancy(index, level));

    --level;

    bool hit            = false;
    int iterations      = 0;

    do {
        float minT;
        bvec3 isMinComp;

        bool potentialHit   = false;
        int octreeIterations = 0;

        if (outsideVoxelVolume(index)) {
            OutsideVolume = iterations < 8;
            break;
        }

        do {
            int size        = int(pow(2, level));
            ivec3 plane     = (scaleIndex(index, size) + positiveDir) * size;
            vec3 planeT     = abs(plane - pos) * deltaT;

            minT            = minOf(planeT);

            if (minT > 256.0) break;

            isMinComp       = bvec3(planeT.x == minT, planeT.y == minT, planeT.z == minT);

            ivec3 prevIndex = index;

            ivec3 stepsToNext = ivec3(minT * abs(dir) - steps + 0.5 * vec3(isMinComp));
                steps      += stepsToNext;
                index      += stepsToNext * deltaSign;

            if (outsideVoxelVolume(index)) {
                OutsideVolume = octreeIterations < 4 && iterations < 8;
                break;
            }


            int levelAbove  = level + 1;
            int sizeAbove   = int(pow(2, levelAbove));

            bool stepUp     = scaleIndex(prevIndex, sizeAbove) != scaleIndex(index, sizeAbove);
                level       = min(stepUp ? levelAbove : level, maxLevel);

            bool blocked    = getVoxelOccupancy(index, level, voxel);

            while (blocked && level > 0) {
                blocked     = getVoxelOccupancy(index, --level, voxel);
            }

            potentialHit    = blocked && level == 0;
        } while(++octreeIterations < 64 && !potentialHit);

        if (potentialHit) {
            hitNormal       = vec3(isMinComp) * -deltaSign;

            float hitDist   = minT;

            ivec2 voxelID   = unpack2x8I(voxel.z);

            //if (voxelID.y == 2) continue;

            hit             = intersectVoxel(pos - index, dir, voxelID.y, hitDist, hitNormal);
            hitPos          = pos + hitDist * dir;

            hitIndex        = index;

            if (voxelID.y == 3 || voxelID.y == 40) {
                hit     = false;
                absorption *= decodeVoxelTint(voxel);
            }
        }

    } while (++iterations < 64 && !hit);

    return hit;
}