# vim: set noet ts=4 sw=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
# =============================================================================
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
#  publish.mk -- Libellus Potionis, publishing (included by ./Makefile)
# =============================================================================
#
#  A root-level INCLUDE (after make/release.mk, whose STAGED_* artifacts and
#  VERSION it reuses). These targets UPLOAD already-staged, already-signed
#  artifacts and build the source tarball; they NEVER build or sign. Each fails
#  fast if the artifact, credential or git tag is missing, so a push only runs
#  against something you produced explicitly. They pin the release signing key
#  (read from SECURITY.md) and require the v<VERSION> git tag to already exist --
#  they never create it. `push` pushes commits + tags; the store pushes upload the
#  staged AAB/IPA; push-gitlab publishes the release and verifies each asset's
#  sha256. Uploading is the last, deliberate step.
# =============================================================================

tgz: potillus-$(VERSION).tar.gz

# Release tarball. The set of files to leave out is derived DYNAMICALLY from
# .gitignore instead of being duplicated here, so the two can never drift.
#
# Mapping .gitignore patterns to tar --exclude patterns faithfully needs care:
#   * Comments (# ...), trailing whitespace and blank lines are stripped.
#   * A negation (!pattern) cannot be expressed with tar --exclude, so we abort
#     rather than silently over-exclude. (There are none today.)
#   * git treats a pattern that contains a '/' as anchored to the repo root and
#     one without any '/' as matching at ANY depth. tar's default is the
#     opposite (all patterns float), so we split the list: anchored patterns get
#     the archive's top directory (this repo dir) prepended and are matched with
#     --anchored; the rest are matched with --no-anchored.
#   * tar lets '*' cross '/' by default, which would make e.g. '/*.pdf' (root
#     PDFs only) also swallow nested PDFs; --no-wildcards-match-slash restores
#     git's single-'*'-stays-in-one-segment semantics.
#   * .git itself is not in .gitignore (git implies it), so it is excluded
#     explicitly.
# The two pattern files are written under a mktemp dir OUTSIDE the archived tree
# so they never end up inside the tarball.
potillus-$(VERSION).tar.gz: CHANGELOG.md
	@if grep -q '^[[:space:]]*!' .gitignore; then \
	    echo "tgz: .gitignore has a negation (!) that tar --exclude cannot express — aborting." >&2; \
	    exit 1; \
	fi
	@top=`basename "$$PWD"`; td=`mktemp -d`; \
	clean=`sed -e 's/#.*$$//' -e 's/[[:space:]]*$$//' -e '/^$$/d' .gitignore`; \
	printf '%s\n' "$$clean" | grep '/'    | sed -e 's#^/##' -e "s#^#$$top/#" > "$$td/anchored"   || true; \
	printf '%s\n' "$$clean" | grep -v '/'                                    > "$$td/unanchored" || true; \
	tar czf ../potillus-$(VERSION).tar.gz -C .. \
		--no-wildcards-match-slash \
		--anchored    --exclude="$$top/.git" --exclude-from="$$td/anchored" \
		--no-anchored --exclude-from="$$td/unanchored" \
		"$$top"; \
	rm -rf "$$td"

# ── push-playstore ── upload the ALREADY-BUILT release AAB to Google Play and
# OVERWRITE the store listing there (localized titles, short/full descriptions,
# feature graphics, screenshots) plus the release notes, from
# fastlane/metadata/android/. The fastlane OPTIONS (track alpha, status
# completed, metadata-overwriting) live in the fastlane `testing` lane, NOT here —
# override them there or via `fastlane testing track:...`.
#
# DELIBERATELY NOT A DEPENDENCY BUILD: this target has NO prerequisites, so it
# never triggers a rebuild of the AAB or SBOM. It FAILS FAST if a precondition
# is missing — the signed AAB, the bundled fastlane, or the Play service-account
# key — so the push only runs against artifacts you built explicitly
# (`make release-android`, or `make -C android bundle`) with credentials in place. Build
# the AAB yourself first; this target purely uploads it.
#
# The credential path mirrors the Appfile: SUPPLY_JSON_KEY if set, else
# fastlane/play-store-credentials.json.
#
# VALIDATE_ONLY=1 makes this a NON-PUBLISHING dry run: fastlane supply validates
# the upload against the Play API without changing anything on Google Play
# (supply's validate_only). Use it to exercise credentials and metadata safely.
# Expected release signing-key fingerprint (SHA-256 of the DER signing
# certificate, bare lowercase hex). SINGLE SOURCE: it is read from SECURITY.md's
# "Verifying releases" section rather than duplicated here, so the pin and the
# document that publishes it to users can never drift. release-check.sh §14
# guards that SECURITY.md carries exactly one such token in canonical (lowercase)
# form, so a reformat is caught at build time instead of at push time. The
# `tr` mirrors the normalization the push targets apply to the MEASURED
# fingerprint, so the comparison stays case-insensitive end to end even if an
# uppercase pin ever slips past the gate. The same key signs
# the Play upload bundle (its role as the Play upload key) and the GitLab/
# F-Droid release APK, so both publishing targets pin against this one value.
SIGNING_KEY_FINGERPRINT := $(shell grep -oiE '\b[0-9a-f]{64}\b' SECURITY.md | head -1 | tr 'A-F' 'a-f')

# The Play service-account key, ABSOLUTE. The path mirrors the Appfile's own
# default (SUPPLY_JSON_KEY if set, else fastlane/play-store-credentials.json), but
# $(abspath) resolves it against make's working directory -- the repository root --
# BEFORE any recipe runs. That matters because the preflight below hands the path
# to a `fastlane run` one-off inside a `( cd fastlane && ... )` subshell: a lane
# gets fastlane's chdir back to the project root, a `run` one-off does NOT, so a
# repo-root-relative path was resolved against fastlane/ and produced
# <root>/fastlane/fastlane/play-store-credentials.json. Absolute is immune to both.
# $(abspath) leaves an already-absolute SUPPLY_JSON_KEY untouched, and it is a
# make builtin -- no realpath, which macOS does not ship without coreutils.
# NOTE this is the MAKE-side path only. The lane at step 5 gets its key from the
# Appfile, whose relative default is correct there precisely because lanes DO run
# from the root.
PLAY_JSON_KEY := $(abspath $(if $(SUPPLY_JSON_KEY),$(SUPPLY_JSON_KEY),fastlane/play-store-credentials.json))

# ── push-playstore ── upload the STAGED release bundle to Google Play via the
# fastlane `testing` lane. Never builds or stages (that is `make release-android`); FAILS
# FAST if the staged AAB is missing. Uploads only the staged bundle so the exact
# verified bytes reach Play.
#
# Guards, in order: (1) staged AAB present; (2) release tag v$(VERSION) exists
# locally AND on the push remote -- a RELEASE-HYGIENE gate mirroring push-gitlab
# (Play itself has no notion of git tags), so a build only reaches Play when its
# exact version is a reproducible, pushed tag; (3) the AAB is signed with the
# EXPECTED key. For (3): jarsigner -verify prints "jar verified." for a signed
# archive but returns 0 even for an UNSIGNED one, so grepping the verdict line is
# what fails an unsigned bundle; -strict is avoided (the self-signed upload key
# would trip its chain check and fail a correct bundle); keytool then prints the
# signer SHA-256 (colon/upper), normalized to bare lowercase hex and required to
# equal the pin in SECURITY.md. Then (4) a real PRE-FLIGHT auth check against the
# Play API (validate_play_store_json_key) so a missing/again-misconfigured key or
# revoked access fails HERE, before any metadata is uploaded -- that action logs
# a success line but does NOT raise on failure, so its success line is required
# explicitly. The remote pick uses `|| true` inside the substitution because,
# under `.SHELLFLAGS := -eu -o pipefail`, `git rev-parse @{u}` with no upstream
# would abort the recipe on the assignment before the `${remote:-origin}` fallback
# runs. A fastlane LANE runs from the PROJECT ROOT (fastlane chdirs one level up
# out of fastlane/), so the staged path passed to the lane's aab: option is
# repo-root-relative -- exactly $(STAGED_AAB), no ../ prefix. A `fastlane run`
# one-off does NOT get that chdir: it resolves paths against the shell's cwd,
# which the `( cd fastlane && ... )` subshell has already moved into fastlane/.
# Hence PLAY_JSON_KEY below is made ABSOLUTE and the two forms cannot be confused.
push-playstore:
	# 1) staged AAB must exist (never builds/stages)
	@test -f "$(STAGED_AAB)" || { echo "push-playstore: staged AAB not found at '$(STAGED_AAB)' -- run 'make release-android' first (it builds and stages the bundle). This target does NOT build or stage it." >&2; exit 1; }
	# 2) release tag must exist locally and on the push remote
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-playstore: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && git push && git push --tags). This target does NOT create the tag." >&2; exit 1; }
	remote="$$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || true)"; remote="$${remote:-origin}"
	git ls-remote --exit-code --tags "$$remote" "refs/tags/v$(VERSION)" >/dev/null || { echo "push-playstore: tag 'v$(VERSION)' not found on remote '$$remote' -- push it first (git push && git push --tags)." >&2; exit 1; }
	# 3) staged AAB must be signed with the expected key (jarsigner verdict + keytool SHA-256 pin)
	js="$${JARSIGNER:-$$(command -v jarsigner || echo "$${JAVA_HOME:+$$JAVA_HOME/bin/}jarsigner")}"
	"$$js" -verify "$(STAGED_AAB)" | grep '^jar verified\.'
	kt="$${KEYTOOL:-$$(command -v keytool || echo "$${JAVA_HOME:+$$JAVA_HOME/bin/}keytool")}"
	got="$$("$$kt" -printcert -jarfile "$(STAGED_AAB)" | grep -oiE 'SHA-?256:[[:space:]]*[0-9A-F:]+' | sed -E 's/.*SHA-?256:[[:space:]]*//I; s/://g' | tr 'A-F' 'a-f' | sort -u)"
	echo "push-playstore: AAB signer certificate SHA-256: $$got"
	test "$$got" = "$(SIGNING_KEY_FINGERPRINT)"
	@( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "push-playstore: fastlane gems not installed -- run 'cd fastlane && bundle install'." >&2; exit 1; }
	@test -f "$(PLAY_JSON_KEY)" || { echo "push-playstore: Play service-account key not found at '$(PLAY_JSON_KEY)' -- place the JSON key there or set SUPPLY_JSON_KEY (see fastlane/Appfile)." >&2; exit 1; }
	# 4) pre-flight: prove the key can actually reach the Play API BEFORE uploading
	#    (the action never raises, so its success line is required explicitly)
	( cd fastlane && bundle exec fastlane run validate_play_store_json_key json_key:"$(PLAY_JSON_KEY)" ) | grep -q 'Successfully established connection to Google Play Store' || { echo "push-playstore: the Play service-account key at '$(PLAY_JSON_KEY)' could not connect to the Play API -- check that the service account is invited to the Play Console with 'Manage testing track releases' permission for this app (see fastlane/Appfile)." >&2; exit 1; }
	# 5) upload the staged bundle (repo-root-relative aab: for fastlane's chdir)
	( cd fastlane && bundle exec fastlane testing aab:"$(STAGED_AAB)" $(if $(VALIDATE_ONLY),validate_only:true) )

# ── push-appstore ── the iOS counterpart of push-playstore: upload the STAGED
# .ipa to App Store Connect via the fastlane `ios testing` lane, which also
# OVERWRITES the App Store listing (names, subtitles, keywords, descriptions,
# screenshots and release notes) from fastlane/metadata/ios/. Never builds and
# never stages -- that is `make release-ios`. Mac-only, like release-ios.
#
# SUBMIT=1 switches the target to the `ios production` lane, which performs the
# SAME upload and additionally submits the build for Apple review. The default is
# deliberately the non-submitting lane: upload, look at the result in App Store
# Connect, then submit in a second, explicit step. (This mirrors how
# push-playstore's `production` counterpart stages a draft rather than going live.)
#
# NOTE what `ios testing` is NOT: unlike Play's alpha track, it has no separate
# audience. The App Store has ONE listing, and this target overwrites it. "testing"
# here means "not submitted for review", not "not public". There is also no iOS
# equivalent of VALIDATE_ONLY: deliver has no validate-only mode, so the closest
# thing to a dry run is `make push-appstore-preflight`, which checks the
# credentials and touches nothing else.
#
# Guards, in order -- (1), (2) and (5) are the same guards push-playstore applies,
# and the two in between are where the platforms genuinely differ:
#
#   (1) the staged .ipa is present (this target never builds or stages it);
#   (2) the release tag v$(VERSION) exists locally AND on the push remote -- the
#       same release-hygiene gate push-playstore and push-gitlab apply, so a
#       build only reaches a store when its exact version is a pushed tag;
#   (3) the .ipa's OWN Info.plist agrees with this working tree: bundle
#       identifier, build number and marketing version must equal $(RELEASE_ID),
#       $(VERSION_CODE) and $(VERSION). This has no Android counterpart and is the
#       more valuable half of the pair: it catches the everyday mistake of pushing
#       a stale .ipa left in releases/ from an earlier versionCode. It is a real
#       cross-check rather than a tautology because the three values enter the .ipa
#       through a different path than they enter here -- tools/gen-ios-version.py
#       writes MARKETING_VERSION (from CHANGELOG.md) and CURRENT_PROJECT_VERSION
#       (from build.gradle.kts's versionCode) into Version.xcconfig at
#       `make -C ios project` time, and Xcode maps those to CFBundleShortVersionString
#       and CFBundleVersion; if the archive predates a version bump, the values
#       disagree and this fails.
#   (4) the .ipa is signed, the signature verifies, and it was signed by OUR team.
#       This is the analogue of push-playstore's fingerprint pin, but it pins the
#       TEAM ID, not a certificate digest, and the difference is deliberate. The
#       Android pin works because the maintainer owns the signing key and its
#       SHA-256 is published in SECURITY.md for users to verify against. An iOS
#       distribution certificate is issued BY Apple, rotates roughly yearly, and
#       under this project's automatic signing is minted by Xcode at export time
#       (see release-ios's -allowProvisioningUpdates) -- so its digest is neither
#       chosen by the maintainer nor stable, and pinning it would schedule an
#       annual false failure while proving little. The Team ID is the stable,
#       maintainer-owned identity in that signature, and it is already resolved
#       here exactly as release-ios resolves it (DEVELOPMENT_TEAM, else
#       ios/signing.properties).
#   (5) a real PRE-FLIGHT auth check against App Store Connect. This one is a
#       PREREQUISITE rather than a step inside the recipe, and that is not
#       cosmetic: under .ONESHELL the whole recipe is a single shell script, so a
#       `$(MAKE) push-appstore-preflight` inside it would make the ENTIRE script
#       "a line containing $(MAKE)" -- and make executes those even under `-n`.
#       `make -n push-appstore` would then really upload. As a prerequisite it
#       runs in its own recipe, `-n` stays a dry run, and the check still happens
#       before the upload. The cost is ordering: with credentials missing you learn
#       that before guards (1)-(4) report, and with a missing .ipa you pay one
#       read-only round trip first. Both are cheap; a `-n` that publishes is not.
#   (6) the LISTING, before it is sent: the reviewer contact exists (it is
#       git-ignored and set up once per machine, so its absence is a setup step
#       rather than a bug), and check-ios-metadata and check-ios-screenshots
#       pass. deliver checks all of this too -- from the far side of the network,
#       one finding per attempt, after the .ipa has already gone over the wire.
#
# The .ipa is a zip, and neither codesign nor plutil reads inside one, so (3) and
# (4) unpack it into a mktemp directory and inspect the .app there. The staged file
# itself is never touched, and the temp directory is removed on every exit path via
# a trap -- including the failure paths, which under `-e` leave the recipe at the
# failing line.
#
# fastlane runs actions from the PROJECT ROOT (it chdirs one level up from
# fastlane/), so the staged path handed to the lane's ipa: option is
# repo-root-relative -- exactly $(STAGED_IPA), with no ../ prefix. Same convention
# as push-playstore's aab:.
push-appstore: push-appstore-preflight
	# 1) staged .ipa must exist (never builds/stages)
	@test -f "$(STAGED_IPA)" || { echo "push-appstore: staged .ipa not found at '$(STAGED_IPA)' -- run 'make release-ios' first (it archives, exports and stages the .ipa). This target does NOT build or stage it." >&2; exit 1; }
	# 2) release tag must exist locally and on the push remote
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-appstore: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && git push && git push --tags). This target does NOT create the tag." >&2; exit 1; }
	remote="$$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || true)"; remote="$${remote:-origin}"
	git ls-remote --exit-code --tags "$$remote" "refs/tags/v$(VERSION)" >/dev/null || { echo "push-appstore: tag 'v$(VERSION)' not found on remote '$$remote' -- push it first (git push && git push --tags)." >&2; exit 1; }
	# Resolve the expected Team ID exactly as release-ios does: the environment
	# wins, else ios/signing.properties. The $${VAR:-} default keeps -u happy and
	# the file is only read when it exists (sed on a missing file would abort this
	# .ONESHELL recipe under -e before the friendly message below could print).
	team="$${DEVELOPMENT_TEAM:-}"
	if [ -z "$$team" ] && [ -f ios/signing.properties ]; then \
		team="$$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' ios/signing.properties | head -n 1)"; \
	fi
	if [ -z "$$team" ] || [ "$$team" = "XXXXXXXXXX" ]; then \
		echo "push-appstore: no Apple Developer Team ID -- set DEVELOPMENT_TEAM or copy ios/signing.properties.example to ios/signing.properties and fill it in (see docs/RELEASE-IOS.md)." >&2; \
		exit 1; \
	fi
	# Unpack the staged .ipa so codesign and plutil can see the .app inside. The
	# trap fires on every exit path, so the temp tree never survives the recipe.
	work="$$(mktemp -d)"
	trap 'rm -rf "$$work"' EXIT
	unzip -q "$(STAGED_IPA)" -d "$$work"
	app="$$(find "$$work/Payload" -maxdepth 1 -name '*.app' -print -quit)"
	test -n "$$app" || { echo "push-appstore: no Payload/*.app inside '$(STAGED_IPA)' -- the staged file is not a valid .ipa. Re-run 'make release-ios'." >&2; exit 1; }
	# 3) the .ipa must describe THIS version of THIS app
	got_id="$$(plutil -extract CFBundleIdentifier raw -o - -- "$$app/Info.plist")"
	got_build="$$(plutil -extract CFBundleVersion raw -o - -- "$$app/Info.plist")"
	got_version="$$(plutil -extract CFBundleShortVersionString raw -o - -- "$$app/Info.plist")"
	echo "push-appstore: staged .ipa says id=$$got_id version=$$got_version build=$$got_build"
	test "$$got_id" = "$(RELEASE_ID)" || { echo "push-appstore: staged .ipa has bundle identifier '$$got_id', expected '$(RELEASE_ID)'." >&2; exit 1; }
	test "$$got_build" = "$(VERSION_CODE)" || { echo "push-appstore: staged .ipa has build number '$$got_build', but this tree is at versionCode $(VERSION_CODE) -- the staged .ipa is from another release. Re-run 'make release-ios' (or remove the stale releases/ artifact)." >&2; exit 1; }
	test "$$got_version" = "$(VERSION)" || { echo "push-appstore: staged .ipa has marketing version '$$got_version', but this tree is at v$(VERSION) -- the staged .ipa is from another release. Re-run 'make release-ios'." >&2; exit 1; }
	# 4) the signature must verify, and it must be OUR team's. codesign writes its
	#    report to stderr, hence the 2>&1; --verbose=4 is what prints TeamIdentifier.
	codesign --verify --strict "$$app"
	got_team="$$(codesign -dv --verbose=4 "$$app" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -n 1)"
	echo "push-appstore: .ipa signed by TeamIdentifier: $$got_team"
	test "$$got_team" = "$$team" || { echo "push-appstore: staged .ipa is signed by team '$$got_team', expected '$$team' -- it was exported with different credentials than this tree configures." >&2; exit 1; }
	@( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "push-appstore: fastlane gems not installed -- run 'cd fastlane && bundle install'." >&2; exit 1; }
	# 5) The listing itself, checked BEFORE it is sent. `make ios` already runs
	#    check-ios-metadata, but nothing ran it HERE -- which is how this cycle
	#    spent four upload attempts learning what a gate could have said in a
	#    second: wrong locale directory names, A4-shaped report screenshots, and
	#    a reviewer contact still reading PLACEHOLDER. deliver catches all three,
	#    but only from the far side of the network, one per attempt.
	@for f in first_name last_name email_address phone_number; do \
		test -f "fastlane/metadata/ios/review_information/$$f.txt" || { echo "push-appstore: fastlane/metadata/ios/review_information/$$f.txt is missing -- the App Store reviewer contact is git-ignored and set up once per machine: copy the .txt.example files beside it and fill in your own details." >&2; exit 1; }; \
	done
	# --release here (and only here) makes check-ios-metadata enforce the
	# per-locale release_notes.txt that `make ios` defers: this is the release
	# path, so the translations must be present now.
	python3 tools/check-ios-metadata.py --release
	python3 tools/check-ios-screenshots.py
	# 6) upload the staged .ipa (repo-root-relative ipa: for fastlane's chdir).
	#    The App Store Connect pre-flight already ran as this target's
	#    prerequisite -- see the comment block above for why it lives there.
	( cd fastlane && bundle exec fastlane ios $(if $(SUBMIT),production,testing) ipa:"$(STAGED_IPA)" )

# ── push-appstore-preflight ── the credential half of push-appstore, on its own.
# Runs the fastlane `ios preflight` lane, which authenticates with the App Store
# Connect API key and performs one READ-ONLY query against the app record. Nothing
# is uploaded and nothing changes on the store, so this is safe to run at any time
# -- it is the closest this platform gets to push-playstore's VALIDATE_ONLY dry run
# (deliver has no validate-only mode; see the note on push-appstore above).
#
# The three APP_STORE_CONNECT_API_KEY_* variables are read from the environment by
# fastlane's own `app_store_connect_api_key` action under its default env names, so
# they are checked HERE only to turn an unhelpful fastlane error into a legible
# one. They are SECRETS and are never written to disk by this target.
push-appstore-preflight:
	@for v in APP_STORE_CONNECT_API_KEY_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_KEY_FILEPATH; do \
		eval "val=\$${$$v:-}"; \
		test -n "$$val" || { echo "push-appstore-preflight: $$v is not set -- the App Store Connect API key is injected through the three APP_STORE_CONNECT_API_KEY_* variables (see fastlane/Fastfile, iOS block, and docs/RELEASE-IOS.md)." >&2; exit 1; }; \
	done
	@test -f "$$APP_STORE_CONNECT_API_KEY_KEY_FILEPATH" || { echo "push-appstore-preflight: the API key file '$$APP_STORE_CONNECT_API_KEY_KEY_FILEPATH' (APP_STORE_CONNECT_API_KEY_KEY_FILEPATH) does not exist." >&2; exit 1; }
	@( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "push-appstore-preflight: fastlane gems not installed -- run 'cd fastlane && bundle install'." >&2; exit 1; }
	( cd fastlane && bundle exec fastlane ios preflight )

# ── push-gitlab ── create a GitLab release for the ALREADY-PUSHED release tag
# from the command line instead of the web UI, and publish the release APK + SBOMs
# as its assets.
#
# WHY THIS IS A TWO-STEP UPLOAD. A GitLab release does not STORE files: its
# assets are LINKS. The bytes therefore have to live somewhere first, and the
# project's own generic package registry is that somewhere:
#
#   1. PUT each staged file to
#      .../projects/$(GITLAB_PROJECT_ID)/packages/generic/releases/v$(VERSION)/<asset>
#   2. attach it to the release as an asset link whose `direct_asset_path` is
#      "/<asset>", which is what makes GitLab serve it under the PERMANENT,
#      namespace-relative URL
#      https://gitlab.com/$(GITLAB_REPO)/-/releases/v$(VERSION)/downloads/<asset>
#
# That permanent form is not cosmetic: it is the URL shape the F-Droid recipe's
# `Binaries:` field interpolates per version (see fdroid/de.godisch.potillus.yml),
# so it must keep working unchanged from release to release. The registry URL
# underneath carries a numeric project id and is an implementation detail.
#
# The assets are the STAGED files from releases/ (produced by `make release-android`),
# published under their canonical names de.godisch.potillus_<versionCode>.apk and
# _<versionCode>_{android,ios}_sbom.json. After each upload the published asset is
# re-downloaded from its permanent release URL and its sha256 is diffed against
# the staged file, so a corrupted upload is caught.
#
# DETACHED SIGNATURES. Each artifact is also published with an ASCII-armoured
# OpenPGP signature beside it (<asset>.asc). The APK already carries an Android
# signature INSIDE it, but that one lives in the APK signing block and is
# invisible to anything looking at the release page; a detached .asc lets anyone
# verify the published bytes with gpg and nothing else. It matters more still for
# the SBOMs, which carry no internal signature at all. The key is the one
# SECURITY.md publishes for encrypted reports and the one the release tags are
# signed with, and it is distributed through the Debian keyserver (the maintainer
# is a Debian Developer) -- so a verifier need not trust a project-specific key
# handed out by the project itself; there is a path through the Debian web of
# trust:
#
#     gpg --keyserver hkps://keyring.debian.org:443 --recv-keys $(GPG_SIGNING_KEY)
#     gpg --verify de.godisch.potillus_<versionCode>.apk.asc \
#                  de.godisch.potillus_<versionCode>.apk
#
# NAME vs. IDENTITY. A link carries a human-readable `name` shown on the release
# page ("Android Package Kit", not de.godisch.potillus_95.apk) and a `url`. Only
# the URL identifies the artifact: GitLab requires BOTH to be unique within a
# release, but the name is display text a maintainer may reword at any time,
# while the URL is derived from the file name and the version and is therefore
# reproducible from the staged file alone. Recognition below is consequently by
# URL. Doing it by name would break the moment a link is renamed in the web UI --
# the target would not recognise the existing link, would try to add a second one
# for the same file, and would fail on the URL uniqueness constraint. The display
# names come from $(GITLAB_ASSET_LABELS) below.
#
# SAFE TO RE-RUN: a previous invocation may have uploaded some files and then
# died (network). Every step is therefore idempotent -- a package file whose
# published sha256 already matches the staged file is left alone, an existing
# release for the tag is REUSED instead of failing on GitLab's duplicate-release
# 409, and an asset link whose URL is already attached is not added twice. It is
# also SELF-HEALING for the one case that cannot be fixed by re-running a naive
# version: a link created without `direct_asset_path` (the web UI offers no such
# field) resolves its permanent URL to the registry URL instead of the
# /-/releases/.../downloads/ form, which would leave the F-Droid `Binaries:` URL
# dead. Such a link is PATCHED in place rather than reported.
#
# Like push-playstore, this never builds and never stages: `make release-android`
# builds and stages the artifacts. It FAILS FAST if the tag, the staged APK, the
# staged SBOM, the release notes, curl/python3 or the GitLab token file are
# missing. Build+stage first (`make release-android`) and push the tag first
# (`git tag -s vX.Y.Z ... && git push && git push --tags`); this only publishes.
#
# The GitLab access token is READ FROM $(GITLAB_TOKEN_FILE) (Settings ->
# Access tokens, `api` scope -- `read_api` is not enough, the target writes).
# That file is a SECRET, git-ignored and never committed -- mirroring the Play
# service-account key. The recipe's commands are echoed (so you can see what
# runs), but that does NOT leak the token: it lives in a SHELL variable --
# written $$token in the recipe, i.e. the shell's own $token -- read from the
# file at run time. make expands its own make-variables when it echoes a line,
# but never shell-variables, so the echo shows the literal "$token" and never the
# token VALUE. The token also never appears on a curl COMMAND LINE (which any
# local process could read from /proc/<pid>/cmdline while curl runs): it is
# written into a mode-0600 temp file and passed with curl's `-H @file` form
# (curl >= 7.55; Debian stable qualifies), removed again by an EXIT trap.
GITLAB_API        := https://gitlab.com/api/v4
GITLAB_REPO       := godisch/potillus
# Numeric project id: the REST API addresses a project by id (or by URL-encoded
# path); the id is stable across renames, which the path is not. Shown on the
# project's overview page and in Settings -> General.
GITLAB_PROJECT_ID := 84607593
# Generic-package NAME the release artifacts are filed under; the package VERSION
# is the release tag, so each release gets its own package.
GITLAB_PACKAGE    := releases
# Display names for the release-page asset links, as "<suffix>=<label>" pairs.
# The suffix is matched against the END of the staged file name, so the version
# code in the middle of the name does not have to be spelled out here. A file
# matching no suffix keeps its bare file name as the label -- a new artifact type
# therefore still publishes correctly, it is only labelled less prettily until it
# is added here. These are DISPLAY TEXT only; the link URL is what identifies the
# artifact (see the note above).
#
# ORDER MATTERS: the match takes the LAST pair whose suffix fits, so the ".asc"
# entries must come after their base entries -- ".apk" also matches
# "....apk.asc", and without the later, longer pair a signature would inherit the
# artifact's own label and collide with it (GitLab requires link names to be
# unique within a release).
GITLAB_ASSET_LABELS := \
	.apk=Android\ Package\ Kit \
	_android_sbom.json=Android\ Software\ Bill\ of\ Materials \
	_ios_sbom.json=iOS\ Software\ Bill\ of\ Materials \
	.apk.asc=Android\ Package\ Kit\ OpenPGP\ Signature \
	_android_sbom.json.asc=Android\ Software\ Bill\ of\ Materials\ OpenPGP\ Signature \
	_ios_sbom.json.asc=iOS\ Software\ Bill\ of\ Materials\ OpenPGP\ Signature
# OpenPGP key the release artifacts are signed with, pinned to a full 40-hex-digit
# fingerprint rather than a short id (short ids are forgeable) -- the same key
# SECURITY.md publishes for encrypted vulnerability reports and the one the
# release tags are signed with. Overridable without editing the recipe, for a
# maintainer succession: make push-gitlab GPG_SIGNING_KEY=<fingerprint>
GPG_SIGNING_KEY   := 1842323B4FCF9B90995FA17FA350B991F05A4857
GITLAB_TOKEN_FILE := fastlane/gitlab-credentials.txt
# (VERSION_CODE and the staged/Gradle artifact paths are defined in the "Release
# staging" section above -- the staged files, not the raw Gradle outputs, are
# what this uploads.)
push-gitlab:
	# require curl + python3 (GitLab REST + JSON encoding) and gpg (detached signatures)
	command -v curl
	command -v python3
	command -v gpg
	@test -f "$(GITLAB_TOKEN_FILE)" || { echo "push-gitlab: token file '$(GITLAB_TOKEN_FILE)' not found -- create it containing your GitLab personal or project access token (Settings > Access tokens, 'api' scope). It is git-ignored." >&2; exit 1; }
	token="$$(tr -d '[:space:]' < "$(GITLAB_TOKEN_FILE)")"
	@test -n "$$token" || { echo "push-gitlab: token file '$(GITLAB_TOKEN_FILE)' is empty." >&2; exit 1; }
	# token -> mode-0600 header file (never on argv); removed by the EXIT trap
	hdr="$$(mktemp)"
	trap 'rm -f "$$hdr"' EXIT
	printf 'PRIVATE-TOKEN: %s\n' "$$token" > "$$hdr"
	# release tag must exist locally and on the push remote (server resolves the release against it)
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-gitlab: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && git push && git push --tags). This target does NOT create the tag." >&2; exit 1; }
	remote="$$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || true)"; remote="$${remote:-origin}"
	git ls-remote --exit-code --tags "$$remote" "refs/tags/v$(VERSION)" >/dev/null || { echo "push-gitlab: tag 'v$(VERSION)' not found on remote '$$remote' -- push it first (git push && git push --tags)." >&2; exit 1; }
	notes="$(META)/en-US/changelogs/$(VERSION_CODE).txt"
	@test -f "$$notes" || { echo "push-gitlab: en-US release notes '$$notes' not found (versionCode $(VERSION_CODE))." >&2; exit 1; }
	# staged, signed APK must exist (canonical name = proof a key was used; never builds/stages)
	apk="$(STAGED_APK)"
	@test -f "$(STAGED_APK)" || { echo "push-gitlab: staged APK not found at '$(STAGED_APK)' -- run 'make release-android' first (it builds and stages the APK). This target does NOT build or stage it." >&2; exit 1; }
	# verify APK signature and pin its signer SHA-256 to SECURITY.md (apksigner from PATH, else ANDROID_HOME build-tools)
	aps="$${APKSIGNER:-$$(command -v apksigner || ls -1 "$${ANDROID_HOME:-$$HOME/android-sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)}"
	"$$aps" verify "$$apk"
	got="$$("$$aps" verify --print-certs "$$apk" | grep -oiE 'SHA-?256 digest:[[:space:]]*[0-9a-f]{64}' | grep -oiE '[0-9a-f]{64}' | tr 'A-F' 'a-f' | sort -u)"
	echo "push-gitlab: APK signer certificate SHA-256: $$got"
	test "$$got" = "$(SIGNING_KEY_FINGERPRINT)"
	@test -f "$(STAGED_SBOM)" || { echo "push-gitlab: staged SBOM not found at '$(STAGED_SBOM)' -- run 'make release-android' first (it builds and stages the SBOM). This target does NOT build or stage it." >&2; exit 1; }
	# 0) sign each artifact with a detached, ASCII-armoured OpenPGP signature.
	# The secret key must be available; a passphrase prompt is fine here, which is
	# why --batch is deliberately NOT used. A signature left behind by an
	# interrupted earlier run is re-VERIFIED rather than trusted on sight and
	# rather than remade, so a rerun neither prompts again nor keeps a stale file.
	ios_sbom=""; test -e "$(STAGED_IOS_SBOM)" && ios_sbom="$(STAGED_IOS_SBOM)"
	@gpg --list-secret-keys "$(GPG_SIGNING_KEY)" >/dev/null 2>&1 || { echo "push-gitlab: no secret OpenPGP key for $(GPG_SIGNING_KEY) -- that is the key SECURITY.md publishes and the one the release tags are signed with. Override with 'make push-gitlab GPG_SIGNING_KEY=<fingerprint>' if the project's key has changed." >&2; exit 1; }
	for staged in "$$apk" "$(STAGED_SBOM)" $$ios_sbom; do
		if [ -f "$$staged.asc" ] && gpg --verify "$$staged.asc" "$$staged" >/dev/null 2>&1; then
			echo "push-gitlab: $$(basename "$$staged").asc already present and valid -- keeping it"
			continue
		fi
		rm -f "$$staged.asc"
		gpg --local-user "$(GPG_SIGNING_KEY)" --armor --detach-sign --output "$$staged.asc" "$$staged"
		gpg --verify "$$staged.asc" "$$staged"
		echo "push-gitlab: signed $$(basename "$$staged")"
	done
	# Publication list: each artifact immediately followed by its signature, so the
	# release page lists them as pairs rather than three files then three signatures
	# (GitLab renders asset links in the order they are attached).
	publish=""
	for staged in "$$apk" "$(STAGED_SBOM)" $$ios_sbom; do
		publish="$$publish $$staged $$staged.asc"
	done
	# 1) upload the staged files into the generic package registry (skip byte-identical re-uploads)
	pkg_base="$(GITLAB_API)/projects/$(GITLAB_PROJECT_ID)/packages/generic/$(GITLAB_PACKAGE)/v$(VERSION)"
	for staged in $$publish; do
		asset="$$(basename "$$staged")"
		want="$$(sha256sum "$$staged" | cut -d' ' -f1)"
		# an interrupted earlier run may already have stored this exact file
		have="$$(curl -sSL --proto '=https' --tlsv1.2 -H @"$$hdr" "$$pkg_base/$$asset" 2>/dev/null | sha256sum | cut -d' ' -f1 || true)"
		if [ "$$have" = "$$want" ]; then
			echo "push-gitlab: package file $$asset already uploaded -- skipping"
			continue
		fi
		curl -fsS --proto '=https' --tlsv1.2 -H @"$$hdr" --upload-file "$$staged" "$$pkg_base/$$asset" >/dev/null
		echo "push-gitlab: uploaded $$asset to the package registry"
	done
	# 2) create the release for the existing tag and REUSE it if present (rerun-safe)
	rel_api="$(GITLAB_API)/projects/$(GITLAB_PROJECT_ID)/releases"
	release_json="$$(curl -sS --proto '=https' --tlsv1.2 -H @"$$hdr" "$$rel_api/v$(VERSION)" || true)"
	have_tag="$$(printf '%s' "$$release_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)"
	if [ -n "$$have_tag" ]; then
		echo "push-gitlab: release for tag v$(VERSION) already exists -- reusing it"
	else
		# body = JSON-encoded en-US Play release notes for this versionCode
		body="$$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1], encoding="utf-8").read()))' "$$notes")"
		payload="$$(printf '{"tag_name":"v%s","name":"Libellus Potionis v%s","description":%s}' "$(VERSION)" "$(VERSION)" "$$body")"
		curl -fsS --proto '=https' --tlsv1.2 -X POST -H @"$$hdr" -H "Content-Type: application/json" -d "$$payload" "$$rel_api" >/dev/null
		echo "push-gitlab: created release 'Libellus Potionis v$(VERSION)'"
		release_json="$$(curl -sS --proto '=https' --tlsv1.2 -H @"$$hdr" "$$rel_api/v$(VERSION)")"
	fi
	# Existing links as "<url> <id> <direct_asset_url>" lines -- keyed by URL, the
	# artifact's identity; the id is what a PATCH below addresses.
	have_links="$$(printf '%s' "$$release_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join("%s %s %s" % (l.get("url",""), l.get("id",""), l.get("direct_asset_url","")) for l in (d.get("assets") or {}).get("links") or []))' 2>/dev/null || true)"
	# 3) attach each package file as an asset link, then verify the PUBLISHED bytes
	dl_base="https://gitlab.com/$(GITLAB_REPO)/-/releases/v$(VERSION)/downloads"
	for staged in $$publish; do
		asset="$$(basename "$$staged")"
		pkg_url="$$pkg_base/$$asset"
		want_dl="$$dl_base/$$asset"
		# display label: longest-suffix match against GITLAB_ASSET_LABELS, else the file name
		label="$$asset"
		for pair in $(GITLAB_ASSET_LABELS); do
			case "$$asset" in *"$${pair%%=*}") label="$${pair#*=}";; esac
		done
		existing="$$(printf '%s\n' "$$have_links" | awk -v u="$$pkg_url" '$$1 == u { print $$2, $$3; exit }')"
		if [ -z "$$existing" ]; then
			# direct_asset_path MUST start with '/'; it is what yields $$want_dl
			link="$$(python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1],"url":sys.argv[2],"direct_asset_path":"/"+sys.argv[3]}))' "$$label" "$$pkg_url" "$$asset")"
			curl -fsS --proto '=https' --tlsv1.2 -X POST -H @"$$hdr" -H "Content-Type: application/json" -d "$$link" "$$rel_api/v$(VERSION)/assets/links" >/dev/null
			echo "push-gitlab: attached $$asset as '$$label'"
		else
			link_id="$${existing%% *}"; got_dl_url="$${existing##* }"
			if [ "$$got_dl_url" = "$$want_dl" ]; then
				echo "push-gitlab: asset link for $$asset already attached -- skipping"
			else
				# link exists but lacks direct_asset_path (e.g. created in the web UI),
				# so its permanent URL is wrong and the F-Droid Binaries: URL would 404
				patch="$$(python3 -c 'import json,sys; print(json.dumps({"direct_asset_path":"/"+sys.argv[1]}))' "$$asset")"
				curl -fsS --proto '=https' --tlsv1.2 -X PUT -H @"$$hdr" -H "Content-Type: application/json" -d "$$patch" "$$rel_api/v$(VERSION)/assets/links/$$link_id" >/dev/null
				echo "push-gitlab: repaired direct_asset_path of the existing link for $$asset"
			fi
		fi
		# download the published asset and diff its sha256 against the staged file (one 2s retry for endpoint lag)
		want="$$(sha256sum "$$staged" | cut -d' ' -f1)"
		got_dl=""
		for attempt in 1 2; do
			got_dl="$$(curl -fsSL --proto '=https' --tlsv1.2 "$$dl_base/$$asset" | sha256sum | cut -d' ' -f1 || true)"
			[ "$$got_dl" = "$$want" ] && break
			sleep 2
		done
		test "$$got_dl" = "$$want" || { echo "push-gitlab: sha256 mismatch for published asset $$asset at $$want_dl (staged $$want, downloaded $$got_dl) -- the upload is corrupt; re-run after deleting the package file and the asset link on GitLab." >&2; exit 1; }
		echo "push-gitlab: verified $$asset sha256 $$want"
	done
	echo "push-gitlab: done -> https://gitlab.com/$(GITLAB_REPO)/-/releases/v$(VERSION)"

.PHONY: tgz push-playstore push-appstore push-appstore-preflight push-gitlab
