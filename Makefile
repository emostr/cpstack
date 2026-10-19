.PHONY: app run dmg install icon clean

app:        ## Build build/CPStack.app
	./Scripts/build-app.sh

run: app    ## Build and launch
	-pkill -x CPStack
	open build/CPStack.app

dmg: app    ## Build build/CPStack-<version>.dmg
	./Scripts/build-dmg.sh

install: app  ## Copy to /Applications
	-pkill -x CPStack
	rm -rf /Applications/CPStack.app
	cp -R build/CPStack.app /Applications/
	open /Applications/CPStack.app

icon:       ## Re-render Resources/AppIcon.icns
	swift Scripts/make-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build build
