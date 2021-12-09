/*

Tehbot  Copyright � 2012  Tehtsuo and Vendan

This file is part of Tehbot.

Tehbot is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Tehbot is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Tehbot.  If not, see <http://www.gnu.org/licenses/>.

*/

objectdef obj_Ship inherits obj_StateQueue
{
	; Module list name and its query id.
	variable collection:uint ModuleListQueryID

	; Avoid creating duplicate operators for the same module.
	variable collection:obj_Module RegisteredModule

	variable set ActiveJammerSet
	variable set ActiveNeuterSet

	; A Set doesn't keep the order of inserted key so we need another container
	variable index:string ActiveJammerList
	variable index:string ActiveNeuterList

	variable bool verbose = TRUE

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This:AddModuleList[ArmorProjectors, "ToItem.GroupID = GROUP_ARMOR_PROJECTOR"]
		This:AddModuleList[ShieldTransporters, "ToItem.GroupID = GROUP_SHIELD_TRANSPORTER"]
		This:AddModuleList[MiningLaser, "ToItem.GroupID = GROUP_MININGLASER || ToItem.GroupID = GROUP_STRIPMINER || ToItem.GroupID = GROUP_FREQUENCYMININGLASER"]
		This:AddModuleList[Weapon, "ToItem.GroupID = GROUP_PRECURSORWEAPON || ToItem.GroupID = GROUP_ENERGYWEAPON || ToItem.GroupID = GROUP_PROJECTILEWEAPON || ToItem.GroupID = GROUP_HYBRIDWEAPON || ToItem.GroupID = GROUP_MISSILELAUNCHERRAPIDHEAVY || ToItem.GroupID = GROUP_MISSILELAUNCHER || ToItem.GroupID = GROUP_MISSILELAUNCHERASSAULT || ToItem.GroupID = GROUP_MISSILELAUNCHERBOMB || ToItem.GroupID = GROUP_MISSILELAUNCHERCITADEL || ToItem.GroupID = GROUP_MISSILELAUNCHERCRUISE || ToItem.GroupID = GROUP_MISSILELAUNCHERDEFENDER || ToItem.GroupID = GROUP_MISSILELAUNCHERHEAVY || ToItem.GroupID = GROUP_MISSILELAUNCHERHEAVYASSAULT || ToItem.GroupID = GROUP_MISSILELAUNCHERROCKET || ToItem.GroupID = GROUP_MISSILELAUNCHERTORPEDO || ToItem.GroupID = GROUP_MISSILELAUNCHERSTANDARD"]
		This:AddModuleList[ECCM, "ToItem.GroupID = GROUP_ECCM"]
		This:AddModuleList[ActiveResists, "ToItem.GroupID = GROUP_SHIELD_HARDENER || ToItem.GroupID = GROUP_ARMOR_HARDENERS || ToItem.GroupID = GROUP_ARMOR_RESISTANCE_SHIFT_HARDENER"]
		This:AddModuleList[DamageControl, "ToItem.GroupID = GROUP_DAMAGE_CONTROL"]
		This:AddModuleList[Regen_Shield, "ToItem.GroupID = GROUP_SHIELD_BOOSTER"]
		This:AddModuleList[Repair_Armor, "ToItem.GroupID = GROUP_ARMOR_REPAIRERS"]
		This:AddModuleList[Repair_Hull, "ToItem.GroupID = NONE"]
		This:AddModuleList[AB_MWD, "ToItem.GroupID = GROUP_AFTERBURNER"]
		This:AddModuleList[Salvagers, "ToItem.GroupID = GROUP_SALVAGER"]
		This:AddModuleList[TractorBeams, "ToItem.GroupID = GROUP_TRACTOR_BEAM"]
		This:AddModuleList[Cloaks, "ToItem.GroupID = GROUP_CLOAKING_DEVICE"]
		This:AddModuleList[Scrambler, "ToItem.GroupID = GROUP_SCRAMBLER"]
		This:AddModuleList[SurveyScanner, "ToItem.GroupID = GROUP_SURVEYSCANNER"]
		This:AddModuleList[CommandBurst, "ToItem.GroupID = GROUP_COMMANDBURST"]
		This:AddModuleList[StasisWeb, "ToItem.GroupID = GROUP_STASIS_WEB"]
		This:AddModuleList[StasisGrap, "ToItem.GroupID = GROUP_STASIS_GRAPPLER"]
		This:AddModuleList[SensorBoost, "ToItem.GroupID = GROUP_SENSORBOOSTER"]
		This:AddModuleList[TargetPainter, "ToItem.GroupID = GROUP_TARGETPAINTER"]
		This:AddModuleList[EnergyVampire, "ToItem.GroupID = GROUP_ENERGY_VAMPIRE"]
		This:AddModuleList[TrackingComputer, "ToItem.GroupID = GROUP_TRACKINGCOMPUTER || ToItem.GroupID = GROUP_MISSILEGUIDANCECOMPUTER"]
		This:AddModuleList[GangLinks, "ToItem.GroupID = GROUP_GANGLINK"]
		This:AddModuleList[DroneControlUnit, "ToItem.GroupID = GROUP_DRONECONTROLUNIT"]
		This:AddModuleList[EnergyTransfer, "ToItem.GroupID = GROUP_ENERGY_TRANSFER"]
		This:AddModuleList[AutoTarget, "ToItem.GroupID = GROUP_AUTOMATED_TARGETING_SYSTEM"]
		This:AddModuleList[Siege, "ToItem.GroupID = GROUP_SIEGEMODULE"]
		This:AddModuleList[TargetModules, "MaxRange>0"]
		; This:AddModuleList[Passive, "!IsActivatable"]
		This:Clear
		This:QueueState["WaitForInSpace"]
		This:QueueState["UpdateModules", 5000]
	}

	method AddModuleList(string Name, string QueryString)
	{
		This.ModuleListQueryID:Set[${Name}, ${LavishScript.CreateQuery[${QueryString.Escape}]}]
		declarevariable ModuleList_${Name} obj_ModuleList object
	}

	member:bool WaitForInSpace()
	{
		if ${Client.InSpace}
		{
			return TRUE
		}
		return FALSE
	}

	member:bool WaitForInStation()
	{
		if ${Me.InStation}
		{
			return TRUE
		}
		return FALSE
	}

	member:bool UpdateModules()
	{
		This:LogInfo["Update Called"]

		if !${Client.InSpace}
		{
			This:LogCritical["UpdateModules called while in station"]
			This:Clear
			This:QueueState["WaitForInSpace"]
			This:QueueState["UpdateModules"]
			return TRUE
		}

		variable string moduleListName

		if ${ModuleListQueryID.FirstKey(exists)}
		{
			do
			{
				moduleListName:Set[${ModuleListQueryID.CurrentKey}]
				This.ModuleList_${moduleListName}:Clear
			}
			while ${ModuleListQueryID.NextKey(exists)}
		}

		variable index:module shipModules
		MyShip:GetModules[shipModules]
		if !${shipModules.Used} && ${MyShip.HighSlots} > 0
		{
			This:LogCritical["UpdateModuleList - No modules found. Retrying in a few seconds", "o"]
			This:LogCritical["If this ship has slots, you must have at least one module equipped, of any type.", "o"]

			This:InsertState["UpdateModules", 5000]
			return TRUE
		}

		variable iterator moduleIterator
		shipModules:GetIterator[moduleIterator]
		if ${moduleIterator:First(exists)}
		do
		{
			if !${moduleIterator.Value(exists)}
			{
				This:LogCritical["UpdateModuleList - Null module found. Retrying in a few seconds.", "o"]
				This:InsertState["UpdateModules", 5000]
				return TRUE
			}

			if ${moduleIterator.Value.IsActivatable} && !${RegisteredModule.Element[${moduleIterator.Value.ID}](exists)}
			{
				This:LogDebug["Registering module ${moduleIterator.Value.ID} ${moduleIterator.Value.Name}", "g"]
				RegisteredModule:Set[${moduleIterator.Value.ID}, ${moduleIterator.Value.ID}]
			}
			; TODO deattach atoms and remove object for modules no longer present.

			if ${ModuleListQueryID.FirstKey(exists)}
			{
				do
				{
					moduleListName:Set[${ModuleListQueryID.CurrentKey}]
					; This:LogDebug[" inserting, group ${moduleListName}, query of which is ${ModuleListQueryID.CurrentValue}"]
					if ${LavishScript.QueryEvaluate[${ModuleListQueryID.CurrentValue}, moduleIterator.Value]}
					{
						; This:LogDebug[" insert ${moduleIterator.Value.ID} ${moduleIterator.Value.Name} ${RegisteredModule.Element[${moduleIterator.Value.ID}].ModuleID} to group ${moduleListName}"]
						ModuleList_${moduleListName}:Insert[${moduleIterator.Value.ID}]
					}
				}
				while ${ModuleListQueryID.NextKey(exists)}
			}
		}
		while ${moduleIterator:Next(exists)}

		This:LogInfo["Ship Module Inventory", "y"]
		if ${ModuleListQueryID.FirstKey(exists)} && ${verbose}
		{
			do
			{
				moduleListName:Set[${ModuleListQueryID.CurrentKey}]

				This.ModuleList_${moduleListName}:GetIterator[moduleIterator]
				if ${moduleIterator:First(exists)}
				{
					This:LogInfo["Active module list ${moduleListName}:", "g"]
					do
					{
						This:LogInfo[" Slot: ${MyShip.Module[${moduleIterator.Value}].ToItem.Slot} ${MyShip.Module[${moduleIterator.Value}].ToItem.Name}", "-g"]
					}
					while ${moduleIterator:Next(exists)}
				}
			}
			while ${ModuleListQueryID.NextKey(exists)}

			verbose:Set[FALSE]
		}

		if ${This.ModuleList_AB_MWD.Used} > 1
		{
			This:LogInfo["Warning: More than 1 Afterburner or MWD was detected, I will only use the first one.", "o"]
		}
		This:QueueState["WaitForInStation"]
		This:QueueState["WaitForInSpace"]
		This:QueueState["UpdateModules"]
		return TRUE
	}

	member:bool IsClosebyFrigate(int64 targetID)
	{
		if (${Entity[${targetID}].Group.Find[Frigate]} && ${Entity[${targetID}].Distance} < 15000) || \
		   (${Entity[${targetID}].Group.Find[Destroyer]} && ${Entity[${targetID}].Distance} < 10000)
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}

	member:bool IsHardToDealWithTarget(int64 targetID)
	{
		; TODO Add Missile judgement
		return ${This.IsClosebyFrigate[${targetID}]}
	}

	method BuildActiveJammerList()
	{
		ActiveJammerSet:Clear
		ActiveJammerList:Clear

		variable index:jammer attackers
		variable iterator attackerIterator
		Me:GetJammers[attackers]
		attackers:GetIterator[attackerIterator]
		if ${attackerIterator:First(exists)}
		do
		{
			variable index:string jams
			variable iterator jamsIterator
			attackerIterator.Value:GetJams[jams]
			jams:GetIterator[jamsIterator]
			if ${jamsIterator:First(exists)}
			{
				do
				{
					if ${jamsIterator.Value.Lower.Find["warp"]}
					{
						; Both scramble and disrupt ew warpScramblerMWD
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["trackingdisrupt"]}
					{
						; ewTrackingDisrupt
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["electronic"]}
					{
						; electronic
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["energy"]}
					{
						; Energy vampire and neutralizer
						; ewEnergyNeut
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["remotesensordamp"]}
					{
						; RemoteSensorDamp
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["webify"]}
					{
						; Webify
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					elseif ${jamsIterator.Value.Lower.Find["targetpaint"]}
					{
						; TargetPaint
						if !${ActiveJammerSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveJammerSet:Add[${attackerIterator.Value.ID}]
							ActiveJammerList:Insert[${attackerIterator.Value.ID}]
						}
					}
					else
					{
						This:LogInfo["unknown EW ${jamsIterator.Value}", "r"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		if !${ActiveJammerSet.Used} != !${ActiveJammerList.Used}
		{
			This:LogCritical["not equal!", "r"]
		}
	}

	method BuildActiveNeuterList()
	{
		ActiveNeuterSet:Clear
		ActiveNeuterList:Clear

		variable index:jammer attackers
		variable iterator attackerIterator
		Me:GetJammers[attackers]
		attackers:GetIterator[attackerIterator]
		if ${attackerIterator:First(exists)}
		do
		{
			variable index:string jams
			variable iterator jamsIterator
			attackerIterator.Value:GetJams[jams]
			jams:GetIterator[jamsIterator]
			if ${jamsIterator:First(exists)}
			{
				do
				{
					if ${jamsIterator.Value.Lower.Find["energy"]}
					{
						; Energy vampire and neutralizer
						; ewEnergyNeut
						if !${ActiveNeuterSet.Contains[${attackerIterator.Value.ID}]}
						{
							ActiveNeuterSet:Add[${attackerIterator.Value.ID}]
							ActiveNeuterList:Insert[${attackerIterator.Value.ID}]
						}
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		if !${ActiveNeuterSet.Used} != !${ActiveNeuterList.Used}
		{
			This:LogCritical["not equal!", "r"]
		}
	}

	; TODO: update for other ships
	member:string FallbackAmmo()
	{
		return "Conflagration L"
	}

	member:string FallbackSecondaryAmmo()
	{
		return "Scorch L"
	}

	member:float TurretChanceToHit(int64 targetID)
	{
		; Target relative coordinate and velocity.
		variable float64 X
		variable float64 Y
		variable float64 Z
		variable float64 vX
		variable float64 vY
		variable float64 vZ
		X:Set[${Math.Calc[${Entity[${targetID}].X} - ${MyShip.ToEntity.X}]}]
		Y:Set[${Math.Calc[${Entity[${targetID}].Y} - ${MyShip.ToEntity.Y}]}]
		Z:Set[${Math.Calc[${Entity[${targetID}].Z} - ${MyShip.ToEntity.Z}]}]
		vX:Set[${Math.Calc[${Entity[${targetID}].vX} - ${MyShip.ToEntity.vX}]}]
		vY:Set[${Math.Calc[${Entity[${targetID}].vY} - ${MyShip.ToEntity.vY}]}]
		vZ:Set[${Math.Calc[${Entity[${targetID}].vZ} - ${MyShip.ToEntity.vZ}]}]

		variable float64 dotProduct
		dotProduct:Set[${Math.Calc[${vX} * ${X} + ${vY} * ${Y} + ${vZ} * ${Z}]}]

		; Distance calculated from coordinate is somewhat 500m larger than Entity.Distance,
		; actually the later one gives the same angular velocity number as shown in the overview tab,
		; But I will take the coordinate one as the difference to chance to hit should be small and won't need to deal with devide by zero error.
		variable float64 targetDistance
		targetDistance:Set[${Math.Distance[${X}, ${Y}, ${Z}, 0, 0, 0]}]

		variable float64 norm
		norm:Set[${Math.Calc[${targetDistance} * ${targetDistance}]}]

		; Orthogonal(radical) velocity ratio.
		variable float64 ratio
		ratio:Set[${Math.Calc[${dotProduct} / ${norm}]}]

		; Tangent velocity.
		variable float64 projectionvX
		variable float64 projectionvY
		variable float64 projectionvZ
		projectionvX:Set[${Math.Calc[${vX} - ${ratio} * ${X}]}]
		projectionvY:Set[${Math.Calc[${vY} - ${ratio} * ${Y}]}]
		projectionvZ:Set[${Math.Calc[${vZ} - ${ratio} * ${Z}]}]

		; Tangent velocity scalar.
		variable float64 Vt
		Vt:Set[${Math.Sqrt[${projectionvX} * ${projectionvX} + ${projectionvY} * ${projectionvY} + ${projectionvZ} * ${projectionvZ}]}]

		variable float64 angularVelocity
		angularVelocity:Set[${Math.Calc[${Vt} / ${targetDistance}]}]
		This:LogDebug["Target angular velocity: \ao ${projectionvX} ${projectionvY} ${projectionvZ} ->  ${angularVelocity}"]

		; angularVelocity:Set[${Math.Calc[${Vt} / ${Entity[${targetID}].Distance}]}]
		; This:LogDebug[" target angular velocity ver 2: \ao ${projectionvX} ${projectionvY} ${projectionvZ} ->  ${angularVelocity}"]

		variable float64 trackingSpeed
		trackingSpeed:Set[${This.ModuleList_Weapon.TrackingSpeed}]

		variable float64 targetSignatureRadius
		targetSignatureRadius:Set[${Entity[${targetID}].Radius}]

		variable float64 trackingFactor
		trackingFactor:Set[${Math.Calc[(${angularVelocity} * 40000 / ${trackingSpeed} / ${targetSignatureRadius}) ^^ 2]}]

		This:LogDebug["trackingFactor: \ao ${trackingSpeed} ${targetSignatureRadius} ->  ${trackingFactor}"]

		variable float64 turretOptimalRange
		turretOptimalRange:Set[${This.ModuleList_Weapon.OptimalRange}]

		variable float64 turretFalloff
		turretFalloff:Set[${This.ModuleList_Weapon.AccuracyFalloff}]

		variable float64 decay
		decay:Set[${targetDistance} - ${turretOptimalRange}]
		if ${decay} < 0
		{
			decay:Set[0]
		}

		variable float64 rangeFactor
		rangeFactor:Set[${Math.Calc[(${decay} / ${turretFalloff}) ^^ 2]}]
		This:LogDebug["rangeFactor: \ao ${turretOptimalRange} ${turretFalloff} ${decay} ->  ${rangeFactor}"]

		variable float64 chanceToHit
		chanceToHit:Set[${Math.Calc[0.5 ^^ (${trackingFactor} + ${rangeFactor})]}]

		This:LogDebug["chanceToHit: \ao ${rangeFactor} ${trackingFactor} ->  ${chanceToHit}"]

		return ${chanceToHit}
	}
}
