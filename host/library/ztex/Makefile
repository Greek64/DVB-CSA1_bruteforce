#Makefile for ZTEX
.PHONY: all doc clean distclean

ZTEXPREFIX=..
LIBUSBPATH=../libusbJava/
JAVAC=javac

CLASSPATH:=.:$(ZTEXPREFIX)/:$(LIBUSBPATH):/usr/local/share/java:/usr/share/java:$(CLASSPATH)
JAVAFILES:=$(wildcard *.java)


all : $(JAVAFILES)
	$(JAVAC) -target 1.7 -source 1.7 -bootclasspath ../../Bootclass/rt.jar -cp "$(CLASSPATH)" $(JAVAFILES)

doc : 
	javadoc -d docs *.java

clean: 
	rm -rf *~ *.bak *.old docs/

distclean: clean
	rm -f $(JARTARGET)
	rm -f *.class
