---
-- github-package/github-package.lua
-- Premake github package management extension
-- Copyright (c) 2015 Matthew Versluys
---

print 'GitHub Package module ...'

include 'cache.lua'

premake.modules.github_package = {}
local github_package = premake.modules.github_package

github_package.packages = {}
github_package.current = nil


local function _export(to, to_name, paths, label, isrelative)

	if type(paths) ~= 'table' then
		paths = { paths }
	end

	-- save the filter
	local filter = premake.configset.getFilter(premake.api.scope.current)

	-- save the links
	-- translate them into absolute paths?
	for _, p in ipairs(paths) do
		if isrelative then
			p = path.getabsolute(p)
		end
		verbosef('  EXPORT: %s %s', to_name, p)
		table.insert(github_package.current.includedirs, { label, filter, p })
	end

	-- restore the current filter
	premake.configset.setFilter(premake.api.scope.current, filter)

end

local function _import(package_name, label, func, func_name)

	-- save the filter
	local filter = premake.configset.getFilter(premake.api.scope.current)

	local package = github_package.packages[package_name]

	if package then

		for _, i in ipairs(package[func_name]) do

			if not label or i[1] == label then

				verbosef(' IMPORT: %s %s %s', package_name, func_name, i[3])

				-- apply the filter and set the include dirs
				premake.configset.setFilter(premake.api.scope.current, i[2])
				func { i[3] }
			end
		end
	end

	-- restore the current filter
	premake.configset.setFilter(premake.api.scope.current, filter)

end

-- functions used inside of premake5-package.lua

function package_export_includedirs(paths, label)
	_export(github_package.current.includedirs, 'includedirs', paths, label, true)
end

function package_export_libdirs(paths, label)
	_export(github_package.current.libdirs, 'libdirs', paths, label, true)
end

function package_export_links(paths, label)
	_export(github_package.current.links, 'links', paths, label, true)
end

function package_export_project(paths, label)
	_export(github_package.current.links, 'links', paths, label, false)
end

-- functions used by consumers of packages

function package_includedirs(package, label)
	_import(package, label, includedirs, 'includedirs')
end

function package_libdirs(package, label)
	_import(package, label, libdirs, 'libdirs')
end

function package_links(package, label)
	_import(package, label, links, 'links')
end

function package_use(packages, label)
	package_includedirs(package, label)
	package_libdirs(package, label)
	package_links(package, label)
end

-- import a package given a name and release
function package_import(name, release)

	-- has this package already been imported?
	if github_package.packages[name] then
		return
	end

	-- the name should contain the organization and repository
	organization, repository = name:match('(%S+)/(%S+)')

	verbosef(' PACKAGE: %s/%s %s', organization, repository, release)

	local directory = package_cache.download(organization, repository, release)

	-- create the package
	local package = {
		name = name,
		revision = revision,
		organization = organization,
		repository = repository,
		location = nil,
		includedirs = {},
		links = {},
		libdirs = {},
	}

	github_package.current = package

	-- look for the premake package file
	local path_premake = path.join(directory, 'premake5-package.lua')
	if os.isfile(path_premake) then
		package.func = dofile(path_premake)
	end

	github_package.current = nil

	-- save in the package registry
	github_package.packages[name] = package

end

---
-- override 'project' so that when a package defines a new project we initialize it with some default values.
---
premake.override(premake.project, 'new', function(base, name)
	local project = base(name)

	-- place the project in a group named packages
	project.group = 'packages'

	if github_package.current then

		-- give the project the name of the package by default
		project.package = github_project.current.name:gsub('/', '-')

		-- set some default package values.
--		prj.blocks[1].targetdir = bnet.lib_dir
--		prj.blocks[1].objdir    = path.join(bnet.obj_dir, name)
--		prj.blocks[1].location  = path.join(bnet.projects_dir, 'packages')
	end

	return project
end)


return github_package
