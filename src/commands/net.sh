#!/usr/bin/env bash
cmd_net() {
  local action=$1
  shift
  case "$action" in
    list)
      virsh net-list --all
      ;;
    create)
      local name=""
      local subnet=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --name) name="$2"; shift 2 ;;
          --subnet) subnet="$2"; shift 2 ;;
          *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
        esac
      done
      if [[ -z "$name" ]] || [[ -z "$subnet" ]]; then
        log_err $ERR_MISSING_PARAM "--name and --subnet required"
      fi
      local xml_file="/tmp/${name}.xml"
      local ip prefix range_start range_end
      ip=$(echo "$subnet" | cut -d/ -f1 | sed 's/\.0$/.1/')
      prefix=$(echo "$subnet" | cut -d/ -f2)
      range_start=$(echo "$subnet" | cut -d/ -f1 | sed 's/\.0$/.100/')
      range_end=$(echo "$subnet" | cut -d/ -f1 | sed 's/\.0$/.200/')
      cat <<EOF > "$xml_file"
<network>
  <name>$name</name>
  <forward mode='nat'/>
  <bridge name='virbr-$name' stp='on' delay='0'/>
  <ip address='$ip' prefix='$prefix'>
    <dhcp>
      <range start='$range_start' end='$range_end'/>
    </dhcp>
  </ip>
</network>
EOF
      virsh net-define "$xml_file" && virsh net-start "$name" && virsh net-autostart "$name" || log_err $ERR_NET_EXISTS "Network creation failed"
      rm -f "$xml_file"
      ;;
    delete)
      local name=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --name) name="$2"; shift 2 ;;
          *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
        esac
      done
      if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
      virsh net-destroy "$name" || true
      virsh net-undefine "$name" || true
      ;;
    *) log_err $ERR_UNKNOWN_OPT "Unknown net action: $action" ;;
  esac
}
