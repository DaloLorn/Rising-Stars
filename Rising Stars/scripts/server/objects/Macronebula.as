import systems;
import system_flags;
from ABEM_data import NEBULA_FLAG;

uint macronebulaCount = 0;

tidy class MacronebulaScript {
	uint idInternal;
	array<Region@> nebulae;
	array<Region@> edges;
	array<Territory@> territories;

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

	Region@ get_edges(uint index) {
		if(index >= edges.length)
			return null;
		return edges[index];
	}

	bool containsNebula(Region@ region) {
		return nebulae.find(region) >= 0;
	}

	bool containsEdge(Region@ region) {
		return edges.find(region) >= 0;
	}

	uint get_nebulaCount() {
		return nebulae.length;
	}

	uint get_edgeCount() {
		return edges.length;
	}

	void addNebula(Region@ region) {
		nebulae.insertLast(region);
		for(uint i = 0, cnt = territories.length; i < cnt; ++i) {
			territories[i].add(region);
		}
	}
	
	void claimMacronebula(Territory@ territory) {
		territories.insertLast(territory);
	}
	
	void unclaimMacronebula(Territory@ territory) {
		int index = territories.find(territory);
		if(index >= 0) {
			territories.removeAt(index);
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

	void addEdge(Macronebula& obj, Region@ region) {
		edges.insertLast(region);
		for(uint i = 0, cnt = territories.length; i < cnt; ++i) {
			territories[i].addNebulaEdges(obj);
		}
	}

	void removeEdge(uint index) {
		if(index < edges.length)
			edges.removeAt(index);
	}
	
	void removeEdgeSpecific(Region@ region) {
		int index = edges.find(region);
		if(index >= 0)
		{
			edges.removeAt(index);
		}
	}
}
