#!/bin/bash

# ============================================================================
# VarBash - Bash variable issue check script
# Copyright (C) 2017 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# Website: http://www.urbanware.org
# GitHub: https://github.com/urbanware-org/varbash
# ============================================================================

version="1.0.3"

if [ $# -lt 1 ]; then
    echo "error: File path command-line argument missing"
    echo "usage: varbash.sh <FilePath>"
    exit 1
elif [ $# -gt 1 ]; then
    echo "error: Too many command-line arguments"
    echo "usage: varbash.sh <FilePath>"
    exit 1
fi

input_file="$1"
if [ -e "$input_file" ]; then
    if [ ! -f "$input_file" ]; then
        echo "error: Given path is not a file"
        exit 2
    fi
else
    if [ ! -f "$input_file" ]; then
        echo "error: Given file does not exist"
        exit 3
    fi
fi
echo

count=0
current_line=0
exit_code=0
issue_noinit=0
issue_unused=0
item=""

while read line; do
    current_line=$(( current_line + 1 ))
    for item in $(echo "$line"); do
        if [ "$item" = "\$#" ]; then
            continue
        fi
        echo "$line" | grep -E "=''$|=\"\"$|=$" | grep -v "^#" &>/dev/null
        if [ "$?" = "0" ]; then
            echo -e "\e[1;33mLine $current_line: Initially no"\
                    "value assigned (maybe on purpose): \e[1;31m${line}\e[0m"
            count=$(( count + 1 ))
            issue_noinit=1
            continue
        fi
        if [[ $item =~ ^\$ ]]; then
            if [[ $item =~ \$\( ]]; then
                continue
            elif [[ $item =~ \( ]]; then
                continue
            elif [[ $item =~ \) ]]; then
                continue
            elif [[ $item =~ \" ]]; then
                continue
            elif [[ $item =~ \: ]]; then
                continue
            fi
            temp=$((sed -e 's/\$//g') <<< $item)
            varname=$((sed -e 's/{//g' -e 's/}//g') <<< $temp)

            grep "$varname=" "$input_file" &>/dev/null
            if [ "$?" != "0" ]; then
                echo -e "\e[1;36mLine $current_line: Possibly never used"\
                        "variable: \e[1;37m${item}\e[0m"
                count=$(( count + 1 ))
                issue_unused=1
            fi
        fi
    done
done < $input_file

if [ $issue_noinit -eq 1 ] && [ $issue_unused -eq 1 ]; then
    exit_code=4
elif [ $issue_noinit -eq 1 ]; then
    exit_code=5
elif [ $issue_unused -eq 1 ]; then
    exit_code=6
fi

if [ $count -eq 0 ]; then
    echo "No variable issues found. Please manually revise the code anyway."
elif [ $count -eq 1 ]; then
    echo
    echo "Found one possible issue. Details can be found above."
else
    echo
    echo "Found $count possible issues. Details can be found above."
fi
echo

exit $exit_code

# EOF

