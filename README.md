# Premake GitHub packages

An extension to premake for consuming packages from GitHub repositories.

This extension makes it easy to share and consume C/C++ projects!

Import this extension by placing it somewhere that premake can find it then use.

```lua
require 'ghp'
```

Import packages using the `ghp.import` function in your workspace which refers to a GitHub organization/repository and release.

```lua
ghp.import('mversluys/protobuf', '2.6.1')
```

Pull include directies and libraries into your projects with `ghp.use`.

```lua
ghp.use('mversluys/protobuf')
```

You can also require premake modules directly from github with `ghp.require`.

```lua
ghp.require('mversluys/premake-autoconf', '0.1')
```

For more information, including how to publish your own packages, see the [wiki](https://github.com/mversluys/premake-ghp/wiki).

For a working sample project, see [premake-ghp-sample](https://github.com/mversluys/premake-ghp-sample).

A public index of available packages can be found here http://www.premake-ghp.com.

## Acknowledgements

This extension utilizes the following Lua packages

 * [lunajson](https://github.com/grafi-tt/lunajson) -- JSON parser/encoder/decoder
 * [semver](https://github.com/kikito/semver.lua) -- Semantic Versioning
