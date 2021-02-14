#!/usr/bin/env bash

# Logs activity of a Glowforge laser cutter to glowforge.log.
#
# You need to fill the correct _gf_user_session cookie (instead of CHANGEME),
# taken from the web interface into the curl command below!

log="glowforge.log"
# currentts,lcserial,lcname,lcstate,lastprintts,printid,printtitle,printstatus,printuser,printcreatedts,printstartedts,warmupsec,printsec,cooldownsec,failurereason

function getAccounting {
    curl -s -H 'Cookie: _gf_user_session=CHANGEME' 'https://app.glowforge.com/api/users/machines' | jq -r '[ .machines[] |
        (
        .serial,
        .display_name,
        .state,
        .last_print_at
        ),
        ( .active_print | 
        (.id // "" | tostring),
        .title // "",
        .status // "",
        .username // "",
        .created_at // "",
        .started_at // "",
        (.warmup_period // "" | tostring),
        (.duration // "" | tostring),
        (.cooldown_period // "" | tostring),
        .failure_reason // ""
        ) ] | join(",") ' | \
        while IFS=, read -a line
        do
            for datefield in 3 8 9
            do
                # correct timezone to UTC in date fields
                if [ -n "${line[${datefield}]}" ]
                then
                    line[${datefield}]="$(date -uIs -d "${line[${datefield}]}")"
                fi
            done
            IFS=,
            echo "${line[*]}"
        done
}

while sleep 10
do
  acc="$(getAccounting)"
  if [ -n "${acc}" -a "${acc}" != "$(tail -1 "${log}" | cut -d, -f2-)" ]
  then
    echo "$(date -uIs),${acc}" >> "${log}"
  fi
done
