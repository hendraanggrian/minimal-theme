#!/bin/bash

readonly END=[0m
readonly RED=[91m
readonly GREEN=[92m
readonly YELLOW=[93m

error() { echo; echo "$RED$1$END"; echo; exit 1; }

help() {
  echo
  echo "Usage: generate_index.sh [options]"
  echo
  echo "Options:"
  echo "  -h            Show this help message"
  echo "  -i            Input GitHub username and repository, separated by slash"
  echo "  -o            Output directory"
  echo "  -m            Markdown path relative to that repository, or default README if left empty"
  echo "  --clearoutput Clear the output directory before generating"
  echo
  exit 1
}

if ! command -v jq &> /dev/null; then error "jq is not installed"; fi
if ! command -v pandoc &> /dev/null; then error "pandoc is not installed"; fi

readonly ROOT_DIR="$(cd `dirname "$0"` && pwd)"
readonly IMAGES_DIR="$ROOT_DIR/images"
readonly SCRIPTS_DIR="$ROOT_DIR/scripts"
readonly STYLES_DIR="$ROOT_DIR/styles"
input_github=
output_directory=
markdown_path=
clear_output=false

for arg in "$@"; do
  shift
  case "$arg" in
    --help) set -- "$@" "-h";;
    --clearoutput) clear_output=true;;
    *) set -- "$@" "$arg" ;;
  esac
done

while getopts "i:o:m:h" flag; do
  case "$flag" in
    i) input_github="${OPTARG}" ;;
    o) output_directory="${OPTARG}" ;;
    m) markdown_path="${OPTARG}" ;;
    h | *) help ;;
  esac
done

if [[ -z "$input_github" ]]; then error "Missing input"; fi
if [[ -z "$output_directory" ]]; then error "Missing output directory"; fi

github_username="$(echo "$input_github" | cut -d '/' -f 1)"
github_repository="$(echo "$input_github" | cut -d '/' -f 2)"

echo
echo "fetching..."

github_fullname=$(curl -s "https://api.github.com/users/$github_username" | jq ".name" | tr -d '"')
if [[ "$github_fullname" == null ]]
  then
    error "GitHub user not found"
  else
    echo "Full name: $GREEN$github_fullname$END"
fi

github_description=$(curl -s "https://api.github.com/repos/$github_username/$github_repository" | jq ".description" | tr -d '"')
if [[ "$github_description" == null ]]
  then
    echo "Description: ${YELLOW}not found$END"
  else
    echo "Description: $GREEN$github_description$END"
fi

if [[ -z "$markdown_path" ]]
  then
    markdown_path=$(curl -s "https://api.github.com/repos/$github_username/$github_repository/readme" | jq ".download_url" | tr -d '"')
    echo "Markdown: ${YELLOW}default README$END"
  else
    markdown_path="https://raw.githubusercontent.com/$github_username/$github_repository/$markdown_path"
    echo "Markdown: $GREEN$markdown_path$END"
fi
markdown_content=$(pandoc -f gfm -t html $markdown_path)

echo
echo "writing..."

if [[ "$clear_output" = true ]]; then
  rm -r "$output_directory"/*
fi
yes | cp -rf "$IMAGES_DIR" "$output_directory"
yes | cp -rf "$SCRIPTS_DIR" "$output_directory"
yes | cp -rf "$STYLES_DIR" "$output_directory"

{
echo "<!doctype html>"
echo "<html>"
echo
echo "<head>"
echo "  <meta charset='utf-8'/>"
echo "  <meta http-equiv='X-UA-Compatible' content='chrome=1'/>"
echo "  <title>$github_repository by $github_fullname</title>"
echo "  <link rel='stylesheet' href='styles/main.css'/>"
echo "  <link rel='stylesheet' href='styles/pygment_trac.css'/>"
echo "  <meta name='viewport' content='width=device-width'/>"
echo "  <script src='scripts/theme.js'></script>"
echo "  <!--[if lt IE 9]>"
echo "  <script src='//html5shiv.googlecode.com/svn/trunk/html5.js'/>"
echo "  <![endif]-->"
echo "</head>"
echo
echo "<body>"
echo "  <div class='wrapper'>"
echo "    <header>"
echo "      <h1>$github_repository</h1>"
echo "      <p>$github_description</p>"
echo "      <p class='view'><a href='https://github.com/$github_username/$github_repository'>View the Project on GitHub <small>$github_username/$github_repository</small></a></p>"
echo "      <ul>"
echo "        <li><a href='https://github.com/$github_username/$github_repository/zipball/master'>Download <strong>ZIP File</strong></a></li>"
echo "        <li><a href='https://github.com/$github_username/$github_repository/tarball/master'>Download <strong>TAR Ball</strong></a></li>"
echo "        <li><a href='https://github.com/$github_username/$github_repository'>Fork on <strong>GitHub</strong></a></li>"
echo "      </ul>"
echo "    </header>"
echo "    <section>"
echo "<!-- GENERATED BY PANDOC -->"
echo "$markdown_content"
echo "<!-- END GENERATED BY PANDOC -->"
echo "    </section>"
echo "    <footer>"
echo "      <p><button title='Toggle dark mode' onclick='toggle()'><img id='toggle-img'></button></p>"
echo "      <p>This project is maintained by <a href='https://github.com/$github_username'>$github_fullname</a></p>"
echo "      <small>Hosted on GitHub Pages &mdash; Theme by <a href='https://github.com/hendraanggrian/minimal'>minimal</a></small>"
echo "    </footer>"
echo "  </div>"
echo "  <script src='scripts/scale.fix.js'></script>"
echo "  <script>"
echo "    const toggleImg = document.getElementById('toggle-img')"
echo "    toggleImg.src = getToggleImage(isDarkMode())"
echo "    function toggle() { toggleImg.src = getToggleImage(toggleDarkMode()) }"
echo "    function getToggleImage(isDarkMode) { return isDarkMode ? 'images/light_mode.svg' : 'images/dark_mode.svg' }"
echo "  </script>"
echo "</body>"
echo
echo "</html>"
} > "$output_directory/index.html"

echo "done"
echo
exit 0