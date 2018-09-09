.PHONY: all clean lib libclean

#NOTE: the JAVAPREFIX path has to be adjusted in the libusbJava directory Makefile

NAME=csa
ZTEXPATH=./library/ztex/
LIBUSBPATH=./library/libusbJava/
GNUGETOPPATH=./library/gnu/getopt/

all: *.java
	javac -target 1.7 -source 1.7 -bootclasspath Bootclass/rt.jar -cp '.:./library/:./library/libusbJava/' *.java
	jar cvfm $(NAME).jar MANIFEST.MF *.class -C library ztex -C library gnu -C library/libusbJava .
	rm -f *.class

clean:
	rm -f *.class $(NAME).jar

lib:
	$(MAKE) -C $(ZTEXPATH) all
	$(MAKE) -C $(LIBUSBPATH) native-all
	$(MAKE) -C $(GNUGETOPPATH) all
	
libclean:
	$(MAKE) -C $(ZTEXPATH) distclean
	$(MAKE) -C $(LIBUSBPATH) distclean
	$(MAKE) -C $(GNUGETOPPATH) distclean
