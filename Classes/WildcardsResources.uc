//=============================================================================
// WildcardsResources. 
//=============================================================================
class WildcardsResources expands TournamentPickup;

var() int RU;
var() int GlowHue;
var() int GlowSaturation;


simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	if ( bUnlit != true ) //UTPure doing gay shit again
		FixDefaults();
	if ( class'sgClient'.default.bHighPerformance )
		LightType = LT_None;
}

event BeginPlay()
{
	LightEffect=LE_None;
	LightBrightness=255;
	LightHue=GlowHue;
	LightRadius=8;
	LightSaturation=GlowSaturation;
	LightType=LT_Steady;
}

function PickupFunction(Pawn other)
{
    if ( Pawn(Owner) != None && sgPri(Pawn(Owner).PlayerReplicationInfo) != None )
	    sgPri(Pawn(Owner).PlayerReplicationInfo).AddRU(RU);
	Super.PickupFunction(other);
	Destroy();
}

event float BotDesireability(Pawn Bot)
{
	if ( sgPRI(Bot.PlayerReplicationInfo) != none && sgPRI(Bot.PlayerReplicationInfo).RU < sgPRI(Bot.PlayerReplicationInfo).MaxRU )
		return 1;
	return -1;
}

simulated function FixDefaults()
{
	Style = STY_Translucent;
	bUnlit = True;
	Default.Style = STY_Translucent;
	Default.bUnlit = True;
}

defaultproperties
{
     PickupMessage="堠С"
     PickupViewMesh=LodMesh'Botpack.Diamond'
     PickupSound=Sound'RuPickupSnd01'
     bEdShouldSnap=True
     Style=STY_Translucent
     Texture=WetTexture'WaveRUSkin01'
     Mesh=LodMesh'Botpack.Diamond'
     DrawScale=0.750000
     ScaleGlow=0.500000
     bUnlit=True
     bNoSmooth=True
     bMeshEnviroMap=True
     bMeshCurvy=True
}
