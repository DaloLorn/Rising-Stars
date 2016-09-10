#priority init 1549
import hooks;
import settings.map_lib;
import map_systems;
#section server
import map_generation;
#section all

export SystemList;
export getSystemList, getSystemListCount;

SystemList@[] systemLists;
dictionary idents;

tidy final class SystemList {
	uint id;
	string ident;
	
	array<const SystemType@> systemTypes;
	double[] systemFrequencies;
	bool[] ignoreUniqueness;
	
	double totalFrequency = 0;

#section server
	const SystemType@ getRandomSystemType(MapGeneration& map) const {
		uint count = systemTypes.length;
		double num = randomd(0, totalFrequency);
		for(uint i = 0, cnt = systemTypes.length; i < cnt; ++i) {
			const SystemType@ type = systemTypes[i];
			double freq = systemFrequencies[i];
			if(num <= freq) {
				if(type.unique != SU_NonUnique && !ignoreUniqueness[i]) {
					if(map.uniqueSystems[type.id] || GlobalUniqueSystems[type.id])
						continue;
					else {
						if(type.unique == SU_Galaxy)
							map.uniqueSystems[type.id] = true;
						else
							GlobalUniqueSystems[type.id] = true;
						return type;
					}
				}
				else return type;
			}
			num -= freq;
		}
		return systemTypes[systemTypes.length-1];
	}
#section all
}

void loadSystemLists(const string& filename) {
	ReadFile file(filename, true);
	
	string key, value;
	SystemList@ list;
	
	uint index = UINT_MAX;
	while(file++) {
		key = file.key;
		value = file.value;
		
		if(file.fullLine) {
			if(list is null) {
				error("Missing 'SystemList: ID' line in " + filename);
				continue;
			}
		}
		else if(key.equals_nocase("SystemList")) {
			if(list !is null)
				addSystemList(list);
			@list = SystemList();
			list.ident = value;
		}
		else if(list is null) {
			error("Missing 'SystemList: ID' line in " + filename);
		}
		else if(key.equals_nocase("System")) {
			const SystemType@ type = getSystemType(value);
			if(type is null){
				error("Invalid system '" + value + "' in " + filename);
				continue;
			}
			else if(index == UINT_MAX)
				index = 0;
			else
				index++;
			list.systemTypes.insertLast(type);
			list.systemFrequencies.insertLast(0);
			list.ignoreUniqueness.insertLast(false);
		}
		else if(key.equals_nocase("Frequency")) {
			if(index == UINT_MAX) {
				error("Missing 'System: Ident' line in " + filename);
				continue;
			}
			list.systemFrequencies[index] = toDouble(value);
		}
		else if(key.equals_nocase("Ignore Uniqueness")) {
			if(index == UINT_MAX) {
				error("Missing 'System: Ident' line in " + filename);
				continue;
			}
			list.ignoreUniqueness[index] = toBool(value);
		}
	}
	
	if(list !is null)
		addSystemList(list);
}

void init() {
	FileList list("data/system_lists", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadSystemLists(list.path[i]);
}

const SystemList@ getSystemList(uint id) {
	if(id >= systemLists.length)
		return null;
	return systemLists[id];
}

const SystemList@ getSystemList(const string& ident) {
	SystemList@ list;
	if(idents.get(ident, @list))
		return list;
	return null;
}

uint getSystemListCount() {
	return systemLists.length;
}

void addSystemList(SystemList@ list) {
	list.id = systemLists.length;
	systemLists.insertLast(list);
	idents.set(list.ident, @list);
	for(uint i = 0, icnt = list.systemFrequencies.length; i < icnt; ++i) {
		list.totalFrequency += list.systemFrequencies[i];
	}
}