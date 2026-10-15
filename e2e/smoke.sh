#!/usr/bin/env bash
# smoke e2e: the same script against the jar and the native image. every module the sample ships writes and
# reads back what it keeps as jsonb, so a missing native hint fails here (wasichai ADR-068).
# usage: BASE_URL=http://localhost:8090 e2e/smoke.sh
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8090}"
RUN="s$(date +%s)"
OBJ="predio_${RUN}"
TOKEN=""
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# call METHOD PATH EXPECTED_STATUS [JSON_BODY] -> body in $BODY_FILE
call() {
    local method=$1 path=$2 expected=$3 body=${4:-}
    # names are tenant-wide: every run gets its own (RUNID in a single-quoted body)
    body=${body//RUNID/$RUN}
    local args=(-sS -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE_URL$path" -H 'Accept: application/json')
    [[ -n $TOKEN ]] && args+=(-H "Authorization: Bearer $TOKEN")
    [[ -n $body ]] && args+=(-H 'Content-Type: application/json' -d "$body")
    local status
    status=$(curl "${args[@]}")
    [[ $status == "$expected" ]] || fail "$method $path: expected $expected, got $status: $(head -c 600 "$BODY_FILE")"
    echo "ok  $method $path"
}

json() { jq -r "$1" "$BODY_FILE"; }

# wait for the app: migrations run before it listens
for _ in $(seq 1 60); do
    curl -sf "$BASE_URL/api/health" >/dev/null && break
    sleep 1
done
call GET /api/health 200

call POST /api/auth/login 200 '{"email":"admin@wasichai.local","password":"admin"}'
TOKEN=$(json .token)
[[ -n $TOKEN && $TOKEN != null ]] || fail "no token"

# core: an object with a date, a geometry (gis) and a file (files)
call POST /api/objects 201 "{
  \"name\": \"$OBJ\", \"label\": \"Predio\", \"pluralLabel\": \"Predios\",
  \"fields\": [
    {\"name\": \"codigo\", \"type\": \"TEXT\", \"required\": true},
    {\"name\": \"area\", \"type\": \"DECIMAL\"},
    {\"name\": \"revisado\", \"type\": \"TEXT\"},
    {\"name\": \"vigencia\", \"type\": \"DATE\"},
    {\"name\": \"lote\", \"type\": \"GEOMETRY\", \"geometryType\": \"POINT\", \"srid\": 4326},
    {\"name\": \"acta\", \"type\": \"FILE\"}
  ]
}"
call GET "/api/objects/$OBJ" 200

# workflow
call PUT "/api/objects/$OBJ/workflow" 200 '{
  "name": "aprobacion_RUNID", "label": "Aprobación", "enabled": true,
  "definition": {
    "states": [
      {"name": "draft", "label": "Borrador", "type": "INITIAL"},
      {"name": "approved", "label": "Aprobado", "type": "FINAL"}
    ],
    "transitions": [{"name": "approve", "label": "Aprobar", "from": "draft", "to": "approved"}]
  }
}'
call GET "/api/objects/$OBJ/workflow" 200
[[ $(json '.definition.states | length') == 2 ]] || fail "workflow read back"

# automation: marks every new record, so a run reads its definition and writes its payload
call POST "/api/objects/$OBJ/automations" 201 '{
  "name": "marca_RUNID", "label": "Marca", "enabled": true,
  "definition": {
    "trigger": {"type": "RECORD_CREATED"},
    "conditions": [{"field": "area", "operator": "GREATER_THAN", "value": "10"}],
    "actions": [{"type": "UPDATE_FIELD", "field": "revisado", "value": "{{codigo}} ok"}]
  }
}'
call GET "/api/objects/$OBJ/automations/marca_$RUN" 200

# views, forms, pages
call POST "/api/objects/$OBJ/views" 201 '{
  "name": "grandes_RUNID", "label": "Grandes",
  "definition": {"columns": ["codigo", "area"], "filters": {}, "sort": {"field": "codigo", "direction": "ASC"}, "pageSize": 25}
}'
call GET "/api/objects/$OBJ/views/grandes_$RUN" 200
call POST "/api/objects/$OBJ/forms" 201 '{
  "name": "alta_RUNID", "label": "Alta",
  "definition": {"sections": [{"title": "Datos", "fields": ["codigo", "area"]}]}
}'
call GET "/api/objects/$OBJ/forms/alta_$RUN" 200
call GET "/api/objects/$OBJ/pages/record-detail" 200
PAGE=$(jq -c --arg name "${OBJ}-detalle" '{name: $name, label: .label, objectName: .objectName, kind: .kind,
  template: .template.name, definition: .definition}' "$BODY_FILE")
call POST /api/pages 201 "$PAGE"
call GET "/api/pages/${OBJ}-detalle" 200

# documents
call POST "/api/objects/$OBJ/document-types" 201 "{
  \"name\": \"oficio_$RUN\", \"label\": \"Oficio\", \"prefix\": \"S${RUN: -6}\",
  \"template\": {\"type\": \"doc\", \"content\": [{\"type\": \"paragraph\", \"content\": [
    {\"type\": \"text\", \"text\": \"Predio \"}, {\"type\": \"objectField\", \"attrs\": {\"field\": \"codigo\"}}]}]}
}"
call GET "/api/objects/$OBJ/document-types/oficio_$RUN" 200

# notifications: a date rule
call POST "/api/objects/$OBJ/notification-rules" 201 '{
  "name": "por_vencer_RUNID", "label": "Por vencer", "enabled": true, "field": "vigencia",
  "stages": [{"fromDays": -15, "kind": "WARNING"}], "untilDays": 3,
  "audience": [{"type": "ROLE", "value": "ADMIN"}],
  "title": "{{codigo}} vence el {{date}}", "body": "Quedan {{days}} días."
}'
call GET "/api/objects/$OBJ/notification-rules/por_vencer_$RUN" 200

# records: geometry in, transition, document, file
VIGENCIA=$(date -u -d '+5 days' +%F)
call POST "/api/objects/$OBJ/records" 201 "{
  \"attributes\": {\"codigo\": \"P-001\", \"area\": 850.5, \"vigencia\": \"$VIGENCIA\"},
  \"geometries\": {\"lote\": {\"type\": \"Point\", \"coordinates\": [-77.05, -12.05]}}
}"
ID=$(json .id)
call GET "/api/objects/$OBJ/records/$ID" 200
[[ $(json .geometries.lote.type) == Point ]] || fail "geometry read back"
call GET "/api/gis/objects/$OBJ/features/$ID?geometry=lote" 200

call POST "/api/objects/$OBJ/records/$ID/transitions/approve" 200
call POST "/api/objects/$OBJ/records/$ID/documents/oficio_$RUN" 201
DOC=$(json .id)
call GET "/api/documents/$DOC" 200

status=$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
    -F "file=@$0;type=text/plain" "$BASE_URL/api/objects/$OBJ/records/$ID/files/acta")
[[ $status == 200 ]] || fail "file upload: $status: $(head -c 600 "$BODY_FILE")"
echo "ok  POST /api/objects/$OBJ/records/$ID/files/acta"
call GET "/api/objects/$OBJ/records/$ID/files/acta" 200

# the automation ran (async: after the create commits) and finished
for _ in $(seq 1 30); do
    call GET "/api/objects/$OBJ/automations/marca_$RUN/runs?limit=5" 200 >/dev/null
    [[ $(json '[.[] | select(.status == "SUCCEEDED" or .status == "FAILED")] | length') -ge 1 ]] && break
    sleep 1
done
[[ $(json '.[0].status') == SUCCEEDED ]] || fail "automation run did not succeed: $(json '.[0]')"
call GET "/api/objects/$OBJ/records/$ID" 200
[[ $(json .attributes.revisado) == "P-001 ok" ]] || fail "automation did not mark the record: $(json .attributes)"

# notification rules list and the audit trail
call GET /api/notification-rules 200
call GET "/api/objects/$OBJ/records/$ID/history" 200

echo "smoke passed against $BASE_URL"
