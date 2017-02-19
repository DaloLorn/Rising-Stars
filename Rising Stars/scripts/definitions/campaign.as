export CampaignScenario;
export getCampaignScenarioCount, getCampaignScenario;
export completeCampaignScenario, reloadCampaignCompletion;

class CampaignScenario {
	uint id;
	string ident;

	string name;
	string description;
	Sprite picture;
	Sprite icon;
	Color color;

	array<string> dependencies;
	
	// Using the CampaignScenario class to stand in for a virtually identical Campaign class for UI purposes.
	// I can't understand why the devs didn't think having that sort of thing would be useful...
	//  perhaps they didn't get far enough to need it?
	//
	// In any case, this spares me more than a few headaches...
	CampaignScenario@ parent;
	string parentIdent;        
	uint parentCount = 0;
	string mapName; // NOTE: No campaign item with a scenario map may have children in the UI!
					// NOTE: This may be a ridiculous constraint.
					// NOTE: I'm probably not going to make the children thing work anyway,
					//       at least not in the 'expandable folder' sense I planned.

	bool completed = false;

	bool get_isAvailable() const {
		if(parent !is null && !parent.isAvailable)
			return false;
		for(uint i = 0, cnt = dependencies.length; i < cnt; ++i) {
			auto@ other = getCampaignScenario(dependencies[i]);
			if(other !is null && !other.completed)
				return false;
		}
		return true;
	}
	
	/*
	int opCmp(const CampaignScenario@ other) const {
		if(parent is null)
			return -1;
		if(other.parent is null)
			return 1;
		CampaignScenario@ foundParent = parent;
		CampaignScenario@ otherFoundParent = other.parent;
		while(foundParent.parent !is null && otherFoundParent.parent !is null && foundParent !is otherFoundParent) {
			foundParent = foundParent.parent;
			otherFoundParent = otherFoundParent.parent;
		}
		if(foundParent is otherFoundParent)
			// Presumably missions in a campaign will be declared in their proper order...
			// Truthfully, we could probably go without this whole mess and still come out with a functioning tree.
			// To hell with it, this is unnecessary.
			return id.opCmp(other.id); 
		else if(foundParent.parent is null) // We have a deeper parent tree than the other one.
			return -1;
		else if(otherFoundParent.parent is null) // The other one has a deeper parent tree than we do.
			return 1;
		
		return 0;		
	}
	*/
};

array<CampaignScenario@> campaignList;
dictionary campaignIdents;

uint getCampaignScenarioCount() {
	return campaignList.length;
}

const CampaignScenario@ getCampaignScenario(uint index) {
	if(index >= campaignList.length)
		return null;
	return campaignList[index];
}

const CampaignScenario@ getCampaignScenario(const string& ident) {
	CampaignScenario@ scen;
	if(!campaignIdents.get(ident, @scen))
		return null;
	return scen;
}

// Hacky workaround required to construct a parent tree in preInit().
// DO NOT EVER USE THIS. EVER. You have been warned.
CampaignScenario@ getCampaignScenarioNotConst(const string& ident) {
	CampaignScenario@ scen;
	if(!campaignIdents.get(ident, @scen))
		return null;
	return scen;
}

void loadScenarios(const string& filename) {
	ReadFile file(filename, true);
	
	string key, value;
	CampaignScenario@ scen;
	while(file++) {
		key = file.key;
		value = file.value;
		
		if(key == "Scenario") {
			@scen = CampaignScenario();
			scen.ident = value;
			scen.id = campaignList.length;
			campaignList.insertLast(scen);
			campaignIdents.set(scen.ident, @scen);
		}
		else if(scen is null) {
			file.error("Missing 'Scenario: ID' line.");
		}
		else if(key == "Name") {
			scen.name = localize(value);
		}
		else if(key == "Description") {
			scen.description = localize(value);
		}
		else if(key == "Icon") {
			scen.icon = getSprite(value);
		}
		else if(key == "Picture") {
			scen.picture = getSprite(value);
		}
		else if(key == "Color") {
			scen.color = toColor(value);
		}
		else if(key == "Map") {
			scen.mapName = value;
		}
		else if(key == "Dependency") {
			scen.dependencies.insertLast(value);
		}
		else if(key.equals_nocase("Parent")) {
			scen.parentIdent = value;
		}
	}
}

void preInit() {
	FileList list("data/campaign", "*.txt", true);
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadScenarios(list.path[i]);
	reloadCampaignCompletion();
	
	// Now that we've loaded all scenarios, assign parents accordingly.
	for(uint i = 0, cnt = campaignList.length; i < cnt; ++i) {
		CampaignScenario@ scen = campaignList[i];
		if(scen.parentIdent != "") {
			auto@ parent = getCampaignScenarioNotConst(scen.parentIdent);
			if(parent is null)
				error("Could not find parent campaign '" + scen.parentIdent + "' for scenario '" + scen.ident + "'!");
			else
				@scen.parent = parent;
		}
	}
	
	// This block of code should prevent recursive parenting.
	// On the other hand, the original code doesn't check for recursive dependencies... maybe this is a waste of effort.
	for(uint i = 0, cnt = campaignList.length; i < cnt; ++i) {
		CampaignScenario@ scen = campaignList[i];
		CampaignScenario@ prevParent = null;
		CampaignScenario@ parent = scen.parent;
		
		while(parent !is null && parent !is scen) {
			scen.parentCount += 1;
			@prevParent = parent;
			@parent = parent.parent;
		}
		if(parent is scen)
			@prevParent.parent = null;
	}
	
	/* Alphabetical sorting by filename will probably suffice. This was being ridiculous -and- expensive.
		Campaign_01, Campaign_02, Scenario_X, etc.
		
	// Pre-sort the campaign list so the UI doesn't have to do this repeatedly.
	campaignList.sortAsc();
	for(uint i = 0, cnt = campaignList.length; i < cnt; ++i) {
		campaignList[i].id = i;
	}
	*/
}

void completeCampaignScenario(const string& ident) {
	reloadCampaignCompletion();
	CampaignScenario@ scen;
	if(campaignIdents.get(ident, @scen) && scen !is null)
		scen.completed = true;

	WriteFile file(path_join(modProfile, "campaign.dat"));
	for(uint i = 0, cnt = campaignList.length; i < cnt; ++i) {
		if(campaignList[i].completed)
			file.writeLine(campaignList[i].ident);
	}
}

void reloadCampaignCompletion() {
	for(uint i = 0, cnt = campaignList.length; i < cnt; ++i)
		campaignList[i].completed = false;

	ReadFile completed(path_join(modProfile, "campaign.dat"), true);
	CampaignScenario@ scen;
	while(completed++) {
		if(campaignIdents.get(completed.line, @scen) && scen !is null)
			scen.completed = true;
	}
}
