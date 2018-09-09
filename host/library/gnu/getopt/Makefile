# Makefile for Java port of GNU getopt
.PHONY: all doc clean distclean

all: 
	javac -target 1.7 -source 1.7 -bootclasspath ../../../Bootclass/rt.jar LongOpt.java Getopt.java GetoptDemo.java

doc: 
	javadoc -author -version -public -d docs Getopt.java LongOpt.java
	
clean:
	rm -rf docs/

distclean : clean 
	rm -f *.class
