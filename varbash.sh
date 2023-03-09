#!/usr/bin/env bash

# ============================================================================
# VarBash - Bash variable issue check script
# Copyright (C) 2017 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/varbash
# GitLab: https://gitlab.com/urbanware-org/varbash
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

lines_total=$(wc -l "$input_file" | awk '{ print $1 }')
for current_line in $(seq 1 $lines_total); do
    line=$(awk "NR==$current_line" "$input_file")
    for item in $line; do
        if [ "$item" = "\$#" ] || [ "$item" = "\$_" ] || \
           [ "$item" = "\$-" ] || [ "$item" = "\$?" ] || \
           [ "$item" = "\$$" ] || [ "$item" = "\$!" ] || \
           [ "$item" = "\$*" ] || [ "$item" = "\$@" ]; then
            continue
        elif [[ $item =~ \$[0-9] ]]; then
            continue
        elif [[ $item =~ \$\[.*\] ]]; then
            continue
        fi

        (grep -E "=''$|=\"\"$|=$" | grep -v "^#") <<< $line &>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "\e[1;33mLine $current_line: Initially no"\
                    "value assigned (maybe on purpose): \e[1;31m${item}\e[0m"
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
            elif [[ $item =~ \: ]]; then
                continue
            elif [[ $item =~ \" ]]; then
                continue
            elif [[ $item =~ \' ]]; then
                continue
            fi

            temp=$((sed -e 's/^\$//g' -e 's/;//g' -e 's/\$/ /g' -e 's/{//g' \
                        -e 's/}//g') <<< $item)
            for varname in $temp; do
                grep "$varname" $input_file | grep -E "for|while" &>/dev/null
                if [ $? -eq 0 ]; then
                    continue
                fi
                grep "$varname=" $input_file &>/dev/null
                if [ $? -ne 0 ]; then
                    echo -e "\e[1;36mLine $current_line: Possibly undefined"\
                            "variable: \e[1;37m\$${varname}\e[0m"
                    count=$(( count + 1 ))
                    issue_unused=1
                fi
            done
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
