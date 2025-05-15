##########################################################################
# ARCHIE-VERSE MAKEFILE
# Sort of platform independent but not really. :S
##########################################################################

ifeq ($(OS),Windows_NT)
RM_RF:=-cmd /c rd /s /q
MKDIR_P:=-cmd /c mkdir
COPY:=copy
VASM?=bin\vasmarm_std_win32.exe
VLINK?=bin\vlink.exe
LZ4?=bin\lz4.exe
SHRINKLER?=bin\Shrinkler.exe
PYTHON2?=C:\Dev\Python27\python.exe
PYTHON3?=python.exe
DOS2UNIX?=bin\dos2unix.exe
else
RM_RF:=rm -Rf
MKDIR_P:=mkdir -p
COPY:=cp
VASM?=vasmarm_std
VLINK?=vlink
LZ4?=lz4
SHRINKLER?=shrinkler
PYTHON3?=python
DOS2UNIX?=dos2unix
endif

SPLITMOD=./bin/SplitMod.exe
AKP2ARC=./bin/akp2arc.py
PNG2ARC=./bin/png2arc.py
PNG2ARC_FONT=./bin/png2arc_font.py
PNG2ARC_SPRITE=./bin/png2arc_sprite.py
PNG2ARC_DEPS:=./bin/png2arc.py ./bin/arc.py ./bin/png2arc_font.py ./bin/png2arc_sprite.py
UV_TABLE=./bin/uv-table-conv.py
UV_SHADER=./bin/uv-shader-conv.py
FOLDER=!Verse
HOSTFS=../arculator/hostfs
# TODO: Need a copy command that copes with forward slash directory separator. (Maybe MSYS cp?)

##########################################################################
# MAKE RISCOS FOLDER AND DEPLOY
##########################################################################

.PHONY:deploy
deploy: $(FOLDER)
	$(RM_RF) "$(HOSTFS)\$(FOLDER)"
	$(MKDIR_P) "$(HOSTFS)\$(FOLDER)"
	$(COPY) "$(FOLDER)\*.*" "$(HOSTFS)\$(FOLDER)\*.*"

$(FOLDER): build ./build/archie-verse.bin ./build/!run.txt ./build/icon.bin
	$(RM_RF) $(FOLDER)
	$(MKDIR_P) $(FOLDER)
	$(COPY) .\build\!run.txt "$(FOLDER)\!Run,feb"
	$(COPY) .\build\icon.bin "$(FOLDER)\!Sprites,ff9"
	$(COPY) ".\data\riscos\RasterM36,ffa" "$(FOLDER)"
	$(COPY) ".\data\riscos\QTM149rm48,ffa" "$(FOLDER)"
	$(COPY) .\build\archie-verse.bin "$(FOLDER)\!RunImage,ffd"

build:
	$(MKDIR_P) "./build"

##########################################################################
# ASSET LIST
##########################################################################

./build/assets.txt: build ./build/music.mod ./build/razor-font.bin ./build/tunnel_uv.lz4 ./build/tunnel2_uv.lz4 \
	./build/phong128.bin ./build/itm128.bin ./build/temp-logo.bin \
	./build/fine-font.bin ./build/paul1_uv.lz4 ./build/paul2_uv.lz4 ./build/paul3_uv.lz4  ./build/paul4_uv.lz4 \
	./build/paul5_uv.lz4 ./build/Fire2.bin ./build/ShipIndex.bin ./build/bgtest4.bin \
	./build/paul6_uv.lz4 ./build/paul7_uv.lz4 ./build/FlameIndex.bin ./build/CloudIndex.bin \
	./build/DiskIndex.bin ./build/paul8_uv.lz4 ./build/paul9_uv.lz4 ./build/RocketIndex.bin \
	./build/paul10_uv.lz4 ./build/SpaceIndex.bin ./build/paul11_uv.lz4
	echo done > $@

##########################################################################
# CODE
##########################################################################

./build/archie-verse.bin: build ./build/archie-verse.o link_script3.txt
	$(VLINK) -T link_script3.txt -b rawbin1 -o $@ build/archie-verse.o -Mbuild/linker.txt

.PHONY:./build/archie-verse.o	# always build as we don't have submodule dependencies...
./build/archie-verse.o: build archie-verse.asm ./build/assets.txt
	$(VASM) -L build/compile.txt -m250 -Fvobj -opt-adr -o build/archie-verse.o archie-verse.asm

##########################################################################
# SEPARATE DEMO PARTS
##########################################################################

.PHONY:parts
parts: build ./build/!run.txt ./build/donut.bin ./build/space.bin
	$(COPY) .\build\donut.bin "$(FOLDER)\donut,ffd"
	$(COPY) .\build\space.bin "$(FOLDER)\space,ffd"
	$(COPY) "$(FOLDER)\*.*" "$(HOSTFS)\$(FOLDER)\*.*"

./build/donut.bin: build ./build/donut.o link_script3.txt
	$(VLINK) -T link_script3.txt -b rawbin1 -o $@ build/donut.o -Mbuild/linker.txt

./build/space.bin: build ./build/space.o link_script3.txt
	$(VLINK) -T link_script3.txt -b rawbin1 -o $@ build/space.o -Mbuild/linker.txt

./build/donut.o: build archie-verse.asm ./build/assets.txt
	$(VASM) -L build/compile.txt -m250 -Fvobj -opt-adr -D_DEMO_PART=0 -D_DEBUG=0 -D_SMALL_EXE=1 -o build/donut.o archie-verse.asm

./build/space.o: build archie-verse.asm ./build/assets.txt
	$(VASM) -L build/compile.txt -m250 -Fvobj -opt-adr -D_DEMO_PART=1 -D_DEBUG=0 -D_SMALL_EXE=1 -o build/space.o archie-verse.asm

##########################################################################
# COMPRESSED / FINAL BUILD
##########################################################################

.PHONY:compress
compress: shrink
	$(RM_RF) "$(HOSTFS)\$(FOLDER)"
	$(MKDIR_P) "$(HOSTFS)\$(FOLDER)"
	$(COPY) "$(FOLDER)\*.*" "$(HOSTFS)\$(FOLDER)\*.*"

.PHONY:shrink
shrink: build ./build/!run.txt ./build/loader.bin ./build/icon.bin
	$(RM_RF) $(FOLDER)
	$(MKDIR_P) $(FOLDER)
	$(COPY) .\build\icon.bin "$(FOLDER)\!Sprites,ff9"
	$(COPY) .\build\loader.bin "$(FOLDER)\!Run,ff8"

./build/archie-verse.shri: build ./build/archie-verse.bin
	$(SHRINKLER) -b -d -p -z -3 ./build/archie-verse.bin $@

./build/loader.bin: build ./src/loader.asm ./build/archie-verse.shri
	$(VASM) -L build\loader.txt -m250 -Fbin -opt-adr -D_USE_SHRINKLER=1 -o $@ ./src/loader.asm

##########################################################################
# SEQUENCE TARGET
##########################################################################

.PHONY:seq
seq: ./build/seq.bin
	$(COPY) .\build\seq.bin  "$(FOLDER)\Seq,ffd"
	$(COPY) "$(FOLDER)\Seq,ffd" "$(HOSTFS)\$(FOLDER)"

./build/seq.bin: build ./build/seq.o link_script2.txt
	$(VLINK) -T link_script2.txt -b rawbin1 -o $@ build/seq.o -Mbuild/linker2.txt

./build/seq.o: build archie-verse.asm ./src/sequence-data.asm  ./build/assets.txt
	$(VASM) -L build/compile.txt -m250 -Fvobj -opt-adr -o build/seq.o archie-verse.asm

##########################################################################
# CLEAN
##########################################################################

.PHONY:clean
clean:
	$(RM_RF) "build"
	$(RM_RF) "$(FOLDER)"

##########################################################################
# CRACKTRO ASSETS
##########################################################################

./build/razor-font.bin: ./data/font/Charset_1Bitplan.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC_FONT) -o $@ --glyph-dim 16 15 --max-glyphs 60 --store-as-byte-cols --map-to-ascii ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-./!\"$%&:;'()=*+?,^@ $< 9

##########################################################################
# SPACE ASSETS (TEXTURES)
##########################################################################

./build/phong128.bin: ./data/gfx/phong-x4.png ./data/raw/phong.pal.bin $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --use-palette ./data/raw/phong.pal.bin --double-pixels $< 9

./build/Fire2.bin: ./data/gfx/Fire2.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels $< 9

./build/itm128.bin: ./data/gfx/itm-rot-tex16.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels -p ./build/itmpal.bin $< 9

./build/ShipIndex.bin: ./data/gfx/ShipIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

./build/bgtest4.bin: ./data/gfx/BGTest4.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels -p ./build/bgtest4.pal.bin $< 9

./build/FlameIndex.bin: ./data/gfx/FlameIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

./build/DiskIndex.bin: ./data/gfx/DiskIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

./build/CloudIndex.bin: ./data/gfx/CloudIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

./build/RocketIndex.bin: ./data/gfx/RocketIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

./build/SpaceIndex.bin: ./data/gfx/SpaceIndex.png $(PNG2ARC_DEPS)		# index in red
	$(PYTHON2) $(PNG2ARC) --loud -o $@ --double-pixels --is-index $< 9

##########################################################################
# SPACE ASSETS (UV MAPS)
##########################################################################

./build/tunnel_uv.bin: $(UV_TABLE)
	$(PYTHON2) $(UV_TABLE) -o $@ --func tunnel_func --param1 0.25 --square-aspect --new

./build/tunnel2_uv.bin: $(UV_TABLE)
	$(PYTHON2) $(UV_TABLE) -o $@ --func fancy_func1 --new

./build/paul1_uv.bin: ./data/uvs/LUT01.png $(UV_SHADER)	# robot just blue mask?
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul2_uv.bin: ./data/uvs/LUT02.png $(UV_SHADER)	# ship w/ ext data
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul3_uv.bin: ./data/uvs/LUT03.png $(UV_SHADER)	# inside twisty torus
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul4_uv.bin: ./data/uvs/LUT04.png $(UV_SHADER)	# planet w/ ext data
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul5_uv.bin: ./data/uvs/LUT05.png $(UV_SHADER)	# tunnel w/ ext data
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul6_uv.bin: ./data/uvs/LUT06.png $(UV_SHADER)	# black hole w/ ext data
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul7_uv.bin: ./data/uvs/LUT07.png $(UV_SHADER)	# reactor core
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul8_uv.bin: ./data/uvs/LUT08.png $(UV_SHADER)	# reactor core
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul9_uv.bin: ./data/uvs/LUT09.png $(UV_SHADER)	# monolith
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul10_uv.bin: ./data/uvs/LUT10.png $(UV_SHADER)	# sun
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

./build/paul11_uv.bin: ./data/uvs/LUT11.png $(UV_SHADER)	# moon
	$(PYTHON2) $(UV_SHADER) -o $@ --tex-size 128 $<

##########################################################################
# DONUT ASSETS
##########################################################################

./build/temp-logo.bin: ./data/gfx/temp-logo-320x48x16.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ -p $@.pal $< 9

./build/fine-font.bin: ./data/font/Fine.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC_FONT) -o $@ --glyph-dim 8 8 --max-glyphs 96 $< 9

##########################################################################
# MUSIC ASSETS
##########################################################################

./src/gen/arcmusic.asm: ./data/akp/Rhino2.mod.txt
	$(PYTHON3) $(AKP2ARC) $< -o $@

./build/music.mod.trk: ./build/music.mod
	$(SPLITMOD) $(subst /,\\,$+)

./build/music.mod: ./data/music/django/maze-funky-delicious.mod
	$(COPY) $(subst /,\\,$+) $(subst /,\\,$@)

##########################################################################
# RISCOS ASSETS
##########################################################################

./build/icon.bin: ./data/gfx/aklang_icon16.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC_SPRITE) --name !aklang -o $@ $< 9

./build/!run.txt: ./data/text/!run.txt
	$(DOS2UNIX) -n $< $@

##########################################################################
# RULES
##########################################################################

# Rule to convert PNG files, assumes MODE 9.
%.bin : %.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ -p $@.pal $< 9

# Rule to LZ4 compress bin files.
%.lz4 : %.bin
	$(LZ4) --best -f $< $@

# Rule to Shrinkler compress bin files.
%.shri : %.bin
	$(SHRINKLER) -d -b -p -z $< $@

# Rule to copy MOD files.
%.bin : %.mod
	$(COPY) $(subst /,\\,$+) $(subst /,\\,$@)

##########################################################################
# UNUSED / LEGACY ASSETS
##########################################################################

./build/logo.lz4: ./build/logo.bin
./build/logo.bin: ./data/gfx/chipodjangofina-10colors-216x68.png ./data/logo-palette-hacked.bin $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ --use-palette data/logo-palette-hacked.bin -m $@.mask --mask-colour 0x00ff0000 --loud $< 9

./build/big-font.bin: ./data/font/font-big-finalFINAL.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC_FONT) -o $@ --glyph-dim 16 16 $< 9

./build/bs-logo.bin: ./data/gfx/BITSHIFERS-logo-anaglyph.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ -p $@.pal $< 9

./build/tmt-logo.bin: ./data/gfx/TORMENT-logo-anaglyph.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ -p $@.pal $< 9

./build/credits.bin: ./data/gfx/crew-credits2.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) -o $@ -p $@.pal $< 9

./build/block-sprites.bin: ./data/gfx/block_sprites_8x8x8.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC_FONT) --glyph-dim 8 8 -o $@ $< 9

./build/bbc_owl.bin: ./data/gfx/revision.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ $< 4

./build/greetz1.bin: ./data/gfx/greetz_1_alt.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ $< 4

./build/greetz2.bin: ./data/gfx/greetz_2_alt.png $(PNG2ARC_DEPS)
	$(PYTHON2) $(PNG2ARC) --loud -o $@ $< 4

##########################################################################
# CODE GEN (UNUSED)
##########################################################################

./build/dot_gen_code_a.bin: ./src/dot_plot_generated.asm
	$(VASM) -L build/dot_a.txt -m250 -Fbin -opt-adr -o $@ $<

./build/dot_gen_code_b.bin: ./src/dot_plot_generated_b.asm
	$(VASM) -L build/dot_b.txt -m250 -Fbin -opt-adr -o $@ $<
