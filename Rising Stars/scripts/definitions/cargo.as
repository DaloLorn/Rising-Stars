#priority init 2001
import saving;
import attributes;

export CargoType;
export CargoStorage;
export hasDesignCosts;
export getCargoID;

export getCargoType, getCargoTypeCount;

tidy final class CargoType {
	uint id;
	string ident;
	string name;
	string description;
	Sprite icon;
	Color color;
	bool isGlobal = false;
	bool visible = false;
	bool autostore = false;

	double storageSize = 1.0;
	HexVariable variable = HexVariable(-1);
};

tidy class CargoStorage : Serializable, Savable {
	array<const CargoType@>@ types;
	array<double>@ amounts;
	array<bool>@ persistence;

	double capacity = 0.0;
	double filled = 0.0;

	bool delta = false;

	uint get_length() {
		return types.length;
	}

	int index(const CargoType@ type, bool create = true, bool persistent = false) {
		int ind = -1;
		if(types !is null)
			ind = types.find(type);
		if(ind == -1 && create) {
			if(types is null) {
				@types = array<const CargoType@>();
				@amounts = array<double>();
				@persistence = array<bool>();
			}
			ind = types.length;
			types.insertLast(type);
			amounts.insertLast(0.0);
			persistence.insertLast(persistent);
		}
		return ind;
	}

	void remove(const CargoType@ type) {
		int ind = index(type, false);
		if(ind == -1)
			return;
		if(types is null)
			return;
		types.removeAt(ind);
		amounts.removeAt(ind);
		persistence.removeAt(ind);
		/*if(types.length == 0) {*/
		/*	@types = null;*/
		/*	@amounts = null;*/
		/*}*/
	}

	void removeAll() {
		@types = null;
		@amounts = null;
		@persistence = null;
		filled = 0;
	}

	double get(const CargoType@ type) {
		int ind = index(type, false);
		if(ind == -1)
			return 0.0;
		return amounts[ind];
	}

	double add(const CargoType@ type, double amount, bool persistent = false, bool partial = true) {
		if(!partial && (capacity - filled) < type.storageSize * amount)
			return 0.0;
		double storeAmt = min(amount, (capacity - filled) / type.storageSize);
		if(storeAmt <= 0.0001)
			return 0.0;

		int ind = index(type, true, persistent);
		amounts[ind] += storeAmt;
		filled = clamp(filled + (storeAmt * type.storageSize), 0, capacity);
		delta = true;

		return amount - storeAmt;
	}

	double consume(const CargoType@ type, double amount, bool partial = false) {
		int ind = index(type, false);
		if(ind == -1)
			return 0.0;
		if(!partial && amounts[ind] < amount)
			return 0.0;

		double consAmt = min(amount, amounts[ind]);
		amounts[ind] -= consAmt;

		filled = clamp(filled - (consAmt * type.storageSize), 0, capacity);
		delta = true;

		if(!persistence[ind] && amounts[ind] < 0.0001)
			remove(type);
		return consAmt;
	}

	void write(Message& msg) {
		if(types is null) {
			msg.writeSmall(0);
		}
		else {
			msg.writeSmall(types.length);
			for(uint i = 0, cnt = types.length; i < cnt; ++i) {
				msg.writeSmall(types[i].id);
				msg << amounts[i];
				msg << persistence[i];
			}
		}

		msg << capacity;
		msg << filled;
	}

	void read(Message& msg) {
		uint cnt = msg.readSmall();
		if(cnt == 0) {
			if(types !is null) {
				@types = null;
				@amounts = null;
				@persistence = null;
			}
		}
		else {
			if(types is null) {
				@types = array<const CargoType@>();
				@amounts = array<double>();
				@persistence = array<bool>();
			}

			types.length = cnt;
			amounts.length = cnt;
			persistence.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				@types[i] = getCargoType(msg.readSmall());
				msg >> amounts[i];
				msg >> persistence[i];
			}
		}

		msg >> capacity;
		msg >> filled;
	}

	void save(SaveFile& file) {
		uint cnt = 0;
		if(types !is null)
			cnt = types.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			file.writeIdentifier(SI_CargoType, types[i].id);
			file << amounts[i];
			file << persistence[i];
		}

		file << capacity;
		file << filled;
	}

	void load(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		if(cnt == 0) {
			if(types !is null) {
				@types = null;
				@amounts = null;
				@persistence = null;
			}
		}
		else {
			if(types is null) {
				@types = array<const CargoType@>();
				@amounts = array<double>();
				@persistence = array<bool>();
			}

			types.length = cnt;
			amounts.length = cnt;
			persistence.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				auto@ type = getCargoType(file.readIdentifier(SI_CargoType));
				if(type is null) {
					double tmp = 0;
					file >> tmp;
					amounts.removeAt(i);
					persistence.removeAt(i);
					--cnt; --i;
				}
				else {
					@types[i] = type;
					file >> amounts[i];
					file >> persistence[i];
				}
			}
		}

		file >> capacity;
		file >> filled;
	}
};

#section server
export payDesignCosts, reverseDesignCosts;
bool payDesignCosts(Object& obj, const Design@ dsg, double multiply = 1.0) {
	double energyCost = dsg.total(SV_EnergyBuildCost);
	if(energyCost > 0) {
		if(obj.owner.consumeEnergy(energyCost, consumePartial=false) < energyCost-0.001)
			return false;
	}
	int influenceCost = dsg.total(SV_InfluenceBuildCost);
	if(influenceCost > 0) {
		if(!obj.owner.consumeInfluence(influenceCost)) {
			if(energyCost > 0)
				obj.owner.modEnergyStored(+energyCost);
			return false;
		}
	}
	double ftlCost = dsg.total(SV_FTLBuildCost);
	if(ftlCost > 0) {
		if(obj.owner.consumeFTL(ftlCost, partial=false, record=false) < ftlCost-0.001) {
			if(energyCost > 0)
				obj.owner.modEnergyStored(+energyCost);
			if(influenceCost > 0)
				obj.owner.modInfluence(+influenceCost);
			return false;
		}
	}
	array<double> globalAmts(getCargoTypeCount());
	for(uint i = 0, cnt = getCargoTypeCount(); i < cnt; ++i) {
		auto@ cargo = getCargoType(i);
		if(int(cargo.variable) == -1)
			continue;
		double amt = dsg.total(cargo.variable) * multiply;
		if(cargo.isGlobal) {
			globalAmts[i] = obj.owner.consumeCargo(cargo.id, amt, partial=true);
			amt -= globalAmts[i];
		}
		if(amt > 0) {
			if(!obj.hasCargo || obj.consumeCargo(cargo.id, amt, partial=false) < amt - 0.001) {
				for(uint j = 0; j < i; ++j) {
					auto@ other = getCargoType(j);
					if(int(other.variable) == -1)
						continue;
					if(cargo.isGlobal) {
						obj.owner.addCargo(other.id, globalAmts[i]);
					}
					double localAmt = (dsg.total(other.variable) * multiply) - globalAmts[i];
					if(localAmt > 0)
						obj.addCargo(other.id, localAmt);
				}
				if(energyCost > 0)
					obj.owner.modEnergyStored(+energyCost);
				if(influenceCost > 0)
					obj.owner.modInfluence(+influenceCost);
				if(ftlCost > 0)
					obj.owner.modFTLStored(+ftlCost);
				return false;
			}
		}
	}

	if(ftlCost > 0)
		obj.owner.modAttribute(EA_FTLEnergySpent, AC_Add, ftlCost);
	return true;
}

void reverseDesignCosts(Object& obj, const Design@ dsg, double multiply = 1.0, bool cancel = false) {
	if(!cancel) {
		double energyCost = dsg.total(SV_EnergyBuildCost);
		if(energyCost > 0)
			obj.owner.modEnergyStored(+energyCost);
		int influenceCost = dsg.total(SV_EnergyBuildCost);
		if(influenceCost > 0)
			obj.owner.addInfluence(+influenceCost);
		double ftlCost = dsg.total(SV_FTLBuildCost);
		if(ftlCost > 0)
			obj.owner.modFTLStored(+ftlCost, obeyMaximum=true);
	}
	if(obj.hasCargo) {
		for(uint i = 0, cnt = getCargoTypeCount(); i < cnt; ++i) {
			auto@ cargo = getCargoType(i);
			if(int(cargo.variable) == -1)
				continue;
			double amt = dsg.total(cargo.variable) * multiply;
			if(amt > 0) {
				if(cargo.isGlobal) // Can't easily track where the cargo originated, but *in principle* there shouldn't be any cases where local resources are being consumed.
					obj.owner.addCargo(cargo.id, amt);
				else
					obj.addCargo(cargo.id, amt);
			}
		}
	}
}
#section all

bool hasDesignCosts(const Design@ dsg) {
	for(uint i = 0, cnt = getCargoTypeCount(); i < cnt; ++i) {
		auto@ cargo = getCargoType(i);
		if(int(cargo.variable) == -1)
			continue;
		double amt = dsg.total(cargo.variable);
		if(amt > 0)
			return true;
	}
	if(dsg.total(SV_EnergyBuildCost) > 0)
		return true;
	if(dsg.total(SV_InfluenceBuildCost) > 0)
		return true;
	if(dsg.total(SV_FTLBuildCost) > 0)
		return true;
	return false;
}

array<CargoType@> cargoTypes;
dictionary cargoIdents;

int getCargoID(const string& ident) {
	auto@ type = getCargoType(ident);
	if(type is null)
		return -1;
	return int(type.id);
}

string getCargoIdent(int id) {
	auto@ type = getCargoType(id);
	if(type is null)
		return "";
	return type.ident;
}

const CargoType@ getCargoType(uint id) {
	if(id >= cargoTypes.length)
		return null;
	return cargoTypes[id];
}

const CargoType@ getCargoType(const string& ident) {
	CargoType@ def;
	if(cargoIdents.get(ident, @def))
		return def;
	return null;
}

uint getCargoTypeCount() {
	return cargoTypes.length;
}

void saveIdentifiers(SaveFile& file) {
	for(uint i = 0, cnt = cargoTypes.length; i < cnt; ++i) {
		auto type = cargoTypes[i];
		file.addIdentifier(SI_CargoType, type.id, type.ident);
	}
}

void addCargoType(CargoType@ type) {
	type.id = cargoTypes.length;
	cargoTypes.insertLast(type);
	cargoIdents.set(type.ident, @type);
}

void loadCargo(const string& filename) {
	ReadFile file(filename, false);
	
	string key, value;
	CargoType@ type;
	
	uint index = 0;
	while(file++) {
		key = file.key;
		value = file.value;
		
		if(key.equals_nocase("Cargo")) {
			@type = CargoType();
			type.ident = value;
			addCargoType(type);
			type.variable = getHexVariable(type.ident+"Cost");
		}
		else if(type is null) {
			file.error("Missing 'Cargo: ID' line");
		}
		else if(key.equals_nocase("Name")) {
			type.name = localize(value);
		}
		else if(key.equals_nocase("Description")) {
			type.description = localize(value);
		}
		else if(key.equals_nocase("Icon")) {
			type.icon = getSprite(value);
		}
		else if(key.equals_nocase("Color")) {
			type.color = toColor(value);
		}
		else if(key.equals_nocase("Storage Size")) {
			type.storageSize = toDouble(value);
		}
		else if(key.equals_nocase("Global")) {
			if(value.equals_nocase("Automatic")) {
				type.isGlobal = true;
				type.autostore = true;
			}
			else if(value.equals_nocase("Manual")) {
				type.isGlobal = true;
				type.autostore = false;
			}
			else if(value.equals_nocase("False")) {
				type.isGlobal = false;
				type.autostore = false;
			}
			else {
				file.error("Invalid value for cargo 'Global' parameter: " + value);
			}
		}
		else if(key.equals_nocase("Always Visible")) {
			type.visible = toBool(value);
		}
	}
}

void preInit() {
	FileList list("data/cargo", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadCargo(list.path[i]);
}
