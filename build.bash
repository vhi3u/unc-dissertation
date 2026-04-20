#!/bin/bash

# Define local function for cleaning up auxiliary files
function clean_auxiliary_files() {
    # Define names of expected auxiliary files
    local name="$1"
    local files=(
        "${name%.tex}.aux"
        "${name%.tex}.bbl"
        "${name%.tex}.bcf"
        "${name%.tex}.blg"
        "${name%.tex}.dvi"
        "${name%.tex}.fdb_latexmk"
        "${name%.tex}.fls"
        "${name%.tex}.blg"
        "${name%.tex}.log"
        "${name%.tex}.lof"
        "${name%.tex}.lot"
        "${name%.tex}.nav"
        "${name%.tex}.out"
        "${name%.tex}.out.ps"
        "${name%.tex}.run.xml"
        "${name%.tex}.snm"
        "${name%.tex}.thm"
        "${name%.tex}.toc"
    )

    # Loop through each file; delete files that exist
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
        fi
    done
}

# Allow optional entry of main file name; default to "main.tex"
NAME_IN=${1:-main.tex}
NAME_OUT="./${NAME_IN%.tex}.pdf"
printf "\n\nCompiling LaTeX document:\n$NAME_IN\n\n"

# Create logs directory to store auxiliary files
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${NAME_IN%.tex}.log"

# Delete existing PDF and clean up folder for auxiliary files
if [ -f "$NAME_OUT" ]; then
    rm "$NAME_OUT"
fi
clean_auxiliary_files "$NAME_IN"

# Wait briefly to ensure that file system changes are registered
sleep 0.1

# Do the first of three runs for "pdflatex"
pdflatex --shell-escape "$NAME_IN" -interaction=nonstopmode -file-line-error | tee "$LOG_FILE"

# Generate the bibliography; terminate if something went wrong
biber "${NAME_IN%.tex}"
#bibtex "${NAME_IN%.tex}"
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    printf "\n\Bibliography generation failed. See %s for details.\n\n" "$LOG_FILE"
    exit 1
fi
if [ ! -f "${NAME_IN%.tex}.bbl" ]; then
    echo "Error: .bbl file not found. BibTeX may have failed."
    exit 1
fi

# Run "pdflatex" two more times. The first run creates the necessary
# auxiliary files, and the second run resolves any cross-references.
pdflatex --shell-escape "$NAME_IN" -interaction=nonstopmode -file-line-error | tee -a "$LOG_FILE"
pdflatex --shell-escape "$NAME_IN" -interaction=nonstopmode -file-line-error | tee -a "$LOG_FILE"

# Clean up project folder after the final compilation
if ! grep -q "LaTeX Error:" "$LOG_FILE"; then
    mv "${NAME_IN%.tex}.pdf" "$NAME_OUT"
    # clean_auxiliary_files "$NAME_IN"
else
    printf "\n\nLaTeX compilation error detected in final pass!\n\n"
fi
