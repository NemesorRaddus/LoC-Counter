#!/bin/bash

PROGRAM_NAME="LoC Counter"
VERSION="v0.1"
AUTHOR="Piotr 'Nemesor Raddus' Juszczyk"

function display_help {
	printf "LoC Counter\n"
	printf "Easy to use simple Lines of Code counter.\n\n"
	printf -- "-d DIRECTORY --directory DIRECTORY\n"
	printf "Select entry directory.\n\n"
	printf -- "-e EXTENSIONS --extensions EXTENSIONS\n"
	printf "Select wanted file extensions. Separate them using whitespace characters.\n\n"
	printf -- "-p PATTERNS --patterns PATTERNS\n"
	printf "Select wanted file names using RegEx patterns for paths. Separate them using whitespace characters.\n\n"
	printf "Aforementioned name parameters complement each other and can be mixed.\n\n"
	printf -- "-r --recursive [TRUE]\n"
	printf "Enable recursive mode - search for files also in subdirectories.\n\n"
	printf -- "-s --stripped [TRUE]\n"
	printf "Enable stripped mode - show only the final sum, excluding separate entries.\n\n"
	printf -- "-g --gui [TRUE]\n"
	printf "Enable GUI - express the results using zenity.\n\n"
	printf -- "-h --help\n"
	printf "Display this help text.\n\n"
	printf -- "-v --version\n"
	printf "Display current version.\n\n"
}

function display_version {
	printf "$PROGRAM_NAME\n"
	printf "$VERSION\n"
	printf "by $AUTHOR\n"
}

function error {
	printf "$1" >&2
	exit 1
}

function parsing_error {
	error "Parsing error!\n"
}

# $1 - input to parse
# $2 - boolean to overwrite if the input is considered true
function handle_input_boolean {
	case "$1" in
		"" | 1 | t | T | true | TRUE)
			local "$2" && upvar $2 1 ;;
		0 | f | F | false | FALSE)
			;;
		*)
			parsing_error ;;
	esac
}

OPTS=`getopt -o d:e:p:rsghv --long directory:,extensions:,patterns:,recursive::,stripped::,gui::,help,version -n 'locc' -- "$@"`

if [[ $? != 0 ]]; then
	parsing_error
fi

eval set -- "$OPTS"

DIRECTORY="."
EXTENSIONS=""
PATTERNS=""
RECURSIVE=""
STRIPPED=""
GUI=""

SKIP_HELP_AND_SUM="" # even when the user didn't enter enough information (files to look for), skip help and other info

while true; do
	case "$1" in
		-d | --directory)
			DIRECTORY=$2; shift 2 ;;
		-e | --extensions)
			EXTENSIONS=$2; shift 2 ;;
		-p | --patterns)
			PATTERNS=$2; shift 2 ;;
		-r)
			RECURSIVE=1; shift ;;
		--recursive)
			case "$2" in
				"")
					RECURSIVE=1; shift 2 ;;
				*)
					handle_input_boolean $2 $RECURSIVE; shift 2 ;;
			esac ;;
		-s)
			STRIPPED=1; shift ;;
		--stripped)
			case "$2" in
				"")
					STRIPPED=1; shift 2 ;;
				*)
					handle_input_boolean $2 $STRIPPED; shift 2 ;;
			esac ;;
		-g)
			GUI=1; shift ;;
		--gui)
			case "$2" in
				"")
					GUI=1; shift 2 ;;
				*)
					handle_input_boolean $2 $GUI; shift 2 ;;
			esac ;;
		-h | --help)
			SKIP_HELP_AND_SUM=1
			display_help; shift ;;
		-v | --version)
			SKIP_HELP_AND_SUM=1
			display_version ; shift ;;
		--)
			shift; break ;;
		*)
			parsing_error ;;
	esac
done

if [[ -z "$EXTENSIONS" && -z "$PATTERNS" ]]; then
	if [[ -z "$SKIP_HELP_AND_SUM" ]]; then
		printf "You must specify what should the program look for,"
		printf "using '-e EXTENSIONS' | '--extensions EXTENSIONS' and/or '-p PATTERNS' | '-patterns PATTERNS'."
		display_help
	fi
	exit
fi

CNT=0
INDEX=0
LIST=""

EXTENSIONS=`echo "$EXTENSIONS" | sed -E 's#(\S+)#.*\\\.\1#g'` # add *. everywhere at start
PATTERNS="$EXTENSIONS $PATTERNS" # concatenate patterns into one var
PATTERNS=`echo "$PATTERNS" | sed -E 's#(\S+)#^\1$#g'`

if [[ -z $RECURSIVE ]]; then
	MAXDEPTH="-maxdepth 1"
fi

FILES__="find \"$DIRECTORY\" $MAXDEPTH -name \"*\" -type f" # initially prepare files list
FILES__=`eval "$FILES__"`
FILES__=`echo "$FILES__" | sed -E 's#^\s*##'`

IFS=$'\n'; set -f
for FILE in $FILES__; do
	FILE=`echo "$FILE" | sed -E 's# #!#g'` # replace spaces in filenames with ! to properly handle them
	FILES_="$FILES_ $FILE"
done
unset IFS; set +f

for FILE in $FILES_; do
	for PATTERN in $PATTERNS; do
		if [[ `echo "$FILE" | grep -E "$PATTERN"` ]]; then
			FILES="$FILES $FILE"; # if filename matches any pattern, add it to the final list
			break
		fi
	done
done

MAXLOCLENGTH=0 # used to format results (LoC)

for FILE in $FILES; do
	FILE_HELPER=`echo "$FILE" | sed -E 's#!# #g'` # reverse replacing
	ENTRY="`wc -l "$FILE_HELPER" | cut -d " " -f 1`"" $FILE"
	LIST[$INDEX]="$ENTRY"
	CNTADD=`echo "$ENTRY" | cut -d " " -f 1`
	if [[ -z "$STRIPPED" ]]; then
		NEWLOCLENGTH=${#CNTADD}
		if [[ $NEWLOCLENGTH -gt $MAXLOCLENGTH ]]; then
			MAXLOCLENGTH=$NEWLOCLENGTH
		fi
	fi
	CNT=$((CNT + CNTADD))
	INDEX=$((INDEX + 1))
done

if [[ "$GUI" ]]; then
	if [[ -z "$STRIPPED" ]]; then
		for ENTRY in "${LIST[@]}"; do
			ZENITY_LIST+=( "`echo "$ENTRY" | cut -d " " -f 2 | sed -E 's#!# #g'`" )
			ZENITY_LIST+=( "`echo "$ENTRY" | cut -d " " -f 1`" )
		done
	fi
	ZENITY_LIST+=( "Sum" "$CNT" )
	CHOICE=`zenity --list --title="$PROGRAM_NAME $VERSION" \
	--column="LoC" --column="File" \
	--text="LoC amounts of found files" "${ZENITY_LIST[@]}"`
	case "$CHOICE" in
		Sum | "") ;;
		*)
			xdg-open "$CHOICE"
	esac
else
	if [[ -z "$STRIPPED" ]]; then
		for ENTRY in "${LIST[@]}"; do
			printf "%${MAXLOCLENGTH}d " `echo "$ENTRY" | cut -d " " -f 1`
			printf "%s\n" "`echo "$ENTRY" | cut -d " " -f 2 | sed -E 's#!# #g'`"
		done
	fi
	printf "Sum = $CNT\n"
fi
