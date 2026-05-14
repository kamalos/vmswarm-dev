#!/usr/bin/env bash
cmd_tag() {
  local target=$1
  if [[ "$target" == "list" ]]; then
    local all_tags
    all_tags=$(tail -n +2 "$REGISTRY_FILE" | awk -F, '{print $9}' | tr -d '"' | tr ',' '\n' | grep -v '^$' | sort -u)
    for t in $all_tags; do
      local vms
      vms=$(registry_get_by_tag "$t" | awk -F, '{print $2}' | tr '\n' ',' | sed 's/,$//')
      echo "$t -> [$vms]"
    done
    return
  fi
  
  shift
  local add_tag=""
  local rem_tag=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --add) add_tag="$2"; shift 2 ;;
      --remove) rem_tag="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown tag option: $1" ;;
    esac
  done
  
  if [[ -z "$add_tag" ]] && [[ -z "$rem_tag" ]]; then
    log_err $ERR_MISSING_PARAM "Specify --add or --remove"
  fi
  
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    local row
    row=$(registry_get_by_name "$domain")
    if [[ -z "$row" ]]; then continue; fi
    
    local tags
    tags=$(echo "$row" | awk -F, '{print $9}' | tr -d '"')
    
    if [[ -n "$add_tag" ]]; then
      if [[ -z "$tags" ]]; then
        tags="$add_tag"
      elif [[ ! "$tags" =~ (^|,)($add_tag)(,|$) ]]; then
        tags="$tags,$add_tag"
      fi
    fi
    if [[ -n "$rem_tag" ]]; then
      local tag_arr
      IFS=',' read -ra tag_arr <<< "$tags"
      local new_tags=()
      for tg in "${tag_arr[@]}"; do
        if [[ "$tg" != "$rem_tag" ]]; then new_tags+=("$tg"); fi
      done
      tags=$(IFS=,; echo "${new_tags[*]}")
    fi
    
    local tmp_reg
    tmp_reg=$(mktemp)
    awk -F, -v d="$domain" -v t="$tags" 'OFS="," { if ($2 == d) $9="\"" t "\""; print }' "$REGISTRY_FILE" > "$tmp_reg"
    mv "$tmp_reg" "$REGISTRY_FILE"
    log_info "Updated tags for $domain to $tags"
  done
}
