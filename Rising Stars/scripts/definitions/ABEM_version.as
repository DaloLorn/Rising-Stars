import version;
import CP_version;

// ABEMMOD's last revision was 724.
const string MOD_REVISION = "1193";
const array<string> VERSIONS = {
	"v2.0.3",
};

const array<string> REVISIONS = {
	"5101",
	"5095",
};

const array<string> CP_VERSIONS = {
	"OpenSR Modpack v1.1.0",
};

const array<string> CP_REVISIONS = {
	"171",
	"169"
};

const string MOD_NAME = "Rising Stars v1.3.1";
const string MOD_VERSION = MOD_NAME + " (revision " + MOD_REVISION + ") for Star Ruler 2 " + VERSIONS[0] + " (revision " + REVISIONS[0] + ", currently using " + GAME_VERSION + " " + SCRIPT_VERSION + ")";

string getLowestSupported(string input) {
	print(input.split("; ")[0]);
	return input.split("; ")[0];
};

bool checkSupported() {
	bool resultA = false;
	bool resultB = false;
	bool CPSupported = CommunityPatch::checkSupported() && checkCPSupported();
	for(uint i = 0; i < VERSIONS.length; ++i) {
		if(VERSIONS[i].equals_nocase(GAME_VERSION)) {
			resultA = true;
			break;
		}
	}
	if(resultA) {
		for(uint i = 0; i < REVISIONS.length; ++i) {
			if(("r" + REVISIONS[i]).equals_nocase(SCRIPT_VERSION)) {
				resultB = true;
				break;
			}
		}
	}
	if(resultA && resultB)
		return CPSupported;
	else {
		error("Mod " + MOD_NAME + " does not support current game version " + GAME_VERSION + "(" + SCRIPT_VERSION + "), use with caution!");
		return false;
	}
}

bool checkCPSupported() {
	bool resultA = false;
	bool resultB = false;
	for(uint i = 0; i < CP_VERSIONS.length; ++i) {
		if(CP_VERSIONS[i].equals_nocase(CommunityPatch::MOD_NAME)) {
			resultA = true;
			break;
		}
	}
	if(resultA) {
		for(uint i = 0; i < CP_REVISIONS.length; ++i) {
			if((CP_REVISIONS[i]).equals_nocase(CommunityPatch::MOD_REVISION)) {
				resultB = true;
				break;
			}
		}
	}
	if(resultA && resultB)
		return true;
	else {
		error("Mod " + MOD_NAME + " does not support current OSR Modpack version \"" + CommunityPatch::MOD_NAME + "\"(r" + CommunityPatch::MOD_REVISION + "), use with caution!");
		return false;
	}
}

bool checkDOF() {
	auto@ gateHull = getSubsystemDef("GateHull");
	bool result = gateHull !is null;
	if(!result)
		error("DOF Support Library missing or out of date - Stargate Integration is missing!");
	return result;
}

//bool MOD_SUPPORTS_VERSION = checkSupported();
