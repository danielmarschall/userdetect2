@echo off

del *.dcu
del *.cfg
del *.~*
del *.local
del *.identcache
rmdir /s /q __history
rmdir /s /q __recovery

del Plugins\*.dcu
del Plugins\*.cfg
del Plugins\*.~*
del Plugins\*.local
del Plugins\*.identcache
rmdir /s /q Plugins\__history
rmdir /s /q Plugins\__recovery

del vcl\*.dcu
del vcl\*.~*
del vcl\*.local
del vcl\*.identcache
rmdir /s /q vcl\__history
rmdir /s /q vcl\__recovery

del devcpp_plugins\*.o
del devcpp_plugins\*.a
del devcpp_plugins\Makefile.win
