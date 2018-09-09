.PHONY: all clean distclean

all: *.java
	javac -target 1.7 -source 1.7 -bootclasspath ../../../../../Bootclass/rt.jar *.java ./logger/*.java

docs : 
	javadoc -d docs/ *.java /logger*.java

clean :
	rm -rf docs/

distclean : clean
	rm -f *.class ./logger/*.class
