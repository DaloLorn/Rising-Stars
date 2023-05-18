#include "include/map.as"

enum MapSetting {
	M_SystemCount,
	M_SystemSpacing,
	M_Flatten,
};

#section server
class ContrailBucket {
	array<ContrailSystem@> systems;
}

class ContrailSystem {
	double angle;
	double distance;
	vec3d position;

	ContrailSystem(double angle, double distance, vec3d position) {
		this.angle = angle;
		this.distance = distance;
		this.position = position;
	}
}
#section all

class ContrailMap : Map {
	ContrailMap() {
		super();

		name = locale::CONTRAIL_MAP;
		description = locale::CONTRAIL_MAP_DESC;

		sortIndex = -149;

		color = 0xd252ffff; // TODO
		// icon = "maps/Dumbbell/dumbbell.png"; // TODO
	}

#section client
	void makeSettings() {
		Number(locale::SYSTEM_COUNT, M_SystemCount, DEFAULT_SYSTEM_COUNT, decimals=0, step=10, min=10, halfWidth=true);
		Number(locale::SYSTEM_SPACING, M_SystemSpacing, DEFAULT_SPACING, decimals=0, step=1000, min=MIN_SPACING, halfWidth=true);
		Toggle(locale::FLATTEN, M_Flatten, false, halfWidth=true);
	}

#section server
	void placeSystems() {
		uint systemCount = uint(getSetting(M_SystemCount, DEFAULT_SYSTEM_COUNT));
		double spacing = modSpacing(getSetting(M_SystemSpacing, DEFAULT_SPACING));
		bool flatten = getSetting(M_Flatten, 0.0) != 0.0;
		bool mirror = false;

		uint players = estPlayerCount;
		if (players == 0) {
			players = 1;
		}

		// Pick angle
		double galaxyAngle = randomd(3.14, -3.14);
		// Generate unit vector in direction
		vec3d galaxyDirection = unitVector(galaxyAngle);
		// We'll place a 'spine' of 1/4 of the total system count along the
		// galaxy angle in a line, so half of this is the approximate radius
		// The spine will use slightly more than 100% spacing, so we get a good
		// length (as other systems fill in the gaps the spacing should trend
		// back to specified).
		double galaxyRadius = (systemCount / 8.0) * spacing * 1.3;

		double elevationTiltAngle = randomd(3.14, -3.14) * 0.3;

		// Place black hole at one end
		const SystemType@ blackHoleType = getSystemType("CoreBlackhole");
		if (blackHoleType is null) {
			print("FATAL: Black hole type does not exist");
			return;
		}
		vec3d blackHolePosition = galaxyDirection * (galaxyRadius * -1);
		addSystem(blackHolePosition + elevation(-0.1, elevationTiltAngle, flatten, galaxyRadius), sysType=blackHoleType.id);

		int nebulaType = -1;
		{
			const SystemType@ _nebulaType = getSystemType("ContrailNebula");
			if (_nebulaType is null) {
				print("Contrail Nebula type does not exist");
			} else {
				nebulaType = _nebulaType.id;
			}
		}

		// Initalise buckets to track placed stars so we can avoid placing stars
		// too close together
		// We group stars into buckets based on the distance along the spine
		// so we don't have to waste CPU time comparing star positions that are
		// guaranteed to be far enough away
		array<ContrailBucket@> buckets;
		uint bucketCount = 3 + (systemCount / 15);
		for (uint i = 0; i < bucketCount; ++i) {
			buckets.insertLast(ContrailBucket());
		}

		double maxAngleDelta = 1.1 + randomd(0.05, -0.05);
		double baseDistance = 5.0 * spacing;
		// max cross axis (next to black hole) follows from sin(a) = opposite/hypotenuse
		// since the baseDistance is effectively the hypotenuse and the maxAngleDelta
		// is the angle opposite the cross axis distance
		double maximumCrossAxis = baseDistance * sin(maxAngleDelta);

		// Place spine
		double angleDelta = 0.0;
		uint spineCount = systemCount / 4;
		uint possibleHomeworldsGiven = 0;

		for (uint i = 1; i < spineCount; ++i) {
			double fraction = double(i) / double(spineCount);
			double distance = baseDistance + (i * spacing * 1.3);
			// Keep angle within 1.4 radians each direction but let it vary a
			// bit along each star in the spine
			angleDelta = fractionToAngleFactor(fraction, maximumCrossAxis, distance) * randomd(-maxAngleDelta, maxAngleDelta) * 0.25;
			double angle = galaxyAngle + angleDelta;
			vec3d position = blackHolePosition + (unitVector(angle) * distance) + elevation(fraction, elevationTiltAngle, flatten, galaxyRadius);
			SystemData@ sys = addSystem(position);
			if (fraction < 0.1 && randomd(0.0, 1.0) > 0.3) {
				sys.systemType = nebulaType;
			}

			if ((double(i) / double(spineCount)) >= (double(possibleHomeworldsGiven) / double(players))) {
				// Suggest homeworlds equally spaced along the spine
				// as the number of estimated players
				possibleHomeworldsGiven += 1;
				addPossibleHomeworld(sys);
			}

			ContrailBucket@ b = buckets[bucket(bucketCount, distance, galaxyRadius)];
			b.systems.insertLast(ContrailSystem(angle, distance, position));
		}

		// Place all the other systems to fill out the spine
		angleDelta = 0.0;
		for (uint i = spineCount; i < systemCount; ++i) {
			bool foundSpot = false;
			uint failures = 0;
			double baseFraction = double(i - spineCount) / double(systemCount - spineCount);
			while (!foundSpot) {
				// bias the fraction towards 0
				double fraction = pow(baseFraction, 4.5);
				// Calculate distance based off fraction to align systems within the existing spine
				double distance = baseDistance + ((galaxyRadius * (2.0 + randomd(0.01, -0.01))) * fraction);
				angleDelta = fractionToAngleFactor(fraction, maximumCrossAxis, distance) * randomd(-maxAngleDelta, maxAngleDelta);
				double angle = galaxyAngle + angleDelta;
				vec3d position = blackHolePosition + (unitVector(angle) * distance) + elevation(fraction, elevationTiltAngle, flatten, galaxyRadius);
				uint bClosest = bucket(bucketCount, distance, galaxyRadius);
				bool tooClose = false;
				for (uint b = uint(max(int(bClosest) - 1, 0)); b <= min(bClosest + 1, bucketCount - 1) && !tooClose; ++b) {
					ContrailBucket@ bucket = buckets[b];
					for (uint s = 0; s < bucket.systems.length && !tooClose; ++s) {
						ContrailSystem@ sPos = bucket.systems[s];
						if (sPos.position.distanceTo(position) < (spacing * 0.9)) {
							tooClose = true;
						}
					}
				}
				if (tooClose) {
					failures += 1;
					if (failures % 4 == 3) {
						// reroll position completely if struggling
						baseFraction = randomd(0.0, 1.0);
					}
				} else {
					foundSpot = true;
					SystemData@ sys = addSystem(position);
					if (fraction < 0.1 && randomd(0.0, 1.0) > 0.3) {
						sys.systemType = nebulaType;
					}
					ContrailBucket@ b = buckets[bucket(bucketCount, distance, galaxyRadius)];
					b.systems.insertLast(ContrailSystem(angle, distance, position));
				}
			}
		}
	}

	vec3d unitVector(double angle) {
		return vec3d(cos(angle), 0, sin(angle));
	}

	vec3d elevation(double fraction, double elevationTiltAngle, bool flatten, double galaxyRadius) {
		if (flatten) {
			return vec3d(0.0, 0.0, 0.0);
		}
		double fractionPastHalfWayPoint = fraction - 0.5;
		// Given an angle and a fraction (adjacent), we can calculate the
		// opposite as tan(a) * adjacen
		double opposite = tan(elevationTiltAngle) * fractionPastHalfWayPoint;
		return vec3d(0.0, opposite * (galaxyRadius * 0.6), 0.0);
	}

	double clamp(double angle, double maxAngle) {
		return max(min(angle, maxAngle), -maxAngle);
	}

	// Keep factor in 0-1 range but reduce exponentially as fraction increases
	// to reduce variation of stars furthest away from black hole
	// This creates the triangle-like shape as the max angle delta tends to 0
	double fractionToAngleFactor(double fraction, double maximumCrossAxis, double distance) {
		// pick angle such that cross axis scales linearly from max to 0
		// again we can use the rule that sin(a) = opposite/hypotenuse
		double scaledMaximumCrossAxis = (1 - fraction) * maximumCrossAxis;
		return asin(scaledMaximumCrossAxis / distance);
		// This works much better than lerping the angle directly because trying
		// to just lerp the angle has to counteract increased distance from the
		// black hole also leading to increased cross axis at the projected point
	}

	uint bucket(uint buckets, double distance, double galaxyRadius) {
		double fraction = (distance / (2.0 * galaxyRadius));
		double fractionalBucket = double(buckets) * fraction;
		return max(min(uint(floor(fractionalBucket)), buckets - 1), 0);
	}
#section all
}
