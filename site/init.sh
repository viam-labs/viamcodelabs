#!/bin/bash
#
# init.sh
#
# Automate these steps to get yourself up and running with ViamGuides:
# * Create boilerplate for ViamGuide
# * Configure a nodemon watch command to rebuild your viamguide on save
# - + - + - + - + - + - + - + - + - + - + - + - + - + - + - + - + -

command_exists() {
    # check if command exists and fail otherwise
    command -v "$1" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Note: $1 Does not exist. Please install it first!"
    fi
}

cd `dirname $0`

# validate that a viamguide name was included as an argument
if [ "$#" -ne 1 ]; then
	echo "USAGE: npm run template <VIAMGUIDE_NAME>"
	echo ""
	exit 1
fi

# env variables
VIAMGUIDE_NAME=`echo $1 | tr '[:upper:]' '[:lower:]' | tr ' ' '_'`
AUTHOR_NAME=`git config user.name`

# local variables
viamguide_markdown_filename="viamguides/src/$VIAMGUIDE_NAME/$VIAMGUIDE_NAME.md"
markdown_template="viamguides/src/_template/markdown.template"
#in MacOS sed creates a backup file if zero length extension is not specified e.g. ''
backup_md="$viamguide_markdown_filename-e"

# validate that markdown template exist
if [ ! -f "$markdown_template" ]; then
  msg "ERROR!"
  echo "Could not find one of the following files:"
  echo "  - $markdown_template"
  echo ""
  exit 0
fi

# Create a new directory for the viamguide 
mkdir viamguides/src/$VIAMGUIDE_NAME
cp -r viamguides/src/_template/* viamguides/src/$VIAMGUIDE_NAME/

# rename markdown template file 
mv viamguides/src/$VIAMGUIDE_NAME/markdown.template $viamguide_markdown_filename

# replace placeholder viamguide id in markdown template file with name provided by command line argument 
sed -i \
  -e "s/VIAMGUIDE_NAME.*/$VIAMGUIDE_NAME/g" \
  $viamguide_markdown_filename

# replace placeholder authorname with git username=
sed -i \
  -e "s/AUTHOR_NAME.*/$AUTHOR_NAME/g" \
  $viamguide_markdown_filename

# replace placeholder viamguide name in the watch command with name provided in command line argument
if [ -f "$backup_md" ]; then
  rm $backup_md
fi

echo "Markdown file created! Find it at $PWD/viamguides/src/$VIAMGUIDE_NAME"

command_exists claat
command_exists go