import regions.regions;
from designs import getDesignMesh;

tidy class ShipScript {
	float commandUsed = 0.f;

	float timer = 1.f;
	double shieldMitCap = 0;
	double shieldMitBoost = 0;
	double shieldCores = 0;
	float mass = 0.f;
	float massBonus = 0.f;
	
	bool hasGraphics = false;

	bool get_isStation(Ship& ship) {
		return ship.blueprint.design.hasTag(ST_Station);
	}

	void occasional_tick(Ship& ship, float time) {
		if(ship.hasLeaderAI)
			ship.updateFleetStrength();
	}

	double getBaseMitigation(Ship& ship) {
		if(shieldCores <= 0)
			return 0;
		double shieldMitBase = ship.blueprint.getEfficiencySum(SV_ShieldMitBase) / shieldCores;
		if(ship.blueprint.hasTagActive(ST_ShieldHardener))
			shieldMitBase *= 1 + ship.blueprint.getEfficiencyFactor(SV_HardenerMitigationFactor);
		return shieldMitBase;
	}

	double getMaximumMitigationBoost(Ship& ship) {
		if(shieldCores <= 0)
			return 0;
		double shieldMitBase = getBaseMitigation(ship);
		return (shieldMitCap / shieldCores) - shieldMitBase;
	}

	double getMitigationRate(Ship& ship) {
		if(shieldCores <= 0)
			return 0;
		double shieldMitRate = ship.blueprint.getEfficiencySum(SV_ShieldMitRate) / shieldCores;
		if(ship.blueprint.hasTagActive(ST_ShieldHardener))
			shieldMitRate /= 1 + ship.blueprint.getEfficiencyFactor(SV_HardenerMitigationFactor) / 5.0;
		return shieldMitRate;
	}

	double getMitigationDecay(Ship& ship) {
		if(shieldCores <= 0)
			return 0;
		return (ship.blueprint.design.total(SV_ShieldMitDecay) / ship.blueprint.design.total(SV_ShieldCores)) / (ship.blueprint.getEfficiencyFactor(SV_ShieldMitDecay));
	}

	double get_mitigation(Ship& ship) {
		double shieldMitBase = getBaseMitigation(ship);
		if(shieldCores <= 0)
			return 0;
		double mitigation = min(shieldMitBase + shieldMitBoost, shieldMitCap / shieldCores) + ship.blueprint.getEfficiencySum(SV_BonusMitigation);
		return mitigation;
	}

	float getMass() {
		return max(mass + massBonus, 0.01f);
	}

	float getBaseMass() {
		return max(mass, 0.01f);
	}

	double tick(Ship& ship, double time) {
		if(updateRegion(ship)) {
			auto@ node = ship.getNode();
			if(node !is null)
				node.hintParentObject(ship.region);
		}
		
		ship.moverTick(time);
		if(ship.hasLeaderAI)
			ship.leaderTick(time);

		timer += float(time);
		if(timer >= 1.f) {
			occasional_tick(ship, timer);
			timer = 0.f;
		}
		return 0.2;
	}

	void destroy(Ship& ship) {
		if(ship.inCombat) {
			auto@ region = ship.region;
			if(region !is null) {
				uint debris = uint(log(ship.blueprint.design.size) / log(2.0));
				if(debris > 0)
					region.addShipDebris(ship.position, debris);
			}
		}
		
		leaveRegion(ship);
		if(ship.hasLeaderAI)
			ship.leaderDestroy();
	}

	bool onOwnerChange(Ship& ship, Empire@ prevOwner) {
		regionOwnerChange(ship, prevOwner);
		if(ship.hasLeaderAI)
			ship.leaderChangeOwner(prevOwner, ship.owner);
		return false;
	}
	
	void createGraphics(Ship& ship, const Design@ dsg) {
		if(dsg is null)
			return;
		MeshDesc shipMesh;
		getDesignMesh(ship.owner, ship.blueprint.design, shipMesh);
		shipMesh.memorable = ship.memorable;
		bindMesh(ship, shipMesh);
		hasGraphics = true;
		if(ship.hasLeaderAI) {
			auto@ node = ship.getNode();
			if(node !is null)
				node.animInvis = true;
		}
	}

	void syncInitial(Ship& ship, Message& msg) {
		//Find hull
		uint hullID = msg.readSmall();

		const Hull@ hull = getHullDefinition(hullID);

		//Sync data
		ship.blueprint.recvDetails(ship, msg);

		if(msg.readBit()) {
			ship.activateLeaderAI();
			ship.leaderInit();
			ship.readLeaderAI(msg);
			auto@ node = ship.getNode();
			if(node !is null)
				node.animInvis = true;
		}
		else {
			ship.activateSupportAI();
			ship.readSupportAI(msg);
		}

		ship.readMover(msg);
		if(msg.readBit()) {
			msg >> ship.MaxEnergy;
			ship.Energy = msg.readFixed(0.f, ship.MaxEnergy, 16);
		}
		if(msg.readBit()) {
			msg >> ship.MaxSupply;
			ship.Supply = msg.readFixed(0.f, ship.MaxSupply, 16);
		}
		if(msg.readBit()) {
			msg >> ship.MaxShield;
			ship.Shield = msg.readFixed(0.f, ship.MaxShield, 16);
		}

		if(msg.readBit()) {
			ship.activateAbilities();
			ship.readAbilities(msg);
		}

		if(msg.readBit()) {
			ship.activateStatuses();
			ship.readStatuses(msg);
		}

		if(msg.readBit()) {
			ship.activateCargo();
			ship.readCargo(msg);
		}

		if(msg.readBit()) {
			ship.activateConstruction();
			ship.readConstruction(msg);
		}

		if(msg.readBit()) {
			ship.activateOrbit();
			ship.readOrbit(msg);
		}

		msg >> mass;
		msg >> massBonus;
		
		createGraphics(ship, ship.blueprint.design);
	}

	void syncDetailed(Ship& ship, Message& msg, double tDiff) {
		ship.readMover(msg);
		if(ship.hasLeaderAI)
			ship.readLeaderAI(msg);
		else
			ship.readSupportAI(msg);
		ship.blueprint.recvDetails(ship, msg);
		updateStats(ship);
		msg >> ship.Energy;
		msg >> ship.MaxEnergy;
		msg >> ship.Supply;
		msg >> ship.MaxSupply;
		msg >> ship.Shield;
		msg >> ship.MaxShield;
		ship.isFTLing = msg.readBit();
		ship.inCombat = msg.readBit();
		if(ship.hasAbilities)
			ship.readAbilities(msg);
		if(ship.hasStatuses)
			ship.readStatuses(msg);
		if(msg.readBit()) {
			if(!ship.hasCargo)
				ship.activateCargo();
			ship.readCargo(msg);
		}
		if(msg.readBit()) {
			if(!ship.hasOrbit)
				ship.activateOrbit();
			ship.readOrbit(msg);
		}
		if(msg.readBit()) {
			if(!ship.hasConstruction)
				ship.activateConstruction();
			ship.readConstruction(msg);
		}
		msg >> shieldCores;
		msg >> shieldMitCap;
		msg >> shieldMitBoost;
		msg >> mass;
		msg >> massBonus;
	}

	void updateStats(Ship& ship) {
		const Design@ dsg = ship.blueprint.design;
		if(dsg is null)
			return;
		
		ship.DPS = ship.blueprint.getEfficiencySum(SV_DPS);
		ship.MaxDPS = dsg.total(SV_DPS);
		ship.MaxSupply = dsg.total(SV_SupplyCapacity);
		ship.MaxShield = dsg.total(SV_ShieldCapacity);
		commandUsed = dsg.variable(ShV_REQUIRES_Command);
	}

	void syncDelta(Ship& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
		if(msg.readBit()) {
			ship.blueprint.recvDelta(ship, msg);
			if(!hasGraphics)
				createGraphics(ship, ship.blueprint.design);
			updateStats(ship);
		}
		
		if(msg.readBit())
			ship.Shield = msg.readFixed(0.f, ship.MaxShield, 16);
		
		if(msg.readBit()) {
			if(ship.hasLeaderAI)
				ship.readLeaderAIDelta(msg);
			else
				ship.readSupportAIDelta(msg);
		}
		if(ship.hasAbilities) {
			if(msg.readBit())
				ship.readAbilityDelta(msg);
		}
		if(ship.hasStatuses) {
			if(msg.readBit())
				ship.readStatusDelta(msg);
		}
		if(ship.hasLeaderAI) {
			if(msg.readBit()) {
				if(!ship.hasCargo)
					ship.activateCargo();
				ship.readCargoDelta(msg);
			}
		}
		if(msg.readBit()) {
			if(msg.readBit())
				msg >> ship.Energy;
			else
				ship.Energy = 0;
			if(msg.readBit())
				msg >> ship.Supply;
			else
				ship.Supply = 0;
			
			ship.isFTLing = msg.readBit();
			ship.inCombat = msg.readBit();
		}
		if(msg.readBit()) {
			if(!ship.hasOrbit)
				ship.activateOrbit();
			ship.readOrbitDelta(msg);
		}
		if(ship.hasLeaderAI) {
			if(msg.readBit()) {
				if(!ship.hasConstruction)
					ship.activateConstruction();
				ship.readConstructionDelta(msg);
			}
		}
		if(msg.readBit()) {
			msg >> shieldCores;
			msg >> shieldMitCap;
			msg >> shieldMitBoost;
		}
		if(msg.readBit()) {
			msg >> mass;
			msg >> massBonus;
		}
	}
};
