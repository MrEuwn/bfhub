--[[ data.lua - tables ported from the Redz V2 feature set (values as that source had them).
     Regenerate rather than hand-edit: a wrong CFrame teleports the player into the void. ]]

local D = {}

-- quests[sea] = { {minLv, maxLv, mob, questName, questNum, questCF, monCF|nil, waypoints|nil, team|nil} }
D.quests = {}
D.quests[1] = {
    { 1, 9, "Bandit", "BanditQuest1", 1, CFrame.new(1059, 17, 1546), nil, {CFrame.new(943, 45, 1562), CFrame.new(1115, 45, 1619), CFrame.new(1265, 45, 1606)}, "Pirates" },
    { 1, 9, "Trainee", "MarineQuest", 1, CFrame.new(-2708, 25, 2103), nil, {CFrame.new(-2754, 50, 2063), CFrame.new(-2950, 70, 2240)}, "Pirates" },
    { 10, 14, "Monkey", "JungleQuest", 1, CFrame.new(-1598, 37, 153), nil, {CFrame.new(-1524, 50, 37), CFrame.new(-1424, 50, 216), CFrame.new(-1554, 50, 359), CFrame.new(-1772, 50, 78), CFrame.new(-1715, 50, -61), CFrame.new(-1594, 50, -45)}, nil },
    { 15, 29, "The Gorilla King", "JungleQuest", 3, CFrame.new(-1598, 37, 153), CFrame.new(-1128, 6, -451), {CFrame.new(-1128, 40, -451), CFrame.new(-1313, 40, -546)}, nil },
    { 15, 29, "Gorilla", "JungleQuest", 2, CFrame.new(-1598, 37, 153), nil, {CFrame.new(-1128, 40, -451), CFrame.new(-1313, 40, -546)}, nil },
    { 30, 39, "Pirate", "BuggyQuest1", 1, CFrame.new(-1140, 4, 3829), nil, {CFrame.new(-1262, 40, 3905), CFrame.new(-1167, 40, 3942)}, nil },
    { 40, 59, "Bobby", "BuggyQuest1", 3, CFrame.new(-1140, 4, 3829), CFrame.new(-1131, 14, 4080), {CFrame.new(-976, 55, 4304), CFrame.new(-1196, 55, 4287), CFrame.new(-1363, 55, 4162)}, nil },
    { 40, 59, "Brute", "BuggyQuest1", 2, CFrame.new(-1140, 4, 3829), nil, {CFrame.new(-976, 55, 4304), CFrame.new(-1196, 55, 4287), CFrame.new(-1363, 55, 4162)}, nil },
    { 60, 74, "Desert Bandit", "DesertQuest", 1, CFrame.new(897, 6, 4389), CFrame.new(938, 6, 4470), nil, nil },
    { 75, 89, "Desert Officer", "DesertQuest", 2, CFrame.new(897, 6, 4389), CFrame.new(1546, 14, 4384), nil, nil },
    { 90, 99, "Snow Bandit", "SnowQuest", 1, CFrame.new(1385, 87, -1298), CFrame.new(1303, 106, -1441), {CFrame.new(1362, 120, -1531), CFrame.new(1357, 120, -1381), CFrame.new(1228, 120, -1354)}, nil },
    { 100, 119, "Yeti", "SnowQuest", 3, CFrame.new(1385, 87, -1298), CFrame.new(1185, 106, -1518), {CFrame.new(1243, 140, -1437), CFrame.new(1072, 140, -1458), CFrame.new(1076, 140, -1621), CFrame.new(1209, 140, -1644), CFrame.new(1252, 140, -1480)}, nil },
    { 100, 119, "Snowman", "SnowQuest", 2, CFrame.new(1385, 87, -1298), CFrame.new(1185, 106, -1518), {CFrame.new(1243, 140, -1437), CFrame.new(1072, 140, -1458), CFrame.new(1076, 140, -1621), CFrame.new(1209, 140, -1644), CFrame.new(1252, 140, -1480)}, nil },
    { 120, 149, "Vice Admiral", "MarineQuest2", 2, CFrame.new(-5035, 29, 4326), CFrame.new(-4807, 21, 4360), nil, nil },
    { 120, 149, "Chief Petty Officer", "MarineQuest2", 1, CFrame.new(-5035, 29, 4326), CFrame.new(-4807, 21, 4360), nil, nil },
    { 150, 174, "Sky Bandit", "SkyQuest", 1, CFrame.new(-4844, 718, -2621), CFrame.new(-4956, 296, -2901), nil, nil },
    { 175, 189, "Dark Master", "SkyQuest", 2, CFrame.new(-4844, 718, -2621), CFrame.new(-5268, 392, -2213), nil, nil },
    { 190, 209, "Prisoner", "PrisonerQuest", 1, CFrame.new(5306, 2, 477), CFrame.new(5288, 2, 470), nil, nil },
    { 210, 249, "Swan", "ImpelQuest", 3, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Chief Warden", "ImpelQuest", 2, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Warden", "ImpelQuest", 1, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Dangerous Prisoner", "PrisonerQuest", 2, CFrame.new(5306, 2, 477), CFrame.new(5282, 2, 1052), nil, nil },
    { 250, 274, "Toga Warrior", "ColosseumQuest", 1, CFrame.new(-1581, 7, -2982), CFrame.new(-1897, 7, -2796), nil, nil },
    { 275, 299, "Gladiator", "ColosseumQuest", 2, CFrame.new(-1581, 7, -2982), CFrame.new(-1327, 59, -3231), {CFrame.new(-1268, 30, -2996), CFrame.new(-1472, 30, -3194), CFrame.new(-1387, 30, -3438), CFrame.new(-1198, 30, -3508)}, nil },
    { 300, 324, "Military Soldier", "MagmaQuest", 1, CFrame.new(-5319, 12, 8515), nil, {CFrame.new(-5335, 46, 8638), CFrame.new(-5512, 30, 8366)}, nil },
    { 325, 374, "Magma Admiral", "MagmaQuest", 3, CFrame.new(-5319, 12, 8515), CFrame.new(-5694, 18, 8735), nil, nil },
    { 325, 374, "Military Spy", "MagmaQuest", 2, CFrame.new(-5319, 12, 8515), CFrame.new(-5791, 97, 8834), nil, nil },
    { 375, 399, "Fishman Warrior", "FishmanQuest", 1, CFrame.new(61122, 18, 1567), nil, {CFrame.new(60998, 50, 1534), CFrame.new(60880, 50, 1675), CFrame.new(60785, 50, 1552), CFrame.new(60923, 60, 1262)}, nil },
    { 400, 449, "Fishman Lord", "FishmanQuest", 3, CFrame.new(61122, 18, 1567), CFrame.new(61350, 31, 1095), {CFrame.new(61866, 55, 1655), CFrame.new(62043, 55, 1510), CFrame.new(61812, 55, 1254)}, nil },
    { 400, 449, "Fishman Commando", "FishmanQuest", 2, CFrame.new(61122, 18, 1567), nil, {CFrame.new(61866, 55, 1655), CFrame.new(62043, 55, 1510), CFrame.new(61812, 55, 1254)}, nil },
    { 450, 474, "God's Guard", "SkyExp1Quest", 1, CFrame.new(-4720, 846, -1951), nil, {CFrame.new(-4641, 880, -1902), CFrame.new(-4781, 880, -1817)}, nil },
    { 475, 524, "Wysper", "SkyExp1Quest", 3, CFrame.new(-7861, 5545, -381), CFrame.new(-7927, 5551, -637), {CFrame.new(-7741, 5580, -395), CFrame.new(-7591, 5580, -466), CFrame.new(-7643, 5580, -608)}, nil },
    { 475, 524, "Shanda", "SkyExp1Quest", 2, CFrame.new(-7861, 5545, -381), nil, {CFrame.new(-7741, 5580, -395), CFrame.new(-7591, 5580, -466), CFrame.new(-7643, 5580, -608)}, nil },
    { 525, 549, "Royal Squad", "SkyExp2Quest", 1, CFrame.new(-7903, 5636, -1412), nil, {CFrame.new(-7727, 5650, -1410), CFrame.new(-7522, 5650, -1499)}, nil },
    { 525, 624, "Thunder God", "SkyExp2Quest", 3, CFrame.new(-7903, 5636, -1412), CFrame.new(-7751, 5607, -2315), {CFrame.new(-7894, 5640, -1629), CFrame.new(-7678, 5640, -1696), CFrame.new(-7672, 5640, -1903), CFrame.new(-7925, 5640, -1854)}, nil },
    { 525, 624, "Royal Soldier", "SkyExp2Quest", 2, CFrame.new(-7903, 5636, -1412), nil, {CFrame.new(-7894, 5640, -1629), CFrame.new(-7678, 5640, -1696), CFrame.new(-7672, 5640, -1903), CFrame.new(-7925, 5640, -1854)}, nil },
    { 625, 649, "Galley Pirate", "FountainQuest", 1, CFrame.new(5258, 39, 4052), nil, {CFrame.new(5391, 70, 4023), CFrame.new(5780, 70, 3969)}, nil },
    { 650, 2525, "Cyborg", "FountainQuest", 3, CFrame.new(5258, 39, 4052), CFrame.new(6138, 10, 3939), {CFrame.new(5985, 70, 4790), CFrame.new(5472, 70, 4887)}, nil },
    { 650, 2525, "Galley Captain", "FountainQuest", 2, CFrame.new(5258, 39, 4052), nil, {CFrame.new(5985, 70, 4790), CFrame.new(5472, 70, 4887)}, nil },
}
D.quests[2] = {
    { 700, 724, "Raider", "Area1Quest", 1, CFrame.new(-427, 73, 1835), nil, {CFrame.new(-614, 90, 2240), CFrame.new(-894, 90, 2275), CFrame.new(-872, 90, 2481), CFrame.new(-552, 90, 2528)}, nil },
    { 725, 774, "Diamond", "Area1Quest", 3, CFrame.new(-427, 73, 1835), CFrame.new(-1569, 199, -31), {CFrame.new(-867, 110, 1621), CFrame.new(-1047, 110, 1779), CFrame.new(-1025, 110, 1087), CFrame.new(-1204, 110, 1195)}, nil },
    { 725, 774, "Mercenary", "Area1Quest", 2, CFrame.new(-427, 73, 1835), nil, {CFrame.new(-867, 110, 1621), CFrame.new(-1047, 110, 1779), CFrame.new(-1025, 110, 1087), CFrame.new(-1204, 110, 1195)}, nil },
    { 775, 799, "Swan Pirate", "Area2Quest", 1, CFrame.new(635, 73, 919), nil, {CFrame.new(778, 110, 1129), CFrame.new(1018, 110, 1128), CFrame.new(1020, 110, 1366), CFrame.new(1016, 110, 1115)}, nil },
    { 800, 874, "Jeremy", "Area2Quest", 3, CFrame.new(635, 73, 919), CFrame.new(2316, 449, 787), {CFrame.new(882, 110, -49), CFrame.new(723, 110, 212), CFrame.new(473, 110, 108), CFrame.new(-115, 110, 39)}, nil },
    { 800, 874, "Factory Staff", "Area2Quest", 2, CFrame.new(635, 73, 919), nil, {CFrame.new(882, 110, -49), CFrame.new(723, 110, 212), CFrame.new(473, 110, 108), CFrame.new(-115, 110, 39)}, nil },
    { 875, 899, "Marine Lieutenant", "MarineQuest3", 1, CFrame.new(-2441, 73, -3219), nil, {CFrame.new(-2552, 110, -3050), CFrame.new(-2860, 110, -3089), CFrame.new(-3114, 110, -2947), CFrame.new(-2864, 110, -2679)}, nil },
    { 900, 949, "Fajita", "MarineQuest3", 3, CFrame.new(-2441, 73, -3219), CFrame.new(-2086, 73, -4208), {CFrame.new(-1695, 110, -3299), CFrame.new(-1953, 110, -3165), CFrame.new(-2144, 110, -3341)}, nil },
    { 900, 949, "Marine Captain", "MarineQuest3", 2, CFrame.new(-2441, 73, -3219), nil, {CFrame.new(-1695, 110, -3299), CFrame.new(-1953, 110, -3165), CFrame.new(-2144, 110, -3341)}, nil },
    { 950, 974, "Zombie", "ZombieQuest", 1, CFrame.new(-5495, 48, -794), nil, {CFrame.new(-5715, 90, -917), CFrame.new(-5534, 90, -942), CFrame.new(-5445, 90, -806), CFrame.new(-5485, 90, -663), CFrame.new(-5730, 90, -590), CFrame.new(-5816, 90, -756)}, nil },
    { 975, 999, "Vampire", "ZombieQuest", 2, CFrame.new(-5495, 48, -794), nil, {CFrame.new(-6027, 50, -1130), CFrame.new(-6248, 50, -1281), CFrame.new(-6120, 50, -1450), CFrame.new(-5951, 50, -1520), CFrame.new(-5803, 50, -1360)}, nil },
    { 1000, 1049, "Snow Trooper", "SnowMountainQuest", 1, CFrame.new(607, 401, -5371), nil, {CFrame.new(445, 440, -5175), CFrame.new(523, 440, -5484), CFrame.new(699, 440, -5612)}, nil },
    { 1050, 1099, "Winter Warrior", "SnowMountainQuest", 2, CFrame.new(607, 401, -5371), nil, {CFrame.new(1224, 460, -5332), CFrame.new(1404, 460, -5323), CFrame.new(1258, 460, -5220), CFrame.new(1145, 460, -5077), CFrame.new(1022, 460, -5139)}, nil },
    { 1100, 1124, "Lab Subordinate", "IceSideQuest", 1, CFrame.new(-6061, 16, -4904), nil, {CFrame.new(-5941, 50, -4322), CFrame.new(-5765, 50, -4304), CFrame.new(-5608, 50, -4445), CFrame.new(-5683, 50, -4629)}, nil },
    { 1125, 1174, "Smoke Admiral", "IceSideQuest", 3, CFrame.new(-6061, 16, -4904), CFrame.new(-5078, 24, -5352), {CFrame.new(-6306, 50, -5752), CFrame.new(-6161, 50, -5979), CFrame.new(-6518, 50, -5795), CFrame.new(-6535, 50, -5640)}, nil },
    { 1125, 1174, "Horned Warrior", "IceSideQuest", 2, CFrame.new(-6061, 16, -4904), nil, {CFrame.new(-6306, 50, -5752), CFrame.new(-6161, 50, -5979), CFrame.new(-6518, 50, -5795), CFrame.new(-6535, 50, -5640)}, nil },
    { 1175, 1199, "Magma Ninja", "FireSideQuest", 1, CFrame.new(-5430, 16, -5298), nil, {CFrame.new(-5233, 60, -6227), CFrame.new(-5194, 60, -6031), CFrame.new(-5651, 60, -5854)}, nil },
    { 1200, 1249, "Lava Pirate", "FireSideQuest", 2, CFrame.new(-5430, 16, -5298), nil, {CFrame.new(-4955, 60, -4836), CFrame.new(-5119, 60, -4634), CFrame.new(-5389, 60, -4616), CFrame.new(-5342, 60, -4897)}, nil },
    { 1250, 1274, "Ship Deckhand", "ShipQuest1", 1, CFrame.new(1033, 125, 32909), nil, {CFrame.new(1185, 180, 32979), CFrame.new(1204, 180, 33174), CFrame.new(615, 180, 33169), CFrame.new(638, 180, 32962)}, nil },
    { 1275, 1299, "Ship Engineer", "ShipQuest1", 2, CFrame.new(1033, 125, 32909), nil, {CFrame.new(809, 80, 33090), CFrame.new(751, 80, 32957), CFrame.new(927, 80, 32724), CFrame.new(1040, 80, 32915), CFrame.new(1034, 80, 33058)}, nil },
    { 1300, 1324, "Ship Steward", "ShipQuest2", 1, CFrame.new(973, 125, 33245), nil, {CFrame.new(838, 160, 33408), CFrame.new(1026, 160, 33510)}, nil },
    { 1325, 1349, "Ship Officer", "ShipQuest2", 2, CFrame.new(973, 125, 33245), nil, {CFrame.new(1238, 220, 33148), CFrame.new(1220, 220, 33426), CFrame.new(622, 220, 33435), CFrame.new(593, 220, 33172)}, nil },
    { 1350, 1374, "Arctic Warrior", "FrostQuest", 1, CFrame.new(5668, 28, -6484), nil, {CFrame.new(5836, 80, -6257), CFrame.new(6132, 80, -6098), CFrame.new(6275, 80, -6237), CFrame.new(6095, 80, -6349)}, nil },
    { 1375, 1424, "Awakened Ice Admiral", "FrostQuest", 3, CFrame.new(5668, 28, -6484), CFrame.new(6473, 297, -6944), {CFrame.new(5700, 80, -6724), CFrame.new(5542, 80, -6898), CFrame.new(5512, 80, -6641)}, nil },
    { 1375, 1424, "Snow Lurker", "FrostQuest", 2, CFrame.new(5668, 28, -6484), nil, {CFrame.new(5700, 80, -6724), CFrame.new(5542, 80, -6898), CFrame.new(5512, 80, -6641)}, nil },
    { 1425, 1449, "Sea Soldier", "ForgottenQuest", 1, CFrame.new(-3056, 240, -10145), nil, {CFrame.new(-2583, 80, -9821), CFrame.new(-2830, 80, -9809), CFrame.new(-3271, 80, -9729), CFrame.new(-3486, 80, -9813)}, nil },
    { 1450, 2525, "Tide Keeper", "ForgottenQuest", 3, CFrame.new(-3056, 240, -10145), CFrame.new(-3711, 77, -11469), {CFrame.new(-3339, 290, -10412), CFrame.new(-3518, 290, -10419), CFrame.new(-3536, 290, -10607), CFrame.new(-3345, 280, -10667)}, nil },
    { 1450, 2525, "Water Fighter", "ForgottenQuest", 2, CFrame.new(-3056, 240, -10145), nil, {CFrame.new(-3339, 290, -10412), CFrame.new(-3518, 290, -10419), CFrame.new(-3536, 290, -10607), CFrame.new(-3345, 280, -10667)}, nil },
}
D.quests[3] = {
    { 1500, 1524, "Pirate Millionaire", "PiratePortQuest", 1, CFrame.new(-291, 44, 5580), nil, {CFrame.new(-44, 70, 5623), CFrame.new(-219, 70, 5546), CFrame.new(-574, 70, 5496)}, nil },
    { 1525, 1574, "Stone", "PiratePortQuest", 3, CFrame.new(-291, 44, 5580), CFrame.new(-1049, 40, 6791), {CFrame.new(219, 105, 6018), CFrame.new(-24, 105, 6155), CFrame.new(-312, 105, 6028)}, nil },
    { 1525, 1574, "Pistol Billionaire", "PiratePortQuest", 2, CFrame.new(-291, 44, 5580), nil, {CFrame.new(219, 105, 6018), CFrame.new(-24, 105, 6155), CFrame.new(-312, 105, 6028)}, nil },
    { 1575, 1599, "Dragon Crew Warrior", "AmazonQuest", 1, CFrame.new(5834, 51, -1103), nil, {CFrame.new(5992, 90, -1581), CFrame.new(6364, 90, -1512), CFrame.new(6501, 90, -1104), CFrame.new(6612, 90, -938), CFrame.new(6393, 90, -939)}, nil },
    { 1600, 1624, "Dragon Crew Archer", "AmazonQuest", 2, CFrame.new(5834, 51, -1103), nil, {CFrame.new(6472, 370, -151), CFrame.new(6547, 370, -51), CFrame.new(6539, 410, 72), CFrame.new(6737, 410, 249), CFrame.new(6768, 410, 390), CFrame.new(6625, 410, 371)}, nil },
    { 1625, 1649, "Female Islander", "AmazonQuest2", 1, CFrame.new(5448, 602, 748), nil, {CFrame.new(4836, 740, 928), CFrame.new(4708, 770, 911), CFrame.new(4672, 790, 695), CFrame.new(4657, 800, 498), CFrame.new(4575, 810, 281)}, nil },
    { 1650, 1699, "Island Empress", "AmazonQuest2", 3, CFrame.new(5448, 602, 748), CFrame.new(5730, 602, 199), {CFrame.new(4784, 660, 155), CFrame.new(4662, 660, -57), CFrame.new(4869, 660, -178), CFrame.new(5056, 660, -267), CFrame.new(5332, 660, -166)}, nil },
    { 1650, 1699, "Giant Islander", "AmazonQuest2", 2, CFrame.new(5448, 602, 748), nil, {CFrame.new(4784, 660, 155), CFrame.new(4662, 660, -57), CFrame.new(4869, 660, -178), CFrame.new(5056, 660, -267), CFrame.new(5332, 660, -166)}, nil },
    { 1700, 1724, "Marine Commodore", "MarineTreeIsland", 1, CFrame.new(2180, 29, -6738), nil, {CFrame.new(3156, 120, -7837), CFrame.new(2904, 120, -7863), CFrame.new(2606, 120, -7745), CFrame.new(2409, 120, -7874), CFrame.new(2269, 120, -7416), CFrame.new(2413, 120, -7232), CFrame.new(2284, 120, -6911)}, nil },
    { 1725, 1774, "Kilo Admiral", "MarineTreeIsland", 3, CFrame.new(2180, 29, -6738), CFrame.new(2889, 424, -7233), {CFrame.new(3205, 120, -6742), CFrame.new(3345, 120, -6649), CFrame.new(3776, 210, -7254), CFrame.new(3879, 220, -7083), CFrame.new(3887, 210, -6841), CFrame.new(3546, 210, -6809), CFrame.new(3448, 210, -7014), CFrame.new(3504, 210, -7230)}, nil },
    { 1725, 1774, "Marine Rear Admiral", "MarineTreeIsland", 2, CFrame.new(2180, 29, -6738), nil, {CFrame.new(3205, 120, -6742), CFrame.new(3345, 120, -6649), CFrame.new(3776, 210, -7254), CFrame.new(3879, 220, -7083), CFrame.new(3887, 210, -6841), CFrame.new(3546, 210, -6809), CFrame.new(3448, 210, -7014), CFrame.new(3504, 210, -7230)}, nil },
    { 1775, 1799, "Fishman Raider", "DeepForestIsland3", 1, CFrame.new(-10581, 332, -8758), nil, {CFrame.new(-10550, 380, -8574), CFrame.new(-10860, 380, -8459), CFrame.new(-10578, 380, -8331), CFrame.new(-10377, 380, -8238), CFrame.new(-10147, 380, -8216), CFrame.new(-10234, 380, -8454)}, nil },
    { 1800, 1824, "Fishman Captain", "DeepForestIsland3", 2, CFrame.new(-10581, 332, -8758), nil, {CFrame.new(-10764, 380, -8799), CFrame.new(-10844, 380, -9030), CFrame.new(-11160, 380, -9166), CFrame.new(-11073, 380, -8846), CFrame.new(-11043, 380, -8619)}, nil },
    { 1825, 1849, "Forest Pirate", "DeepForestIsland", 1, CFrame.new(-13233, 332, -7626), nil, {CFrame.new(-13335, 380, -7660), CFrame.new(-13138, 380, -7713), CFrame.new(-13298, 380, -7876), CFrame.new(-13512, 380, -7983), CFrame.new(-13632, 380, -7815)}, nil },
    { 1850, 1899, "Captain Elephant", "DeepForestIsland", 3, CFrame.new(-13233, 332, -7626), CFrame.new(-13393, 319, -8423), {CFrame.new(-13844, 520, -7016), CFrame.new(-13710, 520, -6856), CFrame.new(-13482, 520, -6985), CFrame.new(-13224, 580, -6806)}, nil },
    { 1850, 1899, "Mythological Pirate", "DeepForestIsland", 2, CFrame.new(-13233, 332, -7626), nil, {CFrame.new(-13844, 520, -7016), CFrame.new(-13710, 520, -6856), CFrame.new(-13482, 520, -6985), CFrame.new(-13224, 580, -6806)}, nil },
    { 1900, 1924, "Jungle Pirate", "DeepForestIsland2", 1, CFrame.new(-12682, 391, -9901), nil, {CFrame.new(-12166, 380, -10375), CFrame.new(-12303, 380, -10639), CFrame.new(-11904, 380, -10469), CFrame.new(-11636, 380, -10511), CFrame.new(-11735, 380, -10687), CFrame.new(-11937, 380, -10713)}, nil },
    { 1925, 1974, "Musketeer Pirate", "DeepForestIsland2", 3, CFrame.new(-12682, 391, -9901), CFrame.new(5241, 23, 129), {CFrame.new(-13098, 450, -9831), CFrame.new(-13222, 450, -9621), CFrame.new(-13530, 450, -9760), CFrame.new(-13455, 450, -9940)}, nil },
    { 1925, 1974, "Musketeer Pirate", "DeepForestIsland2", 2, CFrame.new(-12682, 391, -9901), nil, {CFrame.new(-13098, 450, -9831), CFrame.new(-13222, 450, -9621), CFrame.new(-13530, 450, -9760), CFrame.new(-13455, 450, -9940)}, nil },
    { 1975, 1999, "Reborn Skeleton", "HauntedQuest1", 1, CFrame.new(-9481, 142, 5565), nil, {CFrame.new(-8680, 190, 5852), CFrame.new(-8879, 190, 5900), CFrame.new(-8865, 190, 6100), CFrame.new(-8774, 170, 6169), CFrame.new(-8649, 190, 6071)}, nil },
    { 200, 2024, "Living Zombie", "HauntedQuest1", 2, CFrame.new(-9481, 142, 5565), nil, {CFrame.new(-10104, 200, 5739), CFrame.new(-10078, 200, 5953), CFrame.new(-10195, 200, 6139), CFrame.new(-10252, 200, 5973)}, nil },
    { 2025, 2049, "Demonic Soul", "HauntedQuest2", 1, CFrame.new(-9515, 172, 6078), nil, {CFrame.new(-9275, 210, 6166), CFrame.new(-9379, 210, 6076), CFrame.new(-9565, 210, 6201), CFrame.new(-9671, 210, 6096)}, nil },
    { 2050, 2074, "Posessed Mummy", "HauntedQuest2", 2, CFrame.new(-9515, 172, 6078), nil, {CFrame.new(-9442, 60, 6304), CFrame.new(-9427, 60, 6148), CFrame.new(-9598, 60, 6121), CFrame.new(-9733, 60, 6119), CFrame.new(-9735, 60, 6336), CFrame.new(-9618, 60, 6323)}, nil },
    { 2075, 2099, "Peanut Scout", "NutsIslandQuest", 1, CFrame.new(-2104, 38, -10194), nil, {CFrame.new(-1870, 100, -10225), CFrame.new(-2143, 100, -10106)}, nil },
    { 2100, 2124, "Peanut President", "NutsIslandQuest", 2, CFrame.new(-2104, 38, -10194), nil, {CFrame.new(-2005, 100, -10585), CFrame.new(-2293, 88, -10512)}, nil },
    { 2125, 2149, "Ice Cream Chef", "IceCreamIslandQuest", 1, CFrame.new(-818, 66, -10964), nil, {CFrame.new(-501, 100, -10883), CFrame.new(-763, 100, -10834), CFrame.new(-990, 100, -11085)}, nil },
    { 2150, 2199, "Cake Queen", "IceCreamIslandQuest", 3, CFrame.new(-818, 66, -10964), CFrame.new(-710, 382, -11150), {CFrame.new(-690, 100, -11350), CFrame.new(-534, 100, -11284), CFrame.new(-720, 180, -11162)}, nil },
    { 2150, 2199, "Ice Cream Commander", "IceCreamIslandQuest", 2, CFrame.new(-818, 66, -10964), nil, {CFrame.new(-690, 100, -11350), CFrame.new(-534, 100, -11284), CFrame.new(-720, 180, -11162)}, nil },
    { 2200, 2224, "Cookie Crafter", "CakeQuest1", 1, CFrame.new(-2023, 38, -12028), nil, {CFrame.new(-2332, 90, -12049), CFrame.new(-2468, 90, -12121), CFrame.new(-2401, 90, -12224), CFrame.new(-2296, 90, -12114)}, nil },
    { 2225, 2249, "Cake Guard", "CakeQuest1", 2, CFrame.new(-2023, 38, -12028), nil, {CFrame.new(-1514, 90, -12422), CFrame.new(-1455, 90, -12244), CFrame.new(-1674, 90, -12206), CFrame.new(-1707, 90, -12360)}, nil },
    { 2250, 2274, "Baking Staff", "CakeQuest2", 1, CFrame.new(-1931, 38, -12840), nil, {CFrame.new(-1930, 90, -12963), CFrame.new(-1803, 90, -13115), CFrame.new(-1769, 90, -12955), CFrame.new(-1873, 90, -12755)}, nil },
    { 2275, 2299, "Head Baker", "CakeQuest2", 2, CFrame.new(-1931, 38, -12840), nil, {CFrame.new(-2123, 110, -12777), CFrame.new(-2281, 110, -12748), CFrame.new(-2317, 110, -12994), CFrame.new(-2140, 110, -12989)}, nil },
    { 2300, 2324, "Cocoa Warrior", "ChocQuest1", 1, CFrame.new(235, 25, -12199), nil, {CFrame.new(110, 80, -12245), CFrame.new(-71, 80, -12292)}, nil },
    { 2325, 2349, "Chocolate Bar Battler", "ChocQuest1", 2, CFrame.new(235, 25, -12199), nil, {CFrame.new(579, 80, -12413), CFrame.new(735, 80, -12659)}, nil },
    { 2350, 2374, "Sweet Thief", "ChocQuest2", 1, CFrame.new(150, 25, -12777), nil, {CFrame.new(-68, 80, -12692), CFrame.new(90, 80, -12519)}, nil },
    { 2375, 2399, "Candy Rebel", "ChocQuest2", 2, CFrame.new(150, 25, -12777), nil, {CFrame.new(17, 80, -12962), CFrame.new(158, 80, -12961)}, nil },
    { 2400, 2424, "Candy Pirate", "CandyQuest1", 1, CFrame.new(-1148, 14, -14446), nil, {CFrame.new(-1371, 70, -14405), CFrame.new(-1318, 70, -14715)}, nil },
    { 2425, 2449, "Snow Demon", "CandyQuest1", 2, CFrame.new(-1148, 14, -14446), nil, {CFrame.new(-836, 70, -14326), CFrame.new(-884, 70, -14708)}, nil },
    { 2450, 2474, "Isle Outlaw", "TikiQuest1", 1, CFrame.new(-16547, 56, -172), nil, {CFrame.new(-16431, 90, -223), CFrame.new(-16313, 50, -210), CFrame.new(-16160, 35, -156)}, nil },
    { 2475, 2499, "Island Boy", "TikiQuest1", 2, CFrame.new(-16547, 56, -172), nil, {CFrame.new(-16668, 70, -243), CFrame.new(-16744, 60, -195), CFrame.new(-16912, 45, -152)}, nil },
    { 2500, 2524, "Sun-kissed Warrior", "TikiQuest2", 1, CFrame.new(-16540, 56, 1051), nil, {CFrame.new(-16345, 80, 1004), CFrame.new(-16425, 77, 1059), CFrame.new(-16069, 37, 1029)}, nil },
    { 2525, 2525, "Isle Champion", "TikiQuest2", 2, CFrame.new(-16540, 56, 1051), nil, {CFrame.new(-16634, 85, 1106), CFrame.new(-16735, 60, 1075), CFrame.new(-16888, 35, 1011)}, nil },
}

-- bosses[name] = { needQuest, spawnCF, questName, questNum? }
D.bosses = {}
D.bosses["The Gorilla King"] = { true, CFrame.new(-1128, 6, -451), "JungleQuest" }
D.bosses["Bobby"] = { true, CFrame.new(-1131, 14, 4080), "BuggyQuest1" }
D.bosses["Yeti"] = { true, CFrame.new(1185, 106, -1518), "SnowQuest" }
D.bosses["Vice Admiral"] = { true, CFrame.new(-4807, 21, 4360), "MarineQuest2", 2 }
D.bosses["Swan"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest" }
D.bosses["Chief Warden"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest", 2 }
D.bosses["Warden"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest", 1 }
D.bosses["Magma Admiral"] = { true, CFrame.new(-5694, 18, 8735), "MagmaQuest" }
D.bosses["Fishman Lord"] = { true, CFrame.new(61350, 31, 1095), "FishmanQuest" }
D.bosses["Wysper"] = { true, CFrame.new(-7927, 5551, -637), "SkyExp1Quest" }
D.bosses["Thunder God"] = { true, CFrame.new(-7751, 5607, -2315), "SkyExp2Quest" }
D.bosses["Cyborg"] = { true, CFrame.new(6138, 10, 3939), "FountainQuest" }
D.bosses["Saber Expert"] = { false, CFrame.new(-1461, 30, -51) }
D.bosses["The Saw"] = { false, CFrame.new(-690, 15, 1583) }
D.bosses["Greybeard"] = { false, CFrame.new(-4807, 21, 4360) }
D.bosses["Diamond"] = { true, CFrame.new(-1569, 199, -31), "Area1Quest" }
D.bosses["Jeremy"] = { true, CFrame.new(2316, 449, 787), "Area2Quest" }
D.bosses["Fajita"] = { true, CFrame.new(-2086, 73, -4208), "MarineQuest3" }
D.bosses["Smoke Admiral"] = { true, CFrame.new(-5078, 24, -5352), "IceSideQuest" }
D.bosses["Awakened Ice Admiral"] = { true, CFrame.new(6473, 297, -6944), "FrostQuest" }
D.bosses["Tide Keeper"] = { true, CFrame.new(-3711, 77, -11469), "ForgottenQuest" }
D.bosses["Don Swan"] = { false, CFrame.new(2289, 15, 808) }
D.bosses["Cursed Captain"] = { false, CFrame.new(912, 186, 33591) }
D.bosses["Darkbeard"] = { false, CFrame.new(3695, 13, -3599) }
D.bosses["Longma"] = { false, CFrame.new(-10218, 333, -9444) }
D.bosses["Stone"] = { true, CFrame.new(-1049, 40, 6791), "PiratePortQuest" }
D.bosses["Beautiful Pirate"] = { true, CFrame.new(5241, 23, 129), "DeepForestIsland2" }
D.bosses["Island Empress"] = { true, CFrame.new(5730, 602, 199), "AmazonQuest2" }
D.bosses["Kilo Admiral"] = { true, CFrame.new(2889, 424, -7233), "MarineTreeIsland" }
D.bosses["Captain Elephant"] = { true, CFrame.new(-13393, 319, -8423), "DeepForestIsland" }
D.bosses["Cake Queen"] = { true, CFrame.new(-710, 382, -11150), "IceCreamIslandQuest" }
D.bosses["Cake Prince"] = { false, CFrame.new(-2103, 70, -12165) }
D.bosses["rip_indra True Form"] = { false, CFrame.new(-5333, 424, -2673) }

-- these three have no GetBossQuest row in the source: spawn CFrames come from their
-- dedicated auto-kill loops (Order = Law raid boss, Soul Reaper = Hallow Essence boss)
D.bosses["Order"] = { false, CFrame.new(-6300, 16, -4997) }
D.bosses["Soul Reaper"] = { false, CFrame.new(-9529, 316, 6712) }
D.bosses["Dough King"] = D.bosses["Cake Prince"]

D.bossList = {
    [1] = { "Greybeard", "The Saw", "Saber Expert", "The Gorilla King", "Bobby", "Yeti", "Vice Admiral", "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg" },
    [2] = { "Darkbeard", "Cursed Captain", "Order", "Don Swan", "Diamond", "Jeremy", "Fajita", "Smoke Admiral", "Awakened Ice Admiral", "Tide Keeper" },
    [3] = { "Dough King", "Cake Prince", "rip_indra True Form", "Soul Reaper", "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate", "Cake Queen", "Longma" },
}

D.materials = {
}

D.fruits = {
    ["Rocket Fruit"] = "Rocket-Rocket",
    ["Spin Fruit"] = "Spin-Spin",
    ["Chop Fruit"] = "Chop-Chop",
    ["Spring Fruit"] = "Spring-Spring",
    ["Bomb Fruit"] = "Bomb-Bomb",
    ["Smoke Fruit"] = "Smoke-Smoke",
    ["Spike Fruit"] = "Spike-Spike",
    ["Flame Fruit"] = "Flame-Flame",
    ["Falcon Fruit"] = "Falcon-Falcon",
    ["Ice Fruit"] = "Ice-Ice",
    ["Sand Fruit"] = "Sand-Sand",
    ["Dark Fruit"] = "Dark-Dark",
    ["Ghost Fruit"] = "Ghost-Ghost",
    ["Diamond Fruit"] = "Diamond-Diamond",
    ["Light Fruit"] = "Light-Light",
    ["Rubber Fruit"] = "Rubber-Rubber",
    ["Barrier Fruit"] = "Barrier-Barrier",
    ["Magma Fruit"] = "Magma-Magma",
    ["Quake Fruit"] = "Quake-Quake",
    ["Buddha Fruit"] = "Buddha-Buddha",
    ["Love Fruit"] = "Love-Love",
    ["Spider Fruit"] = "Spider-Spider",
    ["Sound Fruit"] = "Sound-Sound",
    ["Phoenix Fruit"] = "Phoenix-Phoenix",
    ["Portal Fruit"] = "Portal-Portal",
    ["Rumble Fruit"] = "Rumble-Rumble",
    ["Pain Fruit"] = "Pain-Pain",
    ["Blizzard Fruit"] = "Blizzard-Blizzard",
    ["Gravity Fruit"] = "Gravity-Gravity",
    ["Mammoth Fruit"] = "Mammoth-Mammoth",
    ["T-Rex Fruit"] = "T-Rex-T-Rex",
    ["Dough Fruit"] = "Dough-Dough",
    ["Shadow Fruit"] = "Shadow-Shadow",
    ["Venom Fruit"] = "Venom-Venom",
    ["Control Fruit"] = "Control-Control",
    ["Spirit Fruit"] = "Spirit-Spirit",
    ["Dragon Fruit"] = "Dragon-Dragon",
    ["Leopard Fruit"] = "Leopard-Leopard",
    ["Kitsune Fruit"] = "Kitsune-Kitsune",
}

D.codes = {
    "NEWTROLL", "KITT_RESET", "Sub2Fer999", "Magicbus", "kittgaming", "SECRET_ADMIN", "EXP_5B", "CONTROL", "UPDATE11", "XMASEXP", "1BILLION", "ShutDownFix2", "UPD14", "STRAWHATMAINE", "TantaiGaming", "Colosseum", "Axiore", "Sub2Daigrock", "Sky Island 3", "Sub2OfficialNoobie", "SUB2NOOBMASTER123", "THEGREATACE", "Fountain City", "BIGNEWS", "FUDD10", "SUB2GAMERROBOT_EXP1", "UPD15", "2BILLION", "UPD16", "3BVISITS", "Starcodeheo", "Bluxxy", "DRAGONABUSE", "Sub2CaptainMaui", "DEVSCOOKING", "Enyu_is_Pro", "JCWK", "Starcodeheo", "Bluxxy", "fudd10_v2", "SUB2GAMERROBOT_EXP1", "Sub2NoobMaster123", "Sub2UncleKizaru", "Sub2Daigrock", "Axiore", "TantaiGaming", "StrawHatMaine"
}

-- highest row whose range contains the level ("for" is reserved, hence .at)
function D.questAt(sea, level)
    local t = D.quests[sea]
    if not t then return nil end
    for _, r in ipairs(t) do
        if level >= r[1] and level <= r[2] then return r end
    end
    return t[#t]
end

return D
