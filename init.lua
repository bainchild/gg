-- goodness gracious
!(
local general_iter = _PARAMS and _PARAMS.GeneralIteration
function iterate(t)
	if general_iter then
		return t
	else
		return "pairs("..t..")"
	end
end
function cie(name,...)
	local cs = ""
	local args = {...}
	for i,a in pairs(args) do
		cs=cs..a..(i~=#args and "," or "")
	end
	name=evaluate(name)
	return "(function()if(("..name..")~=nil)then return("..name..")("..cs..") end end)()"
end
function split(a,b,p)
	local n = {}
	for m in a..(p or b):gmatch("(.-)"..b) do
		table.insert(n,m)
	end
	return n
end
function popen(cmd)
	local file = assert(io.popen(cmd))
	local content = file:read("*a")
	file:close()
	return content
end
function indent(s)
	return s:gsub("\n","\n"..getCurrentIndentationInOutput())
end
function check_instance(self)
	return "assert(type("..self..")==\"userdata\" and typeof("..self..")==\"Instance\",\"Attempt to call function with '.'. Did you mean to use ':'?\")\n"
end
function check_context(ctx,err,self,expected_mt,sync,type_,path)
	local s="local ctx=threadcontext:get()\n"
	if sync then
		s=s.."assert(ctx.synchronized,'"..evaluate(type_).." '..("..path..")..' isn\\'t safe to access in parallel!')\n"
	end
	s=s..check_instance(self)
	if expected_mt~="nil" then
		s=s.."assertft(getmetatable(("..self..")[proxy_underlying])=="..expected_mt..",function()local spl=split("..path..",'%.','.');return spl[#spl]..\" is not a valid member of \"..tostring("..self..")end)\n"
	end
	s=s.."security(ctx,"..ctx..","..err..")"
	return indent(s)
end
function check_argument(variable,idx,can_be_nil,default,type_)
	if evaluate(can_be_nil) then
		return indent("if "..variable.."==nil then\n"
						.."   "..variable.."=("..default..")\n"
						.."else\n"
						.."   "..variable.."=assert(typecast("..variable..","..type_.."))\n"
						.."end")
	else
		return indent("assert("..variable.."~=nil,'Argument "..idx.." missing or nil')\n"
						..variable.."=assert(typecast("..variable..","..type_.."))")
	end
end
function instance_inherit(var,inherit,call,inherit_mt,...)
	local args = {...}
	local arg_string = ""
	if #args>0 then arg_string=", " end
	for i,v in pairs(args) do
		arg_string=arg_string..v..(i~=#args and ", " or "")
	end
	if call then
		return indent("local _tio=classes["..inherit.."]:Inheritable()\n"
			  			.."for i,v in "..iterate("_tio").." do "..var.."[i]=v;end\n"
			  			..(inherit_mt and "setmetatable("..var..",{__mt=getmetatable(_tio).__mt or getmetatable(_tio)}); if inherited_mt==true then inherited_mt=getmetatable(_tio).__mt or getmetatable(_tio)end\n" or "")
			  			.."classes["..inherit.."]:Inherited_instantiate("..var)..arg_string..")"
	else
		return indent("local _tio=classes["..inherit.."]:Inheritable()\n"
			  			.."for i,v in "..iterate("_tio").." do "..var.."[i]=v;end"
			  			..(inherit_mt and "\nsetmetatable("..var..",{__mt=getmetatable(_tio).__mt or getmetatable(_tio)}); if inherited_mt==true then inherited_mt=getmetatable(_tio).__mt or getmetatable(_tio)end" or ""))
	end
end
)
local keep_alive = require('keep_alive')
local thread_tracking = require('thread_tracking')
local fp = require('formprint')
local rt4 = custom_require('robloxtypes4.lua','pm')
local clone = (table.clone~=nil and table.clone) or function(f)local n={};for i,v in @@iterate(f) do n[i]=v end;return n;end
local find = (table.find~=nil and table.find) or function(t,l)for i,v in @@iterate(t) do if v==l then return i;end;end;return nil;end
local filter = function(t,f)local n={};for i,v in @@iterate(t) do if f(v) then table.insert(n,v)end;end;return n;end
local modify = function(t,t2)for i,v in @@iterate(t2) do t[i]=v end; return t; end
local contains = function(t,f)local n={};for i,v in @@iterate(t) do if f(v) then return true end;end;return false;end
local hook = (hookfunction and function(a,b)local org;org=hookfunction(a,function(...)return b(org,...)end);return a;end) or function(a,b)return function(...)return b(a,...)end;end
-- if it's there, we'd want to use it!
local security_enum = {
	None=0;
	UserActionSecurity=1;
	ScriptSecurity=2;
	RobloxScriptSecurity=3;
	RobloxPlaceSecurity=4;
	LocalUserSecurity=5;
	PluginSecurity=6;
	WebSecurity=7;
	ReplicationSecurity=8;
}
local tag_enum = {
	ReadOnly=0;
	NotReplicated=1;
	Hidden=2;
	Deprecated=3;
	NotBrowsable=4;
	CustomLuaState=5;
	CanYield=6;
	NotScriptable=7;
	Yields=8;
	NoYield=9;
}
local threadcontext = thread_tracking.new("Thread context",{level={security_enum.None};synchronized=false})
function security(ctx,lvl,reason,pr)
	for i,v in @@iterate(lvl) do
		if find(ctx.level,v)==nil then
			error("The current identity ("..math.max(unpack(ctx.level))..") cannot "..reason.." (lacking permission "..v..")")
		end
	end
	return ctx
end
function typecast(a,t2)
	if t2=="string" then return tostring(a)end
	local t1 = typeof(a)
	if t1=="string" then
		if t2=="number" then
			local n = tonumber(t2)
			if n then return n end
		end
	end
	return false, "Unable to cast "..t1.." to "..t2
end
function passer(t)
	return function(...)
		for _,f in @@iterate(t) do
			local res = {f(...)}
			if res[1] then return unpack(res,2) end
		end
	end
end
function pass_table(t)
	local nt = {}
	for i,v in @@iterate(t) do
		if type(v)=="table" and is_array_of_type(v,"function") then
			nt[i]=passer(v)
		else
			nt[i]=v
		end
	end
	return nt
end
local metatables = {}
function locked_getmetatable(p) return metatables[p] end
function assertft(a,b)
	if not a then error(b()) end
	return a
end
function is_array_of_type(a,t)
	return is_dictionary_of_type(a,"number",t)
end
function is_dictionary_of_type(a,kt,vt)
	for i,v in @@iterate(a) do
		if type(i)~=kt or type(v)~=vt then return false end
	end
	return true
end
function split(a,b,p)
	local n = {}
	for m in a..(p or b):gmatch("(.-)"..b) do
		table.insert(n,m)
	end
	return n
end
local typeof_map = {
	["Instance"] = newproxy(false)
}
local proxy_underlying = newproxy(false)
function proxy(v,t)
	local p = newproxy(true)
	local mt = getmetatable(p)
	metatables[p]=mt
	mt.__metatable="Locked"
	mt.__type_id=typeof_map[t]
	mt.__index=function(_,i)
		if rawequal(i,proxy_underlying) then
			return v
		end
		--print("PROXY INDEX",v,i)
		if getmetatable(v).__index~=nil then
			return getmetatable(v).__index(v,i)
		end
		return rawget(v,i)
	end
	mt.__newindex=function(_,i,l)
		--print("PROXY NEWINDEX",v,i,l)
		if getmetatable(v).__newindex~=nil then
			return getmetatable(v).__newindex(v,i,l)
		end
		return rawset(v,i,l)
	end
	mt.__tostring=function()return tostring(v)end
	return p
end
function typeof(v)
	if type(v)=="userdata" then
		if locked_getmetatable(v) then
			local meta = locked_getmetatable(v)
			if type(meta)=="table" then
				if find(typeof_map,rawget(meta,"__type_id"))~=nil then
					return find(typeof_map,rawget(meta,"__type_id"))
				end
			end
		end
		return "userdata"
	end
	return type(v)
end
local default_prop_info = {
	security = {
		Write={security_enum.None};
		Read={security_enum.None};
	};
	tags = {tag_enum.ReadOnly};
	threadsafe = {
		Write=false;
		Read=false;
	};
	type = "nil";
}
local classes = {}
--
@@"extra/gg/class_Instance.lua"
--[[
@@"extra/gg/class_Constraint.lua"
@@"extra/gg/class_ValueBase.lua"
@@"extra/gg/class_SoundEffect.lua"
@@"extra/gg/class_Pages.lua"
@@"extra/gg/class_GuiObject.lua"
@@"extra/gg/class_JointInstance.lua"
@@"extra/gg/class_BaseImportData.lua"
@@"extra/gg/class_UIComponent.lua"
@@"extra/gg/class_HandleAdornment.lua"
@@"extra/gg/class_BodyMover.lua"
@@"extra/gg/class_BasePart.lua"
@@"extra/gg/class_GuiBase3d.lua"
@@"extra/gg/class_CharacterAppearance.lua"
@@"extra/gg/class_LayerCollector.lua"
@@"extra/gg/class_Part.lua"
@@"extra/gg/class_PostEffect.lua"
@@"extra/gg/class_ReflectionMetadataItem.lua"
@@"extra/gg/class_Model.lua"
@@"extra/gg/class_StatsItem.lua"
@@"extra/gg/class_UIGridStyleLayout.lua"
@@"extra/gg/class_ControllerBase.lua"
@@"extra/gg/class_PVAdornment.lua"
@@"extra/gg/class_TextChatConfigurations.lua"
@@"extra/gg/class_Controller.lua"
@@"extra/gg/class_BasePlayerGui.lua"
@@"extra/gg/class_UIConstraint.lua"
@@"extra/gg/class_GenericSettings.lua"
@@"extra/gg/class_CacheableContentProvider.lua"
@@"extra/gg/class_PartOperation.lua"
@@"extra/gg/class_Light.lua"
@@"extra/gg/class_BevelMesh.lua"
@@"extra/gg/class_DataModelMesh.lua"
@@"extra/gg/class_CustomSoundEffect.lua"
@@"extra/gg/class_LuaSourceContainer.lua"
@@"extra/gg/class_BaseScript.lua"
@@"extra/gg/class_BackpackItem.lua"]]
@@"extra/gg/class_WorldRoot.lua"--[[
@@"extra/gg/class_PartAdornment.lua"
@@"extra/gg/class_FormFactorPart.lua"
@@"extra/gg/class_NetworkReplicator.lua"
@@"extra/gg/class_Clothing.lua"
@@"extra/gg/class_TriangleMeshPart.lua"
@@"extra/gg/class_Mouse.lua"]]
@@"extra/gg/class_PVInstance.lua"--[[
@@"extra/gg/class_SlidingBallConstraint.lua"
@@"extra/gg/class_PoseBase.lua"]]
@@"extra/gg/class_ServiceProvider.lua"--[[
@@"extra/gg/class_LocalStorageService.lua"
@@"extra/gg/class_PausedState.lua"
@@"extra/gg/class_GuiLabel.lua"
@@"extra/gg/class_GuiButton.lua"
@@"extra/gg/class_SelectionLasso.lua"
@@"extra/gg/class_SurfaceGuiBase.lua"
@@"extra/gg/class_HandlesBase.lua"
@@"extra/gg/class_SensorBase.lua"
@@"extra/gg/class_DynamicRotate.lua"
@@"extra/gg/class_GuiBase2d.lua"
@@"extra/gg/class_Feature.lua"
@@"extra/gg/class_ManualSurfaceJointInstance.lua"
@@"extra/gg/class_FlyweightService.lua"
@@"extra/gg/class_GuiBase.lua"
@@"extra/gg/class_GlobalDataStore.lua"
@@"extra/gg/class_PluginGui.lua"
@@"extra/gg/class_NetworkPeer.lua"
@@"extra/gg/class_AnimationClip.lua"
@@"extra/gg/class_BaseWrap.lua"
@@"extra/gg/class_Accoutrement.lua"
@@"extra/gg/class_Tool.lua"
@@"extra/gg/class_InstanceAdornment.lua"
@@"extra/gg/class_ScreenGui.lua"
@@"extra/gg/class_ControllerSensor.lua"
@@"extra/gg/class_TweenBase.lua"
@@"extra/gg/class_Attachment.lua"
@@"extra/gg/class_Script.lua"
@@"extra/gg/class_PlaneConstraint.lua"
@@"extra/gg/class_ScriptBuilder.lua"
@@"extra/gg/class_InventoryPages.lua"
@@"extra/gg/class_Message.lua"
@@"extra/gg/class_Motor.lua"
@@"extra/gg/class_UILayout.lua"
@@"extra/gg/class_UIBase.lua"
@@"extra/gg/class_Decal.lua"
@@"extra/gg/class_FaceInstance.lua"
@@"extra/gg/class_FileMesh.lua"
@@"extra/gg/class_ILegacyStudioBridge.lua"
@@"extra/gg/class_LocalizationTable.lua"
@@"extra/gg/class_DebuggerConnection.lua"
@@"extra/gg/class_StarterPlayerScripts.lua"
@@"extra/gg/class_PluginPolicyService.lua"
@@"extra/gg/class_PluginMenu.lua"
@@"extra/gg/class_PluginToolbar.lua"
@@"extra/gg/class_CFrameValue.lua"
@@"extra/gg/class_PluginManagerInterface.lua"
@@"extra/gg/class_TimerService.lua"
@@"extra/gg/class_PluginManagementService.lua"
@@"extra/gg/class_PhysicsSettings.lua"
@@"extra/gg/class_Player.lua"
@@"extra/gg/class_PlayerEmulatorService.lua"
@@"extra/gg/class_PhysicsService.lua"
@@"extra/gg/class_PausedStateException.lua"
@@"extra/gg/class_PermissionsService.lua"
@@"extra/gg/class_PluginManager.lua"
@@"extra/gg/class_PlayerScripts.lua"
@@"extra/gg/class_Plugin.lua"
@@"extra/gg/class_PluginDragEvent.lua"
@@"extra/gg/class_PluginGuiService.lua"
@@"extra/gg/class_Players.lua"
@@"extra/gg/class_PluginToolbarButton.lua"
@@"extra/gg/class_PluginAction.lua"
@@"extra/gg/class_PluginDebugService.lua"
@@"extra/gg/class_PointsService.lua"
@@"extra/gg/class_BinaryStringValue.lua"
@@"extra/gg/class_BoolValue.lua"
@@"extra/gg/class_UnvalidatedAssetService.lua"
@@"extra/gg/class_ReflectionMetadataClasses.lua"
@@"extra/gg/class_ReflectionMetadataCallbacks.lua"
@@"extra/gg/class_RbxAnalyticsService.lua"
@@"extra/gg/class_ReflectionMetadata.lua"
@@"extra/gg/class_UserGameSettings.lua"
@@"extra/gg/class_UIStroke.lua"
@@"extra/gg/class_ReflectionMetadataEvents.lua"
@@"extra/gg/class_ReflectionMetadataEnum.lua"
@@"extra/gg/class_ReflectionMetadataEnums.lua"
@@"extra/gg/class_ReflectionMetadataClass.lua"
@@"extra/gg/class_ReflectionMetadataFunctions.lua"
@@"extra/gg/class_UIScale.lua"
@@"extra/gg/class_BrickColorValue.lua"
@@"extra/gg/class_PublishService.lua"
@@"extra/gg/class_ProximityPrompt.lua"
@@"extra/gg/class_VRService.lua"
@@"extra/gg/class_BloomEffect.lua"
@@"extra/gg/class_Pose.lua"
@@"extra/gg/class_PolicyService.lua"
@@"extra/gg/class_NumberPose.lua"
@@"extra/gg/class_ProximityPromptService.lua"
@@"extra/gg/class_BlurEffect.lua"
@@"extra/gg/class_DepthOfFieldEffect.lua"
@@"extra/gg/class_ProcessInstancePhysicsService.lua"
@@"extra/gg/class_ColorCorrectionEffect.lua"
@@"extra/gg/class_SunRaysEffect.lua"
@@"extra/gg/class_UserService.lua"
@@"extra/gg/class_UserInputService.lua"
@@"extra/gg/class_PausedStateBreakpoint.lua"
@@"extra/gg/class_PathfindingLink.lua"
@@"extra/gg/class_PathfindingService.lua"
@@"extra/gg/class_MeshPart.lua"
@@"extra/gg/class_VideoCaptureService.lua"
@@"extra/gg/class_IntersectOperation.lua"
@@"extra/gg/class_VirtualInputManager.lua"
@@"extra/gg/class_WedgePart.lua"
@@"extra/gg/class_Terrain.lua"
@@"extra/gg/class_SpawnLocation.lua"
@@"extra/gg/class_NegateOperation.lua"
@@"extra/gg/class_TrussPart.lua"
@@"extra/gg/class_Actor.lua"
@@"extra/gg/class_UnionOperation.lua"
@@"extra/gg/class_Vector3Curve.lua"
@@"extra/gg/class_VehicleSeat.lua"
@@"extra/gg/class_VersionControlService.lua"
@@"extra/gg/class_Vector3Value.lua"
@@"extra/gg/class_SkateboardPlatform.lua"
@@"extra/gg/class_Platform.lua"
@@"extra/gg/class_VoiceChatInternal.lua"
@@"extra/gg/class_NetworkSettings.lua"
@@"extra/gg/class_NoCollisionConstraint.lua"
@@"extra/gg/class_ServerReplicator.lua"
@@"extra/gg/class_NetworkServer.lua"
@@"extra/gg/class_ClientReplicator.lua"
@@"extra/gg/class_Seat.lua"
@@"extra/gg/class_NotificationService.lua"
@@"extra/gg/class_VisibilityService.lua"
@@"extra/gg/class_FlagStand.lua"
@@"extra/gg/class_Visit.lua"
@@"extra/gg/class_VirtualUser.lua"
@@"extra/gg/class_CornerWedgePart.lua"
@@"extra/gg/class_VisibilityCheckDispatcher.lua"
@@"extra/gg/class_Color3Value.lua"
@@"extra/gg/class_HopperBin.lua"
@@"extra/gg/class_Status.lua"
@@"extra/gg/class_PartOperationAsset.lua"
@@"extra/gg/class_ParticleEmitter.lua"
@@"extra/gg/class_PatchBundlerFileWatch.lua"
@@"extra/gg/class_StandardPages.lua"
@@"extra/gg/class_EmotesPages.lua"
@@"extra/gg/class_OutfitPages.lua"
@@"extra/gg/class_FriendPages.lua"
@@"extra/gg/class_PatchMapping.lua"
@@"extra/gg/class_Path.lua"
@@"extra/gg/class_DoubleConstrainedValue.lua"
@@"extra/gg/class_IntValue.lua"
@@"extra/gg/class_IntConstrainedValue.lua"
@@"extra/gg/class_UIPadding.lua"
@@"extra/gg/class_PathfindingModifier.lua"
@@"extra/gg/class_Flag.lua"
@@"extra/gg/class_DataStoreVersionPages.lua"
@@"extra/gg/class_DataStoreListingPages.lua"
@@"extra/gg/class_RayValue.lua"
@@"extra/gg/class_PackageLink.lua"
@@"extra/gg/class_WorldModel.lua"
@@"extra/gg/class_StringValue.lua"]]
@@"extra/gg/class_Workspace.lua"--[[
@@"extra/gg/class_DataStorePages.lua"
@@"extra/gg/class_PackageService.lua"
@@"extra/gg/class_ObjectValue.lua"
@@"extra/gg/class_DataStoreKeyPages.lua"
@@"extra/gg/class_PackageUIService.lua"
@@"extra/gg/class_CatalogPages.lua"
@@"extra/gg/class_AudioPages.lua"
@@"extra/gg/class_NumberValue.lua"
@@"extra/gg/class_ReflectionMetadataEnumItem.lua"
@@"extra/gg/class_UIListLayout.lua"
@@"extra/gg/class_UITableLayout.lua"
@@"extra/gg/class_Studio.lua"
@@"extra/gg/class_StudioAssetService.lua"
@@"extra/gg/class_StudioData.lua"
@@"extra/gg/class_TotalCountTimeIntervalItem.lua"
@@"extra/gg/class_RunningAverageItemInt.lua"
@@"extra/gg/class_RunningAverageTimeIntervalItem.lua"
@@"extra/gg/class_Translator.lua"
@@"extra/gg/class_StudioDeviceEmulatorService.lua"
@@"extra/gg/class_StudioScriptDebugEventListener.lua"
@@"extra/gg/class_StudioTheme.lua"
@@"extra/gg/class_StudioPublishService.lua"
@@"extra/gg/class_StudioService.lua"
@@"extra/gg/class_Trail.lua"
@@"extra/gg/class_StudioSdkService.lua"
@@"extra/gg/class_SurfaceAppearance.lua"
@@"extra/gg/class_RunningAverageItemDouble.lua"
@@"extra/gg/class_Tween.lua"
@@"extra/gg/class_SoundGroup.lua"
@@"extra/gg/class_SoundService.lua"
@@"extra/gg/class_Sparkles.lua"
@@"extra/gg/class_TremoloSoundEffect.lua"
@@"extra/gg/class_TweenService.lua"
@@"extra/gg/class_ReverbSoundEffect.lua"
@@"extra/gg/class_Stats.lua"
@@"extra/gg/class_SpawnerService.lua"
@@"extra/gg/class_StandalonePluginScripts.lua"
@@"extra/gg/class_StarterCharacterScripts.lua"
@@"extra/gg/class_StackFrame.lua"
@@"extra/gg/class_StarterPlayer.lua"
@@"extra/gg/class_StarterGear.lua"
@@"extra/gg/class_StarterPack.lua"
@@"extra/gg/class_UGCValidationService.lua"
@@"extra/gg/class_TaskScheduler.lua"
@@"extra/gg/class_TeamCreateData.lua"
@@"extra/gg/class_TextChatMessage.lua"
@@"extra/gg/class_TextChatMessageProperties.lua"
@@"extra/gg/class_TouchTransmitter.lua"
@@"extra/gg/class_TracerService.lua"
@@"extra/gg/class_ChatInputBarConfiguration.lua"
@@"extra/gg/class_ChatWindowConfiguration.lua"
@@"extra/gg/class_BubbleChatConfiguration.lua"
@@"extra/gg/class_TextChatService.lua"
@@"extra/gg/class_TextService.lua"
@@"extra/gg/class_TouchInputService.lua"
@@"extra/gg/class_TextFilterResult.lua"
@@"extra/gg/class_ThreadState.lua"
@@"extra/gg/class_TextSource.lua"
@@"extra/gg/class_ThirdPartyUserService.lua"
@@"extra/gg/class_Team.lua"
@@"extra/gg/class_TrackerLodController.lua"
@@"extra/gg/class_TextChannel.lua"
@@"extra/gg/class_TeleportAsyncResult.lua"
@@"extra/gg/class_TeleportOptions.lua"
@@"extra/gg/class_TrackerStreamAnimation.lua"
@@"extra/gg/class_Teams.lua"
@@"extra/gg/class_TeamCreatePublishService.lua"
@@"extra/gg/class_TeamCreateService.lua"
@@"extra/gg/class_TextChatCommand.lua"
@@"extra/gg/class_TeleportService.lua"
@@"extra/gg/class_TemporaryScriptService.lua"
@@"extra/gg/class_TextBoxService.lua"
@@"extra/gg/class_TemporaryCageMeshProvider.lua"
@@"extra/gg/class_TestService.lua"
@@"extra/gg/class_TerrainDetail.lua"
@@"extra/gg/class_TerrainRegion.lua"
@@"extra/gg/class_ReflectionMetadataMember.lua"
@@"extra/gg/class_PitchShiftSoundEffect.lua"
@@"extra/gg/class_EqualizerSoundEffect.lua"
@@"extra/gg/class_UIGradient.lua"
@@"extra/gg/class_ScreenshotHud.lua"
@@"extra/gg/class_SyncScriptBuilder.lua"
@@"extra/gg/class_SafetyService.lua"
@@"extra/gg/class_RunService.lua"
@@"extra/gg/class_RuntimeScriptService.lua"
@@"extra/gg/class_RtMessagingService.lua"
@@"extra/gg/class_ScriptChangeService.lua"
@@"extra/gg/class_ScriptCloneWatcherHelper.lua"
@@"extra/gg/class_ScriptDocument.lua"
@@"extra/gg/class_ScriptCloneWatcher.lua"
@@"extra/gg/class_ScriptDebugger.lua"
@@"extra/gg/class_UICorner.lua"
@@"extra/gg/class_ScriptContext.lua"
@@"extra/gg/class_ScriptEditorService.lua"
@@"extra/gg/class_RotationCurve.lua"
@@"extra/gg/class_RobloxPluginGuiService.lua"
@@"extra/gg/class_ToastNotificationService.lua"
@@"extra/gg/class_UIGridLayout.lua"
@@"extra/gg/class_RemoteCursorService.lua"
@@"extra/gg/class_UIPageLayout.lua"
@@"extra/gg/class_ReflectionMetadataProperties.lua"
@@"extra/gg/class_ReflectionMetadataYieldFunctions.lua"
@@"extra/gg/class_RobloxReplicatedStorage.lua"
@@"extra/gg/class_RemoteDebuggerServer.lua"
@@"extra/gg/class_RemoteFunction.lua"
@@"extra/gg/class_ReplicatedStorage.lua"
@@"extra/gg/class_RemoteEvent.lua"
@@"extra/gg/class_ReplicatedFirst.lua"
@@"extra/gg/class_RenderSettings.lua"
@@"extra/gg/class_RenderingTest.lua"
@@"extra/gg/class_FlangeSoundEffect.lua"
@@"extra/gg/class_ScriptRegistrationService.lua"
@@"extra/gg/class_ScriptService.lua"
@@"extra/gg/class_SmoothVoxelsUpgraderService.lua"
@@"extra/gg/class_SnippetService.lua"
@@"extra/gg/class_SocialService.lua"
@@"extra/gg/class_Smoke.lua"
@@"extra/gg/class_ShorelineUpgraderService.lua"
@@"extra/gg/class_Sky.lua"
@@"extra/gg/class_SharedTableRegistry.lua"
@@"extra/gg/class_Sound.lua"
@@"extra/gg/class_CompressorSoundEffect.lua"
@@"extra/gg/class_EchoSoundEffect.lua"
@@"extra/gg/class_ChorusSoundEffect.lua"
@@"extra/gg/class_DistortionSoundEffect.lua"
@@"extra/gg/class_AssetSoundEffect.lua"
@@"extra/gg/class_ChannelSelectorSoundEffect.lua"
@@"extra/gg/class_NetworkClient.lua"
@@"extra/gg/class_SessionService.lua"
@@"extra/gg/class_UserSettings.lua"
@@"extra/gg/class_BuoyancySensor.lua"
@@"extra/gg/class_ControllerPartSensor.lua"
@@"extra/gg/class_UITextSizeConstraint.lua"
@@"extra/gg/class_Selection.lua"
@@"extra/gg/class_SelectionHighlightManager.lua"
@@"extra/gg/class_ServiceVisibilityService.lua"
@@"extra/gg/class_ServerScriptService.lua"
@@"extra/gg/class_UISizeConstraint.lua"
@@"extra/gg/class_GlobalSettings.lua"
@@"extra/gg/class_ServerStorage.lua"
@@"extra/gg/class_AnalysticsSettings.lua"]]
@@"extra/gg/class_DataModel.lua"--[[
@@"extra/gg/class_UIAspectRatioConstraint.lua"
@@"extra/gg/class_ScriptRuntime.lua"
@@"extra/gg/class_MarkerCurve.lua"
@@"extra/gg/class_MultipleDocumentInterfaceInstance.lua"
@@"extra/gg/class_TorsionSpringConstraint.lua"
@@"extra/gg/class_UniversalConstraint.lua"
@@"extra/gg/class_VectorForce.lua"
@@"extra/gg/class_Torque.lua"
@@"extra/gg/class_PrismaticConstraint.lua"
@@"extra/gg/class_SpringConstraint.lua"
@@"extra/gg/class_CylindricalConstraint.lua"
@@"extra/gg/class_RopeConstraint.lua"
@@"extra/gg/class_ContentProvider.lua"
@@"extra/gg/class_HumanoidController.lua"
@@"extra/gg/class_ClimbController.lua"
@@"extra/gg/class_GroundController.lua"
@@"extra/gg/class_ContextActionService.lua"
@@"extra/gg/class_AirController.lua"
@@"extra/gg/class_SkateboardController.lua"
@@"extra/gg/class_VehicleController.lua"
@@"extra/gg/class_SwimController.lua"
@@"extra/gg/class_RodConstraint.lua"
@@"extra/gg/class_Plane.lua"
@@"extra/gg/class_CommandService.lua"
@@"extra/gg/class_Configuration.lua"
@@"extra/gg/class_ConfigureServerService.lua"
@@"extra/gg/class_CommandInstance.lua"
@@"extra/gg/class_ClusterPacketCache.lua"
@@"extra/gg/class_CollectionService.lua"
@@"extra/gg/class_RigidConstraint.lua"
@@"extra/gg/class_AlignOrientation.lua"
@@"extra/gg/class_AngularVelocity.lua"
@@"extra/gg/class_LineForce.lua"
@@"extra/gg/class_LinearVelocity.lua"
@@"extra/gg/class_AlignPosition.lua"
@@"extra/gg/class_HingeConstraint.lua"
@@"extra/gg/class_AnimationConstraint.lua"
@@"extra/gg/class_BallSocketConstraint.lua"
@@"extra/gg/class_Clouds.lua"
@@"extra/gg/class_ControllerManager.lua"
@@"extra/gg/class_CookiesService.lua"
@@"extra/gg/class_DebuggerBreakpoint.lua"
@@"extra/gg/class_LocalDebuggerConnection.lua"
@@"extra/gg/class_DebuggerConnectionManager.lua"
@@"extra/gg/class_DebuggablePluginWatcher.lua"
@@"extra/gg/class_Debris.lua"
@@"extra/gg/class_DebugSettings.lua"
@@"extra/gg/class_DataStoreSetOptions.lua"
@@"extra/gg/class_DataStoreService.lua"
@@"extra/gg/class_DebuggerLuaResponse.lua"
@@"extra/gg/class_DebuggerUIService.lua"
@@"extra/gg/class_Dialog.lua"
@@"extra/gg/class_DialogChoice.lua"
@@"extra/gg/class_DebuggerManager.lua"
@@"extra/gg/class_DeviceIdService.lua"
@@"extra/gg/class_DebuggerVariable.lua"
@@"extra/gg/class_DebuggerWatch.lua"
@@"extra/gg/class_ControllerService.lua"
@@"extra/gg/class_DataStoreOptions.lua"
@@"extra/gg/class_DataStoreKeyInfo.lua"
@@"extra/gg/class_CrossDMScriptChangeListener.lua"
@@"extra/gg/class_CustomEvent.lua"
@@"extra/gg/class_CustomEventReceiver.lua"
@@"extra/gg/class_CoreScriptSyncService.lua"
@@"extra/gg/class_CorePackages.lua"
@@"extra/gg/class_CoreScriptDebuggingManagerHelper.lua"
@@"extra/gg/class_DataStoreObjectVersionInfo.lua"
@@"extra/gg/class_BlockMesh.lua"
@@"extra/gg/class_SpecialMesh.lua"
@@"extra/gg/class_DataStoreInfo.lua"
@@"extra/gg/class_DataStoreKey.lua"
@@"extra/gg/class_CylinderMesh.lua"
@@"extra/gg/class_DataStoreIncrementOptions.lua"
@@"extra/gg/class_DataModelPatchService.lua"
@@"extra/gg/class_DataModelSession.lua"
@@"extra/gg/class_DraftsService.lua"
@@"extra/gg/class_ClickDetector.lua"
@@"extra/gg/class_Skin.lua"
@@"extra/gg/class_AssetManagerService.lua"
@@"extra/gg/class_AssetPatchSettings.lua"
@@"extra/gg/class_AssetService.lua"
@@"extra/gg/class_AssetImportSession.lua"
@@"extra/gg/class_AssetDeliveryProxy.lua"
@@"extra/gg/class_AssetImportService.lua"
@@"extra/gg/class_AssetCounterService.lua"
@@"extra/gg/class_AppUpdateService.lua"
@@"extra/gg/class_Atmosphere.lua"
@@"extra/gg/class_AudioSearchParams.lua"
@@"extra/gg/class_BadgeService.lua"
@@"extra/gg/class_AnimationImportData.lua"
@@"extra/gg/class_Bone.lua"
@@"extra/gg/class_Backpack.lua"
@@"extra/gg/class_AvatarEditorService.lua"
@@"extra/gg/class_AvatarImportService.lua"
@@"extra/gg/class_FacsImportData.lua"
@@"extra/gg/class_Animator.lua"
@@"extra/gg/class_AnimationStreamTrack.lua"
@@"extra/gg/class_AdService.lua"
@@"extra/gg/class_AdvancedDragger.lua"
@@"extra/gg/class_AnalyticsService.lua"
@@"extra/gg/class_AdPortal.lua"
@@"extra/gg/class_Accessory.lua"
@@"extra/gg/class_Hat.lua"
@@"extra/gg/class_AnimationTrack.lua"
@@"extra/gg/class_Animation.lua"
@@"extra/gg/class_KeyframeSequence.lua"
@@"extra/gg/class_AnimationFromVideoCreatorStudioService.lua"
@@"extra/gg/class_AnimationRigData.lua"
@@"extra/gg/class_CurveAnimation.lua"
@@"extra/gg/class_AnimationFromVideoCreatorService.lua"
@@"extra/gg/class_AnimationClipProvider.lua"
@@"extra/gg/class_AnimationController.lua"
@@"extra/gg/class_Chat.lua"
@@"extra/gg/class_GroupImportData.lua"
@@"extra/gg/class_MaterialImportData.lua"
@@"extra/gg/class_HSRDataContentProvider.lua"
@@"extra/gg/class_MeshContentProvider.lua"
@@"extra/gg/class_SolidModelContentProvider.lua"
@@"extra/gg/class_CSGOptions.lua"
@@"extra/gg/class_BrowserService.lua"
@@"extra/gg/class_BulkImportService.lua"
@@"extra/gg/class_Breakpoint.lua"
@@"extra/gg/class_CalloutService.lua"
@@"extra/gg/class_ChangeHistoryService.lua"
@@"extra/gg/class_Shirt.lua"
@@"extra/gg/class_ShirtGraphic.lua"
@@"extra/gg/class_Camera.lua"
@@"extra/gg/class_Pants.lua"
@@"extra/gg/class_BodyColors.lua"
@@"extra/gg/class_CharacterMesh.lua"
@@"extra/gg/class_JointImportData.lua"
@@"extra/gg/class_RocketPropulsion.lua"
@@"extra/gg/class_BodyThrust.lua"
@@"extra/gg/class_PlayerGui.lua"
@@"extra/gg/class_StarterGui.lua"
@@"extra/gg/class_WrapLayer.lua"
@@"extra/gg/class_CoreGui.lua"
@@"extra/gg/class_MeshImportData.lua"
@@"extra/gg/class_RootImportData.lua"
@@"extra/gg/class_BodyVelocity.lua"
@@"extra/gg/class_WrapTarget.lua"
@@"extra/gg/class_BindableEvent.lua"
@@"extra/gg/class_BodyGyro.lua"
@@"extra/gg/class_BodyPosition.lua"
@@"extra/gg/class_Beam.lua"
@@"extra/gg/class_BodyForce.lua"
@@"extra/gg/class_BindableFunction.lua"
@@"extra/gg/class_BodyAngularVelocity.lua"
@@"extra/gg/class_NetworkMarker.lua"
@@"extra/gg/class_Dragger.lua"
@@"extra/gg/class_EulerRotationCurve.lua"
@@"extra/gg/class_KeyboardService.lua"
@@"extra/gg/class_Keyframe.lua"
@@"extra/gg/class_KeyframeMarker.lua"
@@"extra/gg/class_JointsService.lua"
@@"extra/gg/class_VelocityMotor.lua"
@@"extra/gg/class_Weld.lua"
@@"extra/gg/class_Snap.lua"
@@"extra/gg/class_Rotate.lua"
@@"extra/gg/class_KeyframeSequenceProvider.lua"
@@"extra/gg/class_LanguageService.lua"
@@"extra/gg/class_Lighting.lua"
@@"extra/gg/class_LiveScriptingService.lua"
@@"extra/gg/class_LSPFileSyncService.lua"
@@"extra/gg/class_SurfaceLight.lua"
@@"extra/gg/class_PointLight.lua"
@@"extra/gg/class_SpotLight.lua"
@@"extra/gg/class_AppStorageService.lua"
@@"extra/gg/class_Motor6D.lua"
@@"extra/gg/class_ManualGlue.lua"
@@"extra/gg/class_HumanoidDescription.lua"
@@"extra/gg/class_IKControl.lua"
@@"extra/gg/class_LegacyStudioBridge.lua"
@@"extra/gg/class_Humanoid.lua"
@@"extra/gg/class_HttpRequest.lua"
@@"extra/gg/class_HttpService.lua"
@@"extra/gg/class_ManualWeld.lua"
@@"extra/gg/class_IXPService.lua"
@@"extra/gg/class_IncrementalPatchBuilder.lua"
@@"extra/gg/class_RotateV.lua"
@@"extra/gg/class_Glue.lua"
@@"extra/gg/class_ImageDataExperimental.lua"
@@"extra/gg/class_RotateP.lua"
@@"extra/gg/class_InputObject.lua"
@@"extra/gg/class_InsertService.lua"
@@"extra/gg/class_HttpRbxApiService.lua"
@@"extra/gg/class_UserStorageService.lua"
@@"extra/gg/class_CloudLocalizationTable.lua"
@@"extra/gg/class_MeshDataExperimental.lua"
@@"extra/gg/class_Hint.lua"
@@"extra/gg/class_MessageBusConnection.lua"
@@"extra/gg/class_MemoryStoreSortedMap.lua"
@@"extra/gg/class_MemoryStoreQueue.lua"
@@"extra/gg/class_MemoryStoreService.lua"
@@"extra/gg/class_MemStorageService.lua"
@@"extra/gg/class_MessageBusService.lua"
@@"extra/gg/class_MetaBreakpoint.lua"
@@"extra/gg/class_PluginMouse.lua"
@@"extra/gg/class_MouseService.lua"
@@"extra/gg/class_MessagingService.lua"
@@"extra/gg/class_PlayerMouse.lua"
@@"extra/gg/class_MetaBreakpointContext.lua"
@@"extra/gg/class_MetaBreakpointManager.lua"
@@"extra/gg/class_LocalizationService.lua"
@@"extra/gg/class_MemStorageConnection.lua"
@@"extra/gg/class_MaterialService.lua"
@@"extra/gg/class_LoginService.lua"
@@"extra/gg/class_LuaSettings.lua"
@@"extra/gg/class_CoreScript.lua"
@@"extra/gg/class_LogService.lua"
@@"extra/gg/class_LodDataEntity.lua"
@@"extra/gg/class_LodDataService.lua"
@@"extra/gg/class_MaterialVariant.lua"
@@"extra/gg/class_LocalScript.lua"
@@"extra/gg/class_LuaWebService.lua"
@@"extra/gg/class_MaterialGenerationService.lua"
@@"extra/gg/class_MaterialGenerationSession.lua"
@@"extra/gg/class_ModuleScript.lua"
@@"extra/gg/class_MarketplaceService.lua"
@@"extra/gg/class_LuauScriptAnalyzerService.lua"
@@"extra/gg/class_VoiceChatService.lua"
@@"extra/gg/class_DraggerService.lua"
@@"extra/gg/class_Hopper.lua"
@@"extra/gg/class_HiddenSurfaceRemovalAsset.lua"
@@"extra/gg/class_FunctionalTest.lua"
@@"extra/gg/class_GamePassService.lua"
@@"extra/gg/class_GameSettings.lua"
@@"extra/gg/class_FriendService.lua"
@@"extra/gg/class_Folder.lua"
@@"extra/gg/class_ForceField.lua"
@@"extra/gg/class_NonReplicatedCSGDictionaryService.lua"
@@"extra/gg/class_CSGDictionaryService.lua"
@@"extra/gg/class_GamepadService.lua"
@@"extra/gg/class_GetTextBoundsParams.lua"
@@"extra/gg/class_GroupService.lua"
@@"extra/gg/class_CanvasGroup.lua"
@@"extra/gg/class_Geometry.lua"
@@"extra/gg/class_GoogleAnalyticsConfiguration.lua"
@@"extra/gg/class_DataStore.lua"
@@"extra/gg/class_OrderedDataStore.lua"
@@"extra/gg/class_Frame.lua"
@@"extra/gg/class_FloatCurve.lua"
@@"extra/gg/class_Fire.lua"
@@"extra/gg/class_Explosion.lua"
@@"extra/gg/class_FaceAnimatorService.lua"
@@"extra/gg/class_FaceControls.lua"
@@"extra/gg/class_ExperienceInviteOptions.lua"
@@"extra/gg/class_EventIngestService.lua"
@@"extra/gg/class_ExperienceAuthService.lua"
@@"extra/gg/class_FlagStandService.lua"
@@"extra/gg/class_Texture.lua"
@@"extra/gg/class_FacialAnimationStreamingService.lua"
@@"extra/gg/class_MotorFeature.lua"
@@"extra/gg/class_File.lua"
@@"extra/gg/class_FacialAnimationRecordingService.lua"
@@"extra/gg/class_Hole.lua"
@@"extra/gg/class_FacialAnimationStreamingServiceStats.lua"
@@"extra/gg/class_FacialAnimationStreamingServiceV2.lua"
@@"extra/gg/class_Highlight.lua"
@@"extra/gg/class_ImageButton.lua"
@@"extra/gg/class_ImageLabel.lua"
@@"extra/gg/class_ParabolaAdornment.lua"
@@"extra/gg/class_SelectionSphere.lua"
@@"extra/gg/class_ArcHandles.lua"
@@"extra/gg/class_WireframeHandleAdornment.lua"
@@"extra/gg/class_LineHandleAdornment.lua"
@@"extra/gg/class_SphereHandleAdornment.lua"
@@"extra/gg/class_ImageHandleAdornment.lua"
@@"extra/gg/class_Handles.lua"
@@"extra/gg/class_SelectionPartLasso.lua"
@@"extra/gg/class_HapticService.lua"
@@"extra/gg/class_HeightmapImporterService.lua"
@@"extra/gg/class_SurfaceSelection.lua"
@@"extra/gg/class_GuidRegistryService.lua"
@@"extra/gg/class_SelectionPointLasso.lua"
@@"extra/gg/class_GuiService.lua"
@@"extra/gg/class_TextButton.lua"
@@"extra/gg/class_CylinderHandleAdornment.lua"
@@"extra/gg/class_BoxHandleAdornment.lua"
@@"extra/gg/class_VideoFrame.lua"
@@"extra/gg/class_ViewportFrame.lua"
@@"extra/gg/class_BillboardGui.lua"
@@"extra/gg/class_TextBox.lua"
@@"extra/gg/class_TextLabel.lua"
@@"extra/gg/class_ScrollingFrame.lua"
@@"extra/gg/class_ConeHandleAdornment.lua"
@@"extra/gg/class_DockWidgetPluginGui.lua"
@@"extra/gg/class_GuiMain.lua"
@@"extra/gg/class_FloorWire.lua"
@@"extra/gg/class_SelectionBox.lua"
@@"extra/gg/class_QWidgetPluginGui.lua"
@@"extra/gg/class_TextureGuiExperimental.lua"
@@"extra/gg/class_AdGui.lua"
@@"extra/gg/class_SurfaceGui.lua"
@@"extra/gg/class_WeldConstraint.lua"]]
--
local gg = {
	classes=classes;
	thread_context=threadcontext;
	typeof=typeof;
	proxy=proxy;
	proxy_underlying=proxy_underlying;
}
local function createInstanceList(pl)
	local ins = {@@cie("classes.DataModel",{Name="Game"})}
	if pl~=nil then
		for _,v in @@iterate(pl) do
			table.insert(ins,v)
		end
	end
	local new = {}
	for i,v in @@iterate(ins) do
		keep_alive(v)
		new[i]=v
	end
	setmetatable(new,{
		__mode="v"
	})
	return new
end
function gg.new(preload)
	return setmetatable({
		Instances=createInstanceList(preload)
	},{__index=gg})
end
function gg.newInstance(n,parent)
	local c = assertft(classes[n],function() return "Unknown class '"..tostring(n).."'" end)
	assert(find(c.Tags,"NotCreatable")==nil,"Unable to create instance of type '"..classes[n].DisplayName.."'")
	return c({Parent=parent})
end
function gg:GetInstancesMatchingFilter(f)
	return filter(self.Instances,f)
end
function gg:GetFirstInstanceMatchingFilter(f)
	for _,v in @@iterate(self.Instances) do
		if f(v) then return v end
	end
end
function gg:Destroy()
	for _,v in @@iterate(self.Instances) do
		if keep_alive.is(v) then
			keep_alive.kill(v)
		end
		if v.Destroy then v:Destroy() end
	end
	for i,_ in @@iterate(self.Instances) do self.Instances[i]=nil end
	for i,_ in @@iterate(self) do self[i]=nil end
	setmetatable(self,nil)
end
local utf8=utf8
do
	s,utf8 = pcall(require,"utf8")
	if not s then utf8=nil end
end
local char = (utf8 and utf8.char)
local tree_out = (char and char(0x251C)) or ":" -- [ is too far forward, > doesn't bridge, } isn't enough
local tree_segment = (char and char(0x2502)) or "|"
local tree_end = (char and char(0x2514)) or "L"
local tree_bend = (char and char(0x2510)) or ","
local tree_prop = (char and char(0x2576)) or "-"
--[[
[nil]
  L,
   |
   [ abc
   |
   L def
]]
local function rpad(a,b,c)
	return a..c:rep(b-#a)
end
local function lpad(a,b,c)
	return c:rep(b-#a)..a
end
local function format_value(a)
	if type(a)=="string" then
		return "'"..(a:gsub("'","\\'")).."'"
	elseif type(a)=="function" then
		return "f("..format_value(tostring(a):sub(11))..")"
	end
	return tostring(a)
end
local function print_instance(f,inst,pool,parent)
	local last = #pool==0 or not contains(pool,function(v)
		return v.Parent==parent
	end)
	local padname = " "..inst.Name
	f:print((last and tree_end or tree_out)..padname.." ("..inst.ClassName..")")
	do
		f:push()
		f:inc()
		f:inc(1,((not last) and tree_segment) or " ")
		local real = inst[proxy_underlying]
		if real==nil then
			f:print("(no underlying instance)")
		else
			local pi = rawget(real,"prop_info")
			if pi then
				f:inc(4)
				f:inc(1,tree_prop)
				for i,v in @@iterate(pi) do
					local left_half = ("%d:%d (%s)"):format(math.max(unpack(v.security.Read)),math.max(unpack(v.security.Write)),table.concat(v.tags,", "))
					f:print(rpad(rpad(left_half,16," ").."["..format_value(i).."]",32," ").." = "..format_value(rawget(real,i)))
				end
			else
				f:print("(no property info)")
			end
		end
		f:pop()
	end
	if #pool~=0 and contains(pool,function(v)return v.Parent==inst end) then
		f:push()
		if last then
			f:inc(math.floor(#padname/2))
		else
			f:inc()
			f:inc(1,tree_segment)
			f:inc(math.floor(#padname/2)-2)	
		end
		f:print(tree_segment)
		while true do
			local fi
			for i,v in @@iterate(pool) do
				if v.Parent==inst then fi=i; break; end
			end
			if fi==nil then break end
			print_instance(f,table.remove(pool,fi),pool,inst)
		end
		f:pop()
	end
	if not last then
		f:print(tree_segment)
	end
end
function gg:PrettyPrint()
	local remain,f = clone(self.Instances),fp.global()
	f:print('[nil]')
	f:push()
	f:inc(2)
	f:print(tree_end..tree_bend)
	f:inc()
	f:print(tree_segment)
	while true do
		if #remain==0 then break end
		local fi
		for i,v in @@iterate(remain) do
			if v.Parent==nil then fi=i; break; end
		end
		if fi==nil then break end
		print_instance(f,table.remove(remain,fi),remain)
	end
	f:pop()
end
return gg
