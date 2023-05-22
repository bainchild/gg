do
   local CFrame = rt4.CFrame
	local ins = {Tags={"NotCreatable"},DisplayName="PVInstance",Class="PVInstance"}
	local inherited_mt = true
   local prop_info = {
      ["Origin"] = {
         security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={tag_enum.NotReplicated,tag_enum.NotScriptable};
			threadsafe={Read=true,Write=false};
			type="CFrame";
      };
      ["Pivot Offset"] = {
         security={
				Read={security_enum.None};
				Write={security_enum.None};
			};
			tags={tag_enum.NotReplicated,tag_enum.NotScriptable};
			threadsafe={Read=true,Write=false};
			type="CFrame";
      };
   }
	local methods = {}
   function methods:GetPivot()
      @@check_context({security_enum.None},"Class security check",self,nil,false,"Function",self.ClassName..".GetPivot")
		local real = self[proxy_underlying]
		assert(rawget(real,"GetPivot")==methods.GetPivot,"GetPivot is not a valid member of "..tostring(real))
      return rawget(real,'_currentPivot')
   end
   function methods:PivotTo(cf)
      @@check_context({security_enum.None},"Class security check",self,nil,false,"Function",self.ClassName..".PivotTo")
		@@check_argument(cf,1,false,nil,"CFrame")
		local real = self[proxy_underlying]
		assert(rawget(real,"PivotTo")==methods.PivotTo,"PivotTo is not a valid member of "..tostring(real))
      rawset(real,'_currentPivot',cf:ToWorldSpace(rawget(real,'Origin')))
   end
   function ins:Instantiate(props,cloned)
		local n = {}
		@@instance_inherit(n,"Instance",true,true)
		-- any mutable properties here..
		if props then for i,v in @@iterate(props) do n[i]=v end end
		n.ClassName=ins.Class
		n.Origin=CFrame.identity
      n["Pivot Offset"]=CFrame.identity
      n._currentPivot=CFrame.identity
      for i,v in @@iterate(methods) do n[i]=v end
		for i,v in @@iterate(prop_info) do n["prop_info"][i]=v end
		if getmetatable(n) then setmetatable(n,getmetatable(n).__mt) end
		return proxy(n,"Instance")
	end
	function ins:Inheritable()
		local n = {}
		@@instance_inherit(n,"Instance",false,true)
		n.Origin=CFrame.identity
      n["Pivot Offset"]=CFrame.identity
      n._currentPivot=CFrame.identity
      for i,v in @@iterate(methods) do n[i]=v end
		for i,v in @@iterate(prop_info) do n["prop_info"][i]=v end
      return n
	end
	function ins:Inherited_instantiate()end
	setmetatable(ins,{__call=ins.Instantiate})
	classes[ins.Class] = ins
end