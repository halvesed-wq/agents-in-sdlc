#!/usr/bin/env bash
# Testa se a rede do ambiente Claude Code na nuvem libera os servidores MCP dos plugins.
# Uso:  bash testar-rede-plugins.sh            -> testa todos os hosts
#       bash testar-rede-plugins.sh --lista    -> só imprime os domínios (para "Allowed domains")
set -uo pipefail

# Servidores MCP remotos dos plugins instalados (plugin: host)
HOSTS=(
  # enterprise-search / productivity / human-resources
  mcp.slack.com mcp.notion.com mcp.api.getguru.com mcp.atlassian.com mcp.asana.com
  mcp.linear.app mcp.monday.com mcp.clickup.com
  # data
  bigquery.googleapis.com app.hex.tech mcp.amplitude.com mcp.eu.amplitude.com api.definite.app
  # finanças / research
  kfinance.kensho.com mcp.daloopa.com docs.daloopa.com api.analytics.lseg.com gatewaymcp.verisk.com
  # eddyter
  mcp.eddyter.com
  # small-business
  mcp.airwallex.com mcp.apollo.io mcp.canva.com api.clay.com mcp.docusign.com mcp.emergent.sh
  www.expensify.com gmailmcp.googleapis.com calendarmcp.googleapis.com drivemcp.googleapis.com
  mcp.api.gusto.com mcp.hubspot.com ai-inc.mailchimp.com ai-inc.quickbooks.intuit.com
  mcp.myob.com mcp.paypal.com mcp.ramp.com mcp.labs.ringcentral.com setup.shopify.com
  mcp.squareup.com mcp.stripe.com business-api.tiktok.com mcp.trello.com mcp.wix.com
  mcp.xero.com mcp.zapier.com claude-zohobooks.zohomcp.com claude-zohocrm.zohomcp.com
  claude-zohodesk.zohomcp.com claude-zohoprojects.zohomcp.com mcp.zoom.us
)

if [[ "${1:-}" == "--lista" ]]; then
  printf '%s\n' "${HOSTS[@]}"
  exit 0
fi

# 1) A rede geral está aberta? (com acesso Full, estes respondem)
echo "== Rede geral =="
for h in example.com www.google.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://$h/")
  if [[ "$code" == "000" ]]; then echo "  BLOQUEADO  $h"; else echo "  OK ($code)  $h"; fi
done

# 2) Cada servidor de plugin. Qualquer código HTTP (200, 401, 404...) significa que a rede
#    passou; "000" significa que o proxy recusou (403 de política) ou não houve resposta.
echo
echo "== Servidores dos plugins =="
ok=0; bloq=()
for h in "${HOSTS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://$h/")
  if [[ "$code" == "000" ]]; then
    printf '  BLOQUEADO  %s\n' "$h"; bloq+=("$h")
  else
    printf '  OK (%s)   %s\n' "$code" "$h"; ok=$((ok + 1))
  fi
done

echo
echo "== Resumo: $ok liberados, ${#bloq[@]} bloqueados de ${#HOSTS[@]} =="
if (( ${#bloq[@]} > 0 )); then
  echo "Adicione estes domínios em Network access > Allowed domains (ou use o nível Full):"
  printf '  %s\n' "${bloq[@]}"
  # O proxy da sessão registra o motivo das recusas mais recentes
  if [[ -n "${HTTPS_PROXY:-}" ]]; then
    echo
    echo "Últimas recusas registradas pelo proxy:"
    curl -s --max-time 5 "$HTTPS_PROXY/__agentproxy/status" \
      | python3 -c 'import json,sys
for f in json.load(sys.stdin).get("recentRelayFailures", [])[-5:]:
    print("  ", f.get("host"), "-", f.get("detail"))' 2>/dev/null
  fi
  exit 1
fi
