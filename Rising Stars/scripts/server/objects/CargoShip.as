import regions.regions;
import saving;
import cargo;
import systems;

tidy class CargoShipScript {
	int moveId = -1;

	CargoShipScript() {
	}

	void makeMesh(CargoShip& obj) {
		MeshDesc shipMesh;
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin("Freighter");

		if(skin !is null) {
			@shipMesh.model = skin.model;
			@shipMesh.material = skin.material;
		}
		else {
			@shipMesh.model = model::Fighter;
			@shipMesh.material = material::Ship10;
		}

		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(obj, shipMesh);
	}

	void load(CargoShip& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		msg >> cast<Savable>(obj.Mover);
		@obj.Origin = msg.readObject();
		@obj.Target = msg.readObject();

		msg >> moveId;

		msg >> obj.CargoType;
		msg >> obj.Cargo;

		//Create the graphics
		makeMesh(obj);
	}

	void save(CargoShip& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;

		msg << moveId;
		
		msg << obj.CargoType;
		msg << obj.Cargo;
	}

	void init(CargoShip& ship) {
		ship.maxAcceleration = (2.5 + 8.409 * config::NEW_MOVEMENT) * 6.3636;
	}

	void postInit(CargoShip& ship) {
		makeMesh(ship);
	}

	bool onOwnerChange(CargoShip& ship, Empire@ prevOwner) {
		regionOwnerChange(ship, prevOwner);
		return false;
	}

	void destroy(CargoShip& ship) {
		leaveRegion(ship);
	}
	
	double tick(CargoShip& ship, double time) {
		Object@ target = ship.Target;
		ship.moverTick(time);
		updateRegion(ship);
	
		if(target is null) {
			if(ship.region !is null) {
				Region@ lookIn = ship.region;
				
				uint plCount = lookIn.planetCount;
				if(plCount > 0) {
					Planet@ targ = lookIn.planets[randomi(0, plCount-1)];
					if(targ !is null && targ.owner is ship.owner) {
						@target = targ;
						@ship.Target = targ;
						ship.moveTo(target, moveId, enterOrbit=false);
					}
				}

				if(target is null) {
					SystemDesc@ desc = getSystem(lookIn.SystemId);
					if(desc.adjacent.length > 0)
						@lookIn = getSystem(desc.adjacent[randomi(0, desc.adjacent.length-1)]).object;
						
					uint plCount = lookIn.planetCount;
					if(plCount > 0) {
						Planet@ targ = lookIn.planets[randomi(0, plCount-1)];
						if(targ !is null && targ.owner is ship.owner) {
							@target = targ;
							@ship.Target = targ;
							ship.moveTo(target, moveId, enterOrbit=false);
						}
					}
				}
				
				if(target !is null)
					return 0.2;
			}

			// If all else fails, pick a random planet.
			Planet@ targ = ship.owner.planetList[randomi(0, ship.owner.planetCount-1)];
			if(targ !is null) {
				@target = targ; 
				@ship.Target = targ;
				ship.moveTo(target, moveId, enterOrbit=false);
			}
			return 0.2;
		}

		if(!target.owner.valid || ship.owner !is target.owner) {
			@target = null;
			@ship.Target = null;
		}
		else if(ship.position.distanceTo(target.position) <= (ship.radius + target.radius + 0.1) || ship.moveTo(target, moveId, enterOrbit=false)) {
			if(target.isPlanet) {
				target.addCargo(ship.CargoType, ship.Cargo);
			}
			ship.destroy();
		}
		return 0.2;
	}

	void damage(CargoShip& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0) {
			if(ship.owner !is null && ship.owner.valid && ship.owner.GloryMode == 2) {
				ship.owner.Glory -= 1;
			}
			if(evt.obj !is null) {
				if(evt.obj.owner !is null && evt.obj.owner.valid) {
					evt.obj.owner.addCargo(ship.CargoType, ship.Cargo * 0.2f);
				}
			}
			ship.destroy();
		}
	}

	void syncInitial(const CargoShip& ship, Message& msg) {
		ship.writeMover(msg);
		msg << ship.CargoType;
		msg << ship.Cargo;
	}

	void syncDetailed(const CargoShip& ship, Message& msg) {
		ship.writeMover(msg);
		msg << ship.CargoType;
		msg << ship.Cargo;
	}

	bool syncDelta(const CargoShip& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		return used;
	}
};
