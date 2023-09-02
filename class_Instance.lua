do
	local ins = {
		Tags={"NotCreatable","NotBrowsable"};
		DisplayName="Instance";
		Class="Instance";
	}
	local prop_aliases = {
		["name"]="Name";
		["parent"]="Parent";
	}
	local prop_info = {
		Name=modify(clone(default_prop_info),{
			security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={};
			threadsafe={Read=true,Write=false};
			type="string";
		});
		Archivable=modify(clone(default_prop_info),{
			security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={};
			threadsafe={Read=true,Write=false};
			type="boolean";
		});
		Parent=modify(clone(default_prop_info),{
			security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={};
			threadsafe={Read=true,Write=false};
			type={"Instance","nil"};
		});
		RobloxLocked=modify(clone(default_prop_info),{
			security={
				Read={security_enum.PluginSecurity,security_enum.UserActionSecurity};
				Write={security_enum.PluginSecurity,security_enum.UserActionSecurity};
			};
			tags={};
			threadsafe={Read=true,Write=false};
			type="boolean";
		});
		ClassName=modify(clone(default_prop_info),{
			security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={tag_enum.ReadOnly};
			threadsafe={Read=true,Write=false};
			type="boolean";
		});
		Remove=modify(clone(default_prop_info),{
			tags={tag_enum.ReadOnly};
			threadsafe={Read=false,Write=false};
			type="function";
		});
		Destroy=modify(clone(default_prop_info),{
			tags={tag_enum.ReadOnly};
			threadsafe={Read=false,Write=false};
			type="function";
		});
	}
	local metatable = {
		__index=passer({
			function(self,i)
				if rawget(self,"prop_aliases")[i] then i=rawget(self,"prop_aliases")[i] end
				local pi = rawget(self,"prop_info")[i]
				if pi==nil then return false end
				local ctx = threadcontext:get()
				if not pi.threadsafe.Read then
					assert(ctx.synchronized,"Property "..tostring(i).." isn't safe to access in parallel.")
				end
				security(ctx,pi.security.Read,"Class security check",true)
				if pi.__index then return pi.__index(self,i) end
				return true, rawget(self,i)	
			end;
			function(self,i)			
				return assertft(filter(rawget(self,"_children"),function(n)
					return n.Name==i
				end)[1],function()
					return "'"..tostring(i).."' is not a valid member of "..tostring(self)
				end)
			end;
		});
		__newindex=function(self,i,v)
			if rawget(self,"prop_aliases")[i] then i=rawget(self,"prop_aliases")[i] end
			local pi = rawget(self,"prop_info")[i]
			if pi==nil then
				error("Attempt to index "..tostring(self).." with "..tostring(i))
			end
			assert(not pi.ReadOnly,"Property "..tostring(i).." is read only.")
			local ctx = threadcontext:get()
			security(ctx,pi.security.Write,"Class security check",true)
			if not pi.threadsafe.Write then
				assert(ctx.synchronized,"Property "..tostring(i).." isn't safe to write in parallel.")
			end
			local typed=false
			if type(pi.type)=="table" then
				typed=find(pi.type,typeof(v))~=nil
			else
				typed=typeof(v)==pi.type
			end
			assert(typed,"Attempt to index "..tostring(self).." with "..typeof(v))
			assert(find(self.locked_props,i)==nil,"Property '"..tostring(i).."' is locked!")
			if pi.__newindex then return pi.__newindex(self,i,v) end
			return rawset(self,i,v)
		end;
		__tostring=function(self)
			return self.Name
		end;
	}
	local methods = {}
	function methods:Destroy()
		@@check_context({security_enum.None},"Class security check",self,nil,false,"Function",self.ClassName..".Destroy")
		assert(rawget(self[underlying_proxy],"Destroy")==methods.Destroy,"Destroy is not a valid member of "..tostring(self[underlying_proxy]))
		local real = self[underlying_proxy]
		real.Parent=nil
		table.insert(rawget(real,"locked_props"),"Parent")
	end
	function methods:Remove()
		@@check_context({security_enum.None},"Class security check",self,nil,false,"Function",self.ClassName..".Remove")
		assert(rawget(self[underlying_proxy],"Remove")==methods.Remove,"Remove is not a valid member of "..tostring(self[underlying_proxy]))
		self[underlying_proxy].Parent=nil
	end
	function ins:Instantiate(props,cloned)
		local n = {}
		n.Name = "Instance"
		n.Parent = nil
		n.Archivable = true
		n.RobloxLocked = false
		if props then for i,v in @@iterate(props) do n[i]=v end end
		n.prop_info = prop_info
		n.prop_aliases = prop_aliases
		n.locked_props = {}
		n._children = {}
		n.ClassName = "Instance"
		for i,v in @@iterate(methods) do n[i]=v end
		setmetatable(n,metatable)
		return proxy(n,"Instance")
	end
	function ins:Inheritable()
		local n = {}
		n.Name = "Instance"
		n.Parent = nil
		n.Archivable = true
		n.RobloxLocked = false
		n.prop_info = clone(prop_info)
		n.prop_aliases = prop_aliases
		n.locked_props = {}
		n._children = {}
		n.ClassName = "Instance"
		for i,v in @@iterate(methods) do n[i]=v end
		setmetatable(n,metatable)
		return n
	end
	function ins:Inherited_instantiate(sub)end
	setmetatable(ins,{__call=ins.Instantiate})
	classes[ins.Class] = ins
end
