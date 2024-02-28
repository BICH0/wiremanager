#!/bin/bash
##Yet another wireguard manager written in pure bash
ip_net="10.0.0.0"
port=51820
host="confugiradores.es"
####
endpoint=${host}:${port}
clear_file(){
    echo "Cleaning file"
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
    local ips_mask="$(grep "AllowedIPs" $cfile | awk '{print $3}')"
    local ips="$(echo "$ips_mask" | cut -f1 -d'/' | sort -t . -k 3,3n -k 4,4n)"
    local mask=$(echo "$ips_mask" | head -1 | cut -f2 -d"/")
    unset ips_mask
    local lastip=($(echo $ips | cut -f1 -d" " | sed 's/\./ /g'))
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
    return
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
            res=$(grep $peer $cfile".names" | cut -f1 -d":")
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
        echo "An error ocurred while deleting user, aborting"
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
    #Format [NAME] PK -> IP
}
fn_handler(){
    case $action in
        "a")
            echo "Creating new peer"
            local privatekey=$(wg genkey)
            local publickey=$(echo $privatekey | wg pubkey)
            local ip=$(fetch_ip)
            local name=$val
            if [ -z "$name" ]
            then
                name="Peer"
            else
                if [ ! -f "${cfile}.names" ]
                then
                    echo "[INFO] Creating pretty names file"
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
                echo $publickey:$name >> $cfile.names
            fi
            local peer="[Peer]\nPublicKey = $publickey\nAllowedIPs = $ip"
            echo -e "\n$peer">>$cfile
            echo -e "Created client [$name]:\n   IP: $ip\n   PK: $privatekey\n   PUB: $publickey\n------------------------------------------------------"
            while [[ ! ${qr,,} =~ ^q|f$ ]]
            do
                echo -n "Do you want to generate (Q)rCode or (F)ile: "
                read -r qr

            done
            clear
            local client="[Interface]\nAddress = $ip\nListenPort = $port\nPrivateKey = $privatekey\n\n[Peer]\nPublicKey = $publickey\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = $endpoint"
            case ${qr,,} in
                "q")
                    echo -e "$client" | qrencode -s 1 -t ANSIUTF8
                ;;
                "f")
                    echo -e "$client" > ${name}_client.wg
                    echo "Client stored in $(pwd)/${name}_client.wg"
                ;;
            esac
        ;;
        "d")
            if [ -z $val ]
            then
                echo "You need to choose a name, ip or public key to delete that peer"
                exit 1
            fi
            echo "Fetching peer..."
            local peer=$(fetch_peer $val)
            if [ -z "$peer" ]
            then
                echo "[ERROR] Peer not found"
                exit 1
            fi
            echo "Removing peer [ $peer ]..."
            remove_peer $peer
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
    clear_file
    if [ -n $action ]
    then
        fn_handler
    else    
        help
    fi
}
main $@