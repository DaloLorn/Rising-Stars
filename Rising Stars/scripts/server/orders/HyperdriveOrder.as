import orders.Order;
import resources;
import attributes;
import ftl;
import ABEM_data;
import notifications;

tidy class HyperdriveOrder : Order {
	vec3d destination;
	quaterniond facing;
	double charge = 0.0;
	int cost = 0;
	int moveId = -1;
	bool isInstant;
	Region@ origin;

	HyperdriveOrder(vec3d pos, bool IsInstant = false) {
		destination = pos;
		isInstant = IsInstant;
	}

	HyperdriveOrder(SaveFile& msg) {
		Order::load(msg);
		msg >> destination;
		msg >> facing;
		msg >> moveId;
		msg >> charge;
		msg >> cost;
		msg >> isInstant;
		msg >> origin;
	}

	void save(SaveFile& msg) override {
		Order::save(msg);
		msg << destination;
		msg << facing;
		msg << moveId;
		msg << charge;
		msg << cost;
		msg << isInstant;
		msg << origin;
	}

	OrderType get_type() override {
		return OT_Hyperdrive;
	}

	string get_name() override {
		return "Hyperdrifting";
	}

	bool cancel(Object& obj) override {
		//Cannot cancel while already ftling
		if(charge < 0.0)
			return false;

		//Refund a part of the ftl cost
		if(cost > 0) {
			if(obj.owner.HyperdriveNeedCharge == 0 || isInstant)
				obj.owner.modFTLStored(cost);
			else {
				double chargeTime = HYPERDRIVE_CHARGE_TIME;
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

		bool isSuppressed = isFTLSuppressed(obj);
		if(isSuppressed)
			time *= 0.5; // Slow the charge rate.

		//Pay for the FTL
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null && ship.delayFTL && charge >= 0) {
			if(charge > 0)
				charge = 0.001;
			return OS_BLOCKING;
		}
		if(charge == 0) {
			@origin = getRegion(obj.position);
			int scale = 1;
			if(ship !is null) {
				scale = ship.blueprint.design.size;
				if(ship.group !is null)
					scale *= ship.group.objectCount;
			}

			double dist = obj.position.distanceTo(destination);
			if(isInstant)
				cost = hyperdriveInstantCost(ship, destination);
			else
				cost = hyperdriveCost(ship, destination);

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
			
			if(obj.owner.HyperdriveNeedCharge != 0)
				playParticleSystem("FTLCharge", vec3d(), quaterniond(), obj.radius * 4.0, obj);
		}

		//Wait for the facing to complete
		if(charge > 0.0) {
			bool isFacing = obj.rotateTo(facing, moveId);

			double chargeTime = HYPERDRIVE_CHARGE_TIME;
			if(obj.owner.HyperdriveNeedCharge == 0 || isInstant)
				chargeTime = 0.0;

			//Charge up the hyperdrive for a while first
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

		//Do actual hyperdriving
		double speed = hyperdriveSpeed(obj);
		if(isSuppressed)
			speed *= 0.5;
		bool wasMoving = moveId != -1;
		bool arrived = obj.FTLTo(destination, speed, moveId);
		if(!wasMoving) {
			obj.idleAllSupports();
			//Order supports to ftl
			uint cnt = obj.supportCount;
			for(uint i = 0; i < cnt; ++i) {
				Object@ support = obj.supportShip[i];
				support.FTLTo(destination + (support.position - obj.position), speed);
			}
			
			playParticleSystem("FTLEnter", obj.position, obj.rotation, obj.radius * 4.0, obj.visibleMask);
		}
		else {
			if(speed != obj.ftlSpeed) {
				obj.ftlSpeed = speed;
				uint cnt = obj.supportCount;
				for(uint i = 0; i < cnt; ++i) {
					Object@ support = obj.supportShip[i];
					support.ftlSpeed = speed;
				}
			}
		}

		if(arrived) {
			//Flag ship as no longer in ftl
			if(ship !is null) {
				ship.blueprint.clearTracking(ship);
				ship.isFTLing = false;
			}

			//Clear tracking on arrival
			uint cnt = obj.supportCount;
			for(uint i = 0; i < cnt; ++i) {
				Ship@ support = cast<Ship>(obj.supportShip[i]);
				support.FTLTo(destination + (support.position - obj.position), speed);
				support.blueprint.clearTracking(support);
			}

			//Set rotation on arrival
			obj.setRotation(facing);
			return OS_COMPLETED;
		}
		else {
			//Check for dropping out of hyperdrive
			Region@ reg = getRegion(obj.position);
			if(reg !is null && obj.owner !is null) {
				bool shouldDrop = reg.BlockFTLMask & obj.owner.mask != 0 ||
					(reg !is origin && reg.SuppressFTLMask & obj.owner.mask != 0);
				
				if(shouldDrop) {
					obj.FTLDrop();
					uint cnt = obj.supportCount;
					for(uint i = 0; i < cnt; ++i) {
						Object@ support = obj.supportShip[i];
						if(support !is null)
							support.FTLDrop();
					}

					if(obj.orderCount == 1)
						obj.addMoveOrder(destination, true);
					return OS_COMPLETED;
				}
			}
			return OS_BLOCKING;
		}
	}
};
