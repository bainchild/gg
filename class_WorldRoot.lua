do
	local ins = {Tags={"NotCreatable"},DisplayName="WorldRoot",Class="WorldRoot"}
	local inherited_mt = true
	function ins:Instantiate(props,cloned)
		local n = {}
		@@instance_inherit(n,"PVInstance",true,true)
		-- any mutable properties here..
		if props then for i,v in @@iterate(props) do n[i]=v end end
		n.ClassName=ins.Class
		if getmetatable(n) then setmetatable(n,getmetatable(n).__mt) end
		return proxy(n,"Instance")
	end
	function ins:Inheritable()
		local n = {}
		@@instance_inherit(n,"PVInstance",false,true)
		return n
	end
	function ins:Inherited_instantiate()end
	setmetatable(ins,{__call=ins.Instantiate})
	classes[ins.Class] = ins
end
