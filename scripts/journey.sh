#!/usr/bin/env bash
set -euo pipefail

BASE=${BASE:-http://library.localhost}
RUN=$(date +%s)
TODAY=$(date +%Y-%m-%d)

req() {
  local method=$1 path=$2 data=${3:-} out code
  out=$(curl -sS -X "$method" -H 'Content-Type: application/json' ${data:+-d "$data"} -w $'\n%{http_code}' "$BASE$path")
  code=${out##*$'\n'}
  BODY=${out%$'\n'*}
  printf '%-6s %-36s %s\n' "$method" "$path" "$code"
  [[ $code == 2* ]] || { echo "$BODY"; exit 1; }
}

field() { grep -o "\"$1\":[0-9]*" <<<"$BODY" | head -1 | cut -d: -f2; }

req POST /author "{\"name\":\"Author $RUN\"}"
AUTHOR=$(field id)

req POST /book "{\"title\":\"Book-$RUN\",\"authorId\":$AUTHOR,\"genre\":\"FICTION\",\"publicationDate\":\"2020-01-01\",\"isbn\":\"978-$RUN\"}"
BOOK=$(field bookId)

req GET "/book/title/Book-$RUN"

req POST /patron "{\"name\":\"Patron $RUN\",\"email\":\"patron$RUN@example.com\",\"registrationDate\":\"$TODAY\"}"
PATRON=$(field patronID)

req POST /lending "{\"bookTitle\":\"Book-$RUN\",\"patronID\":$PATRON,\"dateBorrowed\":\"$TODAY\",\"dueDate\":\"2099-01-01\",\"lendingStatus\":\"BORROWED\"}"
LENDING=$(field lendingID)

req GET "/lending/patron/$PATRON"
grep -q '"BORROWED"' <<<"$BODY"

req PUT "/lending/$LENDING" "{\"bookTitle\":\"Book-$RUN\",\"patronID\":$PATRON,\"dateBorrowed\":\"$TODAY\",\"dueDate\":\"2099-01-01\",\"dateReturned\":\"$TODAY\",\"lendingStatus\":\"RETURNED\"}"

req GET "/lending/$LENDING"
grep -q '"RETURNED"' <<<"$BODY"

echo "journey ok: author=$AUTHOR book=$BOOK patron=$PATRON lending=$LENDING"
