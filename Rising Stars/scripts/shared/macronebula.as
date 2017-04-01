import systems;
import system_flags;

const int NEBULA_FLAG = getSystemFlag("IsNebula");

uint macronebulaCount = -1;

tidy class Macronebula {
	uint id;
	array<Region@> nebulae;
	array<Region@> edges;
	
	Macronebula() {
		id = macronebulaCount++;
	}
}