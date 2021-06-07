#section server-side
from regions.regions import getRegion;
#section all
import orbitals;

// BEGIN NON-MIT CODE - DOF (Scaling)
// Adjusting for increased scaling
const double HYPERDRIVE_COST = 0.02;
// END NON-MIT CODE 
const double HYPERDRIVE_START_COST = 25.0;
const double HYPERDRIVE_CHARGE_TIME = 15.0;

bool canHyperdrive(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null || !ship.hasLeaderAI)
		return false;
	if(isFTLBlocked(ship))
		return false;
	return ship.blueprint.hasTagActive(ST_Hyperdrive);
}

double hyperdriveSpeed(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.getEfficiencySum(SV_HyperdriveSpeed);
}

double hyperdriveMaxSpeed(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.design.total(SV_HyperdriveSpeed);
}

int hyperdriveCost(Object& obj, const vec3d& position) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0;
	auto@ dsg = ship.blueprint.design;
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	int result = ceil((log(dsg.size) * (ship.getMass()*0.5/dsg.size) * sqrt(position.distanceTo(obj.position)) * HYPERDRIVE_COST + HYPERDRIVE_START_COST + owner.HyperdriveStartCostMod)* owner.FTLCostFactor);
	if(result < 0)
		result = INT_MAX;
	return result;
}

int hyperdriveCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i) {
		if(!canHyperdrive(objects[i]))
			continue;
		cost += hyperdriveCost(objects[i], destination);
	}
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

int hyperdriveInstantCost(Object& obj, const vec3d& position) {
	if(obj.owner is null)
		return 0;
	int result = hyperdriveCost(obj, position) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int hyperdriveInstantCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i) {
		if(!canHyperdrive(objects[i]))
			continue;
		cost += hyperdriveInstantCost(objects[i], destination);
	}
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

double hyperdriveRange(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0.0;
	int scale = ship.blueprint.design.size;
	return hyperdriveRange(obj, scale, playerEmpire.FTLStored);
}

double hyperdriveRange(Object& obj, int scale, int stored) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return INFINITY;
	double result = sqr(max(double(stored) - (HYPERDRIVE_START_COST - owner.HyperdriveStartCostMod) * owner.FTLCostFactor, 0.0) / (log(double(scale)) * HYPERDRIVE_COST * owner.FTLCostFactor));
	if(result < 0)
		result = 0.0;
	return result;
}

double hyperdriveInstantRange(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0.0;
	int scale = ship.blueprint.design.size;
	return hyperdriveInstantRange(obj, scale, playerEmpire.FTLStored);
}

double hyperdriveInstantRange(Object& obj, int scale, int stored) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return INFINITY;
	if(owner is null)
		return 0.0;
	double result = sqr(max(double(stored) - (HYPERDRIVE_START_COST - owner.HyperdriveStartCostMod) * owner.FTLCostFactor * owner.InstantFTLFactor, 0.0) / (log(double(scale)) * HYPERDRIVE_COST * owner.FTLCostFactor * owner.InstantFTLFactor));
	if(result < 0)
		result = 0.0;
	return result;
}

bool canHyperdriveTo(Object& obj, const vec3d& pos) {
	return !isFTLBlocked(obj, pos);
}

// BEGIN NON-MIT CODE - DOF (Scaling)
// Adjusting for increased scaling
const double FLING_BEACON_RANGE = 250000.0;
// END NON-MIT CODE 
const double FLING_BEACON_RANGE_SQ = sqr(FLING_BEACON_RANGE);
const double FLING_COST = 8.0;
const double FLING_CHARGE_TIME = 15.0;
const double FLING_TIME = 15.0;

bool canFling(Object& obj) {
	if(isFTLBlocked(obj))
		return false;
	if(!obj.hasLeaderAI)
		return false;
	if(obj.isShip) {
		return true;
	}
	else {
		if(obj.isOrbital) {
			if(obj.owner.isFlingBeacon(obj))
				return false;
			Orbital@ orb = cast<Orbital>(obj);
			auto@ core = getOrbitalModule(orb.coreModule);
			return core is null || core.canFling;
		}
		if(obj.isPlanet)
			return true;
		return false;
	}
}

bool canFlingTo(Object& obj, const vec3d& pos) {
	return !isFTLBlocked(obj, pos);
}

double flingSpeed(Object& obj, const vec3d& pos) {
	return obj.position.distanceTo(pos) / FLING_TIME;
}

int flingCost(Object& obj, vec3d position) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	bool freeFTL = reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0;
	if(freeFTL && !obj.isPlanet)
		return 0;
	int result = INFINITY;
	if(obj.isShip) {
		Ship@ ship = cast<Ship>(obj);
		auto@ dsg = ship.blueprint.design;
		int scale = dsg.size;
		double massFactor = ship.getMass() * 0.3/dsg.size;
		double flingCostFactor = dsg.total(SV_FlingCostMult);

		double scaleFactor;
		if(dsg.hasTag(ST_Station))
			scaleFactor = pow(double(scale), 0.75);
		else
			scaleFactor = sqrt(double(scale));

		result = ceil(FLING_COST * scaleFactor * massFactor * flingCostFactor * owner.FTLCostFactor * owner.FTLThrustFactor / 100);
	}
	else {
		if(obj.isOrbital)
			result = ceil(FLING_COST * cast<Orbital>(obj).mass * 0.03 * owner.FTLCostFactor * owner.FTLThrustFactor / 100);
		else if(obj.isPlanet) {
			double modifier = 1;
			if(freeFTL) modifier = 0.25; // Planets only receive a serious discount from free FTL effects.
			result = ceil(FLING_COST * obj.radius * 30.0 * owner.FTLCostFactor * owner.FTLThrustFactor / 100 * modifier / 4);
		}
	}
	if(result < 0)
		result = INT_MAX;
	return result;
}

int flingInstantCost(Object& obj, vec3d position) {
	if(obj.owner is null)
		return 0;
	int result = flingCost(obj, position) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int flingCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i)
		cost += flingCost(objects[i], destination);
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

int flingInstantCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i)
		cost += flingInstantCost(objects[i], destination);
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

double flingRange(Object& obj) {
	if(flingCost(obj, obj.position) > obj.owner.FTLStored)
		return 0.0;
	return INFINITY;
}

double flingInstantRange(Object& obj) {
	if(flingInstantCost(obj, obj.position) > obj.owner.FTLStored)
		return 0.0;
	return INFINITY;
}

const double SLIPSTREAM_CHARGE_TIME = 15.0;
const double SLIPSTREAM_LIFETIME = 10.0 * 60.0;

bool canSlipstream(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null || !ship.hasLeaderAI)
		return false;
	if(isFTLBlocked(ship))
		return false;
	return ship.blueprint.hasTagActive(ST_Slipstream);
}

int slipstreamCost(Object& obj, int scale, double distance) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	Ship@ ship = cast<Ship>(obj);
	double baseCost = ship.blueprint.design.total(SV_SlipstreamCost);
	double optDist = ship.blueprint.design.total(SV_SlipstreamOptimalDistance);
	int result;
	if(distance < optDist)
		result = baseCost * obj.owner.FTLCostFactor;
	else result = baseCost * ceil(distance / optDist) * obj.owner.FTLCostFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int slipstreamInstantCost(Object& obj, int scale, double distance) {
	if(obj.owner is null)
		return 0;
	int result = slipstreamCost(obj, scale, distance) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

double slipstreamRange(Object& obj, int scale, int stored) {
	Ship@ ship = cast<Ship>(obj);

	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return INFINITY;

	double baseCost = ship.blueprint.design.total(SV_SlipstreamCost);
	double optDist = ship.blueprint.design.total(SV_SlipstreamOptimalDistance);

	if(stored < baseCost)
		return 0.0;
	double result = floor(double(stored) / baseCost / obj.owner.FTLCostFactor) * optDist;
	if(result < 0)
		result = 0.0;
	return result;
}

double slipstreamInstantRange(Object& obj, int scale, int stored) {
	if(obj.owner is null)
		return 0;
	double result = slipstreamRange(obj, scale, stored) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = 0.0;
	return result;
}

double slipstreamLifetime(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.getEfficiencyFactor(SV_SlipstreamDuration) * ship.blueprint.design.total(SV_SlipstreamDuration);
}

double slipstreamInstantLifetime(Object& obj) {
	if(obj.owner is null)
		return 0;
	return slipstreamLifetime(obj) / (obj.owner.InstantFTLFactor/2);
}

void slipstreamModifyPosition(Object& obj, vec3d& position) {
	double radius = slipstreamInaccuracy(obj, position);

	vec2d offset = random2d(radius);
	position += vec3d(offset.x, randomd(-radius * 0.2, radius * 0.2), offset.y);
}

void slipstreamInstantModifyPosition(Object& obj, vec3d& position) {
	double radius = slipstreamInstantInaccuracy(obj, position);

	vec2d offset = random2d(radius);
	position += vec3d(offset.x, randomd(-radius * 0.2, radius * 0.2), offset.y);
}

double slipstreamInaccuracy(Object& obj, const vec3d& position) {
	double dist = obj.position.distanceTo(position);
	return dist * 0.01;
}

double slipstreamInstantInaccuracy(Object& obj, const vec3d& position) {
	return slipstreamInaccuracy(obj, position) * obj.owner.InstantFTLFactor / 2;
}

bool canSlipstreamTo(Object& obj, const vec3d& point) {
	auto@ reg = obj.region;
	if(reg !is null) {
		if(reg.BlockFTLMask & obj.owner.mask != 0)
			return false;
	}
	@reg = getRegion(point);
	if(reg !is null) {
		if(reg.BlockFTLMask & obj.owner.mask != 0)
			return false;
	}
	return true;
}

bool isFTLBlocked(Object& obj, const vec3d& point) {
	auto@ reg = getRegion(point);
	if(reg is null)
		return false;
	if(obj.owner is null)
		return false;
	if(reg.BlockFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

bool isFTLBlocked(Object& obj) {
	auto@ reg = obj.region;
	if(reg is null)
		return false;
	if(obj.owner is null)
		return false;
	if(reg.BlockFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

bool isFTLSuppressed(Object& obj, const vec3d& point) {
	auto@ reg = getRegion(point);
	if(reg is null)
		return false;
	if(obj.owner is null)
		return false;
	if(reg.SuppressFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

bool isFTLSuppressed(Object& obj) {
	auto@ reg = obj.region;
	if(reg is null)
		return false;
	if(obj.owner is null)
		return false;
	if(reg.SuppressFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

// BEGIN NON-MIT CODE - DOF (Scaling)
// Adjusting for increased scaling
const double JUMPDRIVE_COST = 0.015;
// END NON-MIT CODE 
const double JUMPDRIVE_START_COST = 50.0;
const double JUMPDRIVE_CHARGE_TIME = 25.0;

bool canJumpdrive(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null || !ship.hasLeaderAI)
		return false;
	if(isFTLBlocked(ship))
		return false;
	return ship.blueprint.hasTagActive(ST_Jumpdrive);
}

int jumpdriveCost(Object& obj, const vec3d& fromPos, const vec3d& position) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0;
	auto@ dsg = ship.blueprint.design;
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	double dist = position.distanceTo(fromPos);
	dist = min(dist, jumpdriveRange(obj));

	int result = ceil(log(dsg.size) * (ship.getMass()*0.5/dsg.size) * sqrt(dist) * JUMPDRIVE_COST + JUMPDRIVE_START_COST) * owner.FTLCostFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int jumpdriveInstantCost(Object& obj, const vec3d& fromPos, const vec3d& position) {
	if(obj.owner is null)
		return 0;
	int result = jumpdriveCost(obj, fromPos, position) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int jumpdriveCost(Object& obj, const vec3d& position) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0;
	auto@ dsg = ship.blueprint.design;
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	double dist = position.distanceTo(obj.position);
	dist = min(dist, jumpdriveRange(obj));

	int result = ceil(log(dsg.size) * (ship.getMass()*0.5/dsg.size) * sqrt(dist) * JUMPDRIVE_COST + JUMPDRIVE_START_COST) * owner.FTLCostFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int jumpdriveInstantCost(Object& obj, const vec3d& position) {
	if(obj.owner is null)
		return 0;
	int result = jumpdriveCost(obj, position) * obj.owner.InstantFTLFactor;
	if(result < 0)
		result = INT_MAX;
	return result;
}

int jumpdriveCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i) {
		if(!canJumpdrive(objects[i]))
			continue;
		cost += jumpdriveCost(objects[i], destination);
	}
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

int jumpdriveInstantCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i) {
		if(!canJumpdrive(objects[i]))
			continue;
		cost += jumpdriveInstantCost(objects[i], destination);
	}
	if(cost < 0)
		cost = INT_MAX;
	return cost;
}

double jumpdriveRange(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.design.total(SV_JumpRange);
}

double jumpdriveRange(Object& obj, int scale, int stored) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.design.total(SV_JumpRange);
}

double jumpdriveInstantRange(Object& obj) {
	if(obj.owner is null)
		return 0;
	return jumpdriveRange(obj) / (obj.owner.InstantFTLFactor/2);
}

bool canJumpdriveTo(Object& obj, const vec3d& pos) {
	return !isFTLBlocked(obj, pos);
}

double jumpdriveChargeTime(Object& obj, const vec3d& pos) {
	return min(max(4.0, JUMPDRIVE_CHARGE_TIME * (pos.distanceTo(obj.position) / jumpdriveRange(obj))), JUMPDRIVE_CHARGE_TIME);
}

const double FLUX_CD_RANGE = 6000.0;

bool isFluxableDestination(Object& obj, Region@ reg, Region@ curReg) {
	if(curReg is null)
		return false;
	if(reg is null)
		return false;
	if(reg is curReg)
		return false;

	if(reg.VisionMask & obj.owner.mask == 0)
		return false;
	if(reg.BlockFTLMask & obj.owner.mask != 0)
		return false;
	return true;
}

bool isFluxableObject(Object& obj) {
	if(!obj.hasMover || obj.maxAcceleration < 2)
		return false;
	if(isFTLBlocked(obj))
		return false;
	return true;
}

bool isFluxCharging(Object& obj) {
	if(obj.hasMover && obj.fluxCooldown > 0)
		return true;
	return false;
}

bool canFluxTo(Object& obj, const vec3d& pos) {
	if(obj.owner.HasFlux == 0)
		return false;

	auto@ reg = getRegion(pos);
	auto@ curReg = obj.region;

	if(!isFluxableDestination(obj, reg, curReg))
		return false;

	if(!isFluxableObject(obj))
		return false;
	if(isFluxCharging(obj))
		return false;
	return true;
}

vec3d getFluxDest(Object& obj, const vec3d& pos) {
	auto@ reg = getRegion(pos);
	auto@ curReg = obj.region;

	vec3d dir;
	if(curReg !is null)
		dir = (obj.position - curReg.position) / curReg.radius;
	else
		dir = random3d(0.6);

	if(reg !is null)
		return reg.position + (dir * reg.radius);
	else
		return pos;
}

double calculateFluxCooldown(Object& obj, const vec3d& fluxPos) {
	if(obj.hasLeaderAI && obj.hasMover) {
		Region@ reg = obj.region;
		Empire@ owner = obj.owner;
		if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
			return 0;
		double dist = fluxPos.distanceTo(obj.position);
		double cd = dist / FLUX_CD_RANGE * owner.FTLThrustFactor / 100;
		return cd;
	}
	return INFINITY;
}

double instantRefluxCost(Object& obj) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(obj.owner is null || !isFluxableObject(obj) || !isFluxCharging(obj))
		return 0.0;
	if(reg !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0.0;
	return obj.fluxCooldown * owner.FTLThrustFactor * owner.InstantFTLFactor;
}

#section server-side
void performInstantReflux(Object& obj) {
	Empire@ owner = obj.owner;
	if(owner is null || !isFluxableObject(obj) || !isFluxCharging(obj))
		return;
	double cost = instantRefluxCost(obj);
	if(cost > owner.FTLStored)
		return;
	owner.consumeFTL(cost, false, record=false);
	obj.modFluxCooldown(-obj.fluxCooldown);
}

void commitFlux(Object& obj, const vec3d& pos) {
	vec3d fluxPos = getFluxDest(obj, pos);
	Region@ destRegion = getRegion(pos);

	if(isFTLSuppressed(obj, pos)) {
		vec3d offsetFromCenter = destRegion.position - fluxPos;
		double multiplier = offsetFromCenter.lengthSQ / (destRegion.radius * destRegion.radius);
		fluxPos += offsetFromCenter * multiplier;
	}

#section server
	playParticleSystem("FluxJump", obj.position, obj.rotation, obj.radius * 4.0, obj.visibleMask);
	playParticleSystem("FluxJump", fluxPos, obj.rotation, obj.radius * 4.0, obj.visibleMask);
#section server-side

	if(obj.hasLeaderAI && obj.hasMover) {
		obj.modFluxCooldown(calculateFluxCooldown(obj, fluxPos));
	}

	if(obj.hasLeaderAI) {
		obj.teleportTo(fluxPos, movementPart=true);
	}
	else {
		obj.position = fluxPos;
		obj.velocity = vec3d();
		obj.acceleration = vec3d();
	}
}
#section all
