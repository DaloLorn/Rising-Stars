import resources;
import ftl;
from obj_selection import selectedObject, selectedObjects, getSelectionPosition, getSelectionScale, FTL_BEAM_COLOR;
import targeting.PointTarget;
import targeting.targeting;
from targeting.MoveTarget import getFleetTargetPositions;
import system_flags;

class JumpdriveTarget : PointTarget {
	double cost = 0.0;
	Object@ obj;
	array<uint> invalidObjs;
	array<uint> validObjs;
	array<Object@> objs;

	JumpdriveTarget(Object@ obj) {
		@this.obj = obj;
		objs = selectedObjects;
		range = INFINITY;
	}

	vec3d get_origin() override {
		if(shiftKey) {
			Object@ obj = selectedObject;
			return obj.finalMoveDestination;
		}
		else {
			return getSelectionPosition(true);
		}
	}

	bool hover(const vec2i& mpos) override {
		//if(selectedObjects.length > 1) {
			auto@ positions = getFleetTargetPositions(objs, hovered, isFTL=true);
			cost = 0;
			invalidObjs.length = 0;
			for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
				Object@ obj = objs[i];
				if(canJumpdrive(obj)) {
					validObjs.insertLast(i);
					cost += jumpdriveCost(obj, positions[i]);
				}
				else if(obj.hasLeaderAI) {
					invalidObjs.insertLast(i);
				}
			}
		//}
		//else {
		//	cost = jumpdriveCost(obj, hovered);
		//}
		if(cost <= playerEmpire.FTLStored)
			range = INFINITY;
		else
			range = 0;
		PointTarget::hover(mpos);
		return canJumpdriveTo(obj, hovered) && (distance <= range || shiftKey);
	}

	bool click() override {
		return shiftKey || distance <= range;
	}
};

class JumpdriveDisplay : PointDisplay {
	PlaneNode@ range;
	double jumpRange;

	~JumpdriveDisplay() {
		if(range !is null) {
			range.visible = false;
			range.markForDeletion();
			@range = null;
		}
	}

	void draw(TargetMode@ mode) override {
		PointDisplay::draw(mode);

		JumpdriveTarget@ ht = cast<JumpdriveTarget>(mode);
		if(ht is null)
			return;

		if(range is null) {
			jumpRange = cast<Ship>(ht.obj).blueprint.getEfficiencySum(SV_JumpRange);
			@range = PlaneNode(material::RangeCircle, jumpRange);
			range.visible = false;
			range.position = ht.obj.node_position;
			range.rebuildTransform();
			range.color = Color(0xff2b0cff);
			range.visible = true;
		}

		bool isSafe = false;
		Region@ reg = getRegion(ht.hovered);
		if(reg !is null)
			isSafe = reg.getSystemFlag(playerEmpire, safetyFlag);

		Color color;
		if(!ht.valid || ht.cost > playerEmpire.FTLStored)
			color = colors::Red;
		else if(ht.distance >= jumpRange && !isSafe)
			color = colors::Orange;
		else
			color = colors::Green;

		string text = locale::FTL_COST_INDICATOR;

		font::DroidSans_11_Bold.draw(mousePos + vec2i(16, 0),
			format(text,
				int(ht.cost),
				ht.distance
				),
			color);
		
		int y = 16;
		if(ht.cost > playerEmpire.FTLStored) {
			y += 16;
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSUFFICIENT_FTL,
				color);
		}
		else if(isFTLBlocked(ht.obj, ht.hovered)) {
			y += 16;
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				format(locale::FTL_JAMMED_DESTINATION, reg.name),
				colors::Red);
		}
		else if(ht.distance >= jumpRange && !isSafe) {
			y += 16;
			if(ht.distance >= jumpRange * 2.0) {
				font::DroidSans_11_Bold.draw(mousePos + vec2i(16, 16),
					locale::JUMPDRIVE_SAFETY_WARNING_SEVERE,
					Color(0xff0000ff));
			}
			else {
				font::DroidSans_11.draw(mousePos + vec2i(16, 16),
					locale::JUMPDRIVE_SAFETY_WARNING,
					Color(0xff0000ff));
			}
		}

		double avgChargeTime = 0;
		double chargeTime = 0;
		bool suppressed = false;
		bool doubleSuppressed = false;
		bool combat = true;
		for(uint i = 0, cnt = ht.validObjs.length; i < cnt; ++i) {
			Object@ obj = ht.objs[ht.validObjs[i]];
			chargeTime = jumpdriveChargeTime(obj, ht.hovered);
			if(!obj.inCombat) {
				chargeTime *= 0.5;
				combat = false;
			}
			if(isFTLSuppressed(obj)) {
				suppressed = true;
			}
			if(isFTLSuppressed(obj, ht.hovered)) {
				doubleSuppressed = suppressed;
				suppressed = true;
			}
			if(doubleSuppressed)
				chargeTime *= 8;
			else if(suppressed)
				chargeTime *= 4;
			avgChargeTime += chargeTime;
		}
		text = locale::AVG_HYPERJUMP_TIME;
		if(doubleSuppressed) {
			if(combat) text = locale::AVG_HYPERJUMP_TIME_DOUBLE_SUPPRESSED_COMBAT;
			else text = locale::AVG_HYPERJUMP_TIME_DOUBLE_SUPPRESSED;
		}
		else if(suppressed) {
			if(combat) text = locale::AVG_HYPERJUMP_TIME_SUPPRESSED_COMBAT;
			else text = locale::AVG_HYPERJUMP_TIME_SUPPRESSED;
		}
		else if(combat) text = locale::AVG_HYPERJUMP_TIME_COMBAT;
		font::OpenSans_11_Italic.draw(mousePos + vec2i(16, y),
			format(text, formatTime(avgChargeTime)),
			FTL_BEAM_COLOR);

		for(uint i = 0, cnt = ht.invalidObjs.length; i < cnt; ++i) {
			Object@ obj = ht.objs[ht.invalidObjs[i]];
			vec2i drawPos = mousePos + vec2i(16, y + 16*i);
			if(isFTLBlocked(obj))
				text = locale::FTL_JAMMED_ORIGIN;
			else text = locale::NO_FTL_DRIVE;
			font::OpenSans_11_Italic.draw(drawPos, format(text, obj.name), colors::Red);
		}
	}

	void render(TargetMode@ mode) override {
		JumpdriveTarget@ ht = cast<JumpdriveTarget>(mode);
		if(ht !is null && range !is null) {
			range.position = ht.obj.node_position;
			range.rebuildTransform();
		}
		PointDisplay::render(mode);
	}
};

class JumpdriveCB : TargetCallback {
	void call(TargetMode@ mode) override {
		bool anyFTL = false;
		Object@[] selection = selectedObjects;
		auto@ positions = getFleetTargetPositions(selection, mode.position, isFTL=true);
		for(uint i = 0, cnt = selection.length; i < cnt; ++i) {
			Object@ obj = selection[i];
			if(!obj.hasMover || !obj.hasLeaderAI || !canJumpdrive(obj))
				continue;
			obj.addJumpdriveOrder(positions[i], shiftKey || obj.inFTL);
			anyFTL = true;
		}
		
		if(anyFTL)
			sound::order_fling.play(priority=true);
	}
};

void targetJumpdrive() {
	Object@ sel = selectedObject;
	if(sel.owner is null || !sel.owner.valid)
		return;
	if(!selectedObject.isShip)
		return;

	JumpdriveTarget targ(selectedObject);
	JumpdriveDisplay disp;
	JumpdriveCB cb;

	startTargeting(targ, disp, cb);
}

int safetyFlag = -1;
void init() {
	safetyFlag = getSystemFlag("JumpdriveSafety");
}
