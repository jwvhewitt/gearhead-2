************************
***   GEARHEAD  II   ***
************************

Welcome to the modern age. In NT157, a group of terrorists caused massive
destruction on Earth by awakening the biomonster Typhon. Five years later
tensions are running high and it looks like war is inevitable.

GH2 is released under the terms of the LGPL; see license.txt for more details.

To run the SDL version you need to have SDL, SDL_Image, and SDL_ttf installed.
The precompiled Windows releases come with all needed dlls.

As of v0.630 the SDL package comes with two executables:

  gearhead2    - The 2D graphical version.
  cosplay2     - A color testing program. You can view the game images and
                 change their colors.

For help with the game you can visit the GearHead homepage:
  http://gearheadrpg.com

You can also contact the developer at pyrrho12@yahoo.ca.


*************************
***   CONFIGURATION   ***
*************************

When you run GearHead2 for the first time it creates a configuration
file, "gearhead.cfg". You can edit this file with any text editor. Some of the
useful settings are:

  WINDOW - The graphical version will run in a window on the desktop rather than
    taking over the whole screen. This option has no effect in ASCII mode.

  SCREENHEIGHT, SCREENWIDTH - Sets the width and height of the screen in ASCII
    mode. These options have no effect in graphical mode.

  ANIMSPEED - Sets the animation delay. Higher = Slower animations

  LAPTOP_ISO_KEYS - The movement keys will be rotated by 45 degrees, so you'll
    have access to the four cardinal directions when using the arrow keys in
    isometric mode.

  LOADPLOTSATSTART - If plot loading causes a noticeable delay every 5 minutes
    of game time, uncomment this option to do all plot loading at scene changes.

  MINIMAL_SCREEN_REFRESH, USE_SOFTWARE_SURFACE - If the graphical version is too
    slow, try using these options.

  REVERT_SLOWER_SAFER - If the graphical version crashes on Linux, try
    uncommenting this option.

  NAMESON - Names will appear above the heads of characters, mecha, and
    locations. So far this option only works in the 2D version.

  USEMESH - Activates full 3D mode in the 3D graphical version. When this
    option is enabled, all characters and mecha will be depicted using meshes.

  ERSATZ_MOUSE - Replaces your system mouse pointer with a game-rendered mouse
    pointer. Useful if the regular mouse pointer isn't showing up.


***************************
***   TROUBLESHOOTING   ***
***************************

Some graphics issues have been reported. If the display is corrupt, please
take the time to report the problem along with your operating system and
graphics card. In the meantime, the following tips might help:

- If the mouse pointer doesn't appear, try activating the ERSATZ_MOUSE
  configuration option.

- If the problem happens in fullscreen, try switching to windowed mode.

- If the problem happens in 3D, try using the 2D version (and vice versa).

- Try activating REVERT_SLOWER_SAFER.

The game seems to be more stable in a window than it is running fullscreen.



*********************
***   COMPILING   ***
*********************

First, you need a copy of the source code. If you are reading this you probably
already have it. Next, you need to install FreePascal and the SDL 1.2 libraries.
Open a terminal in the folder with the source code and type:

    fpc gearhead2

For the ASCII version, just type:

    fpc -dASCII gearhead2

Ignore the notes and warnings. If everything you need has already been
installed, that should be it.

Windows Notes:
- You need to download the 32 bit binaries for SDL 1.2, SDL_TTF for
SDL 1.2, and SDL_IMAGE for SDL 1.2. Put the .dll files in the same folder
as gharena.exe. You should download the 32 bit versions since it seems that
FPC compiles to a 32 bit target on Windows by default, and these will run on a
64 bit system just fine. There's probably some way to get a 64 bit executable;
if you figure it out, let me know.
- To open a terminal in a Windows folder, press shift and right click in the
folder window. The option to open a terminal should be there. Alternatively,
install Git for Windows and open a Git Bash shell by right clicking without
shift.

Linux Notes:
- On Debian and its derivatives, you need the packages libsdl1.2, libsdl1.2-dev,
libsdl-image1.2, libsdl-image1.2dev, libsdl-ttf2.0-0, and libsdl-ttf2.0-0dev.
- On Guix, you need the packages sdl, sdl-image, sdl-ttf and you need to set the '-Fl'
option of 'fpc'. The following one-liner can be used:
guix shell --pure bash fpc sdl sdl-image sdl-ttf -- sh -c 'fpc -Fl"$GUIX_ENVIRONMENT/lib" gearhead2.pas'.
Additionally, to run gearhead, you need to set LD_LIBRARY_PATH:
guix shell sdl sdl-ttf sdl-image -- sh -c 'LD_LIBRARY_PATH="$GUIX_ENVIRONMENT/lib" ./gearhead2'.
There is probably a way to set rpath to avoid that, but -Xr is insufficient.  If you find
a way, let me know.

If you get a blue screen and no graphics, try uncommenting Revert_Slower_Safer
in gearhead.cfg.

I hope you have fun with the program.

- Joseph Hewitt
pyrrho12@yahoo.ca
