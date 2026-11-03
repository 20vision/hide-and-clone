#!/bin/bash
# Hide and Clone: 20-day usage check. Numbers go into Alex's daily digest mail.
set -euo pipefail
set -a; . ~/.config/track/box.env; set +a
q(){ curl -sf --max-time 30 "http://127.0.0.1:8123/?database=track" -u "${CH_USER:-default}:$CH_PASSWORD" --data-binary "$1"; }
W="ns='myclawn' AND bot=0 AND event LIKE 'clone_%' AND ts>now()-INTERVAL 20 DAY"
TOTAL=$(q "SELECT uniqExact(if(user_id!='',user_id,anon_key)),uniqExactIf(visit_id,event='clone_host'),countIf(event='clone_round_start'),countIf(event='clone_join_ok'),countIf(event='clone_site_click') FROM events_resolved WHERE $W FORMAT TSV")
read -r PEOPLE HOSTS ROUNDS JOINS CLICKS <<<"$TOTAL"
PLAT=$(q "SELECT JSONExtractString(props,'platform') p,os,uniqExact(visit_id) FROM events_resolved WHERE $W AND event='clone_online' GROUP BY p,os ORDER BY 3 DESC LIMIT 12 FORMAT TSV")
BODY="Hide and Clone, last 20 days
Players (daily-unique visitors): $PEOPLE
Games hosted: $HOSTS
Rounds played: $ROUNDS
Friends who joined: $JOINS
Clicks to myclawn.com: $CLICKS

By platform and system (sessions):
${PLAT:-none yet}

Live numbers: http://127.0.0.1:8092 (Hide and Clone card)
Target from MC-E25 in ~/phonewall/experiments/hypotheses.jsonl; review it now."
if [ "${DRY:-}" = 1 ]; then echo "$BODY"; else python3 ~/projects/watchers/bin/notify.py "Hide and Clone: 20-day usage check" "$BODY"; fi
