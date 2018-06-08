#include "include/map.as"
//AUTO GENERATED FILE
// Formatted and slightly fixed by Dalo Lorn
enum MapSetting {
	M_Scale
};

#section all

class PreciousClouds : Map {
	PreciousClouds() {
		super();

		name = "Precious Clouds (4)";
		description = locale::PRECIOUS_CLOUDS_DESC;

		color = 0x00e9ffff;
		sortIndex = 1000;
	}

#section client
	void makeSettings() {
		Number("Scale", M_Scale, 1, decimals=0, step=1, min=1, halfWidth=true);
		Description("[color=#aaa][i]" + description +"[/i][/color]", lines=3);
	}

#section server
	void placeSystems() {
		double scale = getSetting(M_Scale, 1) * 20;

		autoGenerateLinks = false;
		auto@ bh0 = getSystemType("EconomicNebula");
		auto@ sys0 = addSystem(vec3d(131600*scale,0,45600*scale),150,false,bh0.id);
		auto@ bh1 = getSystemType("EconomicNebula");
		auto@ sys1 = addSystem(vec3d(141800*scale,0,65800*scale),150,false,bh1.id);
		auto@ bh2 = getSystemType("EconomicNebula");
		auto@ sys2 = addSystem(vec3d(66600*scale,0,27200*scale),150,false,bh2.id);
		auto@ bh3 = getSystemType("EconomicNebula");
		auto@ sys3 = addSystem(vec3d(87200*scale,0,30600*scale),150,false,bh3.id);
		auto@ bh4 = getSystemType("EconomicNebula");
		auto@ sys4 = addSystem(vec3d(58600*scale,0,90600*scale),150,false,bh4.id);
		auto@ bh5 = getSystemType("EconomicNebula");
		auto@ sys5 = addSystem(vec3d(53000*scale,0,74400*scale),150,false,bh5.id);
		auto@ bh6 = getSystemType("EconomicNebula");
		auto@ sys6 = addSystem(vec3d(110200*scale,0,109400*scale),150,false,bh6.id);
		auto@ bh7 = getSystemType("EconomicNebula");
		auto@ sys7 = addSystem(vec3d(127800*scale,0,94600*scale),150,false,bh7.id);
		auto@ bh8 = getSystemType("RadioactiveNebula");
		auto@ sys8 = addSystem(vec3d(90200*scale,0,72400*scale),150,false,bh8.id);
		auto@ bh9 = getSystemType("EconomicNebula");
		auto@ sys9 = addSystem(vec3d(86800*scale,0,53400*scale),150,false,bh9.id);
		auto@ bh10 = getSystemType("EconomicNebula");
		auto@ sys10 = addSystem(vec3d(111000*scale,0,66000*scale),150,false,bh10.id);
		auto@ bh11 = getSystemType("RadioactiveNebula");
		auto@ sys11 = addSystem(vec3d(97800*scale,0,59800*scale),150,false,bh11.id);
		auto@ bh12 = getSystemType("EconomicNebula");
		auto@ sys12 = addSystem(vec3d(98000*scale,0,82400*scale),150,false,bh12.id);
		auto@ bh13 = getSystemType("EconomicNebula");
		auto@ sys13 = addSystem(vec3d(81600*scale,0,65800*scale),150,false,bh13.id);
		auto@ bh14 = getSystemType("EconomicNebula");
		auto@ sys14 = addSystem(vec3d(80200*scale,0,75400*scale),150,false,bh14.id);
		auto@ bh15 = getSystemType("EconomicNebula");
		auto@ sys15 = addSystem(vec3d(84200*scale,0,83600*scale),150,false,bh15.id);
		auto@ bh16 = getSystemType("EconomicNebula");
		auto@ sys16 = addSystem(vec3d(94600*scale,0,50600*scale),150,false,bh16.id);
		auto@ bh17 = getSystemType("EconomicNebula");
		auto@ sys17 = addSystem(vec3d(107600*scale,0,56000*scale),150,false,bh17.id);
		auto@ bh18 = getSystemType("RemnantBase");
		auto@ sys18 = addSystem(vec3d(94400*scale,0,66200*scale),150,false,bh18.id);
		auto@ sys19 = addSystem(vec3d(153800*scale,0,46600*scale),150,false);
		addPossibleHomeworld(sys19);
		auto@ sys20 = addSystem(vec3d(77600*scale,0,16600*scale),150,false);
		addPossibleHomeworld(sys20);
		auto@ sys21 = addSystem(vec3d(44800*scale,0,95000*scale),150,false);
		addPossibleHomeworld(sys21);
		auto@ bh22 = getSystemType("RemnantBase");
		auto@ sys22 = addSystem(vec3d(130200*scale,0,106200*scale),150,false,bh22.id);
		addPossibleHomeworld(sys22);
		auto@ sys23 = addSystem(vec3d(59600*scale,0,100000*scale),150,false);
		auto@ sys24 = addSystem(vec3d(42000*scale,0,79800*scale),150,false);
		auto@ sys25 = addSystem(vec3d(34400*scale,0,98400*scale),150,false);
		auto@ sys26 = addSystem(vec3d(49200*scale,0,102800*scale),150,false);
		auto@ sys27 = addSystem(vec3d(39800*scale,0,89600*scale),150,false);
		auto@ sys28 = addSystem(vec3d(65800*scale,0,20600*scale),150,false);
		auto@ sys29 = addSystem(vec3d(77600*scale,0,24800*scale),150,false);
		auto@ sys30 = addSystem(vec3d(73200*scale,0,11600*scale),150,false);
		auto@ sys31 = addSystem(vec3d(101400*scale,0,11600*scale),150,false);
		auto@ sys32 = addSystem(vec3d(87200*scale,0,18400*scale),150,false);
		auto@ sys33 = addSystem(vec3d(124000*scale,0,115600*scale),150,false);
		auto@ sys34 = addSystem(vec3d(123400*scale,0,103000*scale),150,false);
		auto@ sys35 = addSystem(vec3d(137200*scale,0,112600*scale),150,false);
		auto@ sys36 = addSystem(vec3d(145200*scale,0,103400*scale),150,false);
		auto@ sys37 = addSystem(vec3d(142600*scale,0,116600*scale),150,false);
		auto@ bh38 = getSystemType("RemnantBase");
		auto@ sys38 = addSystem(vec3d(114600*scale,0,98600*scale),150,false,bh38.id);
		auto@ bh39 = getSystemType("RemnantBase");
		auto@ sys39 = addSystem(vec3d(109000*scale,0,89800*scale),150,false,bh39.id);
		auto@ bh40 = getSystemType("RemnantBase");
		auto@ sys40 = addSystem(vec3d(61800*scale,0,83400*scale),150,false,bh40.id);
		auto@ bh41 = getSystemType("RemnantBase");
		auto@ sys41 = addSystem(vec3d(70200*scale,0,79600*scale),150,false,bh41.id);
		auto@ bh42 = getSystemType("RemnantBase");
		auto@ sys42 = addSystem(vec3d(76000*scale,0,38200*scale),150,false,bh42.id);
		auto@ bh43 = getSystemType("RemnantBase");
		auto@ sys43 = addSystem(vec3d(85400*scale,0,43400*scale),150,false,bh43.id);
		auto@ bh44 = getSystemType("RemnantBase");
		auto@ sys44 = addSystem(vec3d(132200*scale,0,56800*scale),150,false,bh44.id);
		auto@ bh45 = getSystemType("RemnantBase");
		auto@ sys45 = addSystem(vec3d(122600*scale,0,57400*scale),150,false,bh45.id);
		auto@ sys46 = addSystem(vec3d(158000*scale,0,56400*scale),150,false);
		auto@ sys47 = addSystem(vec3d(149400*scale,0,40600*scale),150,false);
		auto@ sys48 = addSystem(vec3d(159800*scale,0,39200*scale),150,false);
		auto@ sys49 = addSystem(vec3d(154200*scale,0,51600*scale),150,false);
		auto@ sys50 = addSystem(vec3d(161600*scale,0,48600*scale),150,false);
		addLink(sys37, sys35);
		addLink(sys33, sys22);
		addLink(sys22, sys35);
		addLink(sys22, sys36);
		addLink(sys22, sys34);
		addLink(sys34, sys6);
		addLink(sys34, sys7);
		addLink(sys38, sys34);
		addLink(sys42, sys29);
		addLink(sys29, sys2);
		addLink(sys29, sys3);
		addLink(sys20, sys28);
		addLink(sys30, sys20);
		addLink(sys32, sys31);
		addLink(sys32, sys20);
		addLink(sys20, sys29);
		addLink(sys43, sys9);
		addLink(sys43, sys16);
		addLink(sys42, sys43);
		addLink(sys16, sys11);
		addLink(sys9, sys11);
		addLink(sys17, sys11);
		addLink(sys10, sys11);
		addLink(sys45, sys17);
		addLink(sys17, sys10);
		addLink(sys16, sys17);
		addLink(sys9, sys16);
		addLink(sys10, sys45);
		addLink(sys45, sys44);
		addLink(sys44, sys49);
		addLink(sys0, sys49);
		addLink(sys1, sys49);
		addLink(sys19, sys50);
		addLink(sys46, sys49);
		addLink(sys19, sys47);
		addLink(sys19, sys48);
		addLink(sys19, sys49);
		addLink(sys11, sys18);
		addLink(sys8, sys18);
		addLink(sys8, sys13);
		addLink(sys13, sys14);
		addLink(sys15, sys12);
		addLink(sys12, sys8);
		addLink(sys14, sys15);
		addLink(sys15, sys8);
		addLink(sys14, sys8);
		addLink(sys12, sys10);
		addLink(sys13, sys9);
		addLink(sys39, sys38);
		addLink(sys39, sys12);
		addLink(sys39, sys15);
		addLink(sys40, sys41);
		addLink(sys41, sys14);
		addLink(sys41, sys13);
		addLink(sys21, sys27);
		addLink(sys27, sys24);
		addLink(sys21, sys25);
		addLink(sys21, sys26);
		addLink(sys21, sys23);
		addLink(sys27, sys4);
		addLink(sys27, sys5);
		addLink(sys27, sys40);
	}
#section all
};
