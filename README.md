# Premake GitHub packages

An extension to premake for consuming packages from GitHub repositories.

This extension makes it easy to share and consume C/C++ projects!

Import this extension by placing it somewhere that premake can find it then use.

```lua
require 'ghp'
```

Import packages using the **ghp.import** function in your workspace which refers to a GitHub organization/repository and release.

```lua
ghp.import('mversluys/protobuf', '2.6.1')
```

Pull include directies and libraries into your projects with **ghp.use**.

```lua
ghp.use('mversluys/protobuf')
```

For more information, including how to publish your own packages, see the [wiki](https://github.com/mversluys/premake-ghp/wiki).
