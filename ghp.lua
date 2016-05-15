---
-- ghp/ghp.lua
-- Premake GitHub package management extension
-- Copyright (c) 2015 Matthew Versluys
---

print 'GitHub Package module...'

json = require 'lunajson'

premake.modules.ghp = {}
ghp = premake.modules.ghp
ghp._VERSION = "0.2.0"

newoption {
	trigger = "ghp-api",
	value = "URL",	
	description = "The url of the GitHib api to use. Change to retrieve from GitHib enterprise"
}

newoption {
	trigger = "ghp-cache",
	value = "DIRECTORY",
	description = "Directory to use for the package cache"
}

newoption {
	trigger = "ghp-environment",
	value = "FILE",	
	description = "File to write environment variables into."
}

newoption {
	trigger = "ghp-user",
	value = "USERNAME[:PASSWORD]",
	description = "The user name and optional password used to retrieve packages from GitHub"
}


ghp.packages = {}
ghp.current = nil

ghp.api = nil
ghp.cache = nil
ghp.environment = nil
ghp.user = nil

ghp.local_packages  = { 'ghp_local' }

local function _local_packages()
	if type(ghp.local_packages) == 'string' then
		return { ghp.local_packages }
	else
		return ghp.local_packages
	end
end

local function _get_cache()

	if ghp.cache then
		return ghp.cache
	end

	-- check for command line
	if _OPTIONS['ghp-cache'] then
		ghp.cache = _OPTIONS['ghp-cache']
	else

		-- check envronment variable
		local env = os.getenv('GHP_CACHE')
		if env then
			ghp.cache = env
		else

			-- use default location
			if os.get() == 'windows' then
				local temp = os.getenv('TEMP')
				if temp then
					ghp.cache = path.join(temp, 'ghp_cache')
				else
					ghp.cache = 'c:\\temp'
				end
			else

				-- assume that we're on something that's using a standard file system heirachy
				ghp.cache = '/var/tmp/ghp_cache'
			end
		end
	end

	verbosef('  caching packages at %s', ghp.cache)
	return ghp.cache
end

local function _get_user()

	if ghp.user then
		return ghp.user
	end

	local user = nil

	-- check for command line
	if _OPTIONS['ghp-user'] then
		user = _OPTIONS['ghp-user']
	else 
		-- check for environment variable
		user = os.getenv('GHP_USER')
	end

	if user then
		if user:find(':') then
			ghp.user = user
		else
			ghp.user = user .. ':' .. os.getpass('Enter GitHub password for user "' .. user .. '": ')
		end
	end

	return ghp.user

end

local function _get_environment()

	if ghp.environment then
		return ghp.environment
	end

	local filename = nil

	-- check for command line
	if _OPTIONS['ghp-environment'] then
		filename = _OPTIONS['ghp-environment']
	else
		-- check for environment variable
		filename = os.getenv('GHP_ENVIRONMENT') 	
	end

	-- if we found a filename, open the file
	if filename then
		verbosef('  writing environment to %s', filename)
		ghp.environment = io.open(filename, 'w')
	end

	return ghp.environment
end

local function _get_api()

	if ghp.api then
		return ghp.api
	end

	-- check for command line
	if _OPTIONS['ghp-api'] then
		ghp.api = _OPTIONS['ghp-api']
	else
		-- check for environment variable
		local env = os.getenv('GHP_API')
		if env then
			ghp.api = env
			return ghp.api
		else
			-- use default url
			ghp.api = 'https://api.github.com'
		end
	end

	verbosef('  using api url %s', ghp.api)
	return ghp.api
end

local function _download_release(organization, repository, release)

	local p = path.normalize(path.join(organization, repository, release, 'release'))

	-- see if the file exists locally
	for _, folder in ipairs(_local_packages()) do
		local location = path.join(folder, p)
		if os.isdir(location) then
			verbosef('  LOCAL: %s', location)
			return location
		end
	end

	-- see if it's cached
	local location = path.join(_get_cache(), p)
	if os.isdir(location) then
		verbosef('  CACHED: %s', location)
		return location
	end

	-- try to download it 
	local api_url = _get_api() .. '/repos/' .. organization .. '/' .. repository .. '/releases/tags/' .. release
	local release_json, result_error = http.get(api_url, nil, _get_user())

	if not release_json then
		premake.error('Unable to retrieve release information from GitHub from %s\n%s', api_url, result_error)
	end

	local source = json.decode(release_json)['zipball_url']

	--local source = _get_api() .. '/repos/' .. organization .. '/' .. repository .. '/zipball/' .. release
	local destination = location .. '.zip'

	print('  DOWNLOAD: ' .. source)
	os.mkdir(path.getdirectory(destination))
	local return_str, return_code = http.download(source, destination, nil, _get_user())
	if return_code ~= 0 then
		premake.error('Download of file %s returned: %s\nCURL_ERROR_CODE(%d)', source, return_str, return_code)
	end

	-- unzip it
	verbosef('   UNZIP: %s', destination)
	zip.extract(destination, location)

	-- GitHub puts an extra folder in the archive, if we can find it, let's remove it
	-- TODO: figure out how to request the archive from GitHub without the extra folder
	local cruft = os.matchdirs(path.join(location, organization .. '-' .. repository .. '-*'))

	if #cruft == 1 then
		local cruft_path = cruft[1]

		-- what we want to do is rename cruft_path to location
		-- because it's inside of location we need to move it out of location
		verbosef('   CLEANING: %s', cruft_path)
		os.rename(cruft_path, location .. '-temp')
		-- remove the old location
		os.rmdir(location)
		-- then replace it with the new one
		os.rename(location .. '-temp', location)
	end

	-- remove the downloaded file
	os.remove(destination)

	return location
end

local function _download_asset(organization, repository, release, asset)

	local f = asset
	local p = path.normalize(path.join(organization, repository, release, 'assets', f))
	local d = p

	-- is this a zip file?
	if path.getextension(f) == '.zip' then
		f = path.getbasename(f)
		d = path.normalize(path.join(organization, repository, release, 'assets', f))
	end

	-- see if it the file exists locally
	for _, folder in ipairs(_local_packages()) do
		local location = path.join(folder, d)
		if os.isdir(location) then
			verbosef('  LOCAL: %s', location)
			return location
		end
	end

	-- see if it's cached
	local location = path.join(_get_cache(), d)
	if os.isdir(location) then
		verbosef('  CACHED: %s', location)
		return location
	end

	-- try to download it
	local api_url = _get_api() .. '/repos/' .. organization .. '/' .. repository .. '/releases/tags/' .. release
	local release_json, result_error = http.get(api_url, nil, _get_credentials())

	if not release_json then
		premake.error('Unable to retrieve release information from GitHub from %s\n%s', api_url, result_error)
	end

	local release_info = json.decode(release_json)

	local asset_url = nil
	for _, asset_info in release_info['assets'] do
		if asset_info['name'] == asset then
			asset_url = asset_info['url']
			break
		end
	end

	if not asset_url then
		premake.error('Unable to find asset named %s in release %s/%s/%s', asset, organization, repository, release)
	end

	local destination = path.join(_get_cache(), p)

	-- try to download it
	local source = asset_url
	local destination = path.join(_get_cache(), p)

	print('  DOWNLOAD: ' .. source)

	os.mkdir(path.getdirectory(destination))
	local return_str, return_code = http.download(source, destination, nil, _get_credentials())
	if return_code ~= 0 then
		premake.error('Download of file %s returned: %s\nCURL_ERROR_CODE(%d)', source, return_str, return_code)
	end

	-- if it's a zip, unzip it
	if path.getextension(asset) == '.zip' then
		verbosef('   UNZIP: %s', destination)
		zip.extract(destination, location)
		os.remove(destination)
	end

	return location
end

local function _export(to, to_name, paths, label, isrelative)

	if type(paths) ~= 'table' then
		paths = { paths }
	end

	-- capture the current premake filter
	local filter = premake.configset.getFilter(premake.api.scope.current)

	-- iterate the paths and save them
	for _, p in ipairs(paths) do
		if isrelative then
			p = path.getabsolute(p)
		end
		verbosef('  EXPORT: %s %s', to_name, p)
		table.insert(to, { label, filter, p })
	end

end

local function _label_test(label, label_filter)

	-- if no filter was provided, success!
	if not label_filter then
		return true
	end

	-- if the filter is a table, check to see if the label is in it
	if type(label_filter) == 'table' then
		for _, l in ipairs(label_filter) do
			if label == l then
				return true
			end
		end
	end

	-- otherwise it needs to be an exact match
	return label_filter == label

end

local function _import(package, label_filter, func, func_name)

	-- preserve the current premake filter
	local filter = premake.configset.getFilter(premake.api.scope.current)

	-- resolve the package
	for _, i in ipairs(package[func_name]) do
		if _label_test(i[1], label_filter) then 
			verbosef('GHP %s: %s %s', func_name, package.name, i[3])

			-- apply the filter that was captured at export
			premake.configset.setFilter(premake.api.scope.current, i[2])

			-- call the function with the parameter that was captured at export
			func { i[3] }
		end
	end

	-- restore the current premake filter
	premake.configset.setFilter(premake.api.scope.current, filter)
end

-- functions used inside of premake5-ghp.lua

function ghp.export_includedirs(paths, label)
	if not ghp.current then
		premake.error('ghp.export_includedirs can only be used inside of packages')
	end
	_export(ghp.current.includedirs, 'includedirs', paths, label, true)
end

-- libdirs shouldn't be neccesary, all exported library references "should" be absolute
--function package_export_libdirs(paths, label)
--	if not ghp.current then
--		premake.error('ghp.export_includedirs can only be used inside of packages')
--	end
--	_export(ghp.current.libdirs, 'libdirs', paths, label, true)
--end

function ghp.export_library(paths, label)
	if not ghp.current then
		premake.error('ghp.export_includedirs can only be used inside of packages')
	end
	_export(ghp.current.links, 'links', paths, label, true)
end

function ghp.export_project(paths, label)
	if not ghp.current then
		premake.error('ghp.export_includedirs can only be used inside of packages')
	end
	_export(ghp.current.links, 'links', paths, label, false)
end

function ghp.asset(name)
	if not ghp.current then
		premake.error('ghp.export_includedirs can only be used inside of packages')
	end

	local package = ghp.current
	return _download_asset(package.organization, package.repository, package.release, name)
end

-- functions used by consumers of packages

function ghp.includedirs(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, includedirs, 'includedirs')
	else
		printf(' ghp.includedirs could not resolve package name %s', package_name)
	end
end

function ghp.links(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, links, 'links')
	else
		printf(' ghp.links could not resolve package name %s', package_name)
	end
end

function ghp.use(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, includedirs, 'includedirs')
		_import(package, label_filter, links, 'links')
	else
		printf(' ghp.use could not resolve package name %s', package_name)
	end
end

-- import a package given a name and release
function ghp.import(name, release)

	-- has this package already been imported?
	if ghp.packages[name] then
		return
	end

	-- the name should contain the organization and repository
	organization, repository = name:match('(%S+)/(%S+)')

	printf('GITHUB PACKAGE: %s/%s %s', organization, repository, release)

	local directory = _download_release(organization, repository, release)

	-- create the package
	local package = {
		name = name,
		revision = revision,
		organization = organization,
		repository = repository,
		release = release,
		location = nil,
		includedirs = {},
		links = {},
		libdirs = {},
	}

	-- add to the environment file
	local env = _get_environment()
	if env then 
		env:write('GHP_' .. string.upper(organization) .. '_' .. string.upper(repository) .. '=' .. path.getabsolute(directory) .. '\n')
	end

	ghp.current = package

	-- look for the premake package file
	local path_premake = path.join(directory, 'premake5-ghp.lua')
	if os.isfile(path_premake) then
		package.func = dofile(path_premake)
	end

	ghp.current = nil

	-- save in the package registry
	ghp.packages[name] = package

end

---
-- override 'project' so that when a package defines a new project we initialize it with some default values.
---
premake.override(premake.project, 'new', function(base, name)
	local project = base(name)

	-- place the project in a group named ghp
	project.group = 'ghp'

	return project
end)

return ghp