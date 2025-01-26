import orders.Order;
from regions.regions import getRegion;
import resources;
import attributes;
import system_flags;
import ftl;
import ABEM_data;
import notifications;

tidy class JumpdriveOrder : Order {
	vec3d destination;
	quaterniond facing;
	double charge = 0.0;
	double chargeTime = JUMPDRIVE_CHARGE_TIME;
	int cost = 0;
	int moveId = -1;
	int64 chargeParticlesId = 0;
	bool isInstant;

	JumpdriveOrder(vec3d pos, bool IsInstant = false) {
		destination = pos;
		isInstant = IsInstant;
	}

	JumpdriveOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> destination;
		msg >> facing;
		msg >> moveId;
		msg >> charge;
		msg >> cost;
		msg >> chargeTime;
		msg >> chargeParticlesId;
		msg >> isInstant;
	}

	void save(SaveFile& msg) override {
		Order::save(msg);
		msg << destination;
		msg << facing;
		msg << moveId;
		msg << charge;
		msg << cost;
		msg << chargeTime;
		msg << chargeParticlesId;
		msg << isInstant;
	}

	OrderType get_type() override {
		return OT_Jumpdrive;
	}

	string get_name() override {
		return "Jumping";
	}

	bool cancel(Object& obj) override {
		//Cannot cancel while already ftling
		if(charge < 0.0)
			return false;

		//Refund a part of the ftl cost
		if(cost > 0) {
			if(isInstant)
				obj.owner.modFTLStored(cost);
			else {
				double pct = 1.0 - min(charge / chargeTime, 1.0);
				double refund = cost * pct;
				obj.owner.modFTLStored(refund);
			}
			cost = 0;
		}

		//Mark ship as no longer FTLing
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null)
			ship.isFTLing = false;
		return true;
	}

	bool get_hasMovement() override {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) override {
		return destination;
	}

	OrderStatus tick(Object& obj, double time) override {
		if(!obj.hasMover)
			return OS_COMPLETED;

		bool suppressed = false, doubleSuppressed = false;
		if(isFTLSuppressed(obj))
			suppressed = true;
		if(isFTLSuppressed(obj, destination)) {
			doubleSuppressed = suppressed;
			suppressed = true;
		}

		if(suppressed)
			time *= 0.25;
		if(doubleSuppressed)
			time *= 0.5; // Add another +400% to the charge time, rather than the +1200% we'd get by multiplying with 0.25 again.

		//Pay for the FTL
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null && ship.delayFTL && charge >= 0) {
			if(charge > 0)
				charge = 0.001;
			return OS_BLOCKING;
		}
		if(charge == 0) {
			int scale = 1;
			if(ship !is null) {
				scale = ship.blueprint.design.size;
				if(ship.group !is null)
					scale *= ship.group.objectCount;
			}

			double dist = obj.position.distanceTo(destination);
			if(isInstant)
				cost = jumpdriveInstantCost(ship, destination);
			else
				cost = jumpdriveCost(ship, destination);

			if(cost > 0) {
				double consumed = obj.owner.consumeFTL(cost, false, record=false);
				if(consumed < cost)
					return OS_COMPLETED;
			}
			charge = 0.001;

			//Mark ship as FTLing
			if(ship !is null)
				ship.isFTLing = true;

			auto@ region = getRegion(destination);
			if(region !is obj.region && region !is null && obj.owner !is null && obj.owner.valid && obj.owner.major) {
				for(uint i = 0; i < getEmpireCount(); i++) {
					Empire@ other = getEmpire(i);
					if(other !is obj.owner && other.major && other.valid && region.getSystemFlag(other, EARLY_WARNING_FLAG) && other.isHostile(obj.owner))
						other.notifyWarEvent(region, WET_IncomingHostiles);
				}
			}

			//Calculate needed facing
			facing = quaterniond_fromVecToVec(vec3d_front(), destination - obj.position);
			obj.stopMoving();
			
			if(chargeParticlesId != 0)
				removeChargeParticles();
			chargeParticlesId = obj.id << 32 | 0x2 << 24 | randomi(0, 0xffffff);
			makePersistentParticles(ALL_PLAYERS, chargeParticlesId, obj, "JumpCharge", 4.0);
		}

		vec3d exitPos = destination;
		double distance = destination.distanceTo(obj.position);
		
		double range = 10000;
		if(isInstant) {
			range = 5000;
			if(ship !is null)
				range = jumpdriveInstantRange(obj);
		}
		else if(ship !is null) {
			range = jumpdriveRange(obj);
		}
		
		//Wait for the facing to complete
		if(charge > 0.0) {
			bool isFacing = obj.rotateTo(facing, moveId);

			// Minimum of 4.0 seconds, maximum of JUMPDRIVE_CHARGE_TIME, otherwise scaled by ratio of distance to range.  Halved when not in combat, including minimum.
			chargeTime = jumpdriveChargeTime(obj, destination);
			if(isInstant)
				chargeTime = 0;
			
			//Charge up the jumpdrive for a while first
			if(charge < chargeTime)
			{
				if(ship !is null)
				{
					if(!ship.inCombat)
						charge += time; // add once if it's not in combat
				}
				
				charge += time; // add once always - so ships that aren't in combat charge twice as fast.
			}

			if(!isFacing) {
				return OS_BLOCKING;
			}
			else {
				if(charge < chargeTime)
					return OS_BLOCKING;

				charge = -1.0;
				moveId = -1;

				if(cost > 0)
					obj.owner.modAttribute(EA_FTLEnergySpent, AC_Add, cost);
			}
		}

		//Teleport to destination
		auto@ destRegion = getRegion(destination);
		Region@ origin = getRegion(obj.position);

		if(distance > range && (destRegion is null || !destRegion.getSystemFlag(obj.owner, safetyFlag))) {
			//Random offset based on over-distance
			double minOffset = 0.0;
			double maxOffset = (distance - range) * 0.25;
			vec2d offset = random2d(randomd(minOffset, maxOffset));
			exitPos += vec3d(offset.x, 0, offset.y);

			//Random damage based on over-distance
			if(ship !is null) {
				int hits = min(int(floor((distance - range) / range * 25.0)), 100);
				for(int i = 0; i < hits; ++i) {
					DamageEvent dmg;
					dmg.damage = randomd(0.01, 0.03) * ship.blueprint.design.totalHP;
					@dmg.obj = obj;
					@dmg.target = obj;

					obj.damage(dmg, -1.0, random2d(1.0));
				}
			}
		}

		if(origin !is destRegion && isFTLSuppressed(obj, destination) && getRegion(exitPos) is destRegion) {
			vec3d offsetFromCenter = exitPos - destRegion.position;
			double multiplier = offsetFromCenter.length / destRegion.radius;
			exitPos = destRegion.position + offsetFromCenter / multiplier;
		}

		playParticleSystem("FTLEnter", obj.position, obj.rotation, obj.radius * 4.0, obj.visibleMask);
		playParticleSystem("FTLExit", exitPos, obj.rotation, obj.radius * 4.0, obj.visibleMask);
		removeChargeParticles();

		if(obj.hasOrbit && obj.inOrbit) {
			obj.stopOrbit();
			obj.position = exitPos;
			obj.remakeStandardOrbit();
		}
		else if(obj.hasLeaderAI) {
			obj.teleportTo(exitPos, true);
			int dummy = -1;
			obj.moveTo(exitPos, dummy);
		}

		//Flag ship as no longer in ftl
		if(ship !is null) {
			ship.blueprint.clearTracking(ship);
			ship.isFTLing = false;
		}
		obj.idleAllSupports();

		//Clear tracking on arrival
		uint cnt = obj.supportCount;
		for(uint i = 0; i < cnt; ++i) {
			Ship@ support = cast<Ship>(obj.supportShip[i]);
			support.blueprint.clearTracking(support);
		}

		//Set rotation on arrival
		obj.setRotation(facing);

		return OS_COMPLETED;
	}
	
	void removeChargeParticles()
	{
		if(chargeParticlesId != 0)
			removeGfxEffect(ALL_PLAYERS, chargeParticlesId);
		
		chargeParticlesId = 0;
	}
};

int safetyFlag = -1;
void init() {
	safetyFlag = getSystemFlag("JumpdriveSafety");
}
