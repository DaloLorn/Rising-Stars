import systems;
import system_flags;
from ABEM_data import NEBULA_FLAG;

uint macronebulaCount = 0;

tidy class MacronebulaScript {
	uint idInternal;
	array<Region@> nebulae;
	array<Region@> edges;

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
	}

	void removeNebula(uint index) {
		if(index < nebulae.length)
			nebulae.removeAt(index);
	}

	void addEdge(Region@ region) {
		edges.insertLast(region);
	}

	void removeEdge(uint index) {
		if(index < edges.length)
			edges.removeAt(index);
	}
}
