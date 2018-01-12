import cargo;
import saving;

tidy class Cargo : CargoStorage, Component_Cargo {
	bool hasGlobalAccess = false;

	void getCargo() {
		yield(this);
	}

	double get_cargoCapacity() {
		return capacity;
	}

	double get_cargoStored() {
		return filled;
	}

	double getCargoStored(uint typeId) {
		auto@ type = getCargoType(typeId);
		if(type is null)
			return -1.0;
		return get(type);
	}

	uint get_cargoTypes() {
		if(types is null)
			return 0;
		return types.length;
	}

	uint get_cargoType(uint index) {
		if(types is null)
			return uint(-1);
		if(index >= types.length)
			return uint(-1);
		return types[index].id;
	}

	void modCargoStorage(double amount) {
		capacity += amount;
		delta = true;
	}

	void addCargo(Object& obj, uint typeId, double amount) {
		auto@ type = getCargoType(typeId);
		if(type is null)
			return;
		// Short-circuit the cargo addition system if we can store this in the global pool.
		if(type.isGlobal && type.autostore && (obj.isPlanet || hasGlobalAccess) && obj.owner !is null && obj.owner.valid) {
			obj.owner.addCargo(typeId, amount);
			return;
		}
		add(type, amount, obj.isAsteroid);
	}

	void setGlobalCargoAccess(Object& obj, bool canStore) {
		hasGlobalAccess = canStore;
		if(canStore) { // Immediately dump all autostorable resources into the global pool.
			if(types is null) return;

			for(uint i = 0; i < types.length; i++) {
				auto@ type = types[i];
				if(type.isGlobal && type.autostore && obj.owner !is null && obj.owner.valid) {
					obj.owner.addCargo(type.id, amounts[i]);
					remove(type);
					i--; // This type will be removed, altering the length of the array. To compensate, we need to push the loop back.
				}
			}
		}
	}

	void removeCargo(uint typeId, double amount) {
		auto@ type = getCargoType(typeId);
		if(type is null)
			return;
		consume(type, amount, true);
	}

	double consumeCargo(uint typeId, double amount, bool partial = false) {
		auto@ type = getCargoType(typeId);
		if(type is null)
			return 0.0;
		return consume(type, amount, partial);
	}

	void transferAllCargoTo(Object@ other) {
		if(types is null || !other.hasCargo)
			return;
		double cap = other.cargoCapacity - other.cargoStored;
		while(cap > 0 && types.length > 0) {
			auto@ type = types[0];
			double cons = min(cap / type.storageSize, amounts[0]);
			cons = consume(type, cons, partial=true);
			if(cons > 0) {
				other.addCargo(type.id, cons);
				cap -= cons;
			}
			else {
				break;
			}
		}
	}

	void transferAllCargoTo(Empire@ other) {
		if(types is null)
			return;
		while(types.length > 0) {
			auto@ type = types[0];
			double cons = amounts[0];
			cons = consume(type, cons, partial=true);
			if(cons > 0) {
				other.addCargo(type.id, cons);
			}
			else {
				break;
			}
		}
	}

	void transferPrimaryCargoTo(Object@ other, double rate) {
		if(types is null || types.length == 0)
			return;
		auto@ type = types[0];
		double realAmount = rate / type.storageSize;
		realAmount = consume(type, realAmount, partial=true);
		if(realAmount > 0)
			other.addCargo(type.id, realAmount);
	}

	void transferPrimaryCargoTo(Empire@ other, double rate) {
		if(types is null || types.length == 0)
			return;
		auto@ type = types[0];
		double realAmount = rate / type.storageSize;
		realAmount = consume(type, realAmount, partial=true);
		if(realAmount > 0)
			other.addCargo(type.id, realAmount);
	}

	void transferCargoTo(uint typeId, Object@ other) {
		transferCargoTo(typeId, other, 1000000000);
	}

	void transferCargoTo(uint typeId, Object@ other, double rate) {
		if(types is null || types.length == 0)
			return;
		auto@ type = getCargoType(typeId);
		if(type is null)
			return;

		double amt = min(rate, getCargoStored(typeId));
		if(amt > 0) {
			double cap = other.cargoCapacity - other.cargoStored;
			double cons = min(cap / type.storageSize, amt);
			cons = consume(type, cons, partial=true);
			if(cons > 0) {
				other.addCargo(type.id, cons);
				cap -= cons;
			}
		}
	}

	void transferCargoTo(uint typeId, Empire@ other) {
		transferCargoTo(typeId, other, 1000000000);
	}

	void transferCargoTo(uint typeId, Empire@ other, double rate) {
		if(types is null || types.length == 0)
			return;
		auto@ type = getCargoType(typeId);
		if(type is null)
			return;

		double amt = min(rate, getCargoStored(typeId));
		if(amt > 0) {
			double cons = amt;
			cons = consume(type, cons, partial=true);
			if(cons > 0) {
				other.addCargo(type.id, cons);
			}
		}
	}

	void writeCargo(Message& msg) {
		msg << this;
	}

	void save(SaveFile& file) override {
		CargoStorage::save(file);
		file.writeBit(hasGlobalAccess);
	}

	void load(SaveFile& file) override {
		CargoStorage::load(file);
		hasGlobalAccess = file.readBit();
	}

	bool writeCargoDelta(Message& msg) {
		if(!delta)
			return false;
		msg.write1();
		writeCargo(msg);
		delta = false;
		return true;
	}
};
