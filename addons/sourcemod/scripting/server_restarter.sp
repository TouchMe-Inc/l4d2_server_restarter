#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>


public Plugin myinfo = {
    name        = "ServerRestarter",
    author      = "TouchMe",
    description = "Restarts the server when all players have disconnected",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_server_restarter"
}


ConVar g_cvAllBotGame = null;

float g_fLastDisconnectTime  = -1.0;


public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvAllBotGame = FindConVar("sb_all_bot_game");

    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnMapStart()
{
    static bool bFirstMapLoaded = false;
    if (bFirstMapLoaded)
    {
        CreateTimer(60.0, Timer_OnMapStart, .flags = TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    bFirstMapLoaded = true;
}

Action Timer_OnMapStart(Handle hTimer)
{
    if (IsEmptyServer()) {
        RestartServer();
    }

    return Plugin_Stop;
}

public void OnClientConnected(int iClient)
{
	if (IsFakeClient(iClient)) {
		return;
	}

	if (!GetConVarBool(g_cvAllBotGame)) {
		SetConVarBool(g_cvAllBotGame, true, .notify = false);
	}
}

void Event_PlayerDisconnect(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!iClient || !IsClientConnected(iClient) || IsFakeClient(iClient)) {
        return;
    }

    float fDisconnectTime = GetGameTime();
    if (g_fLastDisconnectTime == fDisconnectTime) {
        return;
    }

    g_fLastDisconnectTime = fDisconnectTime;

    CreateTimer(0.5, Timer_PlayerDisconnect, fDisconnectTime, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(15.0, Timer_HibernateServer, fDisconnectTime, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PlayerDisconnect(Handle hTimer, float fDisconnectTime)
{
    if (fDisconnectTime != -1.0 && fDisconnectTime != g_fLastDisconnectTime) {
        return Plugin_Stop;
    }

    if (IsEmptyServer()) {
        RestartServer();
    }

    return Plugin_Stop;
}

Action Timer_HibernateServer(Handle hTimer, float fDisconnectTime)
{
	if (fDisconnectTime != -1.0 && fDisconnectTime != g_fLastDisconnectTime) {
		return Plugin_Stop;
	}

	if (!IsEmptyServer()) {
		return Plugin_Stop;
	}

	SetConVarBool(g_cvAllBotGame, false, .notify = false);

	return Plugin_Stop;
}

void RestartServer()
{
    SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
    ServerCommand("crash");
}

bool IsEmptyServer()
{
    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (IsClientConnected(iClient) && !IsFakeClient(iClient)) {
            return false;
        }
    }

    return true;
}
