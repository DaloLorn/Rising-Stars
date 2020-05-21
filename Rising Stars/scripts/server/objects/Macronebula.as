import systems;
import system_flags;
from ABEM_data import NEBULA_FLAG;

uint macronebulaCount = 0;

tidy class MacronebulaScript {
	uint idInternal;
	array<Region@> nebulae;

	MacronebulaScript() {
		idInternal = macronebulaCount++;
	}

	uint get_id() {
		return idInternal;
	}

	Region@ get_nebulae(uint index) {
		if(index >= nebulae.length)
			return null;
		return nebulae[index];
	}

	bool containsNebula(Region@ region) {
		return nebulae.find(region) >= 0;
	}

	uint get_nebulaCount() {
		return nebulae.length;
	}

	void addNebula(Region@ region) {
		nebulae.insertLast(region);
		if(nebulae.length == 1) return;

		// Synchronize the macronebula's trade grants.
		// We don't need to do this if this is our first nebula.
		for(uint i = 0, cnt = nebulae.length-1; i < cnt; i++) {
			for(uint j = 0, empires = getEmpireCount(); j < empires; j++) {
				Empire@ emp = getEmpire(j);
				for(uint k = 0, repeats = region.getTradeGrants(emp); k < repeats; k++) {
					nebulae[i].grantTradeInner(emp);
				}
			}
		}
		for(uint i = 0, empires = empires = getEmpireCount(); i < empires; i++) {
			Empire@ emp = getEmpire(i);
			for(uint j = 0, repeats = nebulae[0].getTradeGrants(emp); j < repeats; j++) {
				region.grantTradeInner(emp);
			}
		}
	}

	void removeNebula(uint index) {
		if(index < nebulae.length)
			nebulae.removeAt(index);
	}
	
	void removeNebulaSpecific(Region@ region) {
		int index = nebulae.find(region);
		if(index >= 0)
		{
			nebulae.removeAt(index);
		}
	}
}
