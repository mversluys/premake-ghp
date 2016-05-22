---
-- ghp/ghp.lua
-- Premake GitHub package management extension
-- Copyright (c) 2015 Matthew Versluys
---

print 'GitHub Package module ... (ghp)'

json = require 'lunajson'
semver = require 'semver'

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

	verbosef('  CACHE LOCATION: %s', ghp.cache)
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
		verbosef('  ENVIRONMENT FILE %s', filename)
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

	verbosef('  API URL %s', ghp.api)
	return ghp.api
end

local function _http_get(url, context)

	local result, result_str, result_code = http.get(url, { userpwd = _get_user() })

	-- TODO: update premake to return the result code from http.get0
	result_code = -1

	-- TODO: handle lazy authentication so that users don't need to specify on the command line

	if not result then
		premake.error('%s retrieval of %s failed (%d)\n%s', context, url, result_code, result_str)
	end

	return result
end

local function _http_download(url, destination, context)
	local result_str, result_code = http.download(url, destination, { userpwd = _get_user() })

	-- TODO: handle lazy authentication so that users don't need to specify on the command line

	if result_code ~= 0 then
		premake.error('%s retrieval of %s failed (%d)\n%s', label, result_code, result_str)
	end
end

local function _download_release(organization, repository, release, context)

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
	local release_json = _http_get(api_url, context)
	local source = json.decode(release_json)['zipball_url']
	local destination = location .. '.zip'

	print('  DOWNLOAD: ' .. source)
	os.mkdir(path.getdirectory(destination))
	_http_download(source, destination, context)

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

local function _download_asset(organization, repository, release, asset, context)

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
	local release_info = json.decode(_http_get(api_url, context))

	local asset_url = nil
	for _, asset_info in release_info['assets'] do
		if asset_info['name'] == asset then
			asset_url = asset_info['url']
			break
		end
	end

	if not asset_url then
		premake.error('%s unable to find asset named %s', context, asset)
	end

	-- try to download it
	print('  DOWNLOAD: ' .. asset_url)

	local destination = path.join(_get_cache(), p)
	os.mkdir(path.getdirectory(destination))
	_http_download(asset_url, destination, context)

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
			verbosef('ghp.%s %s %s', func_name, package.name, i[3])

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
	local context = string.format('ghp.asset %s %s %s', package.name, package.release, name)
	return _download_asset(package.organization, package.repository, package.release, name, context)
end

-- functions used by consumers of packages

function ghp.includedirs(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, includedirs, 'includedirs')
	else
		premake.error('ghp.includedirs could not resolve package name %s', package_name)
	end
end

function ghp.links(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, links, 'links')
	else
		premake.error('ghp.links could not resolve package name %s', package_name)
	end
end

function ghp.use(package_name, label_filter)
	local package = ghp.packages[package_name]
	if package then
		_import(package, label_filter, includedirs, 'includedirs')
		_import(package, label_filter, links, 'links')
	else
		premake.error('ghp.use could not resolve package name %s', package_name)
	end
end

-- import a package given a name and release
function ghp.import(name, release)

	if ghp.current then
		premake.error('ghp.import can not be used inside of packages, currently in package %s', ghp.current.name)
	end

	-- has this package already been imported?
	if ghp.packages[name] then
		premake.error('ghp.import package %s has already been imported', name)
	end

	-- the name should contain the organization and repository
	local organization, repository = name:match('(%S+)/(%S+)')

	-- version is the numerical and dotted part of the release
	local version = release:match('(%d[%d\\\.]+%d)')
	local context = string.format('ghp.import %s %s', name, release)

	printf('%s (%s)', context, version)
	local directory = _download_release(organization, repository, release, context)

	-- create the package
	local package = {
		name = name,
		revision = revision,
		organization = organization,
		repository = repository,
		release = release,
		version = version,
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

-- require a package to have been imported
function ghp.require(name, version)
	if not ghp.current then
		premake.error('ghp.require can only be used inside of packages')
	end

	local package = ghp.packages[name]

	if not package then
		premake.error('ghp.require package %s requires %s %s %s package not found', ghp.current.name, name, operator, version)
	end

	local operator, version = version:match('(.)(.+)')

	verbosef('  REQUIRE: %s %s%s', name, operator, version)

	local current_version = semver(package.version)
	local compare_version = semver(version)

	if operator == '=' then
		-- looking for an exact match
		if compare_version == current_version then
			return 
		else
			premake.error('ghp.require package %s requires %s =%s found version %s', ghp.current.name, name, version, package.version)
		end
	end

	if operator == '>' then
		-- looking for a comparison
		if compare_version < current_version then
			return
		else
			premake.error('ghp.require package %s requires %s >%s found version %s', ghp.current.name, name, version, package.version)
		end			
	end

	if operator == '^' then
		-- looking for persimistic upgrade 
		if compare_version ^ current_version then
			return
		else
			premake.error('ghp.require package %s requires %s ^%s found version %s', ghp.current.name, name, version, package.version)
		end			
	end

	premake.error('ghp.require package %s has unknown comparison operator %s when requiring %s %s', ghp.current.name, operator, name, version)
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
