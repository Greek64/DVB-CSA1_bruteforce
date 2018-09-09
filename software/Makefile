all: csa csa_crack tsgen

csa : csa.c
	gcc -c -std=c99 -o csa.o csa.c 
	gcc -static -s -o csa csa.o -static -L. -ldvbcsa/dvbcsa/libdvbcsa
	rm -f csa.o

csa_crack : csa_crack.c
	gcc -c -std=c99 -O3 -o csa_crack.o csa_crack.c 
	gcc -static -s -o csa_crack csa_crack.o -static -L. -ldvbcsa/dvbcsa/libdvbcsa
	rm -f csa_crack.o
	
tsgen : tsgen.c
	gcc -c -std=c99 -o tsgen.o tsgen.c 
	gcc -static -s -o tsgen tsgen.o -static -L. -ldvbcsa/dvbcsa/libdvbcsa
	rm -f tsgen.o

clean:
	rm -rf csa csa_crack tsgen
