import statuses;
import util.formatting;

// For use in effects using statuses.
// DO NOT CHANGE THIS UNLESS YOU KNOW WHAT YOU'RE DOING.
enum ABEMStatusTypes {
	SType_VoidRay = 1
};

enum ABEMVictoryTypes {
	VType_Standard = 1,
	VType_Vanguard = 2,
};

const StatusType@ getABEMStatus(int index) {
	switch(index) {
		case SType_VoidRay:
			return getStatusType("VoidRay");
		default:
			error("Invalid status index in function getABEMStatus: "+index); return null;
	}
	error("Unknown error has occurred in getABEMStatus.");
	return null;
}

class VictoryTabData {
	string headingText, descriptionText;
	Color headingColor;
	Sprite typeIcon;
}

interface VictoryAdjuster {
#section gui
	void AdjustVictorText(VictoryTabData& tab, Empire@ winner, Empire@ playerEmpire);
#section all
}

class VictorySelector {
#section gui
	void AdjustVictorText(VictoryTabData& tab, Empire@ winner, Empire@ playerEmpire) {
		VictoryAdjuster@ adjuster;
		switch(winner.Victory) {
			case VType_Vanguard:
				@adjuster = VanguardVictoryAdjuster();
				break;
			default:
				@adjuster = StandardVictoryAdjuster();
				break;
		}
		adjuster.AdjustVictorText(tab, winner, playerEmpire);
	}
#section all
}

class StandardVictoryAdjuster : VictoryAdjuster {
#section gui
	void AdjustVictorText(VictoryTabData& tab, Empire@ winner, Empire@ playerEmpire) {
		if(playerEmpire is winner) {
			tab.headingText = locale::V_WON_TITLE;
			tab.headingColor = colors::Green;
			tab.descriptionText = format(locale::V_WON_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
			tab.typeIcon = Sprite(material::PointsIcon);
		}
		else if(playerEmpire.Victory == -2 && playerEmpire.SubjugatedBy is winner) {
			switch(int(playerEmpire.VictoryType)) {
				case VType_Vanguard:
					tab.headingText = locale::V_VANGUARD_LESSER_TITLE;
					tab.headingColor = Color(0xfff500ff);
					tab.descriptionText = format(locale::V_VANGUARD_LESSER_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
					tab.typeIcon = Sprite(material::SystemUnderAttack);
					break;
				default:
					tab.headingText = locale::V_LESSER_TITLE;
					tab.headingColor = Color(0xfff500ff);
					tab.descriptionText = format(locale::V_LESSER_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
					tab.typeIcon = Sprite(material::PointsIcon);
					break;
			}
		}
		else {
			switch(int(playerEmpire.VictoryType)) {
				case VType_Vanguard:
					tab.headingText = locale::V_VANGUARD_LOST_TITLE;
					tab.headingColor = colors::Red;
					tab.descriptionText = format(locale::V_VANGUARD_LOST_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
					tab.typeIcon = Sprite(material::SystemUnderAttack);
					break;
				default:
					tab.headingText = locale::V_LOST_TITLE;
					tab.headingColor = colors::Red;
					tab.descriptionText = format(locale::V_LOST_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
					tab.typeIcon = Sprite(material::SystemUnderAttack);
					break;
			}
		}
	}
#section all
}

class VanguardVictoryAdjuster : VictoryAdjuster {
#section gui
	void AdjustVictorText(VictoryTabData& tab, Empire@ winner, Empire@ playerEmpire) {
		if(playerEmpire is winner) {
			if(playerEmpire.VanguardVictoryRequirement == 0) {
				tab.headingText = locale::V_VANGUARD_SUCCESS_TITLE;
				tab.headingColor = colors::Green;
				tab.descriptionText = format(locale::V_VANGUARD_SUCCESS_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
				tab.typeIcon = Sprite(material::ShieldImpactLarge, Color(0xde12deff));
			}
			else {
				tab.headingText = locale::V_VANGUARD_WON_TITLE;
				tab.headingColor = colors::Green;
				tab.descriptionText = format(locale::V_VANGUARD_WON_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
				tab.typeIcon = Sprite(material::PointsIcon);
			}
		}
		else if(playerEmpire.Victory == -2 && playerEmpire.SubjugatedBy is winner) {
			switch(int(playerEmpire.VictoryType)) {
				case VType_Vanguard:
					tab.headingText = locale::V_LESSER_TITLE;
					tab.headingColor = Color(0xfff500ff);
					if(winner.VanguardVictoryRequirement == 0) {
						tab.descriptionText = format(locale::V_VANGUARD_LESSEROTHERSUCCESS_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::ShieldImpactLarge, Color(0xde12deff));
					}
					else {
						tab.descriptionText = format(locale::V_VANGUARD_LESSEROTHER_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::PointsIcon);
					}
					break;
				default:
					tab.headingText = locale::V_LESSERTOVANGUARD_TITLE;
					tab.headingColor = Color(0xfff500ff);
					if(winner.VanguardVictoryRequirement == 0) {
						tab.descriptionText = format(locale::V_LESSERTOVANGUARDSUCCESS_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::ShieldImpactLarge, Color(0xde12deff));
					}
					else {
						tab.descriptionText = format(locale::V_LESSERTOVANGUARD_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(spritesheet::PlanetType, 14);
					}
					break;
			}
		}
		else {
			switch(int(playerEmpire.VictoryType)) {
				case VType_Vanguard:
					tab.headingText = locale::V_LOST_TITLE;
					tab.headingColor = colors::Red;
					if(winner.VanguardVictoryRequirement == 0) {
						tab.descriptionText = format(locale::V_VANGUARD_LOSTOTHERSUCCESS_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::ShieldImpactLarge, Color(0xde12deff));
					}
					else {
						tab.descriptionText = format(locale::V_VANGUARD_LOSTOTHER_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::SystemUnderAttack);
					}
					break;
				default:
					tab.headingColor = colors::Red;
					if(winner.VanguardVictoryRequirement == 0) {
						tab.headingText = locale::V_LOSTTOVANGUARDSUCCESS_TITLE;
						tab.descriptionText = format(locale::V_LOSTTOVANGUARDSUCCESS_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::ShieldImpactLarge, Color(0xde12deff));
					}
					else {
						tab.headingText = locale::V_LOSTTOVANGUARD_TITLE;
						tab.descriptionText = format(locale::V_LOSTTOVANGUARD_TEXT, formatEmpireName(winner), formatEmpireName(playerEmpire));
						tab.typeIcon = Sprite(material::SystemUnderAttack);
					}
					break;
			}
		}
	}
#section all
}

// Data entries for baseline sight ranges for ships, stations (multiplies SHIP_BASESIGHTRANGE), orbitals and planets.
const double SHIP_BASESIGHTRANGE = 250;
const double STATION_SIGHTMULTIPLIER = 2;
const double ORBITAL_BASESIGHTRANGE = 1000;
const double PLANET_BASESIGHTRANGE = 1500;