#priority init 10
import design_settings;

enum StatType {
	ST_Hex,
	ST_Subsystem,
	ST_Global,
};

enum SysVariableType {
	SVT_SubsystemVariable,
	SVT_HexVariable,
	SVT_ShipVariable
};

enum StatAggregate {
	SA_Sum,
};

enum StatDisplayMode {
	SDM_Normal,
	SDM_Short,
};

enum CustomStatFormula {
	CSF_None,
	CSF_HPStrength,
	CSF_Strength,
};

class DesignStat {
	uint index = 0;
	string ident;
	string name;
	string description;
	string suffix;
	Sprite icon;
	Color color;
	StatDisplayMode display = SDM_Normal;
	CustomStatFormula customFormula = CSF_None;

	int reqTag = -1;
	int secondary = -1;

	StatType type;

	SysVariableType varType;
	int variable;
	int usedVariable;

	SysVariableType divType;
	SysVariableType multType;
	int divVar = -1;
	int multVar = -1;

	bool outputZero = false;

	int importance;

	StatAggregate aggregate;
	double defaultValue;

	DesignStat() {
		importance = 0;
		aggregate = SA_Sum;
		varType = SVT_SubsystemVariable;
		defaultValue = 0;
		variable = -1;
		usedVariable = -1;
	}
};

class DesignStats {
	DesignStat@[] stats;
	double[] values;
	double[] used;

	void dump() {
		for(uint i = 0, cnt = stats.length; i < cnt; ++i)
			print(stats[i].name+": "+values[i]);
	}
};

namespace design_stats {
	bool hasValue(const ::Design@ dsg, const ::Subsystem@ sys, ::DesignStat@ stat) {
		switch(stat.varType) {
			case ::SVT_HexVariable:
				return sys.has(::HexVariable(stat.variable));
			case ::SVT_SubsystemVariable:
				return sys.has(::SubsystemVariable(stat.variable)) && sys.variable(::SubsystemVariable(stat.variable)) != 0;
		}
		return false;
	}

	double getValue(const Design@ dsg, const Subsystem@ sys, vec2u hex, SysVariableType type, int var, int aggregate = 0) {
		if(type == SVT_HexVariable) {
			if(hex != vec2u(uint(-1))) {
				return dsg.variable(hex, HexVariable(var));
			}
			else if(sys !is null) {
				double val = 0.0;
				for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
					switch(aggregate) {
						case ::SA_Sum:
							val += double(sys.hexVariable(HexVariable(var), i));
						break;
					}
				}
				return val;
			}
			else {
				double val = 0.0;
				for(uint n = 0, ncnt = dsg.subsystemCount; n < ncnt; ++n) {
					auto@ sys = dsg.subsystem(n);
					if(sys.has(HexVariable(var))) {
						for(uint i = 0, cnt = sys.hexCount; i < cnt; ++i) {
							switch(aggregate) {
								case ::SA_Sum:
									val += double(sys.hexVariable(HexVariable(var), i));
								break;
							}
						}
					}
				}
				return val;
			}
		}
		else if(type == SVT_SubsystemVariable) {
			if(sys !is null) {
				return dsg.variable(sys, SubsystemVariable(var));
			}
			else {
				double val = 0.0;
				for(uint n = 0, ncnt = dsg.subsystemCount; n < ncnt; ++n) {
					auto@ sys = dsg.subsystem(n);
					if(sys.has(SubsystemVariable(var))) {
						switch(aggregate) {
							case ::SA_Sum:
								val += double(dsg.variable(sys, SubsystemVariable(var)));
							break;
						}
					}
				}
				return val;
			}
		}
		else if(type == SVT_ShipVariable) {
			return dsg.variable(ShipVariable(var));
		}
		return 0.0;
	}

	::DesignStat@[] hexStats;
	::DesignStat@[] sysStats;
	::DesignStat@[] globalStats;
};

double calculateHPStrength(const Design@ dsg) {
	double ShieldBehaviorMod = 1.0;
	auto@ settings = cast<const DesignSettings>(dsg.settings);
	if (settings !is null && dsg.hasTag(ST_Support) && settings.behavior == SG_Shield) ShieldBehaviorMod = 1.1;
	return ((dsg.totalHP + (dsg.total(SV_Repair) / 3.0 * pow(max(log10(dsg.total(SV_Repair)/3.0), 0.0), 2))) * (1.0 + log10(dsg.size) * 0.1) * dsg.total(SV_HullStrengthMult) + ((1.0 + max(log10(dsg.total(SV_ShieldRegen))*2.0, 1.0)) * dsg.total(SV_ShieldCapacity) / (1.0 - dsg.total(SV_Chance)))) * ShieldBehaviorMod;
}

DesignStats@ getDesignStats(const Design@ dsg) {
	DesignStats stats;

	uint sysCnt = dsg.subsystemCount;
	for(uint i = 0, cnt = design_stats::globalStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::globalStats[i];
		if(stat.reqTag != -1 && !dsg.hasTag(SubsystemTag(stat.reqTag)))
			continue;
		bool has = false;
		double val = 0;
		double used = -1.0;
		switch(stat.customFormula) {
			case CSF_Strength:
				val = calculateHPStrength(dsg) * dsg.total(SV_DPS) * 0.001;
				break;
			case CSF_HPStrength:
				val = calculateHPStrength(dsg);
				break;
			case CSF_None:
			default:
				val = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.varType, stat.variable, stat.aggregate);
				if(stat.usedVariable != -1)
					used = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.varType, stat.usedVariable, stat.aggregate);
				if(stat.divVar != -1) {
					double div = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.divType, stat.divVar, stat.aggregate);
					if(div != 0.0)
						val /= div;
				}
				if(stat.multVar != -1) {
					double mult = design_stats::getValue(dsg, null, vec2u(uint(-1)), stat.multType, stat.multVar, stat.aggregate);
					val *= mult;
				}
				break;
		}

		if(val != 0.0 || stat.outputZero) {
			stats.stats.insertLast(stat);
			stats.values.insertLast(val);
			stats.used.insertLast(used);
		}
	}

	return stats;
}

DesignStats@ getHexStats(const Design@ dsg, vec2u hex) {
	DesignStats stats;

	const Subsystem@ sys = dsg.subsystem(hex);
	for(uint i = 0, cnt = design_stats::hexStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::hexStats[i];
		if(stat.reqTag != -1 && !dsg.hasTag(stat.reqTag))
			continue;
		if(design_stats::hasValue(dsg, sys, stat)) {
			float val = design_stats::getValue(dsg, sys, hex, stat.varType, stat.variable, stat.aggregate);
			if(val != 0.f) {
				stats.stats.insertLast(stat);
				stats.values.insertLast(val);
			}
		}
	}

	return stats;
}


DesignStats@ getSubsystemStats(const Design@ dsg, const Subsystem@ sys) {
	DesignStats stats;

	for(uint i = 0, cnt = design_stats::sysStats.length; i < cnt; ++i) {
		DesignStat@ stat = design_stats::sysStats[i];
		if(stat.reqTag != -1 && !sys.type.hasTag(stat.reqTag))
			continue;
		if(design_stats::hasValue(dsg, sys, stat)) {
			float val = design_stats::getValue(dsg, sys, vec2u(uint(-1)),
							stat.varType, stat.variable, stat.aggregate);
			if(val != 0.f) {
				stats.stats.insertLast(stat);
				stats.values.insertLast(val);
			}
		}
	}

	return stats;
}

void loadStats(const string& filename) {
	//Load stat descriptors
	ReadFile file(filename);

	DesignStat@ stat;
	array<DesignStat@>@ list;
	string key, value;
	while(file++) {
		key = file.key;
		value = file.value;

		if(key == "HexStat") {
			@list = design_stats::hexStats;
			@stat = DesignStat();
			stat.type = ST_Hex;
			stat.ident = value;
			stat.display = SDM_Short;
			stat.index = design_stats::hexStats.length;
			design_stats::hexStats.insertLast(stat);
		}
		else if(key == "SubsystemStat") {
			@list = design_stats::sysStats;
			@stat = DesignStat();
			stat.ident = value;
			stat.type = ST_Subsystem;
			stat.display = SDM_Short;
			stat.index = design_stats::sysStats.length;
			design_stats::sysStats.insertLast(stat);
		}
		else if(key == "GlobalStat") {
			@list = design_stats::globalStats;
			@stat = DesignStat();
			stat.ident = value;
			stat.type = ST_Global;
			stat.index = design_stats::globalStats.length;
			design_stats::globalStats.insertLast(stat);
		}
		else if(key == "Name") {
			stat.name = localize(value);
		}
		else if(key == "Description") {
			stat.description = localize(value);
		}
		else if(key == "Variable") {
			if(value.startswith("Hex.")) {
				value = value.substr(4);
				stat.varType = SVT_HexVariable;
				stat.variable = getHexVariable(value);
			}
			else if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.varType = SVT_ShipVariable;
				stat.variable = getShipVariable(value);
			}
			else {
				stat.varType = SVT_SubsystemVariable;
				stat.variable = getSubsystemVariable(value);
			}
		}
		else if(key == "UsedVariable") {
			if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.usedVariable = getShipVariable(value);
			}
			else {
				error("UsedVariable needs to be a ship variable.");
			}
		}
		else if(key == "Default") {
			stat.defaultValue = toDouble(value);
		}
		else if(key == "Aggregate") {
			if(value == "Sum") {
				stat.aggregate = SA_Sum;
				stat.defaultValue = 0;
			}
		}
		else if(key == "Importance") {
			stat.importance = toInt(value);
		}
		else if(key == "Icon") {
			stat.icon = getSprite(value);
		}
		else if(key == "Color") {
			stat.color = toColor(value);
		}
		else if(key == "Suffix") {
			stat.suffix = localize(value);
		}
		else if(key == "RequireTag") {
			stat.reqTag = getSubsystemTag(value);
		}
		else if(key.equals_nocase("AllowZero")) {
			stat.outputZero = toBool(value);
		}
		else if(key.equals_nocase("CustomFormula")) {
			if(value.equals_nocase("None")) {
				stat.customFormula = CSF_None;
			}
			else if(value.equals_nocase("Strength")) {
				stat.customFormula = CSF_Strength;
			}
			else if(value.equals_nocase("HPStrength")) {
				stat.customFormula = CSF_HPStrength;
			}
		}
		else if(key == "Secondary") {
			int sec = -1;
			for(uint i = 0, cnt = list.length; i < cnt; ++i) {
				if(list[i].ident.equals_nocase(value)) {
					sec = int(i);
					break;
				}
			}
			if(sec == -1)
				file.error("Could not find previous stat for secondary: "+value);
			else
				stat.secondary = sec;
		}
		else if(key == "DivBy") {
			if(value.startswith("Hex.")) {
				value = value.substr(4);
				stat.divType = SVT_HexVariable;
				stat.divVar = getHexVariable(value);
			}
			else if(value.startswith("Ship.")) {
				value = value.substr(5);
				stat.divType = SVT_ShipVariable;
				stat.divVar = getShipVariable(value);
			}
			else {
				stat.divType = SVT_SubsystemVariable;
				stat.divVar = getSubsystemVariable(value);
			}
		}
		else if(key == "MultBy") {
            		if(value.startswith("Hex.")) {
		                value = value.substr(4);
		                stat.multType = SVT_HexVariable;
		                stat.multVar = getHexVariable(value);
            		}
                        else if(value.startswith("Ship.")) {
		                value = value.substr(5);
		                stat.multType = SVT_ShipVariable;
		                stat.multVar = getShipVariable(value);
            		}
            		else {
		                stat.multType = SVT_SubsystemVariable;
		                stat.multVar = getSubsystemVariable(value);
            		}
        	}
	}
}

void init() {
	FileList list("data/design_stats", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadStats(list.path[i]);
}
