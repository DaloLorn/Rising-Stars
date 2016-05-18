import generic_effects;
import hooks;
import generic_hooks;
import subsystem_effects;

class AddSightModifier : GenericEffect {
	Document doc("Changes the sight range of an object.");
	Argument priority(AT_Integer, "100", doc="The order in which the modifier is executed. The lower the number, the sooner it is executed. NOTE: Only use positive integers here!");
	Argument multiplier(AT_Decimal, "1", doc="The number by which the object's base sight range and all previously executed modifiers are multiplied. NOTE: Same-priority modifiers do not multiply each other, they just combine their results when they're done!");
	Argument addedRange(AT_Decimal, "0", doc="The amount of extra sight range to add, expressed in units. For reference, the sides of the biggest squares on the system grid are 500 units.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj is null)
			return;
		if(obj.hasLeaderAI) {
			uint id = obj.addSightModifier(uint(priority.integer), multiplier.decimal, addedRange.decimal);
			data.store(id);
		}
	}

	void disable(Object& obj, any@ data) const override {
		if(obj is null)
			return;
		if(obj.hasLeaderAI) {
			uint id = 0;
			data.retrieve(id);
			obj.removeSightModifier(id);
		}
	}

	void save(any@ data, SaveFile& file) const override {
		uint id = 0;
		data.retrieve(id);

		file << id;
	}

	void load(any@ data, SaveFile& file) const override {
		uint id = 0;

		file >> id;
		data.store(id);
	}
#section all
}

class SubsystemSightData {
	bool hasLeader = false;
	uint id;
	float workingPercent;
	any data;
}

class AddSensor : SubsystemEffect {
	Document doc("Changes the sight range of the ship using a subsystem. Modifier scales based on how much of the subsystem is still operational. If no scaling is required, use AddSightModifier instead.");
	Argument priority(AT_Integer, "100", doc="The order in which the modifier is executed. The lower the number, the sooner it is executed. NOTE: Only use positive integers here!");
	Argument multiplier(AT_Decimal, "1.0", doc="The number by which the ship's base sight range and all previously executed modifiers are multiplied. NOTE: Same-priority modifiers do not multiply each other, they just combine their results when they're done!");
	Argument addedRange(AT_Decimal, "0.0", doc="The amount of extra sight range to add, expressed in units. For reference, the sides of the biggest squares on the system grid are 500 units.");

#section server
	void start(SubsystemEvent& event) const override {
		SubsystemSightData info;
		event.data.store(@info);
		if(event.obj is null) {
//			print("Object is currently null.");
			return;
		}
		if(event.obj.hasLeaderAI) {
//			print("Proper initialization done.");
			info.hasLeader = true;
			info.id = event.obj.addSightModifier(uint(priority.integer), multiplier.decimal, addedRange.decimal);
//			print(info.hasLeader);
//			print(event.workingPercent);
//			print(uint(priority.integer) + "/" + priority.integer);
//			print(multiplier.decimal);
//			print(addedRange.decimal);
			info.workingPercent = event.workingPercent;
		}
	}

	void tick(SubsystemEvent& event, double time) const override {
		SubsystemSightData@ info;
		event.data.retrieve(@info);
		event.data.store(@info);
		if(event.obj is null) {
//			print("Object is null in current tick.");
			return;
		}
		if(event.obj.hasLeaderAI) {
			if(!info.hasLeader) {
//				print("Backup initialization done.");
				double finalMult = multiplier.decimal * event.workingPercent;
				if(finalMult < 1.0)
					finalMult += 1;
				info.hasLeader = true;
				info.id = event.obj.addSightModifier(uint(priority.integer), finalMult, addedRange.decimal * event.workingPercent);
//				print(info.hasLeader);
//				print(event.workingPercent);
//				print(uint(priority.integer) + "/" + priority.integer);
//				print(finalMult + "/" + multiplier.decimal);
//				print(addedRange.decimal);
				info.workingPercent = event.workingPercent;
			}
			else if(info.workingPercent != event.workingPercent) {
				double finalMult = multiplier.decimal * event.workingPercent;
				if(finalMult < 1.0)
					finalMult += 1;
				event.obj.modifySightModifier(info.id, finalMult, addedRange.decimal * event.workingPercent);
				info.workingPercent = event.workingPercent;
			}
		}
		else
			info.hasLeader = false;
	}

	void end(SubsystemEvent& event) const override {
		SubsystemSightData@ info;
		event.data.retrieve(@info);
		if(event.obj is null)
			return;
		if(event.obj.hasLeaderAI && (info !is null && info.hasLeader)) {
			event.obj.removeSightModifier(info.id);
		}
		event.data.store(@info);
	}

	void save(SubsystemEvent& event, SaveFile& file) const override {
		SubsystemSightData@ info;
		event.data.retrieve(@info);

		if(info !is null) {  
			file << info.hasLeader;  
			file << info.id;  
			file << info.workingPercent;  
		}  
		else {  
			uint nil = 0xffffffff;  
			file << false;  
			file << nil;  
			file << event.workingPercent;  
		}  
	}

	void load(SubsystemEvent& event, SaveFile& file) const override {
		SubsystemSightData info;
		event.data.store(@info);

		file >> info.hasLeader;
		file >> info.id;
		file >> info.workingPercent;
		if(event.obj.hasLeaderAI && !info.hasLeader) {
			double finalMult = multiplier.decimal * event.workingPercent;
			if(finalMult < 1.0)
				finalMult += 1;
			info.hasLeader = true;
			info.id = event.obj.addSightModifier(uint(priority.integer), finalMult, addedRange.decimal * event.workingPercent);
			info.workingPercent = event.workingPercent;
		}
	}
#section all
}