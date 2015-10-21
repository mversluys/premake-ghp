# Premake packages

An extension to premake for consuming packages from other repositories.

This extension makes it easy to share and consume C/C++ projects!

## Using this extension

Import this module by placing it somewhere in the premake search path and then use require to import it.

    require 'package'

## Using packages

To include a dependent project, import it your premake5.lua file using the package_import keyword.

    package_import {
        'madler/zlib' = 'v1.2.8'
    }

This imports the repository named zlib from the organization madler and uses the release named v1.2.8.

To add the include path of the package in your project

    package_includedirs { 'madler/zlib' }

To link the library created by the project

    package_links { 'madler/zlib' }

As a convenience you can get the includedirs and links from the package in one command.

    package_use { 'madler/zlib' }


## Creating packages

If it's a repository on GitHub, it could already be a package.

A package can contain a premake5-package.lua file that should return a snippet of lua that will be executed to create a project when needed.

There are some additional premake direcives available which are used to handle assets associated with the release and to declare what this package exports.

### package_export_includedirs

Exports an include directory. When a project uses package_includedirs on this package, it will add all of the includes directories specified.

Examples:

    package_export_includedirs '.'

Exports home folder of the package.

    package_export_includedirs 'include'

Exports a folder in the package named include.


### package_export_links

Exports something that will be linked.

When a project uses package_links on this package, it will add all of the libraries specified to the link.

Examples:

    package_export_links 'foo'

In premake, projects can be linked in addition to specific libraries. If there are projects declared in the premake5-package.lua file, they can be exported using the package_export_library directive.

Example:

    project 'foo'
        type 'StaticLib'
        package_export_links 'foo'

### package_asset

There can be assets associated with the release which aren't stored in the repository, but have been published as assets. Those assets can be retrieved using the package_asset directive.

Example:

Here's an asset that could be associated with the release of the Oracle Instant Client.

    package_asset 'instantclient-basiclite-windows.x64-12.1.0.2.0.zip'

If the asset is a zip file, it will be unzipped into the cache. This directive returns an object that can be referred to later.

### package_asset:include

Using the object that was returned by package_asset, export an include path from it.

### package_asset:library

Using the object that was returned by package_asset, export a library for linking. If there are no parameters, it's assumed that the entire asset is a library. If there is a parameter, then it refers to a file inside of the library.

Examples:

    package_asset('win32-i386.lib').library()


## Package best practices

Packages are putting a lot of things into a global namespace. To minimize collisions, it's recomended to reuse the organization and repository name which github makes unique.

At the very least organization names should be used and then organizations can manage their namespace.

Projects should be named <organization>-<repository>. If there are multiple projects in a repository, then <organization>-<repository> should be the prefix.

Examples:
(references to repositories that have good organization)

A README.md is present at the root which describes what this project is.
A premake5-package.lua file is present


## The package cache

Packages are downloaded from GitHub and are stored in a package cache. The default location of the cache differs by operating system.

For linux and macosx the default location is

    /var/tmp/premake_package_cache

For windows systems the default location is 

    %USERPROFILE%\AppData\Local\Temp\premake_package_cache

To override the location of the package cache, set the environment variable PREMAKE_PACKAGE_CACHE_PATH. The location needs to be writable by the user who is invoking premake to create project files.

Packages are stored inside of the cache by their name and version.

For example, the package named madler/zlib version v1.2.8 will be stored in

    /var/tmp/premake_package_cache/madler/zlib/v1.2.8/release

When premake is run and projects are created, there will be absolute path references made to locations in the cache. If you delete the contents of the cache and don't run premake, your projects will no longer compile.

When assets are downloaded they're stored inside an asserts folder.

    /var/tmp/premake_package_cache/madler/zlib/v1.2.8/assets


## Local packages

When developing packages, it's convenient to work locally and iterate quickly rather than publishing the package each time.

Premake will look in the local directory named 'packages'.

## Publishing packages

To publish a package, tag a repository on GitHub that has a premake5-package.lua file in it's root.

It's recomended that (GitHub release)[https://help.github.com/categories/releases/] to provide more information for the release.

## A package index

To make it easier to discover packages, see the GitHub pages for this project. Too add new packages, issue

At the moment GitHub doesn't allow it's API to be used to search all repositories across GitHub so a manual index needs to be maintained. For the time being, to add a new package to the index, please issue a pull request on the index.json file that can be found here.

Packackages don't have to be indexed for them to be used in premake, but adding them to the index will make it easier for other people to find your package.
