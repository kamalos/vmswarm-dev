#!/usr/bin/env bash
# REGISTRY

registry_next_id() {
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo 1
    return
  fi
  local last_id
  last_id=$(awk -F, 'NR>1{print $1}' "$REGISTRY_FILE" | sort -n | tail -1)
  if [[ -z "$last_id" ]]; then
    echo 1
  else
    echo "$((last_id + 1))"
  fi
}

registry_add() {
  local name=$1
  local uuid=$2
  local ram=$3
  local cpus=$4
  local disk=$5
  local os=$6
  local net=$7
  local tags=$8
  local created=$9
  local ssh_user=${10}

  local id
  id=$(registry_next_id)
  echo "$id,$name,$uuid,$ram,$cpus,$disk,$os,$net,\"$tags\",$created,$ssh_user" >> "$REGISTRY_FILE"
}

registry_remove() {
  local name=$1
  local tmp_reg
  tmp_reg=$(mktemp)
  awk -F, -v name="$name" 'NR==1 {print} NR>1 && $2 != name {print}' "$REGISTRY_FILE" > "$tmp_reg"
  mv "$tmp_reg" "$REGISTRY_FILE"
}

registry_get_by_id() {
  local id=$1
  awk -F, -v id="$id" '$1 == id' "$REGISTRY_FILE"
}

registry_get_by_name() {
  local name=$1
  grep "^[0-9]*,${name}," "$REGISTRY_FILE" || true
}

registry_get_by_tag() {
  local tag=$1
  grep -E "^[0-9]+,[^,]+,[^,]+,[0-9]+,[0-9]+,[0-9]+,[^,]+,[^,]+,\"[^\"]*${tag}[^\"]*\"" "$REGISTRY_FILE" || true
}

registry_list_all() {
  cat "$REGISTRY_FILE"
}
