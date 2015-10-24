# Premake github packages

An extension to premake for consuming packages from github repositories.

This extension makes it easy to share and consume C/C++ projects!

Import this extension by placing it somewhere that premake can find it then use.

    require 'github-package'

Import packages using the **ghp.import** function which refers to a GitHub organization/repository and release.

    ghp.import('google/protobuf', '3.0.0-beta-1')

Pull header files into your project using **ghp.includedirs**.

    ghp.includedirs('google/protobuf')

Link the libraries exported by the package using **ghp.links**.

    ghp.links('google/protobuf')

To pull in the headers and link the libraries, there's a convenience function named **ghp.use**.

    ghp.use('google/protobuf')

For more information, including how to publish your own packages, see the [wiki](https://github.com/mversluys/github-package/wiki).
