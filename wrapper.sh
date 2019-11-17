#!/bin/sh

# Fast fail
set -e

# Determining program's working directory
PROGNAME="$(basename "$0")"

PROGDIR="$(dirname "$0")"
case "$PROGDIR" in
	/*)
		# Path is already absolute
		true
		;;
	*)
		# Path is relative, so use $PWD
		PROGDIR="${PWD}/${PROGDIR}"
		;;
esac

# Changing to the program dir
cd "${PROGDIR}"
	
# Creating a separate, clean environment
eval $(perl -Mlocal::lib="${PROGDIR}/.plenv")

# Bootstrapping is needed
if [ ! -d "${PROGDIR}/local" ] ; then
	# Checking whether cpm is already in the environment
	# (as it is needed)
	type -a cpm >& /dev/null || cpan App::cpm
	
	# Now, installing all
	for CPANF in cpanfile* ; do
		case "$CPANF" in
			*.snapshot)
				# Ignore these
				true
				;;
			*)
				cpm install --resolver 02packages,https://gitlab.bsc.es/inb/darkpan/raw/master/ --resolver metadb --cpanfile "$CPANF"
				# Should we regenerate the snapshot file?
				if [ -f "${CPANF}.snapshot" ] ; then
					carton install --cpanfile "$CPANF" --deployment --without develop
				else
					carton install --cpanfile "$CPANF" --without develop
				fi
				;;
		esac
	done
fi

# Last, time to run everything!
exec carton exec "${PROGDIR}/${PROGNAME}.pl" "$@"