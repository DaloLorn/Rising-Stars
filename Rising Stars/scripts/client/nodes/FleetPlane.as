// BEGIN NON-MIT CODE - DOF (Scaling)
// Controls factor by which ship/fleet icons start to scale down
const double MAX_SIZE = 30000.0;
// END NON-MIT CODE

// ------------------------------
// Tunables / constants
// ------------------------------
const double APPROACH_EPSILON = 0.0002;
const double MAX_ICON_SIZE    = MAX_SIZE; // Keep legacy value but use a clearer name

// Plane visibility distances (world units)
const double PLANE_SHOW_MIN   = 500.0;   // start showing plane
const double PLANE_FADE_RANGE = 100.0;   // fade from 500 -> 600
const double PLANE_SHOW_MAX   = 2000.0;  // fully hidden beyond this

// Icon sizing & fades
const double ICON_DIST_FACTOR   = 600.0; // iconDist = this * leader.radius
const double SCALE_DIST_FACTOR  = 0.25;  // scales against distance
const double SELECTED_SCALE_BOOST = 1.1; // highlight selected leaders
const double ICON_SCALE         = 0.5;   // final billboard scale factor

// ------------------------------
// Feature toggles
// ------------------------------
bool SHOW_FLEET_PLANES = true;
bool SHOW_FLEET_ICONS  = true;

void setFleetPlanesShown(bool enabled) { SHOW_FLEET_PLANES = enabled; }
bool getFleetPlanesShown() { return SHOW_FLEET_PLANES; }
void setFleetIconsShown(bool enabled) { SHOW_FLEET_ICONS = enabled; }
bool getFleetIconsShown() { return SHOW_FLEET_ICONS; }

// ------------------------------
// Colors / shader params
// ------------------------------
const Color FTLColor(0x00c0ff80);
const Color CombatColor(0xffc60080);
vec4f CombatVec;
vec4f FTLVec;

void init() {
	CombatColor.toVec4(CombatVec);
	FTLColor.toVec4(FTLVec);
}

// ------------------------------
// Helpers
// ------------------------------
double clampd(double v, double lo, double hi) {
	return max(lo, min(hi, v));
}
double saturate(double v) {
	return clampd(v, 0.0, 1.0);
}
uint8 alphaFromUnit(double t) {
	return uint8(255.0 * saturate(t));
}
double safeAcos(double x) {
	return acos(clampd(x, -1.0, 1.0));
}
double computeBillboardRotation(Object& leader, bool rotate) {
	if(!rotate) return 0.0;

	vec3d cf = cameraFacing;
	vec3d cu = cameraUp;
	vec3d objFacing = leader.node_rotation * vec3d_front();

	double alongDot = clampd(cf.dot(objFacing), -1.0, 1.0);

	// If the facing is not (almost) parallel to camera
	if(alongDot > -0.9999 && alongDot < 0.9999) {
		objFacing -= cf * alongDot;
		objFacing.normalize();

		vec3d camRight = cf.cross(cu).normalized();
		double d = clampd(camRight.dot(objFacing), -1.0, 1.0);
		double rot = safeAcos(d);

		if(camRight.cross(cf).dot(objFacing) < 0.0)
			rot = -rot;
		return rot;
	}
	else {
		return (alongDot > 0.0) ? (pi * 0.5) : (pi * -0.5);
	}
}

class FleetPlaneNodeScript {
	Object@ leader;
	Sprite fleetIcon;
	double radius = 0.0;
	bool hasPlane = false;
	bool withFleet = false; // currently not used in rendering; reserved for future behavior
	bool rotate = true;
	bool wasVisible = false;

	FleetPlaneNodeScript(Node& node) {
		node.transparent = true;
		node.visible = false;
		node.needsTransform = false;
		node.fixedSize = true;
		node.createPhysics();
	}
	
	void establish(Node& node, Object& obj, double rad) {
		@leader = obj;
		radius = rad;

		// Try to fetch a fleet icon for ships
		if(obj.isShip) {
			const Design@ dsg = cast<Ship>(obj).blueprint.design;
			if(dsg !is null)
				fleetIcon = dsg.fleetIcon;
		}
		
		node.scale = radius;
		node.position = obj.position;
		@node.object = obj;
		node.rebuildTransform();
	}
	
	void set_hasSupply(bool supply) {
		hasPlane = supply;
	}

	void set_hasFleet(bool has) {
		withFleet = has;
	}

	bool preRender(Node& node) {
		if(!node.visible || leader is null) {
			wasVisible = false;
			return false;
		}

		// Track leader position
		node.position = leader.node_position;

		// Base size grows gently with leader.radius, then scales with distance
		const double r = leader.radius;
		const double base = 0.2 * (1.0 + r) / (3.0 + r);

		const double dist = wasVisible ? node.sortDistance
		                               : cameraPos.distanceTo(node.position);

		double size = base * dist * SCALE_DIST_FACTOR;
		size = min(size, MAX_ICON_SIZE);
		if(leader.selected)
			size *= SELECTED_SCALE_BOOST;

		node.scale = size * ICON_SCALE;
		rotate = !leader.hasOrbit;

		node.rebuildTransform();
		wasVisible = true;
		return true;
	}

	void render(Node& node) {
		if(leader is null)
			return;

		// --------------------------
		// Fleet plane circle
		// --------------------------
		if(SHOW_FLEET_PLANES && hasPlane && node.sortDistance < PLANE_SHOW_MAX && node.sortDistance >= PLANE_SHOW_MIN) {
			Color color(0xffffff14); // base alpha 0x14
			if(node.sortDistance < PLANE_SHOW_MIN + PLANE_FADE_RANGE) {
				double t = (node.sortDistance - PLANE_SHOW_MIN) / PLANE_FADE_RANGE; // 0 at 500 -> 1 at 600
				color.a = uint8(double(color.a) * saturate(t));
			}
			renderPlane(material::FleetCircle, node.abs_position, radius, color);
		}
		
		// --------------------------
		// Billboard fleet icon
		// --------------------------
		if(!SHOW_FLEET_ICONS)
			return;

		const double iconDist = ICON_DIST_FACTOR * max(0.0, leader.radius);

		if(node.sortDistance <= iconDist)
			return;

		// Rotation to keep icon aligned with the object's facing vs camera
		const double rot = computeBillboardRotation(leader, rotate);

		// Owner color with distance-based fade-in
		Color col;
		Empire@ owner = leader.owner;
		if(owner !is null) col = owner.color;
		else col = Color(0xffffffff);

		if(node.sortDistance < iconDist * 2.0) {
			double t = (node.sortDistance - iconDist) / iconDist; // 0 at iconDist -> 1 at 2*iconDist
			col.a = alphaFromUnit(t);
		}
		node.color = col;

		// Glow state: FTL, combat, or none
		Ship@ ship = cast<Ship>(leader);
		if(ship !is null && ship.isFTLing) {
			shader::GLOW_COLOR = FTLVec;
		}
		else if(owner is playerEmpire && leader.inCombat) {
			shader::GLOW_COLOR = CombatVec;
		}
		else {
			// Avoid stale glow from previous draws
			shader::GLOW_COLOR = vec4f(0.f, 0.f, 0.f, 0.f);
		}

		shader::APPROACH = APPROACH_EPSILON;

		// Choose the best available icon
		if(fleetIcon.valid)
			renderBillboard(fleetIcon.sheet, fleetIcon.index, node.abs_position, node.scale * 2.0, rot);
		else
			renderBillboard(spritesheet::ShipGroupIcons, 0, node.abs_position, node.scale * 2.0, rot);
	}
};
