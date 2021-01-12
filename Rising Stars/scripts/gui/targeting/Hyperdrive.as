import resources;
import ftl;
from obj_selection import selectedObject, selectedObjects, getSelectionPosition, getSelectionScale, FTL_BEAM_COLOR;
import targeting.PointTarget;
import targeting.targeting;
from targeting.MoveTarget import getFleetTargetPositions;

class HyperdriveTarget : PointTarget {
	double cost = 0.0;
	Object@ obj;
	array<vec3d>@ offsets;
	array<uint> invalidObjs;
	array<uint> validObjs;
	array<Object@> objs;
	bool isInstant;

	HyperdriveTarget(Object@ Obj, bool IsInstant) {
		@obj = Obj;
		objs = selectedObjects;
		isInstant = IsInstant;
	}

	vec3d get_origin() override {
		if(shiftKey) {
			Object@ obj = selectedObject;
			if(obj is null)
				return vec3d();
			return obj.finalMoveDestination;
		}
		else {
			return getSelectionPosition(true);
		}
	}

	bool hover(const vec2i& mpos) override {
		PointTarget::hover(mpos);

		//if(selectedObjects.length > 1) {
			auto@ positions = getFleetTargetPositions(objs, hovered);
			cost = 0;
			invalidObjs.length = 0;
			validObjs.length = 0;
			for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
				Object@ obj = objs[i];
				if(canHyperdrive(obj)) {
					validObjs.insertLast(i);
					if(isInstant) 
						cost += hyperdriveInstantCost(obj, positions[i]);
					else
						cost += hyperdriveCost(obj, positions[i]);
				}
				else if(obj.hasLeaderAI) {
					invalidObjs.insertLast(i);
				}
			}
			range = cost > playerEmpire.FTLStored ? 0.0 : INFINITY;
		//}
		//else {
		//	range = hyperdriveRange(obj);
		//	cost = hyperdriveCost(obj, hovered);
		//}
		return distance <= range || shiftKey;
	}

	bool click() override {
		return distance <= range || shiftKey;
	}
};

class HyperdriveDisplay : PointDisplay {
	void draw(TargetMode@ mode) override {
		PointDisplay::draw(mode);

		HyperdriveTarget@ ht = cast<HyperdriveTarget>(mode);
		if(ht is null)
			return;

		Color color;
		if(ht.distance <= ht.range && ht.valid)
			color = colors::Green;
		else
			color = colors::Red;

		auto@ reg = getRegion(ht.hovered);
		string text = locale::FTL_COST_INDICATOR;
		if(isFTLBlocked(ht.obj, ht.hovered))
			text = locale::FTL_COST_INDICATOR_JAMMED;

		font::DroidSans_11_Bold.draw(mousePos + vec2i(16, 0),
			format(text,
				int(ht.cost),
				ht.distance,
				reg !is null ? reg.name : ""
				),
			color);
		
		if(ht.distance > ht.range) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSUFFICIENT_FTL,
				color);
		}
		else {
			// Keeping the old Hyperfield Sequencing implementation
			// intact, just in case.
			if(playerEmpire.HyperdriveNeedCharge == 0 || ht.isInstant) {
				font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
					locale::INSTANT_HYPERJUMP,
					color);
			}
			else {
				double avgChargeTime = 0;
				double chargeTime = 0;
				bool suppressed = false;
				bool combat = true;
				for(uint i = 0, cnt = ht.validObjs.length; i < cnt; ++i) {
					Object@ obj = ht.objs[ht.validObjs[i]];
					chargeTime = HYPERDRIVE_CHARGE_TIME;
					if(!obj.inCombat) {
						chargeTime *= 0.5;
						combat = false;
					}
					if(isFTLSuppressed(obj)) {
						chargeTime *= 2;
						suppressed = true;
					}
					avgChargeTime += chargeTime;
				}
				avgChargeTime /= ht.validObjs.length;
				text = locale::AVG_HYPERJUMP_TIME;
				if(suppressed) {
					if(combat) text = locale::AVG_HYPERJUMP_TIME_SUPPRESSED_COMBAT;
					else text = locale::AVG_HYPERJUMP_TIME_SUPPRESSED;
				}
				else if(combat) text = locale::AVG_HYPERJUMP_TIME_COMBAT;
				font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
					format(text, formatTime(avgChargeTime)),
					FTL_BEAM_COLOR);
			}
		}
		for(uint i = 0, cnt = ht.invalidObjs.length; i < cnt; ++i) {
			Object@ obj = ht.objs[ht.invalidObjs[i]];
			vec2i drawPos = mousePos + vec2i(16, 32 + 16*i);
			if(isFTLBlocked(obj))
				text = locale::FTL_JAMMED_ORIGIN;
			else text = locale::NO_FTL_DRIVE;
			font::OpenSans_11_Italic.draw(drawPos, format(text, obj.name), colors::Red);
		}
	}

	void render(TargetMode@ mode) override {
		inColor = Color(0x00c0ffff);
		if(shiftKey)
			outColor = Color(0xffe400ff);
		else
			outColor = colors::Red;
		PointDisplay::render(mode);
	}
};

class HyperdriveCB : TargetCallback {
	bool isInstant;

	HyperdriveCB(bool IsInstant) {
		isInstant = IsInstant;
	}

	void call(TargetMode@ mode) override {
		bool anyDidFTL = false;
		Object@[] selection = selectedObjects;
		auto@ positions = getFleetTargetPositions(selection, mode.position);
		for(uint i = 0, cnt = selection.length; i < cnt; ++i) {
			Object@ obj = selection[i];
			if(!obj.hasMover || !obj.hasLeaderAI || !canHyperdrive(obj))
				continue;
			anyDidFTL = true;
			obj.addHyperdriveOrder(positions[i], shiftKey || obj.inFTL, isInstant);
		}
		
		if(anyDidFTL)
			sound::order_hyperdrive.play(priority=true);
		
		if(shiftKey) {
			HyperdriveTarget targ(selectedObject, isInstant);
			targ.isShifted = true;
			HyperdriveDisplay disp;
			HyperdriveCB cb(isInstant);
			startTargeting(targ, disp, cb);
		}
	}
};

void targetHyperdrive() {
	targetHyperdriveImpl(false);
}

void targetInstantHyperdrive() {
	targetHyperdriveImpl(true);
}

void targetHyperdriveImpl(bool isInstant) {
	HyperdriveTarget targ(selectedObject, isInstant);
	HyperdriveDisplay disp;
	HyperdriveCB cb(isInstant);

	startTargeting(targ, disp, cb);
}
