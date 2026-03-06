/**
 * CS:GO Legacy Version - Weapon Swap Menu (SWP)
 *
 * Goal: On legacy CS:GO where the GC / loadout system is not available,
 * let players choose all official buy-menu swap pairs via a simple chat
 * command + menu, and remember their personal preferences.
 *
 * Supported swap pairs (buy menu 1-of-2 / replacement slots):
 * - Slot 1 (CT starting pistol): P2000 <-> USP-S
 * - Slot 4 (CT pistol): Five-SeveN <-> CZ75-Auto
 * - Slot 4 (T  pistol): Tec-9 <-> CZ75-Auto
 * - Slot 5 (pistol, both teams): Desert Eagle <-> R8 Revolver
 * - Slot 2 (CT rifle): M4A4 <-> M4A1-S
 * - Optional (SMG): MP7 <-> MP5-SD (only shown if mp5sd exists)
 *
 * Behavior:
 * - Players type !swp or /swp to open the SWP menu.
 * - Preferences are stored in clientprefs cookies.
 * - CT starting pistol is auto-swapped on spawn (P2000/USP-S).
 * - Buy commands are allowed, then the plugin replaces the bought weapon
 *   entity to match the player's SWP preference (no free weapons given).
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1.0"

enum CTRifleChoice
{
    LOADOUT_CT_RIFLE_M4A4 = 0,
    LOADOUT_CT_RIFLE_M4A1S = 1
};

enum CTStartPistolChoice
{
    LOADOUT_CT_START_P2000 = 0,
    LOADOUT_CT_START_USPS = 1
};

ConVar g_hCvarEnabled;

Handle g_hCookie_CTRifle;
Handle g_hCookie_CTStartPistol;
Handle g_hCookie_CTPistolSlot4;
Handle g_hCookie_TPistolSlot4;
Handle g_hCookie_PistolSlot5;
Handle g_hCookie_SMGSlot;

int g_iCTRifleChoice[MAXPLAYERS + 1];
int g_iCTStartPistolChoice[MAXPLAYERS + 1];
int g_iCTPistolSlot4Choice[MAXPLAYERS + 1];
int g_iTPistolSlot4Choice[MAXPLAYERS + 1];
int g_iPistolSlot5Choice[MAXPLAYERS + 1];
int g_iSMGSlotChoice[MAXPLAYERS + 1];

bool g_bHasMP5SD;

bool g_bIgnoreBuyHook[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "Legacy CS:GO SWP Menu",
    author      = "Jaymmz",
    description = "Chat-based SWP menu to choose official buy-menu swap weapons (M4, pistols, etc.) on legacy CS:GO.",
    version     = PLUGIN_VERSION,
    url         = "https://forums.alliedmods.net/"
};

public void OnPluginStart()
{
    CreateConVar("sm_legacy_swp_version", PLUGIN_VERSION, "Legacy CS:GO SWP menu version", FCVAR_NOTIFY);
    g_hCvarEnabled = CreateConVar("sm_legacy_swp_enabled", "1", "Enable/disable legacy CS:GO SWP menu.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hCookie_CTRifle = RegClientCookie("legacy_swp_ct_rifle", "SWP CT rifle: 0 = M4A4, 1 = M4A1-S", CookieAccess_Protected);
    g_hCookie_CTStartPistol = RegClientCookie("legacy_swp_ct_startpistol", "SWP CT start pistol: 0 = P2000, 1 = USP-S", CookieAccess_Protected);
    g_hCookie_CTPistolSlot4 = RegClientCookie("legacy_swp_ct_pistol_s4", "SWP CT pistol slot4: 0 = Five-SeveN, 1 = CZ75", CookieAccess_Protected);
    g_hCookie_TPistolSlot4 = RegClientCookie("legacy_swp_t_pistol_s4", "SWP T pistol slot4: 0 = Tec-9, 1 = CZ75", CookieAccess_Protected);
    g_hCookie_PistolSlot5 = RegClientCookie("legacy_swp_pistol_s5", "SWP pistol slot5: 0 = Deagle, 1 = Revolver", CookieAccess_Protected);
    g_hCookie_SMGSlot = RegClientCookie("legacy_swp_smg_slot", "SWP SMG slot: 0 = MP7, 1 = MP5-SD", CookieAccess_Protected);

    RegConsoleCmd("sm_swp", Command_SwpMenu, "Open SWP weapon swap menu.");

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    // Only show MP5-SD option if the game actually supports it (older builds won't).
    g_bHasMP5SD = (CS_AliasToWeaponID("mp5sd") != CSWeapon_NONE);
}

public void OnClientPutInServer(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    g_iCTRifleChoice[client] = LOADOUT_CT_RIFLE_M4A4;
    g_iCTStartPistolChoice[client] = LOADOUT_CT_START_P2000;
    g_iCTPistolSlot4Choice[client] = 0; // Five-SeveN
    g_iTPistolSlot4Choice[client] = 0;  // Tec-9
    g_iPistolSlot5Choice[client] = 0;   // Desert Eagle
    g_iSMGSlotChoice[client] = 0;       // MP7
    g_bIgnoreBuyHook[client] = false;
}

public void OnClientDisconnect(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    g_bIgnoreBuyHook[client] = false;
}

public void OnClientCookiesCached(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    char value[8];

    GetClientCookie(client, g_hCookie_CTRifle, value, sizeof(value));
    if (value[0] == '\0')
    {
        g_iCTRifleChoice[client] = view_as<int>(LOADOUT_CT_RIFLE_M4A4);
    }
    else
    {
        int val = StringToInt(value);
        if (val != view_as<int>(LOADOUT_CT_RIFLE_M4A4) && val != view_as<int>(LOADOUT_CT_RIFLE_M4A1S))
        {
            val = view_as<int>(LOADOUT_CT_RIFLE_M4A4);
        }
        g_iCTRifleChoice[client] = val;
    }

    g_iCTStartPistolChoice[client] = GetCookieIntOrDefault(client, g_hCookie_CTStartPistol, 0, 0, 1);
    g_iCTPistolSlot4Choice[client] = GetCookieIntOrDefault(client, g_hCookie_CTPistolSlot4, 0, 0, 1);
    g_iTPistolSlot4Choice[client] = GetCookieIntOrDefault(client, g_hCookie_TPistolSlot4, 0, 0, 1);
    g_iPistolSlot5Choice[client] = GetCookieIntOrDefault(client, g_hCookie_PistolSlot5, 0, 0, 1);
    g_iSMGSlotChoice[client] = GetCookieIntOrDefault(client, g_hCookie_SMGSlot, 0, 0, 1);
}

public Action Command_SwpMenu(int client, int args)
{
    if (!g_hCvarEnabled.BoolValue)
    {
        return Plugin_Handled;
    }

    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    ShowSwpMenu(client);
    return Plugin_Handled;
}

void ShowSwpMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Loadout);
    menu.SetTitle("Weapon Swap (SWP)");

    char line[96];

    // CT Starting Pistol
    if (g_iCTStartPistolChoice[client] == view_as<int>(LOADOUT_CT_START_USPS))
        Format(line, sizeof(line), "CT Starting Pistol: USP-S");
    else
        Format(line, sizeof(line), "CT Starting Pistol: P2000");
    menu.AddItem("ct_startpistol", line);

    // CT Rifle slot
    if (g_iCTRifleChoice[client] == view_as<int>(LOADOUT_CT_RIFLE_M4A1S))
        Format(line, sizeof(line), "CT Rifle (Slot 2): M4A1-S");
    else
        Format(line, sizeof(line), "CT Rifle (Slot 2): M4A4");
    menu.AddItem("ct_rifle", line);

    // CT pistol slot4
    if (g_iCTPistolSlot4Choice[client] == 1)
        Format(line, sizeof(line), "CT Pistol (Slot 4): CZ75-Auto");
    else
        Format(line, sizeof(line), "CT Pistol (Slot 4): Five-SeveN");
    menu.AddItem("ct_pistol_s4", line);

    // T pistol slot4
    if (g_iTPistolSlot4Choice[client] == 1)
        Format(line, sizeof(line), "T Pistol (Slot 4): CZ75-Auto");
    else
        Format(line, sizeof(line), "T Pistol (Slot 4): Tec-9");
    menu.AddItem("t_pistol_s4", line);

    // Slot 5 heavy pistol (both teams)
    if (g_iPistolSlot5Choice[client] == 1)
        Format(line, sizeof(line), "Heavy Pistol (Slot 5): R8 Revolver");
    else
        Format(line, sizeof(line), "Heavy Pistol (Slot 5): Desert Eagle");
    menu.AddItem("pistol_s5", line);

    // Optional SMG slot
    if (g_bHasMP5SD)
    {
        if (g_iSMGSlotChoice[client] == 1)
            Format(line, sizeof(line), "SMG: MP5-SD");
        else
            Format(line, sizeof(line), "SMG: MP7");
        menu.AddItem("smg_slot", line);
    }

    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_Loadout(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }

        case MenuAction_Select:
        {
            if (client <= 0 || !IsClientInGame(client))
            {
                return 0;
            }

            char info[32];
            menu.GetItem(item, info, sizeof(info));

            if (StrEqual(info, "ct_rifle"))
            {
                ToggleCTRifle(client);
            }
            else if (StrEqual(info, "ct_startpistol"))
            {
                ToggleCTStartPistol(client);
            }
            else if (StrEqual(info, "ct_pistol_s4"))
            {
                ToggleCTPistolSlot4(client);
            }
            else if (StrEqual(info, "t_pistol_s4"))
            {
                ToggleTPistolSlot4(client);
            }
            else if (StrEqual(info, "pistol_s5"))
            {
                TogglePistolSlot5(client);
            }
            else if (StrEqual(info, "smg_slot"))
            {
                if (g_bHasMP5SD)
                {
                    ToggleSMGSlot(client);
                }
            }

            // Re-open the menu so the player can quickly review / adjust.
            ShowSwpMenu(client);
        }
    }

    return 0;
}

void ToggleCTRifle(int client)
{
    if (g_iCTRifleChoice[client] == view_as<int>(LOADOUT_CT_RIFLE_M4A4))
    {
        g_iCTRifleChoice[client] = LOADOUT_CT_RIFLE_M4A1S;
        PrintToChat(client, "[SWP] CT rifle preference set to M4A1-S.");
    }
    else
    {
        g_iCTRifleChoice[client] = LOADOUT_CT_RIFLE_M4A4;
        PrintToChat(client, "[SWP] CT rifle preference set to M4A4.");
    }

    char value[8];
    IntToString(g_iCTRifleChoice[client], value, sizeof(value));
    SetClientCookie(client, g_hCookie_CTRifle, value);
}

void ToggleCTStartPistol(int client)
{
    if (g_iCTStartPistolChoice[client] == view_as<int>(LOADOUT_CT_START_P2000))
    {
        g_iCTStartPistolChoice[client] = LOADOUT_CT_START_USPS;
        PrintToChat(client, "[SWP] CT starting pistol preference set to USP-S.");
    }
    else
    {
        g_iCTStartPistolChoice[client] = LOADOUT_CT_START_P2000;
        PrintToChat(client, "[SWP] CT starting pistol preference set to P2000.");
    }

    SetCookieInt(client, g_hCookie_CTStartPistol, g_iCTStartPistolChoice[client]);
}

void ToggleCTPistolSlot4(int client)
{
    g_iCTPistolSlot4Choice[client] = (g_iCTPistolSlot4Choice[client] == 0) ? 1 : 0;
    PrintToChat(client, (g_iCTPistolSlot4Choice[client] == 1)
        ? "[SWP] CT pistol slot preference set to CZ75-Auto."
        : "[SWP] CT pistol slot preference set to Five-SeveN.");
    SetCookieInt(client, g_hCookie_CTPistolSlot4, g_iCTPistolSlot4Choice[client]);
}

void ToggleTPistolSlot4(int client)
{
    g_iTPistolSlot4Choice[client] = (g_iTPistolSlot4Choice[client] == 0) ? 1 : 0;
    PrintToChat(client, (g_iTPistolSlot4Choice[client] == 1)
        ? "[SWP] T pistol slot preference set to CZ75-Auto."
        : "[SWP] T pistol slot preference set to Tec-9.");
    SetCookieInt(client, g_hCookie_TPistolSlot4, g_iTPistolSlot4Choice[client]);
}

void TogglePistolSlot5(int client)
{
    g_iPistolSlot5Choice[client] = (g_iPistolSlot5Choice[client] == 0) ? 1 : 0;
    PrintToChat(client, (g_iPistolSlot5Choice[client] == 1)
        ? "[SWP] Heavy pistol preference set to R8 Revolver."
        : "[SWP] Heavy pistol preference set to Desert Eagle.");
    SetCookieInt(client, g_hCookie_PistolSlot5, g_iPistolSlot5Choice[client]);
}

void ToggleSMGSlot(int client)
{
    g_iSMGSlotChoice[client] = (g_iSMGSlotChoice[client] == 0) ? 1 : 0;
    PrintToChat(client, (g_iSMGSlotChoice[client] == 1)
        ? "[SWP] SMG preference set to MP5-SD."
        : "[SWP] SMG preference set to MP7.");
    SetCookieInt(client, g_hCookie_SMGSlot, g_iSMGSlotChoice[client]);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hCvarEnabled.BoolValue)
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return;
    }

    int team = GetClientTeam(client);
    if (team != CS_TEAM_CT)
    {
        return;
    }

    // Small delay to make sure the game has given default spawn weapons.
    CreateTimer(0.1, Timer_ApplySpawnLoadout, GetClientUserId(client));
}

public Action Timer_ApplySpawnLoadout(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    int team = GetClientTeam(client);
    if (team != CS_TEAM_CT)
    {
        return Plugin_Stop;
    }

    ApplySpawnPistol(client);
    return Plugin_Stop;
}

void ApplySpawnPistol(int client)
{
    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    if (weapon == -1)
    {
        return;
    }

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    bool isP2000 = StrEqual(classname, "weapon_hkp2000");
    bool isUSPS = StrEqual(classname, "weapon_usp_silencer");

    if (!isP2000 && !isUSPS)
    {
        return;
    }

    if (g_iCTStartPistolChoice[client] == view_as<int>(LOADOUT_CT_START_USPS) && isP2000)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        GivePlayerItem(client, "weapon_usp_silencer");
    }
    else if (g_iCTStartPistolChoice[client] == view_as<int>(LOADOUT_CT_START_P2000) && isUSPS)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        GivePlayerItem(client, "weapon_hkp2000");
    }
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if (!g_hCvarEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    if (client <= 0 || !IsClientInGame(client))
    {
        return Plugin_Continue;
    }

    int team = GetClientTeam(client);
    if (team != CS_TEAM_CT && team != CS_TEAM_T)
    {
        return Plugin_Continue;
    }

    // Do not block the buy; instead, swap to the preferred SWP weapon on the next frame.
    CreateTimer(0.0, Timer_ApplyPostBuyLoadout, GetClientUserId(client));
    return Plugin_Continue;
}

public Action Timer_ApplyPostBuyLoadout(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    ApplyPostBuyLoadout(client);
    return Plugin_Stop;
}

void ApplyPostBuyLoadout(int client)
{
    int team = GetClientTeam(client);
    if (team != CS_TEAM_CT && team != CS_TEAM_T)
    {
        return;
    }

    // --- CT-only swaps ---
    if (team == CS_TEAM_CT)
    {
        // 主戰步槍：M4A4 <-> M4A1-S（primary slot）
        if (g_iCTRifleChoice[client] == view_as<int>(LOADOUT_CT_RIFLE_M4A1S))
        {
            if (ReplaceWeaponIf(client, CS_SLOT_PRIMARY, "weapon_m4a1", "weapon_m4a1_silencer"))
            {
                PrintBindHint(client, "CT Rifle set to M4A1-S.");
            }
        }
        else
        {
            if (ReplaceWeaponIf(client, CS_SLOT_PRIMARY, "weapon_m4a1_silencer", "weapon_m4a1"))
            {
                PrintBindHint(client, "CT Rifle set to M4A4.");
            }
        }

        // $500 手槍（CT）：Five-SeveN <-> CZ75-Auto（secondary slot）
        if (g_iCTPistolSlot4Choice[client] == 1)
        {
            if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_fiveseven", "weapon_cz75a"))
            {
                PrintBindHint(client, "CT pistol slot set to CZ75-Auto.");
            }
        }
        else
        {
            if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_cz75a", "weapon_fiveseven"))
            {
                PrintBindHint(client, "CT pistol slot set to Five-SeveN.");
            }
        }
    }

    // --- T-only swaps ---
    if (team == CS_TEAM_T)
    {
        // $500 手槍（T）：Tec-9 <-> CZ75-Auto（secondary slot）
        if (g_iTPistolSlot4Choice[client] == 1)
        {
            if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_tec9", "weapon_cz75a"))
            {
                PrintBindHint(client, "T pistol slot set to CZ75-Auto.");
            }
        }
        else
        {
            if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_cz75a", "weapon_tec9"))
            {
                PrintBindHint(client, "T pistol slot set to Tec-9.");
            }
        }
    }

    // --- 兩隊通用：重型手槍（Deagle <-> R8）secondary slot ---
    if (g_iPistolSlot5Choice[client] == 1)
    {
        if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_deagle", "weapon_revolver"))
        {
            PrintBindHint(client, "Heavy pistol set to R8 Revolver.");
        }
    }
    else
    {
        if (ReplaceWeaponIf(client, CS_SLOT_SECONDARY, "weapon_revolver", "weapon_deagle"))
        {
            PrintBindHint(client, "Heavy pistol set to Desert Eagle.");
        }
    }

    // --- 兩隊通用：SMG（MP7 <-> MP5-SD）primary slot ---
    if (g_bHasMP5SD)
    {
        if (g_iSMGSlotChoice[client] == 1)
        {
            if (ReplaceWeaponIf(client, CS_SLOT_PRIMARY, "weapon_mp7", "weapon_mp5sd"))
            {
                PrintBindHint(client, "SMG set to MP5-SD.");
            }
        }
        else
        {
            if (ReplaceWeaponIf(client, CS_SLOT_PRIMARY, "weapon_mp5sd", "weapon_mp7"))
            {
                PrintBindHint(client, "SMG set to MP7.");
            }
        }
    }
}

static int GetCookieIntOrDefault(int client, Handle cookie, int defaultValue, int minValue, int maxValue)
{
    char value[16];
    GetClientCookie(client, cookie, value, sizeof(value));
    if (value[0] == '\0')
        return defaultValue;

    int v = StringToInt(value);
    if (v < minValue || v > maxValue)
        return defaultValue;
    return v;
}

static void SetCookieInt(int client, Handle cookie, int v)
{
    char value[16];
    IntToString(v, value, sizeof(value));
    SetClientCookie(client, cookie, value);
}

static void PrintBindHint(int client, const char[] fmt, any ...)
{
    char buffer[128];
    VFormat(buffer, sizeof(buffer), fmt, 3);
    // \x04 = 綠色, \x01 = 預設白色（在 CS:GO 會顯示有顏色的 [Hint] 標籤）
    PrintToChat(client, "\x04[Hint]\x01 %s", buffer);
}

static bool ReplaceWeaponIf(int client, int slot, const char[] fromEnt, const char[] toEnt)
{
    int weapon = GetPlayerWeaponSlot(client, slot);
    if (weapon == -1)
    {
        return false;
    }

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (!StrEqual(classname, fromEnt, false))
    {
        return false;
    }

    RemovePlayerItem(client, weapon);
    AcceptEntityInput(weapon, "Kill");
    GivePlayerItem(client, toEnt);
    return true;
}

