#!/usr/bin/env bash

#
# VarBash - Bash variable issue check script
# Copyright (C) 2023 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/varbash
# GitLab: https://gitlab.com/urbanware-org/varbash
#

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

cl_n="\e[0m"
cl_bk="\e[30m"
cl_br="\e[33m"
cl_db="\e[34m"
cl_dc="\e[36m"
cl_dy="\e[90m"
cl_dg="\e[32m"
cl_dp="\e[35m"
cl_dr="\e[31m"
cl_lb="\e[94m"
cl_lc="\e[96m"
cl_ly="\e[37m"
cl_lg="\e[92m"
cl_lp="\e[95m"
cl_lr="\e[91m"
cl_wh="\e[97m"
cl_yl="\e[93m"

count_critical=0
count_noinit=0
count_undefined=0
current_line=0
exit_code=0
issue_noinit=0
issue_undefined=0

lines_total=$(wc -l "$input_file" | awk '{ print $1 }')
for current_line in $(seq 1 $lines_total); do
    line=$(awk "NR==$current_line" "$input_file")

    grep -E "^#|[^\s]#" <<< $line &>/dev/null
    if [ $? -eq 0 ]; then
        continue
    fi

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

        grep -E "=''$|=\"\"$|=$" <<< $line &>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${cl_br}[${cl_yl}?${cl_br}] Line" \
                    "$current_line:\tInitially no" \
                    "value assigned:  ${cl_yl}${item}${cl_n}"
            count_noinit=$(( count_noinit + 1 ))
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
                    echo -e \
                        "${cl_dc}[${cl_lc}?${cl_dc}]" \
                        "Line $current_line:\tPossibly undefined" \
                        "variable:  ${cl_lc}\$${varname}${cl_n}"
                    count_undefined=$(( count_undefined + 1 ))
                    issue_undefined=1

                    grep -E "mv\ |rm\ " <<< $line &>/dev/null
                    if [ $? -eq 0 ]; then
                        grep -E "mv\ " <<< $line &>/dev/null
                        if [ $? -eq 0 ]; then
                            critical="mv"
                        else
                            critical="rm"
                        fi
                        echo -e \
                            "${cl_dr}[${cl_lr}!${cl_dr}]" \
                            "Line $current_line:\\tVariable" \
                            "'${cl_lr}\$$varname${cl_dr}'" \
                            "also in same line with"\
                            "'${cl_lr}$critical${cl_dr}' command${cl_n}"
                        count_critical=$(( count_critical + 1 ))
                    fi
                fi
            done
        fi
    done
done < $input_file

if [ $issue_noinit -eq 1 ] && [ $issue_undefined -eq 1 ]; then
    exit_code=4
elif [ $issue_noinit -eq 1 ]; then
    exit_code=5
elif [ $issue_undefined -eq 1 ]; then
    exit_code=6
fi

total_count=$(( count_critical + count_noinit + count_undefined ))
if [ $total_count -gt 0 ]; then
    echo
fi
echo -e "Analysis summary:"
echo
echo -e "  - Initially no values assigned: ${cl_yl}$count_noinit${cl_n}"
echo
echo -e "  - Possibly undefined variables: ${cl_lc}$count_undefined${cl_n}"
if [ $count_undefined -gt 0 ]; then
    if [ $count_critical -gt 0 ]; then
        cl_crit=$cl_lr
    else
        cl_crit=$cl_dy
    fi
    echo -e "  - In combination with critical commands:" \
            "${cl_crit}$count_critical${cl_n}"
fi
echo
echo -e "  - Lines processed total: ${cl_wh}$lines_total${cl_n}"
echo -e "  - Variable issues found: ${cl_wh}$total_count${cl_n}"
echo
echo -e "Finished."
echo
exit $exit_code

# EOF
