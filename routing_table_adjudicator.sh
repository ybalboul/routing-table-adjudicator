#!/bin/bash
progName="${0##*/}"

# Basic counter variables:
passed=0
count=0

# IP verification regex:
ipv4CIDRRegex='(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\/([1-3][0-2]$|[0-2][0-9]$|0?[0-9])$'
ipv4Regex='(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$'

# Operation mode bools (set by CLI switches):
add=false
remove=false
single=false
args=false

    ###  Functions  ###

infoLog()
{
    logger "${progName}: Info: ${1}"
    return "$?"
}

errLog(){
    echo "Error: ${1}" >&2
    logger "${progName}: Error: ${1}"
    return "$?"
}

verifyIPV4()
{
if [[ "$1" =~ ^$ipv4CIDRRegex ]] || [[ "$1" =~ ^$ipv4Regex ]]; then
    return 0
else
    return 1
fi
}

booleanIPV4()
{
    if [ "$1" == 0 ]; then
        return 0
    else
        return 1
    fi
}

routingTableAdd()
{
let "count++"
ip route add "${1}" via "${2}" 2>/dev/null

if [ "$?" != 0 ]; then
    infoLog "${1} could not be added"
    return 1
else
    let "passed++"
    return 0
fi
}

routingTableDel()
{
let "count++"
ip route del "${1}" via "${2}" 2>/dev/null

if [ "$?" != 0 ]; then
    infoLog "${1} could not be removed"
    return 1
else
    let "passed++"
    return 0
fi
}

fileCheck()
{
    if [ ! -f $1 ]; then
        errLog "File: $1 not found"
        exit 1
    fi

    return "$?"
}

helpMessage()
{
    echo "Reads in lst file containg CIDRs, then adds/removes CIDRs to/from routing table." >&2
    echo "Usage: ${progName} -a <lst file path> -g <ip address>" >&2
    echo "Syntax: ${progName} [-a,-r,-A,-R] [file path/single IP] -g [gateway]" >&2
    echo "-A [CIDR], adds a single CIDR" >&2
    echo "-R [CIDR], removes a single CIDR" >&2
    echo "-a [file path], adds CIDRs from text file" >&2
    echo "-r [file path], removes CIDRs contained in text file" >&2
    echo "-g [gateway address], Sets desired gateway (required)" >&2
    echo "-h, help message" >&2
}

if [ "$#" == 0 ]; then
    helpMessage
    exit 1
fi

while getopts "A:R:a:r:g:h" key; do
    case $key in
    A)
        ip=$OPTARG
        add=true
        single=true
        args=true
        ;;
    R)
        ip=$OPTARG
        remove=true
        single=true
        args=true
        ;;
    a)
        file=$OPTARG
        fileCheck "$file"
        add=true
        args=true
        ;;
    r)
        file=$OPTARG
        remove=true
        fileCheck "$file"
        args=true
        ;;
    g)
        gateway=$OPTARG
        ;;
    h)
        helpMessage
        exit 0
        ;;
	esac
done

# Check that we are root:
if [ "$UID" -gt 0 ]; then
    errLog "This script must be ran as root, exiting..."
exit 255
fi

# Check if a gateway is specified and an add/remove arguement is provided:
if [ -z "$gateway" ] || [ "$args" == false ]; then
    errLog "Error: You must specify -g (gateway) when adding/removing routes!"
    exit 1
fi

# Check if add & remove parameters are specified at the same time:
if [ $add == true ] && [ $remove == true ]; then
    errLog "Error: adding and removing are mutually exclusive!"
    exit 1
fi

if [ $single == false ]; then
    while read -r cidr
    do
        verifyIPV4 "$cidr"
        booleanIPV4 "$?"
        firstCheck=$?

        verifyIPV4 "$gateway"
        booleanIPV4 "$?"
        secondCheck=$?

        if [ $firstCheck == 0 ] && [ $secondCheck == 0 ]; then
            if [ $add == true ]; then
                routingTableAdd "$cidr" "$gateway"
            else
                routingTableDel "$cidr" "$gateway"
            fi
        else
            errLog "Incorrect format: ${cidr} via ${gateway}"
        fi
    done < $file
else
    verifyIPV4 "$ip"
    booleanIPV4 "$?"
    firstCheck=$?

    verifyIPV4 "$gateway"
    booleanIPV4 "$?"
    secondCheck=$?

    if [ $firstCheck == 0 ] && [ $secondCheck == 0 ]; then
        if [ $add == true ]; then
            routingTableAdd "$ip" "$gateway"
        else
            routingTableDel "$ip" "$gateway"
        fi
    else
        errLog "Incorrect format: ${ip} via ${gateway}"
    fi
fi

failed=$((count-passed))
infoLog "Total attempted: $count, Passed: $passed, Failed: $failed"

exit 0
