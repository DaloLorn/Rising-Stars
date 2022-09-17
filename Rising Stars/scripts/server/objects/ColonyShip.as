from resources import MoneyType;
import regions.regions;
import saving;
import biomes;
import ftl;

const double COLONY_HYPERSPEED = 7500.0;

tidy class ColonyShipScript {
	int moveId;

	ColonyShipScript() {
		moveId = -1;
	}

	void load(ColonyShip& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		msg >> cast<Savable>(obj.Mover);
		@obj.Origin = msg.readObject();
		@obj.Target = msg.readObject();
		msg >> obj.CarriedPopulation;
		
		if(msg < SV_0033 && obj.Target !is null)
			obj.Target.modIncomingPop(obj.CarriedPopulation);

		msg >> moveId;
		msg >> obj.ColonyType;
	}

	void makeMesh(ColonyShip& obj) {
		MeshDesc shipMesh;
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin("Colonizer");

		if(obj.owner.ColonizerModel.length != 0) {
			@shipMesh.model = getModel(obj.owner.ColonizerModel);
			@shipMesh.material = getMaterial(obj.owner.ColonizerMaterial);
		}
		else if(skin !is null) {
			@shipMesh.model = skin.model;
			@shipMesh.material = skin.material;
		}
		else {
			@shipMesh.model = model::ColonyShip;
			@shipMesh.material = material::VolkurGenericPBR;
		}

		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(obj, shipMesh);
	}

	void postLoad(ColonyShip& obj) {
		//Create the graphics
		makeMesh(obj);
	}

	void save(ColonyShip& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;
		msg << obj.CarriedPopulation;

		msg << moveId;
		msg << obj.ColonyType;
	}

	void init(ColonyShip& ship) {
		//Create the graphics
		ship.sightRange = 0;
		makeMesh(ship);
	}

	void postInit(ColonyShip& ship) {
		if(ship.Target !is null)
			ship.Target.modIncomingPop(ship.CarriedPopulation);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
	}

	bool onOwnerChange(ColonyShip& ship, Empire@ prevOwner) {
		if(prevOwner !is null && prevOwner.valid)
			prevOwner.modMaintenance(-round(80.0 * ship.CarriedPopulation * prevOwner.ColonizerMaintFactor), MoT_Colonizers);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
		regionOwnerChange(ship, prevOwner);
		return false;
	}

	void destroy(ColonyShip& ship) {
		if(ship.owner !is null && ship.owner.valid && ship.CarriedPopulation > 0)
			ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
		if(ship.CarriedPopulation > 0 && ship.Origin !is null && ship.Target !is null) {
			if(ship.Origin.hasSurfaceComponent)
				ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
			ship.Target.modIncomingPop(-ship.CarriedPopulation);
		}
		leaveRegion(ship);
	}

	bool shouldFTL(ColonyShip& ship, int type) {
		if(ship.owner is null || !ship.owner.valid)
			return false;
		if(ship.region !is null && ship.region is ship.Target.region)
			return false; // Don't use FTL for in-system colonization!
		if(ship.region is null && ship.position.distanceTo(ship.Target.position) <= 1000)
			return false; // Too close, not worth FTLing!

		switch(type) {
			case CType_Hyperdrive:
				return !isFTLBlocked(ship) && ship.owner.consumeFTL(5.0 / (1.0 / ship.CarriedPopulation), partial=false) != 0.0;
			case CType_Fling:
				return !isFTLBlocked(ship) && ship.owner.getFlingBeacon(ship.position) !is null && ship.owner.consumeFTL(10.0 / (1.0 / ship.CarriedPopulation), partial=false) != 0.0;
			case CType_Jumpdrive:
				return !isFTLBlocked(ship) && !isFTLBlocked(ship, ship.Target.position) && ship.owner.consumeFTL(10.0 / (1.0 / ship.CarriedPopulation), partial=false) != 0.0;
			case CType_Flux:
				return false; // Handled by mover component
			case CType_Sublight:
				return false; // Non-FTL colonization
			case CType_BestFTL: // Pick fastest FTL available. Not currently used.
				if(shouldFTL(ship, CType_Fling)) {
					ship.ColonyType = CType_Fling;
					return true;
				} else if (ship.owner.JumpdriveConst > 0) {
					ship.ColonyType = CType_Jumpdrive;
					return shouldFTL(ship, CType_Jumpdrive);
				} else if (ship.owner.HyperdriveConst > 0) {
					ship.ColonyType = CType_Hyperdrive;
					return shouldFTL(ship, CType_Hyperdrive);
				}
		}
		return false;
	}

	void commitFTL(ColonyShip& ship, int type) {
		vec3d entryPoint = ship.Target.position;
		switch(type) {
			case CType_Hyperdrive:
				if(!ship.inFTL) {
					playParticleSystem("GateFlash", ship.position, ship.rotation, ship.radius, ship.visibleMask);
				}
				if(
					ship.Target.position.distanceTo(ship.position) <= (ship.radius + ship.Target.radius + 0.1)
					|| ship.FTLTo(ship.Target.position, COLONY_HYPERSPEED, moveId)
				) {
					ship.FTLDrop();
					playParticleSystem("GateFlash", ship.position, ship.rotation, ship.radius, ship.visibleMask);
				}
				break;
			case CType_Fling:
				if(!ship.inFTL) {
					playParticleSystem("GateFlash", ship.position, ship.rotation, ship.radius, ship.visibleMask);
				}
				if(
					ship.Target.position.distanceTo(ship.position) <= (ship.radius + ship.Target.radius + 0.1)
					|| ship.FTLTo(ship.Target.position, ship.Target.position.distanceTo(ship.position) / 15.0, moveId)
				) {
					ship.FTLDrop();
					playParticleSystem("GateFlash", ship.position, ship.rotation, ship.radius, ship.visibleMask);
				}
				break;
			case CType_Jumpdrive:
				playParticleSystem("GateFlash", ship.position, ship.rotation, ship.radius, ship.visibleMask);
				entryPoint += random3d(randomd(500 + ship.Target.radius, 500 + ship.Target.radius * 2));
				ship.position = entryPoint;
				ship.clearMovement();
				playParticleSystem("GateFlash", entryPoint, ship.rotation, ship.radius, ship.visibleMask);
				break;
		}
	}
	
	double tick(ColonyShip& ship, double time) {
		Object@ target = ship.Target;
	
		if(moveId == -1 && target is null)
			return 0.2;
		ship.moverTick(time);

		updateRegion(ship);

		if(target is null) {
			ship.destroy();
		}
		else if(ship.inFTL || shouldFTL(ship, ship.ColonyType)) {
			commitFTL(ship, ship.ColonyType);
		}
		else if(ship.position.distanceTo(target.position) <= (ship.radius + target.radius + 0.1) || ship.moveTo(target, moveId, enterOrbit=false)) {
			ship.destroy();
			if(target.isPlanet) {
				target.colonyShipArrival(ship.owner, ship.CarriedPopulation);
				if(ship.Origin !is null && ship.Origin.hasSurfaceComponent)
					ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
				if(ship.owner !is null && ship.owner.valid)
					ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation * ship.owner.ColonizerMaintFactor), MoT_Colonizers);
				ship.CarriedPopulation = 0;
			}
		}
		else if(target.isPlanet && ship.owner !is null && ship.owner.major && !target.isEmpireColonizing(ship.owner)) {
			if(ship.Origin !is null && ship.Origin.hasSurfaceComponent && ship.position.distanceTo(ship.Origin.position) < 3000.0)
				ship.destroy();
		}
		return 0.2;
	}

	void damage(ColonyShip& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0) {
			if(ship.owner !is null && ship.owner.valid && ship.owner.GloryMode == 2) {
				ship.owner.Glory -= 10 * ship.CarriedPopulation;
			}
			ship.destroy();
		}
	}

	void syncInitial(const ColonyShip& ship, Message& msg) {
		ship.writeMover(msg);
	}

	void syncDetailed(const ColonyShip& ship, Message& msg) {
		ship.writeMover(msg);
	}

	bool syncDelta(const ColonyShip& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		return used;
	}
};
