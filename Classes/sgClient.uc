///////////////////////////////////////
// Client settings and exchange class

//The test mode will spawn one per server, should be one per client at some point

class sgClient expands ReplicationInfo
	config(SiegeClient);

var PlayerPawn LocalPlayer;
var weapon LocalWeapon;

var FV_sgConstructorPanel ConstructorPanel;

//LOCALE LOADING IS AUTOMATIC
var() bool bUseSmallGui;
var() bool bOldConstructor;
var() bool bBuildingLights;
var() float GuiSensitivity; //0-1
var() float SirenVol; //0-1
var() string FingerPrint;
var() bool bFPnoReplace; //Never replace fingerprint
var() bool bUseLC; //Lag compensation >>>> DEPRECATED
var() bool bUseNewDeco;
var() bool bBuildInfo; //Alternative build interface
var() bool bClientIGDropFix;
var() config bool bHighPerformance;
var() float ScoreboardBrightness;

var bool bSendFingerPrint;
var int iChance;
var bool bTimeoutSafety;
var IntFileWriter Writer;
var bool bTriggerSave;

var Object TmpOuter;
var sgClientSettings sgSet;

//Fix erroneous settings and initialize fingerprint system
simulated event PostBeginPlay()
{
	local PlayerPawn P;
	local sgScore ScoreBoard;
	local WildcardsResources WRU;

	ForEach AllActors (class'PlayerPawn', P)
		if ( ViewPort(P.Player) != none )
		{
			LocalPlayer = P;
			break;
		}
	if ( LocalPlayer == none )
	{
		Destroy();
		return;
	}
	if ( Owner == none )
		SetOwner(LocalPlayer);
	bSendFingerPrint = true;
	iChance = 2;
	SetTimer(2.5 * Level.TimeDilation, false);
	TmpOuter = new(self,'SiegeClient') class'Object';
	sgSet = new(TmpOuter,'Settings') class'sgClientSettings';
	LoadSettings();
	GuiSensitivity = fClamp( GuiSensitivity, 0, 1);
	SirenVol = fClamp( SirenVol, 0.1, 1);

	if ( FingerPrint == "" )
		GenerateFingerPrint();
	ClientSetBind();
	
	ForEach AllActors (class'sgScore', ScoreBoard)
	{
		ScoreBoard.ClientActor = self;
		break;
	}

	ConstructorPanel = new( self, 'sgConstructorPanel') class'FV_sgConstructorPanel';
	ConstructorPanel.LocalPlayer = LocalPlayer;

	if ( Level.NetMode != NM_ListenServer )
	{	if ( bHighPerformance )
			ForEach AllActors (class'WildcardsResources', WRU)
				WRU.LightType = LT_None;
		else
			ForEach AllActors (class'WildcardsResources', WRU)
				WRU.LightType = LT_Steady;
	}
}

//Execute timed actions here
simulated event Timer()
{
	if ( bSendFingerPrint )
	{
		if ( LocalPlayer.PlayerReplicationInfo == none )
		{
			ForEach LocalPlayer.ChildActors (class'PlayerReplicationInfo', LocalPlayer.PlayerReplicationInfo )
			{
				SetTimer( 1 * Level.TimeDilation, false);
				return;
			}
			if ( iChance-- > 0 )
			{
				SetTimer(3 * Level.TimeDilation, false);
				return;
			}
			LocalPlayer.ClientMessage("Own PRI actor not received, this is a network problem and you're being disconnected");
			LocalPlayer.ConsoleCommand("disconnect");
			return;
		}
		if ( !bTimeoutSafety && (InStr(LocalPlayer.PlayerReplicationInfo.PlayerName, "Player") != -1) )
		{
			bTimeoutSafety = true;
			sgPRI(LocalPlayer.PlayerReplicationInfo).RequestFPTime();
			SetTimer(5 * Level.TimeDilation, false);
			return;
		}
		sgPRI(LocalPlayer.PlayerReplicationInfo).SendFingerPrint( FingerPrint);
		bSendFingerPrint = false;
	}
}

simulated function AdjustSensitivity( int i)
{
	GuiSensitivity = fClamp( GuiSensitivity + 0.1 * float(i), 0, 1);
	sgSet.GuiSensitivity = GuiSensitivity;
	SaveSettings();
}

simulated function AdjustSirenVol( int i)
{
	SirenVol = fClamp( SirenVol + 0.1 * float(i), 0.1, 1);
	sgSet.SirenVol = SirenVol;
	SaveSettings();
}

simulated function SlideSensitivity( float aF)
{
	GuiSensitivity = fClamp( aF, 0, 1);
	sgSet.GuiSensitivity = GuiSensitivity;
	SaveSettings();
}

simulated function AdjustScoreBright( int i)
{
	ScoreboardBrightness = fClamp( ScoreboardBrightness + 0.1 * float(i), 0, 1);
	sgSet.ScoreboardBrightness = ScoreboardBrightness;
	SaveSettings();
}

simulated function ToggleSize()
{
	bUseSmallGui = !bUseSmallGui;
	sgSet.bUseSmallGui = bUseSmallGui;
	SaveSettings();
}

simulated function ToggleConstructor()
{
	bOldConstructor = !bOldConstructor;
	sgSet.bOldConstructor = bOldConstructor;
	SaveSettings();
}

simulated function ToggleKeepFP()
{
	bFPnoReplace = !bFPnoReplace;
	sgSet.bFPnoReplace = bFPnoReplace;
	SaveSettings();
}

simulated function ToggleBInterface()
{
	bBuildInfo = !bBuildInfo;
	sgSet.bBuildInfo = bBuildInfo;
	SaveSettings();
}

simulated function TogglePerformance()
{
	local WildcardsResources WRU;
	bHighPerformance = !bHighPerformance;
	default.bHighPerformance = bHighPerformance;
	sgSet.bHighPerformance = bHighPerformance;
	if ( Level.NetMode != NM_ListenServer )
	{	if ( bHighPerformance )
			ForEach AllActors (class'WildcardsResources', WRU)
				WRU.LightType = LT_None;
		else
			ForEach AllActors (class'WildcardsResources', WRU)
				WRU.LightType = LT_Steady;
	}
	SaveSettings();
}

simulated function GenerateFingerprint()
{
	local string aStr;
	local int aInt;
	
	aStr = string(Rand(100)) $ "_" $ string(Level.Year) $ "." $ string( Level.Month) $ "." $ string(Level.Day);
	if ( LocalPlayer.PlayerReplicationInfo != none )
		aStr = aStr $ "_" $ LocalPlayer.PlayerReplicationInfo.PlayerName;
	FingerPrint = aStr;
	sgSet.FingerPrint = FingerPrint;
	SaveSettings();
}

simulated event Tick( float DeltaTime)
{
	if ( LocalPlayer == none ) //WTF?, IS THIS A DEMO?
		return;
	if ( LocalWeapon != LocalPlayer.Weapon )
	{
		if ( sgConstructor(LocalWeapon) != none )
			ConstructorPanel.ConstructorDown();
		LocalWeapon = LocalPlayer.Weapon;
	}
	if ( sgConstructor(LocalWeapon) != none )
		ConstructorPanel.Tick( DeltaTime);
}

//Load strings from custom INI
simulated function LoadSettings()
{
	bUseSmallGui = sgSet.bUseSmallGui;
	bOldConstructor = sgSet.bOldConstructor;
	bBuildingLights = sgSet.bBuildingLights;
	GuiSensitivity = sgSet.GuiSensitivity;
	SirenVol = sgSet.SirenVol;
	FingerPrint = sgSet.FingerPrint;
	bFPnoReplace  = sgSet.bFPnoReplace;
	ScoreboardBrightness  = sgSet.ScoreboardBrightness;
	bClientIGDropFix = sgSet.bClientIGDropFix;
	bHighPerformance = sgSet.bHighPerformance;
	default.bHighPerformance = bHighPerformance;
	sgSet.SaveConfig();
}

//Save this class' settings into the SiegeClient localized file
simulated function SaveSettings()
{
	sgSet.SaveConfig();
}

simulated function CheckWriter()
{
	if ( Writer == none )
		Writer = Spawn(class'IntFileWriter');
}

simulated function LoadAndSet( string PropName)
{
	local string Value;
	Value = Locale(PropName);
	Log( Value);
	if ( Value != "" )
		SetPropertyText( PropName, Value);
	else
		bTriggerSave = true;
}
simulated function string Locale( string PropName)
{
	local string S;
	S = Localize ( "SiegeClient", PropName, "SiegeClient");
	Log( S);
	if ( Left( S, 2) == "<?" )
		return "";
	return S;
}

simulated function ClientSetBind()
{
	local int key;
	local string keyName, bind, bindCaps;
	local PlayerPawn playerOwner;

	LocalPlayer.ConsoleCommand("SET INPUT F3 SiegeStats");
	LocalPlayer.ConsoleCommand("SET INPUT F7 TeamRU");

	for ( key = 1; key < 255; key++ )
	{
		keyName = LocalPlayer.ConsoleCommand("KEYNAME"@key);
		bind = LocalPlayer.ConsoleCommand("KEYBINDING"@keyName);
		bindCaps = Caps(bind);
        if ( Left(bindCaps, 4) == "JUMP" || InStr(bindCaps, " JUMP") != -1 || InStr(bindCaps, "|JUMP") != -1 )
		{
			if ( Left(bindCaps, 10) != "SETJETPACK" &&
              InStr(bindCaps, " SETJETPACK") == -1 &&
              InStr(bindCaps, "|SETJETPACK") == -1 )
			{
				bind = "SetJetpack 1|"$bind$"|OnRelease SetJetpack 0";
				LocalPlayer.ConsoleCommand("SET INPUT"@keyName@bind);
			}
		}
	}
}

defaultproperties
{
     SirenVol=1
     bAlwaysRelevant=False
     GuiSensitivity=0.5
     bNetTemporary=True
     RemoteRole=ROLE_SimulatedProxy
     bOldConstructor=True
     bUseLC=True
     bUseNewDeco=True
     bClientIGDropFix=True
}
