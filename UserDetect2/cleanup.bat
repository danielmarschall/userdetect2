@echo off

del *.dcu
del *.cfg
del *.~*
del *.local
del *.identcache
rmdir /s /q __history

del Plugins\*.dcu
del Plugins\*.cfg
del Plugins\*.~*
del Plugins\*.local
del Plugins\*.identcache
rmdir /s /q Plugins\__history

del vcl\*.dcu
del vcl\*.~*
del vcl\*.local
del vcl\*.identcache
rmdir /s /q vcl\__history

del devcpp_plugins\*.o
del devcpp_plugins\*.a
del devcpp_plugins\Makefile.win
