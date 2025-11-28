# BSE-DCS-Hook

This projects contains the Hook file for DCS to export all pertinent data via 
UDP.

With _pertinent data_ we mean:
 - player id
 - player position
 - world objects
 - mission data

More can be added on request.

## Installation:

### from github repo:

Oh well, (fork then) clone this repo:

```
git clone https://github.com/giupo/BSE-DCS-Hook.git
```

Make sure you have a working installation of lua5.1 _and_ python3 (used for the bundler). 
If you use MISE (and you really should, https://mise.jdx.dev), there's a `mise.toml`
To bundle the hook, type:

```
python3 lua_bundler.py --force
```

you'll find a bundle.lua file in the project root, just copy this file in the 
`Saved Files\DCS\Hooks` directory.


### configuration

Open the bundle.lua file with a decent text editor, (please, no Notepad...) and look for `config`. 
There you will find what's is configurable in the hook.

