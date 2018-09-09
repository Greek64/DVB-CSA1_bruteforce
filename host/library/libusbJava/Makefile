#NOTE: The "usb.h" file is required for the compilation of this library. 
#It is included in the "libusb-dev" package.

#JAVAPREFIX should point to the top directory of the include directory containing the "jni.h" File
JAVAPREFIX=/usr/lib/jvm/java-8-openjdk-amd64
#JAVAPREFIX=/usr/lib/jvm/java-7-openjdk-i386

GCC=gcc
STRIP=strip -S
CHMOD=chmod -x
JAVAC=javac
LIBSRCS=LibusbJava.o
LIBSRCS64=LibusbJava.c

LIBTARGET=libusbJava.so
LIBTARGET_SH=libusbJavaSh.so
LIBTARGET_ST=libusbJavaSt.so
LIBTARGET_64=libusbJava64.so
LIBLIBS=-lusb
LIBINCS=-I $(JAVAPREFIX)/include -I $(JAVAPREFIX)/include/linux

LIBUSBJAVAPATH=./ch/ntb/usb/

.PHONY:	all native-all libs clean distclean

all: libs
	$(MAKE) -C $(LIBUSBJAVAPATH) all
	rm -rf *.o

native-all: $(LIBTARGET)
	$(MAKE) -C $(LIBUSBJAVAPATH) all
	rm -rf *.o

libs: $(LIBTARGET_SH) $(LIBTARGET_ST) $(LIBTARGET_64)

%.o: %.c LibusbJava.h
	$(GCC) -fPIC -g -c -std=c99 -Wall -Wno-pointer-to-int-cast $(LIBINCS) $< -o$@

$(LIBTARGET_ST): $(LIBSRCS)
#	$(GCC) -shared -Wl,-static,-soname,$(LIBTARGET_ST) $(LIBINCS) -static $(LIBSRCS) -o $(LIBTARGET_ST) $(LIBLIBS)
#	$(GCC) -shared -Wl,-soname,$(LIBTARGET_ST),-static $(LIBINCS) $(LIBSRCS) -static -o $(LIBTARGET_ST) $(LIBLIBS)
	$(GCC) -shared -Wl,-soname,$(LIBTARGET_ST) $(LIBINCS) $(LIBSRCS) -o $(LIBTARGET_ST) $(LIBLIBS)
	$(STRIP) $(LIBTARGET_ST)
	$(CHMOD) $(LIBTARGET_ST)

$(LIBTARGET_SH): $(LIBSRCS)
	$(GCC) -fPIC -shared -Wl,-soname,$(LIBTARGET_SH) $(LIBINCS) $(LIBSRCS) -o $(LIBTARGET_SH) $(LIBLIBS)
	$(STRIP) $(LIBTARGET_SH)
	$(CHMOD) $(LIBTARGET_SH)

$(LIBTARGET): $(LIBSRCS)
	$(GCC) -fPIC -shared -Wl,-soname,$(LIBTARGET) $(LIBINCS) $(LIBSRCS) -o $(LIBTARGET) $(LIBLIBS)
	$(STRIP) $(LIBTARGET)
	$(CHMOD) $(LIBTARGET)

$(LIBTARGET_64): $(LIBSRCS64)
	$(GCC) -fPIC -m64 -shared -std=c99 -Wall -Wno-pointer-to-int-cast -Wl,-soname,$(LIBTARGET_64) $(LIBINCS) $(LIBSRCS64) $(LIBLIBS) -o $(LIBTARGET_64)
	$(STRIP) $(LIBTARGET_64)
	$(CHMOD) $(LIBTARGET_64)

doc:
	$(MAKE) -C $(LIBUSBJAVAPATH) doc
	
clean:
	$(MAKE) -C $(LIBUSBJAVAPATH) clean
	rm -rf *.o

distclean: clean
	$(MAKE) -C $(LIBUSBJAVAPATH) distclean
	rm -f $(LIBTARGET) $(LIBTARGET_SH) $(LIBTARGET_ST) $(LIBTARGET_64) libusbJava*.dll
