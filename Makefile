RPR_ROOT		:= /Users/unclmike/Library/Application Support/REAPER
RPR_SCRIPTS 	:= "${RPR_ROOT}/Scripts"
RPR_TEMPLATES 	:= "${RPR_ROOT}/ProjectTemplates"

deploy:
	@cp *.lua ${RPR_SCRIPTS}

inputs:
	@echo "$(csv_file)" > ${RPR_SCRIPTS}/inputs.txt

