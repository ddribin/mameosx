###########################################################################
#
#   osx_tiny.mak
#
#   Small driver-specific example makefile
#	Use make TARGET=tiny to build
#
#   Copyright (c) 1996-2006, Nicola Salmoria and the MAME Team.
#   Visit http://mamedev.org for licensing and usage restrictions.
#
###########################################################################


#-------------------------------------------------
# tiny.c contains the list of drivers
#-------------------------------------------------

COREOBJS += $(OBJ)/tiny.o



#-------------------------------------------------
# You need to define two strings:
#
#	TINY_NAME is a comma-separated list of driver
#	names that will be referenced.
#
#	TINY_DRIVER should be the same list but with
#	an & in front of each name.
#-------------------------------------------------

OSX_DRIVERS = suprmrio mspacman pacman puckman argus crysbios crysking

COREDEFS += -DTINY_NAME="driver_robby,driver_gridlee,driver_polyplay,driver_alienar"
COREDEFS += -DTINY_POINTER="&driver_robby,&driver_gridlee,&driver_polyplay,&driver_alienar"



#-------------------------------------------------
# Specify all the CPU cores necessary for these
# drivers.
#-------------------------------------------------

CPUS += Z80
CPUS += M6502
CPUS += N2A03
# FOr crysking:
CPUS += SE3208


#-------------------------------------------------
# Specify all the sound cores necessary for these
# drivers.
#-------------------------------------------------

SOUNDS += DAC
SOUNDS += NES
SOUNDS += NAMCO
SOUNDS += SN76496
SOUNDS += AY8910
# For argus:
SOUNDS += YM2203
# For crysking:
SOUNDS += VRENDER0


#-------------------------------------------------
# This is the list of files that are necessary
# for building all of the drivers referenced
# above.
#-------------------------------------------------

DRVLIBS = \
  $(OBJ)/vidhrdw/vsnes.o \
  $(OBJ)/vidhrdw/vrender0.o \
  $(OBJ)/vidhrdw/argus.o \
  $(OBJ)/vidhrdw/ppu2c0x.o \
  $(OBJ)/vidhrdw/pacman.o \
  $(OBJ)/machine/pacplus.o \
  $(OBJ)/machine/vsnes.o \
  $(OBJ)/machine/acitya.o \
  $(OBJ)/machine/theglobp.o \
  $(OBJ)/machine/ds1302.o \
  $(OBJ)/machine/mspacman.o \
  $(OBJ)/machine/jumpshot.o \
	$(OBJ)/drivers/pacman.o \
	$(OBJ)/drivers/jrpacman.o \
	$(OBJ)/drivers/pengo.o \
	$(OBJ)/drivers/vsnes.o \
	$(OBJ)/drivers/crystal.o \
	$(OBJ)/drivers/argus.o
