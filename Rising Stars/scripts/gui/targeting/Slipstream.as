import resources;
import ftl;
from obj_selection import selectedObject, selectedObjects, getSelectionPosition, getSelectionScale, FTL_BEAM_COLOR;
import targeting.PointTarget;
import targeting.targeting;

class SlipstreamTarget : PointTarget {
	double cost = 0.0;
	int scale = 1;
	Object@ obj;
	bool isInstant;

	SlipstreamTarget(Object@ obj, int totalScale, bool IsInstant) {
		@this.obj = obj;
		scale = totalScale;
		isInstant = IsInstant;
	}

	vec3d get_origin() override {
		if(shiftKey)
			return obj.finalMoveDestination;
		else
			return obj.position;
	}

	bool hover(const vec2i& mpos) override {
		PointTarget::hover(mpos);
		if(isInstant) {
			cost = slipstreamInstantCost(obj, scale, distance);
			range = slipstreamInstantRange(obj, scale, playerEmpire.FTLStored);
		}
		else {
			cost = slipstreamCost(obj, scale, distance);
			range = slipstreamRange(obj, scale, playerEmpire.FTLStored);
		}
		return canSlipstreamTo(obj, hovered) && (distance <= range || shiftKey);
	}

	double get_radius() override {
		if(isInstant)
			return slipstreamInstantInaccuracy(obj, hovered);
		else
			return slipstreamInaccuracy(obj, hovered);
	}

	bool click() override {
		return distance <= range || shiftKey;
	}
};

class SlipstreamDisplay : PointDisplay {
	void draw(TargetMode@ mode) override {
		PointDisplay::draw(mode);

		SlipstreamTarget@ ht = cast<SlipstreamTarget>(mode);
		if(ht is null)
			return;

		Color color;
		if(ht.distance <= ht.range && ht.valid)
			color = colors::Green;
		else
			color = colors::Red;

		string text = locale::FTL_COST_INDICATOR;

		font::DroidSans_11_Bold.draw(mousePos + vec2i(16, 0),
			format(text,
				int(ht.cost),
				ht.distance
				),
			color);
		
		if(ht.distance > ht.range) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSUFFICIENT_FTL,
				color);
		}
		else if(isFTLBlocked(ht.obj)) 
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				format(locale::FTL_JAMMED_ORIGIN, ht.obj.name),
				color);
		else if(isFTLBlocked(ht.obj, ht.hovered))
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				format(locale::FTL_JAMMED_DESTINATION, getRegion(ht.hovered).name),
				color);
		else {
			Object@ obj = ht.obj;
			double chargeTime = SLIPSTREAM_CHARGE_TIME;
			double lifetime = slipstreamLifetime(obj);
			string chargeText = locale::AVG_HYPERJUMP_TIME;
			string lifeText = locale::ESTIMATED_SLIPSTREAM_LIFETIME;
			if(ht.isInstant) {
				lifetime = slipstreamInstantLifetime(obj);
				chargeText = locale::INSTANT_HYPERJUMP;
			}
			bool suppressed = false, doubleSuppressed = false;
			if(isFTLSuppressed(obj)) {
				suppressed = true;
			}
			if(isFTLSuppressed(obj, ht.hovered)) {
				doubleSuppressed = suppressed;
				suppressed = true;
			}
			if(doubleSuppressed) {
				chargeTime *= 8;
				lifetime *= 0.125;
				chargeText = locale::AVG_HYPERJUMP_TIME_DOUBLE_SUPPRESSED;
				lifeText = locale::ESTIMATED_SLIPSTREAM_LIFETIME_DOUBLE_SUPPRESSED;
			}
			else if(suppressed) {
				chargeTime *= 4;
				lifetime *= 0.25;
				chargeText = locale::AVG_HYPERJUMP_TIME_SUPPRESSED;
				lifeText = locale::ESTIMATED_SLIPSTREAM_LIFETIME_SUPPRESSED;
			}
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				format(chargeText, formatTime(chargeTime)),
				FTL_BEAM_COLOR);
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 32),
				format(lifeText, formatTime(lifetime)),
				FTL_BEAM_COLOR);
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

class SlipstreamCB : TargetCallback {
	bool isInstant;

	SlipstreamCB(bool IsInstant) {
		isInstant = IsInstant;
	}

	void call(TargetMode@ mode) override {
		bool anyOpenedTear = false;
		Object@[]@ selection = selectedObjects;
		for(uint i = 0, cnt = selection.length; i < cnt; ++i) {
			Object@ obj = selection[i];
			if(!obj.hasMover || !obj.hasLeaderAI)
				continue;
			if(!canSlipstream(obj))
				continue;
			obj.addSlipstreamOrder(mode.position, shiftKey || obj.inFTL, isInstant);
			anyOpenedTear = true;
			for(uint j = 0; j < cnt; ++j) {
				if(i == j)
					continue;
				Object@ other = selection[j];
				if(!obj.hasMover || !obj.hasLeaderAI)
					continue;
				other.addWaitOrder(obj, shiftKey || obj.inFTL, moveTo=true);
				obj.addSecondaryToSlipstream(other);
			}
			break;
		}
		
		if(anyOpenedTear)
			sound::order_slipstream.play(priority=true);
	}
};

void targetSlipstream() {
	targetSlipstreamImpl(false);
}

void targetInstantSlipstream() {
	targetSlipstreamImpl(true);
}

void targetSlipstreamImpl(bool isInstant) {
	Object@ sel = selectedObject;
	for(uint i = 0, cnt = selectedObjects.length; i < cnt; ++i) {
		if(canSlipstream(selectedObjects[i])) {
			@sel = selectedObjects[i];
			break;
		}
	}
	if(sel.owner is null || !sel.owner.valid)
		return;
	if(!canSlipstream(sel))
		return;

	SlipstreamTarget targ(sel, max(getSelectionScale(), 1), isInstant);
	SlipstreamDisplay disp;
	SlipstreamCB cb(isInstant);

	startTargeting(targ, disp, cb);
}
