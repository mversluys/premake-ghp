---
-- github-package/cache.lua
-- Premake github package management extension
-- Copyright (c) 2015 Matthew Versluys
---

package_cache = {}

package_cache.hostname = 'https://github.com'
package_cache.folders  = { 'packages' }

local function _location()
	local folder = os.getenv('PREMAKE_PACKAGE_CACHE_PATH')
	if folder then
		return folder
	else
		if os.get() == 'windows' then
			local temp = os.getenv('TEMP')
			if temp then
				return path.join(temp, 'premake_package_cache')
			end
			local user_profile = os.getenv('USERPROFILE')
			if user_profile then
				return path.join(user_profile, 'AppData', 'Local', 'Temp', 'premake_package_cache')
			else
				return 'c:\\temp'
			end
		end

		-- assume that we're on something that's using a standard file system heirachy
		return '/var/tmp/premake_package_cache'
	end
end

local function _makepath(folder, organization, repository, release)
	return path.normalize(path.join(folder, organization, repository, release))
end

function package_cache.download(organization, repository, release)

	-- see if the file exists locally
	for i, folder in pairs(package_cache.folders) do
		local location = _makepath(folder, organization, repository, release)
		if os.isdir(location) then
			verbosef('  LOCAL: %s', location)
			return location
		end
	end

	-- see if it's in the cache
	local location = _makepath(_location(), organization, repository, release)
	if os.isdir(location) then
		verbosef('  CACHED: %s', location)
		return location
	end

	-- try to download it
	local source = package_cache.hostname .. '/' .. organization .. '/' .. repository .. '/archive/' .. release  .. '.zip'
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

