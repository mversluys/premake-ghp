---
-- github-package/github-package.lua
-- Premake github package management extension
-- Copyright (c) 2015 Matthew Versluys
---

print 'GitHub Package module...'

premake.modules.github_package = {}
ghp = premake.modules.github_package

ghp.packages = {}
ghp.current = nil

ghp.hostname = 'https://github.com'
ghp.local_packages  = { 'ghp' }

local function _cache_location()
	local folder = os.getenv('PREMAKE_GITHUB_PACKAGE_CACHE')
	if folder then
		return folder
	else
		if os.get() == 'windows' then
			local temp = os.getenv('TEMP')
			if temp then
				return path.join(temp, 'ghp_cache')
			else
				return 'c:\\temp'
			end
		end

		-- assume that we're on something that's using a standard file system heirachy
		return '/var/tmp/ghp_cache'
	end
end

local function _local_packages()
	if type(ghp.local_packages) == 'string' then
		return { ghp.local_packages }
	else
		return ghp.local_packages
	end
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
	local location = path.join(_cache_location(), p)
	if os.isdir(location) then
		verbosef('  CACHED: %s', location)
		return location
	end

	-- try to download it
	local source = ghp.hostname .. '/' .. organization .. '/' .. repository .. '/archive/' .. release  .. '.zip'
	local destination = location .. '.zip'

	print('  DOWNLOAD: ' .. source)
	os.mkdir(path.getdirectory(destination))
	local return_str, return_code = http.download(source, destination, nil)
	if return_code ~= 0 then
		premake.error('Download of file %s returned: %s\nCURL_ERROR_CODE(%d)', source, return_str, return_code)
	end

	-- unzip it
	verbosef('   UNZIP: %s', destination)
	zip.extract(destination, location)

	-- github puts an extra folder in the archive, if we can find it, let's remove it
	-- TODO: figure out how to request the archive from github without the extra folder
	extra_folder = repository .. '-' .. release:gsub('^v', '')
	extra_path = path.join(location, extra_folder)

	if os.isdir(extra_path) then
		-- what we want to do is rename extra_path to location
		-- because it's inside of location we need to move it out of location
		verbosef('   CLEANING: %s', extra_folder)
		os.rename(extra_path, location .. '-temp')
		-- remove the old location
		os.remove(location)
		-- then replace it with the new one
		os.rename(location .. '-temp', location)
	end

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
	local location = path.join(_cache_location(), d)
	if os.isdir(location) then
		verbosef('  CACHED: %s', location)
		return location
	end

	-- try to download it
	local source = ghp.hostname .. '/' .. organization .. '/' .. repository .. '/releases/download/' .. release  .. '/' .. asset
	local destination = path.join(_cache_location(), p)

	print('  DOWNLOAD: ' .. source)

	os.mkdir(path.getdirectory(destination))
	local return_str, return_code = http.download(source, destination, nil)
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

local function _import(package_name, label, func, func_name)

	-- preserve the current premake filter
	local filter = premake.configset.getFilter(premake.api.scope.current)

	-- resolve the package
	local package = ghp.packages[package_name]
	if package then
		for _, i in ipairs(package[func_name]) do

			-- if a label was supplied, match it
			if not label or label == i[1] then
				verbosef(' IMPORT: %s %s %s', package_name, func_name, i[3])

				-- apply the filter that was captured at export
				premake.configset.setFilter(premake.api.scope.current, i[2])

				-- call the function with the parameter that was captured at export
				func { i[3] }
			end
		end
	else
		printf(' IMPORT: could not resolve package name %s', package_name)
	end

	-- restore the current premake filter
	premake.configset.setFilter(premake.api.scope.current, filter)
end

-- functions used inside of premake5-ghp.lua

function ghp.export_includedirs(paths, label)
	_export(ghp.current.includedirs, 'includedirs', paths, label, true)
end

-- libdirs shouldn't be neccesary, all exported library references "should" be absolute
--function package_export_libdirs(paths, label)
--	_export(ghp.current.libdirs, 'libdirs', paths, label, true)
--end

function ghp.export_library(paths, label)
	_export(ghp.current.links, 'links', paths, label, true)
end

function ghp.export_project(paths, label)
	_export(ghp.current.links, 'links', paths, label, false)
end

function ghp.asset(name)
	local package = ghp.current
	return _download_asset(package.organization, package.repository, package.release, name)
end

-- functions used by consumers of packages

function ghp.includedirs(package, label)
	_import(package, label, includedirs, 'includedirs')
end

-- libdirs shouldn't be neccesary, all exported library references "should" be absolute
--function package_libdirs(package, label)
--	_import(package, label, libdirs, 'libdirs')
--end

function ghp.links(package, label)
	_import(package, label, links, 'links')
end

function ghp.use(package, label)
	ghp.includedirs(package, label)
--	ghp.libdirs(package, label)
	ghp.links(package, label)
end

-- import a package given a name and release
function ghp.import(name, release)

	-- has this package already been imported?
	if ghp.packages[name] then
		return
	end

	-- the name should contain the organization and repository
	organization, repository = name:match('(%S+)/(%S+)')

	verbosef(' GITHUB PACKAGE: %s/%s %s', organization, repository, release)

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

	if ghp.current then

		-- save the package in the project ..
--		project.package = ghp.current.name:gsub('/', '-')

		-- set some default package values.
--		project.blocks[1].targetdir = bnet.lib_dir
--		project.blocks[1].objdir    = path.join(bnet.obj_dir, name)
--		project.blocks[1].location  = path.join(location(), 'packages', name)
	end

	return project
end)

return ghp