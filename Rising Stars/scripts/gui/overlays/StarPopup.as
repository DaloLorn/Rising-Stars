import overlays.Popup;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.Gui3DObject;
import elements.GuiProgressbar;
import elements.MarkupTooltip;
import icons;
import statuses;
from overlays.ContextMenu import openContextMenu;

class StarPopup : Popup {
	GuiText@ name;
	Gui3DObject@ objView;
	Star@ obj;
	double lastUpdate = -INFINITY;

	array<GuiSprite@> statusIcons;
	GuiSprite@ defIcon;

	GuiProgressbar@ health;
	GuiProgressbar@ shield;

	StarPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(190, 155);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, recti(34, 26, 156, 98));

		@defIcon = GuiSprite(this, Alignment(Left+4, Top+25, Width=40, Height=40));
		defIcon.desc = icons::Defense;
		setMarkupTooltip(defIcon, locale::TT_IS_DEFENDING);
		defIcon.visible = false;

		@health = GuiProgressbar(this, Alignment(Left+3, Bottom-56, Right-4, Bottom-30));
		health.tooltip = locale::HEALTH;

		auto@ healthIcon = GuiSprite(health, Alignment(Left+2, Top+1, Width=24, Height=24), icons::Health);
		
		@shield = GuiProgressbar(this, Alignment(Left+3, Bottom-30, Right-4, Bottom-4));
		shield.frontColor = Color(0x429cffff);
		shield.backColor = Color(0x59a8ff20);
		shield.tooltip = locale::SHIELD_STRENGTH;
		
		auto@ shieldIcon = GuiSprite(shield, Alignment(Left+2, Top+1, Width=24, Height=24), icons::Shield);
		shieldIcon.noClip = true;

		updateAbsolutePosition();
	}

	bool compatible(Object@ Obj) {
		return Obj.isStar;
	}

	void set(Object@ Obj) {
		@obj = cast<Star>(Obj);
		@objView.object = Obj;
		lastUpdate = -INFINITY;
	}

	Object@ get() {
		return obj;
	}

	void draw() {
		Popup::updatePosition(obj);
		recti bgPos = AbsolutePosition;

		uint flags = SF_Normal;
		SkinStyle style = SS_GenericPopupBG;
		if(isSelectable && Hovered)
			flags |= SF_Hovered;

		Color col;
		Region@ reg = obj.region;
		if(reg !is null) {
			Empire@ other = reg.visiblePrimaryEmpire;
			if(other !is null)
				col = other.color;
		}

		skin.draw(style, flags, bgPos, col);
		if(obj.owner !is null && obj.owner.flag !is null) {
			obj.owner.flag.draw(
				objView.absolutePosition.aspectAligned(1.0, horizAlign=1.0, vertAlign=1.0),
				obj.owner.color * Color(0xffffff30));
		}
		BaseGuiElement::draw();
	}

	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is objView) {
					dragging = false;
					if(!dragged) {
						switch(evt.value) {
							case OA_LeftClick:
								emitClicked(PA_Select);
								return true;
							case OA_RightClick:
								openContextMenu(obj);
								return true;
							case OA_MiddleClick:
							case OA_DoubleClick:
								if(isSelectable)
									emitClicked(PA_Select);
								else
									emitClicked(PA_Manage);
								return true;
						}
					}
				}
			break;
		}
		return Popup::onGuiEvent(evt);
	}

	float statusUpdate = 0.f;
	void update() {
		if(frameTime - 0.2 < lastUpdate)
			return;

		lastUpdate = frameTime;
		const Font@ ft = skin.getFont(FT_Normal);

		defIcon.visible = playerEmpire.isDefending(obj.region);

		//Update name
		name.text = obj.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		//Update health
		health.progress = obj.Health / obj.MaxHealth;
		health.frontColor = colors::Red.interpolate(colors::Green, health.progress);
		health.text = standardize(obj.Health)+" / "+standardize(obj.MaxHealth);
		if(obj.MaxShield != 0)
			shield.progress = obj.Shield / obj.MaxShield;
		else
			shield.progress = 0;
		shield.text = standardize(obj.Shield)+" / "+standardize(obj.MaxShield);
		
		statusUpdate -= frameLength;
		if(statusUpdate <= 0.f) {
			array<Status> statuses;
			if(obj.statusEffectCount > 0)
				statuses.syncFrom(obj.getStatusEffects());
			uint prevCnt = statusIcons.length, cnt = statuses.length;
			for(uint i = cnt; i < prevCnt; ++i)
				statusIcons[i].remove();
			statusIcons.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				auto@ icon = statusIcons[i];
				if(icon is null) {
					@icon = GuiSprite(this, recti_area(6, 25+25*i, 25, 25));
					@statusIcons[i] = icon;
				}

				auto@ status = statuses[i];
				icon.desc = status.type.icon;
				setMarkupTooltip(icon, format("[b]$1[/b]\n$2", status.type.name, status.type.description));
			}
			statusUpdate += 1.f;
		}

		Popup::update();
		Popup::updatePosition(obj);
	}
};
