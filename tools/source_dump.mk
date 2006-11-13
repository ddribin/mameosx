
osx_default:
	@echo Dummy makefile

include mame/makefile

# Using a := forces all variables and functions to be evaluated
OSX_DRVLIBS := $(DRVLIBS)
OSX_CPUOBJS := $(CPUOBJS)
OSX_DBGOBJS := $(DBGOBJS)
OSX_SOUNDOBJS := $(SOUNDOBJS)
OSX_CPUDEFS := $(CPUDEFS)
OSX_SOUNDDEFS := $(SOUNDDEFS)

shared: $(DRVLIBS)
	@./echo1.rb $^

mameosx: gen_cpu_config

gen_cpu_config:
	@./gen_cpu_config.rb CPU_CONFIG_H ${CPUDEFS}

gen_sound_config:
	@./gen_cpu_config.rb SOUND_CONFIG_H ${SOUNDDEFS}

echo_driver_libs:
	@./echo1.rb ${DRVLIBS}

