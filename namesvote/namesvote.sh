#!/bin/bash

set -e errexit -o pipefail

FN="Hanchar"
DB="namesvote.db"

IFS='
'

# if no sqlite DB exists bootstrap one based on names.txt (one name per line)
if [ ! -f "${DB}" ]; then
  sqlite3 "${DB}" "
    CREATE TABLE 'votes' (
      'name'	TEXT NOT NULL,
      'voter'	TEXT DEFAULT NULL,
      'vote'	INTEGER DEFAULT 0,
      'comment'	TEXT,
      'voted'	DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY('name','voter')
    );
    CREATE TRIGGER UpdateVoted AFTER UPDATE OF vote ON votes FOR EACH ROW
    BEGIN
      UPDATE votes SET voted=CURRENT_TIMESTAMP WHERE name = new.name AND voter = new.voter;
    END;"
  if [ -f names.txt ]; then
    while read -r name; do
      sqlite3 "${DB}" <<<"INSERT INTO votes (name, voted) VALUES ('${name}', NULL);"
    done < names.txt
  done
fi

echo 'Wer stimmt ab?'
PS3='Wähler*in anhand der Zahl auswählen oder Name eintippen: '
select voter in $(sqlite3 -noheader -list "${DB}" <<<"
  SELECT voter FROM votes WHERE voter IS NOT NULL GROUP BY voter;
  SELECT '${USER}';" | sort -u
); do
  if [ -z "${voter}" ]; then
    voter="${REPLY}"
  fi
  break
done

echo -e "\nHallo ${voter}!"
echo -e '\nAbstimmen mit von -2 bis 2 mit "+" und "-".'
echo -e "Bestätigen mit Enter. Kommentar mit c. Beenden mit q.\n"

while true; do
  name=""
  origvote=""
  origcomment=""
  while IFS=" " read -r key equals value; do
    case "${key}" in
      "name")    name="${value}";;
      "vote")    origvote=${value};;
      "comment") origcomment="${value}";;
    esac
  done <<<"$(sqlite3 -noheader -line "${DB}" <<<"SELECT a.name, b.vote, b.comment FROM votes a LEFT JOIN votes b ON a.name = b.name AND b.voter = '${voter}' ORDER BY b.voted ASC, b.voter DESC, b.name LIMIT 0,1;")"
  vote="${origvote:-0}"
  comment="${origcomment}"
  echo "Wie gefällt dir der Name ${name} ${FN}?"
  while true; do
    printf "\033[2KWertung: %2d Kommentar: %s\r" "${vote}" "${comment:--}"
    read -r -s -n1 key
    case "${key}" in
      "+"|"A") [ "${vote}" -lt  2 ] && : $((vote++));;
      "-"|"B") [ "${vote}" -gt -2 ] && : $((vote--));;
      "c"    ) echo; read -r -p 'Dein neuer Kommentar zu diesem Namen: ' comment;;
      "q"    ) echo; exit;;
      ""     ) break;;
    esac
  done
  echo -e '\n'
  sqlite3 "${DB}" "INSERT into votes(name, voter, vote, comment) VALUES ('${name}', '${voter}', ${vote}, '${comment}') ON CONFLICT (name, voter) DO UPDATE SET vote = excluded.vote, comment = excluded.comment;"
done
