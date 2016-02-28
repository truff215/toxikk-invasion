//================================================================
// package.InfekktedHud
// ----------------
// ...
// ----------------
// by Chatouille
//================================================================
class InfekktedHud extends CRZHudWrapper;

//======== Radar display config ========
var float RadarSize;

var Texture2D RadarBgTex;
var Color RadarBgColor;

var Texture2D RadarFgTex;
var Color RadarFgColor;

var Texture2D RadarScanTex;
var Color RadarScanColor;

var float RadarUpdateInterval;
var float RadarScanTime;
var float RadarItemDuration;

var Texture2D RadarFriendlyTex;
var Color RadarFriendlyColor;
var float RadarFriendlySize;

var Texture2D RadarMonsterTex;
var Color RadarMonsterColor;
var float RadarMonsterSize;

var Texture2D RadarBossTex;
var Color RadarBossColor;
var float RadarBossSize;

//======== Internal ========
var float RadarMaxDistSqrt;

struct sRadarItem
{
	var Vector WorldLoc;
	var Texture2D Tex;
	var Color Col;
	var float Size;
	var bool bShowing;
	var float Alpha;

	structdefaultproperties
	{
		Alpha=1.0
	}
};
var array<sRadarItem> PrevRadarItems;
var array<sRadarItem> RadarItems;

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();

	SetTimer(RadarUpdateInterval, true, 'UpdateRadar');
}

simulated function UpdateRadar()
{
	local Pawn P;
	local int i;

	PrevRadarItems = RadarItems;
	RadarItems.Length = 0;
	foreach WorldInfo.AllPawns(class'Pawn', P)
	{
		if ( P.Health <= 0 || P == PlayerOwner.Pawn )
			continue;

		i = RadarItems.Length;
		RadarItems.Add(1);

		RadarItems[i].WorldLoc = P.Location;

		if ( CRZPawn(P) != None )
		{
			RadarItems[i].Tex = RadarFriendlyTex;
			RadarItems[i].Col = RadarFriendlyColor;
			RadarItems[i].Size = RadarFriendlySize;
		}
		else if ( ToxikkMonster(P) != None && ToxikkMonster(P).bIsBossMonster )
		{
			RadarItems[i].Tex = RadarBossTex;
			RadarItems[i].Col = RadarBossColor;
			RadarItems[i].Size = RadarBossSize;
		}
		else
		{
			RadarItems[i].Tex = RadarMonsterTex;
			RadarItems[i].Col = RadarMonsterColor;
			RadarItems[i].Size = RadarMonsterSize;
		}
	}
	SetTimer(RadarScanTime, false, 'RadarScanTimer');
}

simulated function RadarScanTimer() {}

simulated event PostRender()
{
	Super.PostRender();

	if ( RadarMaxDistSqrt > 0 )
		DrawRadar();
	else if ( InfekktedGRI(WorldInfo.GRI) != None && InfekktedGRI(WorldInfo.GRI).AvgMapSize > 0 )
		RadarMaxDistSqrt = Sqrt( InfekktedGRI(WorldInfo.GRI).AvgMapSize );
}

simulated function DrawRadar()
{
	local float RadarPosX, RadarPosY;
	local float ScanPct, ScanSize;
	local Vector MyLoc, V;
	local Rotator MyRot;
	local int i;
	local float DistSqrt, DistOnRadar, Angle;

	RadarPosX = Canvas.ClipX - 1.1*RadarSize;
	RadarPosY = Canvas.ClipY * 0.2;

	Canvas.DrawColor = RadarBgColor;
	Canvas.SetPos(RadarPosX, RadarPosY);
	Canvas.DrawTile(RadarBgTex, RadarSize, RadarSize, 0, 0, RadarBgTex.SizeX, RadarBgTex.SizeY);
	Canvas.DrawColor = RadarFgColor;
	Canvas.SetPos(RadarPosX, RadarPosY);
	Canvas.DrawTile(RadarFgTex, RadarSize, RadarSize, 0, 0, RadarFgTex.SizeX, RadarFgTex.SizeY);

	ScanPct = 1.0 - (FMax(GetRemainingTimeForTimer('RadarScanTimer'),0.0) / RadarScanTime);
	if ( ScanPct < 1.0 )
	{
		ScanPct = Sin(ScanPct*Pi/2);
		ScanSize = ScanPct * (RadarSize+16);
		Canvas.SetPos(RadarPosX + (RadarSize-ScanSize)/2, RadarPosY + (RadarSize-ScanSize)/2);
		Canvas.SetDrawColor(RadarScanColor.R, RadarScanColor.G, RadarScanColor.B, byte((1.0-ScanPct)*RadarScanColor.A));
		Canvas.DrawTile(RadarScanTex, ScanSize, ScanSize, 0, 0, RadarScanTex.SizeX, RadarScanTex.SizeY);
	}

	PlayerOwner.GetPlayerViewPoint(MyLoc, MyRot);

	for ( i=0; i<PrevRadarItems.Length; i++ )
	{
		if ( PrevRadarItems[i].Alpha <= 0 )
			continue;

		V = PrevRadarItems[i].WorldLoc - MyLoc;
		DistSqrt = Sqrt( VSize2D(V) );
		if ( DistSqrt > RadarMaxDistSqrt )
			continue;

		DistOnRadar = (DistSqrt / RadarMaxDistSqrt) * RadarSize / 2;
		Angle = (Rotator(V).Yaw - MyRot.Yaw - 16384) * 2*Pi / 65536;

		Canvas.SetPos(RadarPosX + (RadarSize/2) + DistOnRadar*Cos(Angle) - (PrevRadarItems[i].Size/2), RadarPosY + (RadarSize/2) + DistOnRadar*Sin(Angle) - (PrevRadarItems[i].Size/2));
		Canvas.SetDrawColor(PrevRadarItems[i].Col.R, PrevRadarItems[i].Col.G, PrevRadarItems[i].Col.B, byte(PrevRadarItems[i].Alpha*PrevRadarItems[i].Col.A));
		Canvas.DrawTile(PrevRadarItems[i].Tex, PrevRadarItems[i].Size, PrevRadarItems[i].Size, 0, 0, PrevRadarItems[i].Tex.SizeX, PrevRadarItems[i].Tex.SizeY);

		PrevRadarItems[i].Alpha -= (RenderDelta / RadarItemDuration);
	}
	for ( i=0; i<RadarItems.Length; i++ )
	{
		if ( RadarItems[i].Alpha <= 0 )
			continue;

		V = RadarItems[i].WorldLoc - MyLoc;
		DistSqrt = Sqrt( VSize2D(V) );
		if ( DistSqrt > RadarMaxDistSqrt )
			continue;

		if ( RadarItems[i].bShowing )
		{
			DistOnRadar = (DistSqrt / RadarMaxDistSqrt) * RadarSize / 2;
			Angle = (Rotator(V).Yaw - MyRot.Yaw - 16384) * 2*Pi / 65536;

			Canvas.SetPos(RadarPosX + (RadarSize/2) + DistOnRadar*Cos(Angle) - (RadarItems[i].Size/2), RadarPosY + (RadarSize/2) + DistOnRadar*Sin(Angle) - (RadarItems[i].Size/2));
			Canvas.SetDrawColor(RadarItems[i].Col.R, RadarItems[i].Col.G, RadarItems[i].Col.B, byte(RadarItems[i].Alpha*RadarItems[i].Col.A));
			Canvas.DrawTile(RadarItems[i].Tex, RadarItems[i].Size, RadarItems[i].Size, 0, 0, RadarItems[i].Tex.SizeX, RadarItems[i].Tex.SizeY);

			RadarItems[i].Alpha -= (RenderDelta / RadarItemDuration);
		}
		else if ( DistSqrt <= ScanPct*RadarMaxDistSqrt )
			RadarItems[i].bShowing = true;
	}
}

defaultproperties
{
	RadarSize=300

	RadarBgTex=Texture2D'CRZGFx.HUD_I3D'
	RadarBgColor=(R=0,G=0,B=0,A=255)

	RadarFgTex=Texture2D'UDKHUD.ut3_minimap_compass'
	RadarFgColor=(R=255,G=255,B=255,A=255)

	RadarScanTex=Texture2D'CastleHUD.HUD_TouchToMove'   //Texture2D'fx_particles_01.flares.Textures.MF_T_FlareRing_01_D'
	RadarScanColor=(R=100,G=200,B=255,A=200)

	RadarUpdateInterval=1.4
	RadarScanTime=1.2
	RadarItemDuration=1.0

	RadarFriendlyTex=Texture2D'CastleHUD.HUD_TouchToMove'
	RadarFriendlyColor=(R=0,G=255,B=0,A=255)
	RadarFriendlySize=32

	RadarMonsterTex=Texture2D'EngineVolumetrics.LightBeam.Materials.T_EV_LightBeam_Falloff_02'
	RadarMonsterColor=(R=255,G=255,B=0,A=255)
	RadarMonsterSize=24

	RadarBossTex=Texture2D'UDKHUD.skull'
	RadarBossColor=(R=255,G=0,B=0,A=255)
	RadarBossSize=40
}