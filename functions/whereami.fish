
function whereami -d "determine your current network and IP address"
  set -l INTERFACES (ifconfig -l -u | sed 's/ /\n/g')

  set -l HWPORTS "$(networksetup -listallhardwareports)"
  set -l RESULTS "[]"

  for ifx in $INTERFACES
    if echo "$ifx" | egrep '^(?:awdl|ap|llw|bridge|lo)\d' > /dev/null
      continue
    end

    set -l ifdata "$(ifconfig $ifx)"
    set -l ifstat (echo "$ifdata" | grep 'status' | awk '{print $2}')
    set -l ifip (echo "$ifdata" | grep 'inet ' | awk '{print $2}')
    set -l ifmac (echo "$ifdata" | grep 'ether ' | awk '{print $2}')

    if test "$ifstat" = 'inactive' -o -z "$ifip"
      continue
    end

    set -l iftyp (echo "$HWPORTS" | grep "Device: $ifx" -B1 | head -1 | awk '{print $3}')
    if test -z "$iftyp"
      set iftyp "Unknown"
    end

    set -l obj (jq -cn \
      --arg interface "$ifx" \
      --arg ipv4 "$ifip" \
      --arg mac "$ifmac" \
      --arg "type" "$iftyp" \
      '$ARGS.named')

    if test "$iftyp" = "Wi-Fi"
      set -l ifwpower (networksetup -getairportpower "$ifx" | sed -E 's/^.+: //g')
      if test "$ifwpower" = "On"
        set -l ifwnet (networksetup -getairportnetwork "$ifx" | sed -E 's/^.+: //g')
        set obj (jqv "$obj" -c ".network |= \"$ifwnet\"")
      end
    end

    set RESULTS (jqv "$RESULTS" -c ". + [$obj]")
  end

  if test "$argv[1]" = '--json'
    if test "$(count $argv)" -gt 1
      jqv "$RESULTS" $argv[2..]
    else
      jqv "$RESULTS" '.'
    end
    return 0
  end

  jqv "$RESULTS" -c '.[]' | while read entry
    set -l kind (jqv "$entry" -rc '.type')
    set -l ip (jqv "$entry" -rc '.ipv4')
    set -l mac (jqv "$entry" -rc '.mac')
    set -l name (jqv "$entry" -rc '.interface')

    switch $kind
      case "Wi-Fi"
        echo -en "Wi-Fi interface \e[1m$name\e[0m \e[90m(MAC address $mac)\e[0m is connected to network \e[32m"
        echo -n (jqv "$entry" -rc '.network')
        echo -e "\e[0m with IP \e[33m$ip\e[0m"
      case "Unknown"
        echo -e "Interface \e[1m$name\e[0m is online and has IP \e[33m$ip\e[0m"
      case '*'
        echo -e "$kind interface \e[1m$name\e[0m \e[90m(MAC address $mac)\e[0m is online and has IP \e[33m$ip\e[0m"
    end
  end
end
