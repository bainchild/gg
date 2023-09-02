do
	local ins = {Tags={"NotCreatable"},DisplayName="Game",Class="DataModel"}
	local inherited_mt = true
	function ins:Instantiate(props,cloned)
		-- props is always by the sandbox, and so can be trusted
		local n = {}
		@@instance_inherit(n,"ServiceProvider",true,true,{
			["Workspace"]=function(...)
				local ws = classes["Workspace"](...)
				rawset(n,"Workspace",ws)
				return ws
			end;
		})
		-- any mutable properties here..
		if props then for i,v in @@iterate(props) do n[i]=v end end
		n.ClassName="DataModel"
		n.BindToClose=function(inst,f)
			@@check_context({security_enum.None},"Class security check",inst,inherited_mt,false,"Function",ins.DisplayName..".BindToClose")
			@@check_argument(f,1,false,nil,"function")
			return
		end;
		n.GetJobsInfo=function(inst)
			@@check_context({security_enum.PluginSecurity},"Class security check",inst,inherited_mt,false,"Function",ins.DisplayName..".GetJobsInfo")
			return {}
		end;
		n.prop_info["GetJobsInfo"] = modify(clone(default_prop_info),{
			security = {
				Write={security_enum.None};
				Read={security_enum.PluginSecurity};
			};
			tags = {tag_enum.ReadOnly};
			threadsafe = {
				Write=false;
				Read=false;
			};
			type = "function";
		})
		n.prop_info["Workspace"] = modify(clone(default_prop_info),{
			security = {
				Write={security_enum.None};
				Read={security_enum.None};
			};
			tags = {tag_enum.ReadOnly};
			threadsafe = {
				Write=false;
				Read=true;
			};
			type = "Instance"
		})
		table.insert(n.locked_props,"Parent")
		if getmetatable(n) then setmetatable(n,getmetatable(n).__mt) end
		return proxy(n,"Instance")
	end
	function ins:Inheritable()return {}end
	function ins:Inherited_instantiate()end
	setmetatable(ins,{__call=ins.Instantiate})
	classes[ins.Class] = ins
end
