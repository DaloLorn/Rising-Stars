#include "include/map.as"
//AUTO GENERATED FILE
enum MapSetting {
M_SystemCount,
M_SystemSpacing,
M_Flatten,
M_Bonus,
};

#section all

class PreciousClouds : Map {
	PreciousClouds() {
		super();

name = "Precious Clouds (4)";
description = "Resources are scarce within this sector of the galaxy; those who can reach and hold the rich nebula at its heart may take them all, but the Remnants do not part with these riches willingly...

Designed for up to four players. Recommended configurations: 2v2, 1v1, 1v1v1v1";

color = 0x00e9ffff;
sortIndex = 1000;
}

#section client
void makeSettings() {
Number("Scale", M_SystemSpacing, 1, decimals=0, step=1, min=1, halfWidth=true);
}

#section server
void placeSystems() {
autoGenerateLinks = false;
auto@ bh0 = getSystemType("EconomicNebula");
auto@ sys0 = addSystem(vec3d(658000*M_SystemSpacing,0,228000*M_SystemSpacing),150+M_Bonus,false,bh0.id);
auto@ bh1 = getSystemType("EconomicNebula");
auto@ sys1 = addSystem(vec3d(709000*M_SystemSpacing,0,329000*M_SystemSpacing),150+M_Bonus,false,bh1.id);
auto@ bh2 = getSystemType("EconomicNebula");
auto@ sys2 = addSystem(vec3d(333000*M_SystemSpacing,0,136000*M_SystemSpacing),150+M_Bonus,false,bh2.id);
auto@ bh3 = getSystemType("EconomicNebula");
auto@ sys3 = addSystem(vec3d(436000*M_SystemSpacing,0,153000*M_SystemSpacing),150+M_Bonus,false,bh3.id);
auto@ bh4 = getSystemType("EconomicNebula");
auto@ sys4 = addSystem(vec3d(293000*M_SystemSpacing,0,453000*M_SystemSpacing),150+M_Bonus,false,bh4.id);
auto@ bh5 = getSystemType("EconomicNebula");
auto@ sys5 = addSystem(vec3d(265000*M_SystemSpacing,0,372000*M_SystemSpacing),150+M_Bonus,false,bh5.id);
auto@ bh6 = getSystemType("EconomicNebula");
auto@ sys6 = addSystem(vec3d(551000*M_SystemSpacing,0,547000*M_SystemSpacing),150+M_Bonus,false,bh6.id);
auto@ bh7 = getSystemType("EconomicNebula");
auto@ sys7 = addSystem(vec3d(639000*M_SystemSpacing,0,473000*M_SystemSpacing),150+M_Bonus,false,bh7.id);
auto@ bh8 = getSystemType("RadioactiveNebula");
auto@ sys8 = addSystem(vec3d(451000*M_SystemSpacing,0,362000*M_SystemSpacing),150+M_Bonus,false,bh8.id);
auto@ bh9 = getSystemType("EconomicNebula");
auto@ sys9 = addSystem(vec3d(434000*M_SystemSpacing,0,267000*M_SystemSpacing),150+M_Bonus,false,bh9.id);
auto@ bh10 = getSystemType("EconomicNebula");
auto@ sys10 = addSystem(vec3d(555000*M_SystemSpacing,0,330000*M_SystemSpacing),150+M_Bonus,false,bh10.id);
auto@ bh11 = getSystemType("RadioactiveNebula");
auto@ sys11 = addSystem(vec3d(489000*M_SystemSpacing,0,299000*M_SystemSpacing),150+M_Bonus,false,bh11.id);
auto@ bh12 = getSystemType("EconomicNebula");
auto@ sys12 = addSystem(vec3d(490000*M_SystemSpacing,0,412000*M_SystemSpacing),150+M_Bonus,false,bh12.id);
auto@ bh13 = getSystemType("EconomicNebula");
auto@ sys13 = addSystem(vec3d(408000*M_SystemSpacing,0,329000*M_SystemSpacing),150+M_Bonus,false,bh13.id);
auto@ bh14 = getSystemType("EconomicNebula");
auto@ sys14 = addSystem(vec3d(401000*M_SystemSpacing,0,377000*M_SystemSpacing),150+M_Bonus,false,bh14.id);
auto@ bh15 = getSystemType("EconomicNebula");
auto@ sys15 = addSystem(vec3d(421000*M_SystemSpacing,0,418000*M_SystemSpacing),150+M_Bonus,false,bh15.id);
auto@ bh16 = getSystemType("EconomicNebula");
auto@ sys16 = addSystem(vec3d(473000*M_SystemSpacing,0,253000*M_SystemSpacing),150+M_Bonus,false,bh16.id);
auto@ bh17 = getSystemType("EconomicNebula");
auto@ sys17 = addSystem(vec3d(538000*M_SystemSpacing,0,280000*M_SystemSpacing),150+M_Bonus,false,bh17.id);
auto@ bh18 = getSystemType("RemnantBase");
auto@ sys18 = addSystem(vec3d(472000*M_SystemSpacing,0,331000*M_SystemSpacing),150+M_Bonus,false,bh18.id);
auto@ sys19 = addSystem(vec3d(769000*M_SystemSpacing,0,233000*M_SystemSpacing),150+M_Bonus,false);
addPossibleHomeworld(sys19);
auto@ sys20 = addSystem(vec3d(388000*M_SystemSpacing,0,83000*M_SystemSpacing),150+M_Bonus,false);
addPossibleHomeworld(sys20);
auto@ sys21 = addSystem(vec3d(224000*M_SystemSpacing,0,475000*M_SystemSpacing),150+M_Bonus,false);
addPossibleHomeworld(sys21);
auto@ bh22 = getSystemType("RemnantBase");
auto@ sys22 = addSystem(vec3d(651000*M_SystemSpacing,0,531000*M_SystemSpacing),150+M_Bonus,false,bh22.id);
addPossibleHomeworld(sys22);
auto@ sys23 = addSystem(vec3d(298000*M_SystemSpacing,0,500000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys24 = addSystem(vec3d(210000*M_SystemSpacing,0,399000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys25 = addSystem(vec3d(172000*M_SystemSpacing,0,492000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys26 = addSystem(vec3d(246000*M_SystemSpacing,0,514000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys27 = addSystem(vec3d(199000*M_SystemSpacing,0,448000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys28 = addSystem(vec3d(329000*M_SystemSpacing,0,103000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys29 = addSystem(vec3d(388000*M_SystemSpacing,0,124000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys30 = addSystem(vec3d(366000*M_SystemSpacing,0,58000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys31 = addSystem(vec3d(507000*M_SystemSpacing,0,58000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys32 = addSystem(vec3d(436000*M_SystemSpacing,0,92000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys33 = addSystem(vec3d(620000*M_SystemSpacing,0,578000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys34 = addSystem(vec3d(617000*M_SystemSpacing,0,515000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys35 = addSystem(vec3d(686000*M_SystemSpacing,0,563000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys36 = addSystem(vec3d(726000*M_SystemSpacing,0,517000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys37 = addSystem(vec3d(713000*M_SystemSpacing,0,583000*M_SystemSpacing),150+M_Bonus,false);
auto@ bh38 = getSystemType("RemnantBase");
auto@ sys38 = addSystem(vec3d(573000*M_SystemSpacing,0,493000*M_SystemSpacing),150+M_Bonus,false,bh38.id);
auto@ bh39 = getSystemType("RemnantBase");
auto@ sys39 = addSystem(vec3d(545000*M_SystemSpacing,0,449000*M_SystemSpacing),150+M_Bonus,false,bh39.id);
auto@ bh40 = getSystemType("RemnantBase");
auto@ sys40 = addSystem(vec3d(309000*M_SystemSpacing,0,417000*M_SystemSpacing),150+M_Bonus,false,bh40.id);
auto@ bh41 = getSystemType("RemnantBase");
auto@ sys41 = addSystem(vec3d(351000*M_SystemSpacing,0,398000*M_SystemSpacing),150+M_Bonus,false,bh41.id);
auto@ bh42 = getSystemType("RemnantBase");
auto@ sys42 = addSystem(vec3d(380000*M_SystemSpacing,0,191000*M_SystemSpacing),150+M_Bonus,false,bh42.id);
auto@ bh43 = getSystemType("RemnantBase");
auto@ sys43 = addSystem(vec3d(427000*M_SystemSpacing,0,217000*M_SystemSpacing),150+M_Bonus,false,bh43.id);
auto@ bh44 = getSystemType("RemnantBase");
auto@ sys44 = addSystem(vec3d(661000*M_SystemSpacing,0,284000*M_SystemSpacing),150+M_Bonus,false,bh44.id);
auto@ bh45 = getSystemType("RemnantBase");
auto@ sys45 = addSystem(vec3d(613000*M_SystemSpacing,0,287000*M_SystemSpacing),150+M_Bonus,false,bh45.id);
auto@ sys46 = addSystem(vec3d(790000*M_SystemSpacing,0,282000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys47 = addSystem(vec3d(747000*M_SystemSpacing,0,203000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys48 = addSystem(vec3d(799000*M_SystemSpacing,0,196000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys49 = addSystem(vec3d(771000*M_SystemSpacing,0,258000*M_SystemSpacing),150+M_Bonus,false);
auto@ sys50 = addSystem(vec3d(808000*M_SystemSpacing,0,243000*M_SystemSpacing),150+M_Bonus,false);
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
