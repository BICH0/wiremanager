#!/bin/bash
##Yet another wireguard manager written in pure bash
host="confugiradores.es"
#-----
##Colors
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
NC='\e[0;m'
#------
get_value(){
 local value=$(grep "$1" $cfile | awk '{print $3}')
 if [ -z "$value" ] && [ $2 -eq 1 ]
 then
    echo -e "${RED}[ERROR]${NC} No $1 in the config file ${cfile}, verify that the file is correct"
    exit 1
 else
    echo $value
 fi
}
handle_output(){
    if [ $1 -eq 0 ]
    then
        echo -e "${GREEN}[OK]${NC}"
    else
        echo -e "${RED}[ERROR]${NC}"
    fi
}
clear_file(){
    > ${cfile}.tmp
    local empty=0
    while read -r line
    do
        if [ -z "$line" ]
        then
            if [ $empty -eq 1 ]
            then
                echo "" >> ${cfile}.tmp
                empty=0
            else
                empty=1
            fi
        else
            if [ "$line" == "[Peer]" ]
            then
                echo "" >> ${cfile}.tmp
            fi
            echo $line >> ${cfile}.tmp
            empty=0
        fi
    done < $cfile
    mv ${cfile}.tmp $cfile
}
help(){
    echo '''  Wireguard manager by BiCH0 2024
    Available options:
        -h, --help: Print this screen
        -c, --conf: Specify the config file, default: /etc/wireguard/wg0.conf
        -a, --add: Add new client, peer or device, however you prefer to call it
        -d, --delete: Delete a peer by address, or public key
        -l, --list: List all peers
    '''
} 
increment_ip(){
    local mask=$1
    shift
    local ip=($@)
    local incremented=0
    for ((i=3;i>=0;i--))
    do
        if [ ${ip[$i]} -ge 254 ]
        then
            if [ $mask -ge 24 ]
            then
                break
            fi
            ip[$i]=0
            ip[$(($i-1))]=$((${ip[$(($i-1))]}+1))
            incremented=1
        elif [ $incremented -eq 1 ]
        then
            break
        else
            ip[$i]=$((${ip[$i]}+1))
            break
        fi
    done
    echo ${ip[@]}
}
fetch_ip(){
    local ips="$(grep "AllowedIPs" $cfile | awk '{print $3}' | cut -f1 -d'/' | sort -t . -k 3,3n -k 4,4n))"
    local mask=$(echo "$ip_net" | cut -f2 -d"/")
    local lastip=($(echo $ip_net | cut -f1 -d'/' | sed 's/\./ /g'))
    lastip[3]=1
    for ip in $ips
    do
        local ip_blocks=($(echo $ip | sed 's/\./ /g'))
        incremented=$(increment_ip $mask "${lastip[@]}")
        if [[ ! "${ip_blocks[@]}" == "${incremented[@]}" ]]
        then
            if [ -z $(echo "$ips" | grep "${incremented[@]// /.}") ]
            then
                res=$incremented
            else
                lastip=("${incremented[@]}")
                continue
            fi
            break
        fi
        lastip=(${ip_blocks[@]})
    done
    if [ -z "$res" ]
    then
        res=$(increment_ip $mask "${lastip[@]}")
    fi
    echo ${res[@]// /.}/${mask}
}
fetch_peer(){
    local peer=$1
    local peers="$(grep "\[Peer\]" -A6 $cfile)"
    if [[ "$peer" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]
    then
        res=$(echo "$peers" | grep "$peer" -B2 -A2 | grep "PublicKey" | awk '{print $3}')
    elif [[ ${peer: -1} == "=" ]]
    then
        res=$peer
    else
        if [ -f $cfile".names" ]
        then
            res=$(grep ${peer,,} $cfile".names" | cut -f1 -d":")
        fi
    fi
    if [ -z "$(echo "$peers" | grep "PublicKey = $res")" ]
    then
        return
    fi
    echo $res
}
verify_file(){
    if [ $(wc -l $1.tmp | cut -f1 -d" ") -eq 0 ]
    then
        echo -e "${RED}[ERROR]${NC} An error ocurred while deleting user, aborting"
        rm $1.tmp
        exit 1
    else
        mv $1.tmp $1
    fi
}
remove_peer(){
    local peer=$1
    cat $cfile | grep -n "PublicKey = $1" -B1 -A2 | sed -n 's/^\([0-9]\{1,\}\).*/\1d/p' | sed -f - $cfile > $cfile.tmp
    verify_file $cfile
    if [ -f ${cfile}.names ]
    then
        cat $cfile.names | grep -v "$1:" > $cfile.names.tmp
        verify_file $cfile.names
    fi
}
list_peers(){
    local name=""
    local pk=""
    local sk=""
    local ips=""
    echo -e "$(grep -A3 "\[Peer\]" $cfile)\n[Peer]" | while read -r line
    do
        title=$(echo $line | cut -f1 -d" ")
        value=$(echo $line | cut -f3 -d" ")
        case $title in
            "[Peer]")
                if [ -n "$pk" ]
                then
                    echo -e "\n${name^}: ${pk}\n   AllowedIPs: ${ips}${sk}"
                    unset name pk sk ips
                fi
            ;;
            "PublicKey")
                pk=$value
                if [ -f ${cfile}.names ]
                then
                    name="$(grep "$value" ${cfile}.names | cut -f2 -d":")"
                fi
                if [ -z $name ]
                then
                    name="Peer"
                fi
            ;;
            "PresharedKey")
                sk="\n   Preshared Key: ${value}"
            ;;
            "AllowedIPs")
                ips=$value
            ;;
        esac
    done
    if [ -z "$pk" ]
    then
        echo "No peers available"
    fi
}
fn_handler(){
    case $action in
        "a")
            echo "Creating new peer"
            local privatekey=$(wg genkey)
            local publickey=$(echo $privatekey | wg pubkey)
            local ip=$(fetch_ip)
            local name=$val
            if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]
            then
                echo "[ERROR] An error ocurred while fetching an available IP verify that all the ips on $cfile are valid"
                exit 1
            fi
            if [ -z "$name" ]
            then
                name="Peer"
            else
                if [ ! -f "${cfile}.names" ]
                then
                    echo -e "${YELLOW}[INFO]${NC} Creating pretty names file"
                fi
                if [ -n "$(grep "$name" $cfile.names)" ]
                then
                    local num=1
                    until [ -z "$(grep "$name.$num" $cfile.names)" ]
                    do
                        num=$(($num+1))
                    done
                    name=$name.$num
                fi
                echo $publickey:${name,,} >> $cfile.names
            fi
            local psk=""
            local psk_configured="No"
            while [[ ! ${psk,,} =~ ^y|n$ ]]
            do
                echo -n "Do you want to generate a preshared key? Y/n: "
                read -r psk
                if [ -z "$psk" ]
                then
                    psk="y"
                fi
            done
            if [ $psk == "y" ]
            then
                psk_configured="Yes"
                psk="\nPresharedKey = $(wg genpsk)"
            else
                psk=""
            fi
            local peer="[Peer]\nPublicKey = $publickey\nAllowedIPs = ${ip}${psk}"
            echo -e "\n$peer">>$cfile
            echo -e "\nCreated client [$name]:\n   IP: $ip    PSK: $psk_configured\n   PK: $privatekey\n   PUB: $publickey\n------------------------------------------------------\n"
            while [[ ! ${qr,,} =~ ^q|f$ ]]
            do
                echo -n "Do you want to generate (Q)rCode or (F)ile: "
                read -r qr

            done
            local client="[Interface]\nAddress = $ip\nListenPort = $port\nPrivateKey = $privatekey\n\n[Peer]\nPublicKey = $publickey${psk}\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = $endpoint"
            case ${qr,,} in
                "q")
                    echo -e "$client" | qrencode -s 1 -t ANSIUTF8
                    if [ $? -eq 0 ]
                    then
                        return
                    fi
                    echo -e "${RED}[ERROR]${NC} An error ocurred while generating the QRCode, check the error above"
                ;;
                "f")

                ;;
                *)
                    return
                ;;
            esac
            echo -e "$client" > ${name}_client.wg
            echo "Client stored in $(pwd)/${name}_client.wg"
        ;;
        "d")
            if [ -z $val ]
            then
                echo "You need to choose a name, ip or public key to delete that peer"
                exit 1
            fi
            local peer=$(fetch_peer $val)
            if [ -z "$peer" ]
            then
                echo -e "${RED}[ERROR]${NC} Peer not found"
                exit 1
            fi
            echo -n "Removing peer [ $peer ] "
            remove_peer $peer
            handle_output $?
        ;;
        "l")
            list_peers
        ;;
    esac
}
main(){
    cfile="/etc/wireguard/wg0.conf"
    action=""
    val=""
    while [ $# -gt 0 ]
    do
        case "$1" in
            "-c"|"--conf")
                shift
                if [ -f $1 ]
                then
                    echo "Using config file [$1]"
                    cfile="$1"
                    shift
                else
                    echo "Invalid config file"
                    exit 1
                fi
            ;;
            "-a"|"--add"|"add"|\
            "-d"|"--delete"|"del"|"delete"|\
            "-l"|"--list"|"list")
                if [ -z "$action" ]
                then
                    action=$(echo "$1" | tr -d "-" | cut -c1)
                    shift
                    if [[ ! "$1" =~ ^- ]]
                    then
                        val="$1"
                        shift
                    fi
                else
                    echo "Invalid command, use 'wiremanager [--config file] <action> [value]'"
                    exit 1
                fi
            ;;
            *)
                help
                exit 0
            ;;
        esac
    done
    if [ ! -w $cfile ]
    then
        echo -e "[ERROR] Config file $cfile is not writable or doesn't exist"
        exit 1
    fi
    if [ -n "$action" ]
    then
        clear_file
        port=$(get_value "ListenPort" 1)
        ip_net=$(get_value "Address" 1)
        if ! wg -h &>/dev/null
        then
            echo -e "${RED}[ERROR]${NC} Wireguard not installed or not found"
            exit 1
        fi
        if [[ ! $ip_net =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$ ]]
        then
            echo -e "${RED}[ERROR]${NC} Invalid IP $ip_net in config file $cfile"
            exit 1
        fi
        endpoint=${host}:${port}
        fn_handler
    else    
        help
    fi
}
main $@
