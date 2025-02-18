## In order for the powerups mod to work in multiplayer,
### the server must also be running the mods runtime.

Steps
1. [Install a BeamMP Server](https://github.com/BeamMP/BeamMP-Server/releases)
2. Download the powerups mod from the [repository](https://www.beamng.com/resources/powerups.33601)
3. Put the `powerups.zip` as is into the servers `Resources/Client` folder
4. Open the `powerups.zip` in your favorite archive tool (7Zip/WinRAR). You will need it in a bit
5. Navigate to the servers `Resources/Server` folder and create a new folder `powerups`
6. Navigate the previously opened zip to `/lua/ge/extensions`
7. Select all files and folder in this `extensions` folder
8. And copy the contents to the freshly created `powerups` folder

Now simply start/restart the server and your good to go.

After the server started atleast once, the server side script will have create a settings file in `Resources/Server/powerups/mp_settings` by the name of `multiplayer.server.toml`. You can open it in any text editor and configure it. Changes take effect after a server reboot or after a hotreload.

How to hotreload.
For that simply open the `ServerSide.lua` file, press space, then press return and then save. This changes the modification date of the file and tells the server to hotreload it.
