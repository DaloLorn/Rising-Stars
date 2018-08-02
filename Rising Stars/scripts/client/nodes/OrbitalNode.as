import orbitals;
from nodes.FleetPlane import SHOW_FLEET_PLANES;

// DOF - Scaling: Make the viewable icon larger
const double MAX_SIZE = 10000.0;

final class OrbitalNodeScript {
	const Orbital@ obj;
	const OrbitalModule@ def;
	double fleetPlane = 0.0;

	OrbitalNodeScript(Node& node) {
		node.transparent = true;
		node.memorable = true;
		//DOF - Disable AutoCulling
		//node.autoCull = false;
	}
	
	void establish(Node& node, Orbital& orbital, uint type) {
		@obj = orbital;
		@def = getOrbitalModule(type);
	}

	void setFleetPlane(double radius) {
		fleetPlane = radius;
	}

	void render(Node& node) {
		if(def is null)
			return;

		// Dolynick: Distance at which the icon is displaced and how it scales?

		// Dalo: My best guess is that this actually governs the 'fleet plane',
		// the circle that displays the area across which support ships will spread out.
		if(fleetPlane != 0 && node.sortDistance < 2000.0 && node.sortDistance >= 150.0 && SHOW_FLEET_PLANES) {
			Color color(0xffffff14);
			// DOF - Scaling
			if(node.sortDistance < 500.0)
				color.a = double(color.a) * (node.sortDistance - 150.0) / 100.0;
			renderPlane(material::FleetCircle, node.abs_position, fleetPlane, color);
		}
	
		node.applyTransform();
		
		def.material.switchTo();
		def.model.draw();
		
		/*if(obj.Shield > 0) {*/
		/*	shader::SHIELD_STRENGTH = float(obj.Shield / obj.MaxShield);*/
		/*	material::Shield.switchTo();*/
		/*	def.model.draw();*/
		/*}*/
		
		undoTransform();

		// DOF - Scaling: Range at which icon disappears for model view
		if(node.sortDistance > 1000.0 && def.distantIcon.valid) {
			double size = obj.radius * def.iconSize;
			size *= node.sortDistance * 0.09;
			size = min(size, MAX_SIZE);
			if(obj.selected)
				size *= 1.1;

			Empire@ owner = obj.owner;
			Color col;
			if(owner !is null)
				col = owner.color;
			renderBillboard(def.distantIcon.sheet, def.distantIcon.index, node.abs_position, size, 0.0, col);
		}
	}
};
