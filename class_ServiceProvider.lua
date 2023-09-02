do
	local ins = {Tags={"NotCreatable","NotBrowsable"},DisplayName="Service",Class="ServiceProvider"}
	local inherited_mt = true
	local prop_info = {
		["GetService"]=modify(clone(default_prop_info),{
			security = {
				Write={security_enum.None};
				Read={security_enum.None};
			};
			tags = {tag_enum.ReadOnly};
			threadsafe = {
				Write=false;
				Read=true;
			};
			type = "function";
		});
		["FindService"]=modify(clone(default_prop_info),{
			security = {
				Write={security_enum.None};
				Read={security_enum.None};
			};
			tags = {tag_enum.ReadOnly};
			threadsafe = {
				Write=false;
				Read=true;
			};
			type = "function";
		});
	}
	local methods = {}
	function methods:GetService(name)
		@@check_instance(self)
		@@check_argument(name,1,false,nil,"string")
		local real = self[proxy_underlying]
		assert(rawget(real,"GetService")==methods.GetService,"GetService is not a valid member of "..tostring(real))
		local servs = rawget(real,"service_instantiators")
		local services = rawget(real,"services")
		assert(servs[name]~=nil,"'"..name.."' is not a valid service name!")
		if services[name]==nil then
			services[name] = servs[name]({Name=name;Parent=self})
		end
		return services[name]
	end
	function methods:FindService(name)
		@@check_instance(self)
		@@check_argument(name,1,false,nil,"string")
		local real = self[proxy_underlying]
		assert(rawget(real,"FindService")==methods.FindService,"FindService is not a valid member of "..tostring(real))
		local servs = rawget(real,"service_instantiators")
		local services = rawget(real,"services")
		assert(servs[name]~=nil,"'"..name.."' is not a valid service name!")
		return services[name]
	end
	function ins:Instantiate(props,cloned)
		local n = {}
		if props then for i,v in @@iterate(props) do n[i]=v end end
		@@instance_inherit(n,"Instance",true,true)
		for i,v in @@iterate(methods) do n[i]=v end
		for i,v in @@iterate(prop_info) do n["prop_info"][i]=v end
		n.ClassName = "ServiceProvider"
		n.services = {}
		n.service_instantiators = {}
		if getmetatable(n) then setmetatable(n,getmetatable(n).__mt) end
		return proxy(n,"Instance")
	end
	function ins:Inheritable()
		local n = {}
		@@instance_inherit(n,"Instance",false,true)
		for i,v in @@iterate(methods) do n[i]=v end
		for i,v in @@iterate(prop_info) do n["prop_info"][i]=v end
		n.services={}
		return n
	end
	function ins:Inherited_instantiate(sub,servs)
		rawset(sub,"service_instantiators",servs or {})
	end
	setmetatable(ins,{__call=ins.Instantiate})
	classes[ins.Class] = ins
end
