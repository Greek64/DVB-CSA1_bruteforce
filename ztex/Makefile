.PHONY: all clean

FILES=1_15y_fx2_firmware.ihx 2_16_fx2_firmware.ihx

all: $(FILES)

%.ihx: %.c
	./bmpsdcc.sh $< "-I ./include"
	makebin $@ > $<.bin
	rm -f *.asm *.bin *.lk *.lst *.map *.mem *.rel *.rst \
	*.sym *.tmp.c

clean:
	rm -f *.ihx *.asm *.bin *.lk *.lst *.map *.mem *.rel *.rst \
	*.sym *.tmp.c
