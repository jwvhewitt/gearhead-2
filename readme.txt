************************
***   GEARHEAD  II   ***
************************

Welcome to the modern age. In NT157, a group of terrorists caused massive
destruction on Earth by awakening the biomonster Typhon. Five years later
tensions are running high and it looks like war is inevitable.

GH2 is released under the terms of the LGPL; see license.txt for more details.

To run the SDL version you need to have SDL, SDL_Image, SDL_ttf, and
OpenGL installed. The precompiled Windows releases come with all needed
dlls.

As of v0.620 the SDL package comes with three executables:

  gearhead     - The 3D graphical version.
  gearhead_2d  - A 2D isometric version, useful if your computer doesn't
                 support OpenGL or if you just prefer the look.
  cosplay2     - A color testing program. You can view the game images and
                 change their colors.

For help with the game you can visit either the GearHead wiki or the forum:
  Wiki:   http://gearhead.chaosforge.org/wiki/
  Forum:  http://gearhead.chaosforge.org/forum/

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

First of all you need FreePascal, available from www.freepascal.org.
To compile with graphics on Windows you also need the Jedi-SDL package,
available from here: http://sourceforge.net/projects/jedi-sdl/

On Linux, the SDL units come with the fpc compiler. Lucky you. Make sure that
you have libsdl, libsdl_image, and libsdl_ttf installed if you plan to use the
graphics version.

The default graphics mode is OpenGL. The game may be compiled to run in a
terminal window by setting the -dASCII command line switch. The game may also
be compiled in a less resource-intensive 2D graphical interface by setting the
-dCUTE command line switch.


Just type "ppc386 gearhead" and the program should compile.
To get the ASCII version, type "ppc386 -dASCII gearhead".

If you get a blue screen and no graphics, try uncommenting Revert_Slower_Safer
in gearhead.cfg.

I hope you have fun with the program.

- Joseph Hewitt
pyrrho12@yahoo.ca
