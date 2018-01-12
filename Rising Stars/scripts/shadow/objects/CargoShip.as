import regions.regions;

tidy class CargoShipScript {
	CargoShipScript() {
	}

	void makeMesh(CargoShip& obj) {
		MeshDesc shipMesh;
		const Shipset@ ss = obj.owner.shipset;
		const ShipSkin@ skin;
		if(ss !is null)
			@skin = ss.getSkin("CargoShip");

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

	void init(CargoShip& ship) {
		//Create the graphics
		makeMesh(ship);
	}

	void destroy(CargoShip& ship) {
		leaveRegion(ship);
	}

	bool onOwnerChange(CargoShip& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}
	
	double tick(CargoShip& ship, double time) {
		updateRegion(ship);
		ship.moverTick(time);
		return 0.2;
	}

	void syncInitial(CargoShip& ship, Message& msg) {
		ship.readMover(msg);
		msg >> ship.CargoType;
		msg >> ship.Cargo;
	}

	void syncDetailed(CargoShip& ship, Message& msg, double tDiff) {
		ship.readMover(msg);
		msg >> ship.CargoType;
		msg >> ship.Cargo;
	}

	void syncDelta(CargoShip& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
	}
};

