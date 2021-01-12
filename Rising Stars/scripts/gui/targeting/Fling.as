import resources;
import ftl;
from obj_selection import selectedObject, selectedObjects, getSelectionPosition, getSelectionScale, FTL_BEAM_COLOR;
import targeting.PointTarget;
import targeting.targeting;
from targeting.MoveTarget import getFleetTargetPositions;

class FlingTarget : PointTarget {
	double cost = 0.0;
	int scale = 1;
	Object@ obj;
	Object@ beacon;
	array<uint> invalidObjs;
	array<uint> validObjs;
	array<Object@> objs;
	bool inRange = false;
	bool isInstant = false;

	FlingTarget(Object@ beacon, Object@ obj, int totalScale, bool InRange, bool IsInstant = false) {
		@this.obj = obj;
		@this.beacon = beacon;
		scale = totalScale;
		inRange = InRange;
		isInstant = IsInstant;
		objs = selectedObjects;
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
		PointTarget::hover(mpos);
		//if(selectedObjects.length > 1) {
			auto@ positions = getFleetTargetPositions(objs, hovered, isFTL=true);
			cost = 0;
			invalidObjs.length = 0;
			validObjs.length = 0;
			for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
				Object@ obj = objs[i];
				if(canFling(obj)) {
					if(isInstant)
						cost += flingInstantCost(obj, positions[i]);
					else
						cost += flingCost(obj, positions[i]);
					validObjs.insertLast(i);
				}
				else if(obj.hasLeaderAI) {
					invalidObjs.insertLast(i);
				}
			}
			range = cost > playerEmpire.FTLStored ? 0.0 : INFINITY;
		//}
		//else {
		//	range = flingRange(obj);
		//	cost = flingCost(obj, hovered);
		//}
		if(shiftKey)
			return canFlingTo(obj, hovered);
		if(beacon is null || !inRange)
			return false;
		return distance <= range;
	}

	bool click() override {
		return shiftKey || (beacon !is null && inRange && distance <= range);
	}
};

class FlingDisplay : PointDisplay {
	PlaneNode@ range;

	~FlingDisplay() {
		if(range !is null) {
			range.visible = false;
			range.markForDeletion();
			@range = null;
		}
	}

	void draw(TargetMode@ mode) override {
		PointDisplay::draw(mode);

		FlingTarget@ ht = cast<FlingTarget>(mode);
		if(ht is null)
			return;

		if(range is null && ht.beacon !is null) {
			@range = PlaneNode(material::RangeCircle, FLING_BEACON_RANGE);
			range.visible = false;
			range.position = ht.beacon.node_position;
			range.rebuildTransform();
			range.color = Color(0x2bff0cff);
			range.visible = true;
		}

		Color color;
		if(ht.distance <= ht.range && ht.inRange && ht.valid)
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
		
		if(ht.beacon is null) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::NEED_FLING_BEACON,
				color);
		}
		else if(!ht.inRange) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::OUT_OF_BEACON_RANGE,
				color);
		}
		else if(ht.distance > ht.range) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSUFFICIENT_FTL,
				color);
		}
		else if(ht.isInstant) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSTANT_HYPERJUMP,
				FTL_BEAM_COLOR);
		}
		else {
			double avgChargeTime = 0;
			double chargeTime = 0;
			bool suppressed = false;
			for(uint i = 0, cnt = ht.validObjs.length; i < cnt; ++i) {
				Object@ obj = ht.objs[ht.validObjs[i]];
				chargeTime = FLING_CHARGE_TIME;
				if(isFTLSuppressed(obj)) {
					chargeTime *= 2;
					suppressed = true;
				}
				avgChargeTime += chargeTime;
			}
			avgChargeTime /= ht.validObjs.length;
			text = locale::AVG_HYPERJUMP_TIME;
			if(suppressed) 
				text = locale::AVG_HYPERJUMP_TIME_SUPPRESSED;
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				format(text, formatTime(avgChargeTime)),
				FTL_BEAM_COLOR);
		}
		for(uint i = 0, cnt = ht.invalidObjs.length; i < cnt; ++i) {
			Object@ obj = ht.objs[ht.invalidObjs[i]];
			vec2i drawPos = mousePos + vec2i(16, 32 + 16*i);
			if(isFTLBlocked(obj))
				text = locale::FTL_JAMMED_ORIGIN;
			else text = locale::UNFLINGABLE_OBJECT;
			font::OpenSans_11_Italic.draw(drawPos, format(text, obj.name), colors::Red);
		}
	}

	void render(TargetMode@ mode) override {
		inColor = Color(0x00c0ffff);
		if(shiftKey)
			outColor = Color(0xffe400ff);
		else
			outColor = colors::Red;
		FlingTarget@ ht = cast<FlingTarget>(mode);
		if(ht !is null && range !is null && ht.beacon !is null) {
			range.position = ht.beacon.node_position;
			range.rebuildTransform();
		}
		PointDisplay::render(mode);
	}
};

class FlingCB : TargetCallback {
	Object@ beacon;
	bool isInstant;

	FlingCB(Object@ beacon, bool IsInstant) {
		@this.beacon = beacon;
		isInstant = IsInstant;
	}

	void call(TargetMode@ mode) override {
		if(beacon is null)
			return;
		
		bool anyFlung = false;
		Object@[] selection = selectedObjects;
		auto@ positions = getFleetTargetPositions(selection, mode.position, isFTL=true);
		for(uint i = 0, cnt = selection.length; i < cnt; ++i) {
			Object@ obj = selection[i];
			if(!obj.hasMover || !obj.hasLeaderAI || !canFling(obj))
				continue;
			obj.addFlingOrder(beacon, positions[i], shiftKey || obj.inFTL, isInstant);
			anyFlung = true;
		}
		
		if(anyFlung)
			sound::order_fling.play(priority=true);
	}
};

void targetFling() {
	targetFlingImpl(false);
}

void targetFlingImpl(bool isInstant) {
	Object@ sel = selectedObject;
	if(sel.owner is null || !sel.owner.valid)
		return;

	Object@ beacon = sel.owner.getClosestFlingBeacon(sel);

	FlingTarget targ(beacon, selectedObject, max(getSelectionScale(), 1),
					beacon !is null && beacon.position.distanceToSQ(sel.position) <= FLING_BEACON_RANGE_SQ, isInstant);
	FlingDisplay disp;
	FlingCB cb(beacon, isInstant);

	startTargeting(targ, disp, cb);
}

void targetInstantFling() {
	targetFlingImpl(true);
}